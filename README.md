**This describes the old get_it_mixin API. It's here as a reference and for all new to this API**

# get_it_mixin

A set of mixins that allow widgets to `watch` data registered with `GetIt`. Widgets that watch data will rebuild automatically whenever that data changes. 

Supported data types that can be watched are `ChangeNotifier`, `ValueNotifier`, `Stream` and `Future`.

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
getIt.registerSingleton<UserModel>(UserModel());

// Watch it
class UserNameText extends StatelessWidget with GetItMixin {
  @override
  Widget build(BuildContext context) {
    final userName = watchOnly((UserModel m) => m.name);
    return Text(userName);
  }
}
```
## Reading Data

Reading data is already quite easy with `GetIt`, but it gets even easier with the mixin. Just add a `GetItMixin` to a `StatelessWidget` and call `get<T>`:
```dart
class MyWidget extends StatelessWidget with GetItMixin {
  void _handleSubmitPressed() {
    final email = get<Model>().emailAddress;
    ...
  }
}
```

You can do the same thing on `StatefulWidget` using a `GetItStatefulWidgetMixin` and `GetItStateMixin`:
```dart
class MyWidget extends StatefulWidget with GetItStatefulWidgetMixin {
  _MyWidgetState createState() => _MyWidgetState();
}
class _MyWidgetState extends State<MyWidget> with GetItStateMixin {
  void _handleSubmitPressed() {
    final email = get<Model>().emailAddress;
    ...
  }
}
```

__NOTE__: The `GetItMixin` API is generally the same regardless of whether you use `Stateless` or `Stateful` widgets.

## Watching Data

Where `GetItMixin` really shines is data-binding. It comes with a set of `watch` methods to rebuild a widget when data changes.

Imagine you had a very simple shared model, with multiple fields, one of them being country:
```dart
class Model {
    final country = ValueNotifier<String>('Canada');
    ...
}
getIt.registerSingleton<Model>(Model());
```
You could tell your view to rebuild any time country changes with a simple call to `watchX`:
```dart
class MyWidget extends StatelessWidget with GetItStatefulWidgetMixin {
  @override
  Widget build(BuildContext context) {
    String country = watchX((Model x) => x.country);
    ...
  }
}
```
There are various `watch` methods, for common types of data sources, including `ChangeNotifier`, `ValueNotifier`, `Stream` and `Future`:

| API  | Description  |
|---|---|
| `.watch`  | Bind to a `ValueListenable` value  |
| `.watchX`  | Bind to the results of a `select` method on a `ValueListenable` value   |
| `.watchOnly`  | Bind to a basic `Listenable` (like `ChangeNotifier`)  |
| `.watchXOnly`  | Bind to the results of a `select` method on a `Listenable`  |
| `.watchStream` | Subscribe to a `Stream`  |
| `.watchFuture` | Bind to a `Future`   |

Just call `watch_` to listen to the data type you need, and `GetItMixin` will take care of cancelling bindings and subscriptions when the widget is destroyed.

The primary benefit to the `watch` methods is that they eliminate the need for `ValueListenableBuilders`, `StreamBuilder` etc. Each binding consumes only one line and there is no nesting.

Here we watch three `ValueListenable` which would normally be three builders, 12+ lines of code and several levels of indentation. With `GetItMixin`, it's three lines:
```dart
class MyWidget extends StatelessWidget with GetItMixin {
  @override
  Widget build(BuildContext context) {
    bool loggedIn = watchXOnly((UserModel x) => x.isLoggedIn);
    String userName = watchXOnly((UserModel x) => x.user.name);
    bool darkMode = watchXOnly((SettingsModel x) => x.darkMode);
    ...
  }
}
```
This can be used to eliminate `StreamBuilder` and `FutureBuilder` from your UI as well:
```dart
class MyWidget extends StatelessWidget with GetItMixin {
  @override
  Widget build(BuildContext context) {
    final currentUser = watchStream((UserModel x) => x.userNameUpdates, 'NoUser');
    final ready = watchFuture((AppModel x) => x.initializationReady, false).data;
    bool appIsLoading = ready == false || currentUser.hasData == false;
    
    if(appIsLoading) return CircularProgressIndicator();
    return Text(currentUser.data);    
  }
}
```

### Side Effects / Event Handlers

Instead of rebuilding, you might instead want to show a toast notification or dialog when a Stream emits a value or a ValueListenable changes.

To run an action when data changes you can use the `register` methods:

| API  | Description  |
|---|---|
| `.registerHandler`  | Add an event handler for a `ValueListenable`  |
| `.registerStreamHandler`  | Add an event handler for a `Stream`  |
| `.registerFutureHandler`  | Add an event handler for a `Future`  |

The first param in the `register` methods is a `select` delegate that can be used to watch a specific field. The second param is the action which will be triggered when that field changes:
```dart
class MyWidget extends StatelessWidget with GetItMixin {
  @override
  Widget build(BuildContext context) {
    registerHandler(
        (Model x) => x.name,
        (context, value, cancel) => showNameDialog(context, value));
    ...
  }
}
```

In the example above you see that the handler function receives the value that is returned from the select delegate (`(Model x) => x.name`), as well as a `cancel` function that the handler can call to cancel registration at any time.

As with `watch` calls, all `registerHandler` calls are cleaned up when the Widget is destroyed.

# Rules

There are some important rules to follow in order to avoid bugs with the `watch` methods:
* `watch` methods must be called within `build()`
  * It is good practice to define them at the top of your build method
* must be called on every build, in the same order (no conditional watching). This is similar to `flutter_hooks`.
* do not use them inside of a builder as it will break the mixins ability to rebuild

# __isReady<T>() and allReady()__
A common use case is to toggle a loading state when side effects are in-progress. To check whether any registered actions have completed you can use `allReady()` and `isReady<T>()`. These methods return the current state of any registered async operations and a rebuild is triggered when they change.
```dart
class MyWidget extends StatelessWidget with GetItMixin {
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

With `pushScope()` you can push a scope when a Widget/State is mounted, and automatically pop when the Widget/State is destroyed. You can pass an optional init or dispose function.
```dart
  void pushScope({void Function(GetIt getIt) init, void Function() dispose});
```
This can be very useful for injecting mock services when views are opened so you can easily test them. Of course you can also push and pop scope directly from your tests as well!

# Find out more!
For more background on the history of GetItMixin you can check out the [README_EXTENDED](README_EXTENDED.md).

For a more complete explanation of the API watch the presentation: [GetIt in action By Thomas Burkhart](https://youtu.be/YJ52kSfSMyM).

