
[:heart: Sponsor](https://github.com/sponsors/escamoteur) <a href="https://www.buymeacoffee.com/escamoteur" target="_blank"><img align="right" src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# watch_it
A simple state management solution powered by get_it.

>This package is the successor of the get_it_mixin, [here you can find what's new](#whats-different-from-the-get_it_mixin)

This package offers a set of functions to `watch` data registered with `GetIt`. Widgets that watch data will rebuild automatically whenever that data changes. 

Supported data types that can be watched are `Listenable / ChangeNotifier`, `ValueListenable / ValueNotifier`, `Stream` and `Future`. On top off that there are several other powerful function to use in `StatelessWidgets` that normally would require a `StatefulWidget` 

`ChangeNotifier` based example:
```dart
 // Create a ChangeNotifier based model
 class UserModel extends ChangeNotifier {
   get name = _name;
   String _name = '';
   set name(String value){
     _name = value;
     notifyListeners();
   }
   ...
 }

 // Register it
 di.registerSingleton<UserModel>(UserModel());

 // Watch it
 class UserNameText extends WatchingWidget {
   @override
   Widget build(BuildContext context) {
     final userName = watchPropertyValue((UserModel m) => m.name);
     return Text(userName);
   }
 }
```
Whenever the name property changes the `watchPropertyValue` function will trigger a rebuild and return the latest value of `name`.
## Accessing GetIt

WatchIt exports the default instance of get_it as a global variable `di` (**d**ependency **i**njection) which lets
you access it from anywhere in your app. To access any get_it registered
object you only have to type `di<MyType>()` instead of `GetIt.I<MyType>()`.
If you prefer to use `GetIt.I` or you have your own global variable that's fine too as they all
will use the same instance of GetIt.

If you want to use a different instance of get_it you can pass it to
the functions of this library as an optional parameter.


## Watching Data

Where `WatchIt` really shines is data-binding. It comes with a set of `watch` methods to rebuild a widget when data changes.

Imagine you had a very simple shared model, with multiple fields, one of them being country:
```dart
class Model {
    final country = ValueNotifier<String>('Canada');
    ...
}
di.registerSingleton<Model>(Model());
```
You could tell your view to rebuild any time country changes with a simple call to `watchValue`:
```dart
class MyWidget extends StatelessWidget with GetItStatefulWidgetMixin {
  @override
  Widget build(BuildContext context) {
    String country = watchValue((Model x) => x.country);
    ...
  }
}
```
There are various `watch` methods, for common types of data sources, including `ChangeNotifier`, `ValueNotifier`, `Stream` and `Future`:

| API  | Description  |
|---|---|
| `watch` | observes any Listenable you have access to
| `watchIt` | observes any Listenable registered in get_it
| `watchValue` | observes a ValueListenable property of an object registered in get_it
| `watchPropertyValue` | observes a property of a Listenable object and trigger a rebuild whenever the Listenable notifies a change and the value of the property changes
| `watchStream` | observes a Stream and triggers a rebuild whenever the Stream emits a new value
| `watchFuture` | observes a Future and triggers a rebuild whenever the Future completes

To be able to use the functions you have either to derive your widget from
`WatchingWidget` or `WatchingStatefulWidget` or use the `WatchItMixin` in your widget class and call the watch functions inside the their build functions.

Just call `watch*` to listen to the data type you need, and `WatchIt` will take care of cancelling bindings and subscriptions when the widget is destroyed.

The primary benefit to the `watch` methods is that they eliminate the need for `ValueListenableBuilders`, `StreamBuilder` etc. Each binding consumes only one line and there is no nesting. Making your code more readable and maintainable. Especially if you want to bind more than one variable.

Here we watch three `ValueListenable` which would normally be three builders, 12+ lines of code and several levels of indentation. With `WatchIt`, it's three lines:
```dart
class MyWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    bool loggedIn = watchValue((UserModel x) => x.isLoggedIn);
    String userName = watchValue((UserModel x) => x.user.name);
    bool darkMode = watchValue((SettingsModel x) => x.darkMode);
    ...
  }
}
```
This can be used to eliminate `StreamBuilder` and `FutureBuilder` from your UI as well:
```dart
class MyWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    final currentUser = watchStream((UserModel x) => x.userNameUpdates, initialValue: 'NoUser');
    final ready = watchFuture((AppModel x) => x.initializationReady, initialValue: false).data;
    bool appIsLoading = ready == false || currentUser.hasData == false;
    
    if(appIsLoading) return CircularProgressIndicator();
    return Text(currentUser.data);    
  }
}
```

### Side Effects / Event Handlers

Instead of rebuilding, you might instead want to show a toast notification or dialog when a Stream emits a value or a ValueListenable changes. Normally you would need to use a `Stateful` widget to be able to subscribe and unsubscribe your handler function.

To run an action when data changes you can use the `register*Handler` methods:

| API  | Description  |
|---|---|
| `.registerHandler`  | Add an event handler for a `ValueListenable`  |
| `.registerStreamHandler`  | Add an event handler for a `Stream`  |
| `.registerFutureHandler`  | Add an event handler for a `Future`  |

All these `register` methods have an optional `select` delegate parameter that can be used to watch a specific field of an object in GetIt. The second parameter is the action which will be triggered when that field changes:
```dart
class MyWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    registerHandler(
        select: (Model x) => x.name,
        handler: (context, value, cancel) => showNameDialog(context, value));
    ...
  }
}
```

In the example above you see that the handler function receives the value that is returned from the select delegate (`(Model x) => x.name`), as well as a `cancel` function that the handler can call to cancel registration at any time.

As with `watch` calls, all `registerHandler` calls are cleaned up when the Widget is destroyed. If you want to register a handler for a local variable all the functions offer a `target` parameter.

# Rules

There are some important rules to follow in order to avoid bugs with the `watch` or `register*` methods:
* `watch` methods must be called within `build()`
  * It is good practice to define them at the top of your build method
* must be called on every build, in the same order (no conditional watching). This is similar to `flutter_hooks`.
* do not use them inside of a builder as it will break the mixins ability to rebuild

If you want to know more about the reasons for this rule check out [Lifting the magic curtain](#lifting-the-magic-curtain)

# The watch functions in detail:

## `watch()`
`watch` observes any `Listenable` that you pass as parameter and triggers a rebuild whenever it notifies a change. 
```dart
T watch<T extends Listenable>(T target);
```
That listenable could be passed in as a parameter or be accessed via get_it. Like `final userName = watch(di<UserManager>()).userName;` given that `UserManager` is a `Listenable` (eg. `ChangeNotifier`).
If all of the following functions don't fit your needs you can probably use this one by manually providing the Listenable that should be observed.

## `watchIt`

`watchIt` observes any Listenable registered with the type `T` in get_it and triggers a rebuild whenever it notifies a change. Its basically a shortcut for `watch(di<T>())`.
`instanceName` is the optional name of the instance if you registered it
with a name in get_it.
`getIt` is the optional instance of get_it to use if you don't want to use the
default one. 99% of the time you won't need this.
```dart
T watchIt<T extends Listenable>({String? instanceName, GetIt? getIt}) {
```
If we take our Listenable `UserManager` from above we could watch it like
```dart
class MyWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    final userName = watchIt<UserManager>().name;
    return Text(userName);
  }

}
```

## `watchPropertyValue`
If the listenable parent object that you watch with `watchIt` notifies often because other properties have changed that you don't want to watch, the widget would rebuild without any need. In this case you can use `watchPropertyValue`
```dart
R watchPropertyValue<T extends Listenable, R>(R Function(T) selectProperty,
    {T? target, String? instanceName, GetIt? getIt});
```
It will only trigger a rebuild if the watched listenable notifies a change AND the value of the selected property has really changed.
```dart
final userName = watchPropertyValue<UserManager, String>((user) => user.userName);
```
Could be an example. Or even more expressive and concise:
```dart
final userName = watchPropertyValue((UserManager user) => user.userName);
```
which lets the analyzer infer the type of T and R.

If you have a local Listenable and you want to observe only a single property
you can pass it as [target].

## `watchValue`
```dart
R watchValue<T extends Object, R>(ValueListenable<R> Function(T) selectProperty,
    {String? instanceName, GetIt? getIt}) {
```
`watchValue` observes a `ValueListenable` (e.g. a `ValueNotifier`) property of an object registered in get_it.
It triggers a rebuild whenever the `ValueListenable` notifies a change and returns its current
value. It's basically a shortcut for `watchIt<T>().value`
As this is a common scenario it allows us a type safe concise way to do this.
```dart
final userName = watchValue<UserManager, String>((user) => user.userName);
```
is an example of how to use it.
We can use the strength of generics to infer the type of the property and write
it even more expressive like this:

```dart
final userName = watchValue((UserManager user) => user.userName);`
```

`instanceName` is the optional name of the instance if you registered it
with a name in get_it.
`getIt` is the optional instance of get_it to use if you don't want to use the
default one. 99% of the time you won't need this.

# `watchStream and watchFuture`
They follow the same pattern. Please check the API docs for details

# __isReady<T>() and allReady()__
A common use case is to toggle a loading state when side effects are in-progress. To check whether any async registration actions inside `GetIt` have completed you can use `allReady()` and `isReady<T>()`. These methods return the current state of any registered async operations and a rebuild is triggered when they change.
```dart
class MyWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    allReady(onReady: (context)
      => Navigator.of(context).pushReplacement(MainPageRoute()));
    return CircularProgressIndicator();
  }
}
```

Check out the GetIt docs for more information on the `isReady` and `allReady` functionality:
https://pub.dev/packages/get_it

# Pushing a new GetIt Scope

With `pushScope()` you can push a scope when a Widget/State is mounted, and automatically dropped when the Widget/State is destroyed. You can pass an optional init or dispose function.
```dart
  void pushScope({void Function(GetIt getIt) init, void Function() dispose});
```
The newly created Scope gets a unique name so that it is ensured the right Scope is dropped even if you push or drop manually other Scopes.

# The WatchingWidgets
Some people don't like mixins so `WatchIt` offers two Widgets that can be used instead. 
* `WatchingWidget` - can be used instead of `StatelessWidget`
* `WatchingStatefulWidget` - instead of `StatefulWidget`

# Lifting the magic curtain
*It's not necessary to understand the following chapter to use `WatchIt` sucessfully.
You might be wondering how on earth is this possible, that you can watch multiple objects at the same time without passing some identifier to any of the `watch` functions. The reality might feel a bit like a hack but the advantages that you get from it justify it abolutely.
When applying the `WatchItMixin` to a Widget you add a handler into the build mechanism of Flutter that makes sure that before the `build` function is called a `_watchItState` object that contains a reference to the `Element` of this widget plus a list of `WatchEntry`s is assigned to a private global variable. Over this global variable the `watch*` functions can access the `Element` to trigger a rebuild.
With each `watch*` function call a new `WatchEntry` is added to that list and a counter is incremented.
When a rebuild is triggered the counter is reset and incremented again with each `watch*` call so that it can access the data it stored during the last build.
Now it should be clear why the `watch*` functions always have to happen in the same order and no conditionals are allowed that would change the order between two builds because then the relation between `watch*` call and its `WatchEntry` would be messed up.
If you think that all sounds very familiar to you then probably because the exactly same mechanism is used by `flutter_hooks` or React Hooks.

# Find out more!

To learn more about GetIt, watch the presentation: [GetIt in action By Thomas Burkhart](https://youtu.be/YJ52kSfSMyM), in there the predecessor of this package called ´get_it_mixin´ is described but the video should still be helpful for the GetIt part.

## What's different from the `get_it_mixin`
Two main reasons lead me to replace the `get_it_mixin` package with `watch_it`
* The name `get_it_mixin seemed not to catch with people and only a fraction of my get_it users used is.
* The API naming wasn't as intuitive as I thought when first wrote them.

These are the main differences:
* Widgets now can be `const`!
* a reduced API with more intuitive naming.The old package had too many functions which were only slight variations of each others. You can easily achieve the same functionality with the functions of this package.
* no `get/getX` functions anymore because you can just use the included global `get_it` instance `di<T>`.
* only one mixin for all Widgets. You only need to apply it to the widget and no mixin for `States` as no all `watch*` functions are global functions.

Please let me know if you miss anything