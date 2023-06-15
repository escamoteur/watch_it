# watch_it

This package offers a set of mixin types that makes the binding of data that is stored within `
GetIt` really easy.

>When I write of binding, I mean a mechanism that will automatically rebuild a widget that if data it depends on changes

Several users asked for support of data binding for GetIt like `provider` offers. At the same time I have to admit I got really intrigued by `flutter_hooks` from [Remi Rousselet](https://github.com/rrousselGit/), so I started to think about how to create something similar for `GetIt`. **I'm very thankful for Remi's work. I took more than one inspiration from his code**

As I want to keep `GetIt` free of Flutter dependencies I choose to write a separate package with mixins to achive this goal.

To be clear you can achieve the same using different Flutter Builders but it will make your Flutter code less readable and you will have more to type.

## Getting started
>For this readme I expect that you know how to work with [GetIt](https://pub.dev/packages/get_it)

Lets create some model class that we want to access with the mixins:

```Dart
class Model extends ChangeNotifier {
  String _country;
  set country(String val) {
    _country = val;
    notifyListeners();
  }
  String get country => _country;

  String _emailAddress;
  set emailAddress(String val) {
    _emailAddress = val;
    notifyListeners();
  }
  String get emailAddress => _emailAddress;

  final ValueNotifier<String> name;
  final Model nestedModel;

  Stream<String> userNameUpdates;
  Future get initializationReady;
}
```

Now we will explore how to access the different properties by using  `watch_it`

## Accessing GetIt

WatchIt exports the default instance of get_it as a global variable `di` which lets
you access it from anywhere in your app. To access any get_it registered
object you only have to type `di<MyType>()` instead of `GetIt.I<MyType>()`.
If you prefer to use `GetIt.I` or you have your own globale variable that's fine too as they all
will use the same instace of GetIt.

If you want to use a different instance of get_it you can pass it to
the functions of this library as an optional parameter.
### Watching Data
The following functions will return a value and rebuild the widget every-time this data inside GetIt changes.

Imagine you have an object inside `GetIt` registered that implements `ValueListenableBuilder<String>` named `currentUserName` and we want the above widget to rebuild every-time it's value changes.
We could do this adding a `ValueListenableBuilder`:


```Dart
class TestStateLessWidget1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: GetIt.I<ValueListenable<String>>(instanceName: 'currentUserName'),
          builder: (context, val,_) {
            return Text(val);
          }
        ),
      ],
    );
  }
}
```

With the `WatchIt` we can now write this:

```Dart
class TestStateLessWidget extends StatelessWidget with WatchItMixin {
  @override
  Widget build(BuildContext context) {
    final currentUser =
       watchIt<ValueListenable<String>, String>(instanceName: 'currentUserName');

    return Column(
      children: [
         Text(currentUser)
      ],
    );
  }
}
```

Unfortunately we have to provide a second generic parameter because Dart can't infer the type of the return value.
`watch` can not only observe `Valuelistenables` inside GetIt, you also can pass any Valuelistenable as `target` parameter. For instance a `ValueListenable` that was passed as parameter to the Widget.
Luckily we will see with the following functions there is a way to help the compiler.

#### Rules!
**Important: These functions can only be called inside the `build()` function and you can only watch any objects only once. The functions must be called on every `build`, in the same order, and cannot be called conditionally otherwise the mixin gets confused**
You can't use any of the watch functions (you can use `get` and `getX` though) inside an `Builder` because a Builder gets its own context and looses the connection to the mixin. If you want to use a watch function inside a `Builder`, wrap the content of the Builder in another Widget that uses the mixin too.
But you shouldn't need any Builders if you use the mixin.

#### WatchX
In a real app it's way more probable that your business object wont be the `ValueListenable` itself but it will have some properties that might be `ValueListenables` like the `name` property of our `Model` class. To react to changes to of such properties you can use `watchX()`:

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
    final name = watchX((Model x) => x.name);
    /// if the valueListenable is nested deeper in your object
    final innerName = watchX((Model x) => x.nestedModel.name);

    return Column(
      children: [
        Text(name),
        Text(innerName),
      ],
    );
  }
}
```

This widget will rebuild whenever one of the watched `ValueListenables` changes.

You might be wondering why I did not pass the type `Model` as generic Parameter to `watchX()`. The reason it that the signature of it looks like this:

```Dart
R watchX<T, R>(
    ValueListenable<R> Function(T x) select, {
    String instanceName,
  }) =>
```
which means you would have to pass two generic types, not only `T` but also `R`. If you pass `T` inside the `select` function the compiler is able to infer `R`.

#### watchOnly & watchValue
Another popular pattern is that a business object implements `Listenable` like `ChangeNotifier` and it will notify its listeners whenever one of its properties changes. As we want to only rebuild a Widget when a value that it needs is updated `watchOnly()` lets you define which property you want tp observe and it will only trigger the rebuild if it really changes.
`watchValue()` does the same but for nested `Listenables`

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
    final country = watchOnly((Model x) => x.country);
    /// if the watched property is nested deeper in you object
    final innerEmail = watchValue((Model x) => x.nestedModel,(Model o)=>o.emailAddress);

    return Column(
      children: [
        Text(country),
        Text(innerEamil),
      ],
    );
  }
}
```

This Widget will rebuild when either `country` of the `Model` object or `emailAddress` of the nested `Model` changes. If you update `emailAddress` of `Model` it won't update although it too calls `notifyListeners`

If you want to get an update whenever Model triggers `notifyListener` you can achieve this by using this selector method:

```Dart
final model = watchOnly((Model x) => x);
```

#### Streams and Futures
In case you want to update your widget as soon as a Stream in your Model emits a new value or as soon as a `Future` completes you can use `watchStream` and `watchFuture`. The nice thing is that you don't have to care to cancel subscriptions, the mixin takes care of that. So instead of using a `StreamBuilder` you can just do:

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
    final currentUser = watchStream((Model x) => x.userNameUpdates, 'NoUser');
    final ready =
        watchFuture((Model x) => x.initializationReady,false).data;

    return Column(
      children: [
        if (ready != true || !currentUser.hasData) // in case of an error ready could be null
         CircularProgressIndicator()
         else
        Text(currentUser.data),
      ],
    );
  }
}
```

These functions can handle if the selector function returns different Streams and Futures on following `build` calls. In this case the old subscription is cancelled and the new `Stream` subscribed. Check he API docs for more details.


### Event handlers
Maybe you don't need a value updated but want to show a Snackbar as soon as a `Stream` emits a value or a `ValueListenable` updates a value or a `Future`. If you wanted to do this without this mix_in you would need a `StatefulWidget` where you subscribe to a `Stream` in `iniState` and dispose your subscription in the `dispose` function of the `State`.

With this mixin you can register handlers for `Streams`, `ValueListenables` and Futures, and the mixin will dispose everything for you as soon as the widget gets destroyed.

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
    /// Registers a handler for a valueListenable
    registerHandler((Model x) => x.name, (context,name,_)
        => showNameDialog(context,name));

    registerStreamHandler((Model x) => x.userNameUpdates, (context,name,_)
        => showNameDialog(context,name));

    registerFutureHandler((Model x) => x.initializationReady, (context,__,_)
        => Navigator.of(context).push(....));
    return Column(
      children: [
        //...whatever widgets needed
      ],
    );
  }
}
```
For instance you could register a handler for `thrownExceptions` of a `flutter_command` while you use `watch()` to get the values.

In the example above you see that the handler function has a third parameter that we ignored. Your handler gets a dispose function passed there that a handler could use to kill a registration from within itself.

### allReady() & isReady()
If you already used the synchronization functions from GetIt you know both of this functions (otherwise check them out in the GetIt readme). The mixin variant returns the actual status as `bool` value and trigger a rebuild when this status changes. Additionally you can register handlers that are called when the status is `true`.

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
    final isReady = allReady();

    if (isReady) {
      return MyMainPageContent();
    } else {
      return CircularProgressIndicator();
    }
}
```
or with the handler:

```Dart
class TestStateLessWidget1 extends StatelessWidget with WatchIt {
  @override
  Widget build(BuildContext context) {
  allReady(
      onReady: (context) =>
          Navigator.of(context).pushReplacement(MainPageRoute()));

  return CircularProgressIndicator();
  }
}
```
`isReady<T>()` can be used in the same way to react on the status of a single asynchronous singleton.

### Pushing a new GetIt Scope
With `pushScope()` you can push one scope that will be popped when the Widget/State is destroyed.
You can pass an `init` function that will be called immediately after the scope was pushed and an optional `dispose` function that is called directly before the scope is popped.

```Dart
  void pushScope({void Function(GetIt getIt) init, void Function() dispose});
```

### Trigger a rebuild on GetIt Scope changes
As it is possible that objects registered in a higher GetIt-Scope can shadow objects of the same registration type in a lower scope it is important to ensure that the UI can update its references to the newly active object (the one last registered).
The watch_it detects such changes and updates them on the next rebuild but if you want to ensure that this happens immediately you can put a call to

```dart
  /// Will triger a rebuild of the Widget if any new GetIt-Scope is pushed or popped
  /// This function will return `true` if the change was a push otherwise `false`
  /// If no change has happend the return value will be null
  bool? rebuildOnScopeChanges();
```

in the `build()` method of your root widget.
## StatefulWidgets
All the functions above are available for `StatefulWidgets` too. However with this mixin the need for `StatefulWidgets` will drastically decline.
In case you need one and also want to use the comfort of this you have to use two different mixins.

```Dart
class TestStatefulWidget extends StatefulWidget with GetItStatefulWidgetMixin {
  @override
  _TestStatefulWidgetState createState() => _TestStatefulWidgetState();
}

class _TestStatefulWidgetState extends State<TestStatefulWidget> with GetItStateMixin {
  @override
  Widget build(BuildContext context) {
    final currentUser = watchX((Model x) => x.name,);
    return Column(
      children: [
        Text(currentUser),
      ],
    );
  }
}
```
Unfortunately we need two mixins in this case otherwise the automatic updating could not be realised.
