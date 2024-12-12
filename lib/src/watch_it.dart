import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:functional_listener/functional_listener.dart';
import 'package:get_it/get_it.dart';

part 'elements.dart';
part 'mixins.dart';
part 'watch_it_state.dart';
part 'widgets.dart';

/// WatchIt exports the default instance of get_it as a global variable which lets
/// you access it from anywhere in your app. To access any get_it registered
/// object you only have to type `di<MyType>()` instead of `GetIt.I<MyType>()`.
/// if you don't want to use a different instance of get_it you can pass it to
/// the functions of this library as an optional parameter
final di = GetIt.I;

/// The Watch functions:
///
/// The watch functions are the core of this library. They allow you to observe
/// any Listenable, Stream or Future and trigger a rebuild of your widget whenever
/// the watched object changes.
///
/// `ChangeNotifier` based example:
/// ```dart
/// // Create a ChangeNotifier based model
/// class UserModel extends ChangeNotifier {
///   get name = _name;
///   String _name = '';
///   set name(String value){
///     _name = value;
///     notifyListeners();
///   }
///   ...
/// }
///
/// // Register it
/// di.registerSingleton<UserModel>(UserModel());
///
/// // Watch it
/// class UserNameText extends WatchingWidget {
///   @override
///   Widget build(BuildContext context) {
///     final userName = watchPropertyValue((UserModel m) => m.name);
///     return Text(userName);
///   }
/// }
/// ```
///
/// there are the following functions:
///
/// * [watch] - observes any Listenable you have access to
/// * [watchIt] - observes any Listenable registered in get_it
/// * [watchValue] - observes a ValueListenable property of an object registered in get_it
/// * [watchPropertyValue] - observes a property of a Listenable object and trigger a rebuild
///   whenever the Listenable notifies a change and the value of the property changes
/// * [watchStream] - observes a Stream and triggers a rebuild whenever the Stream emits
///   a new value
/// * [watchFuture] - observes a Future and triggers a rebuild whenever the Future completes
///
/// To be able to use the functions you have either to derive your widget from
/// [WatchingWidget] or [WatchingStatefulWidget] or use the [WatchItMixin] in your
/// widget class.
///
/// To use the watch functions you have to call them inside the build function of
/// a [WatchingWidget] or [WatchingStatefulWidget] or a class that uses the
/// [WatchItMixin]. They basically allow you to avoid having to clutter your
/// widget tree with `ValueListenableBuilder`, `StreamBuilder` or `FutureBuilder`
/// widgets. Making your code more readable and maintainable.

/// The functions in detail:

/// [watch] observes any Listenable and triggers a rebuild whenever it notifies
/// a change. That listenable could be passed in as a parameter or be accessed via
/// get_it. Like `final userName = watch(di<UserManager>()).userName;` if UserManager is
/// a Listenable (eg. ChangeNotifier).
/// if any of the following functions don't fit your needs you can probably use
/// this one by manually providing the Listenable that should be observed.
T watch<T extends Listenable>(T target) {
  assert(_activeWatchItState != null,
      'watch can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');

  _activeWatchItState!.watchListenable(target: target);
  return target;
}

/// [watchIt] observes any Listenable registered in get_it and triggers a rebuild whenever
/// it notifies a change. Its basically a shortcut for `watch(di<T>())`
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
T watchIt<T extends Listenable>({String? instanceName, GetIt? getIt}) {
  assert(_activeWatchItState != null,
      'watchIt can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  final getItInstance = getIt ?? di;
  final observedObject = getItInstance<T>(instanceName: instanceName);
  _activeWatchItState!.watchListenable(target: observedObject);
  return observedObject;
}

/// [watchValue] observes a ValueListenable property of an object registered in get_it
/// and triggers a rebuild whenever it notifies a change and returns its current
/// value. It's basically a shortcut for `watchIt<T>().value`
/// As this is a common scenario it allows us a type safe concise way to do this.
/// `final userName = watchValue<UserManager, String>((user) => user.userName);`
/// is an example of how to use it.
/// We can use the strength of generics to infer the type of the property and write
/// it even more expressively like this:
/// `final userName = watchValue((UserManager user) => user.userName);`
///
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
R watchValue<T extends Object, R>(
  ValueListenable<R> Function(T) selectProperty, {
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'watchValue can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  ValueListenable<R> observedObject;
  final getItInstance = getIt ?? di;
  observedObject = selectProperty(getItInstance<T>(instanceName: instanceName));
  _activeWatchItState!.watchListenable(target: observedObject);
  return observedObject.value;
}

/// [watchPropertyValue] allows you to observe a property of a Listenable object and trigger a rebuild
/// whenever the Listenable notifies a change and the value of the property changes and
/// returns the current value of the property.
/// You can achieve a similar result with `watchIt<UserManager>().userName` but that
/// would trigger a rebuild whenever any property of the UserManager changes.
/// `final userName = watchPropertyValue<UserManager, String>((user) => user.userName);`
/// could be an example. Or even more expressive and concise:
/// `final userName = watchPropertyValue((UserManager user) => user.userName);`
/// which lets tha analyzer infer the type of T and R.
///
/// If you have a local Listenable and you want to observe only a single property
/// you can pass it as [target].
///
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
R watchPropertyValue<T extends Listenable, R>(
  R Function(T) selectProperty, {
  T? target,
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'watchPropertyValue can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  late final T observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  final R observedProperty = selectProperty(parentObject);
  assert(
      (observedProperty != null && observedProperty is! Listenable) ||
          (observedProperty == null),
      'selectProperty returns a Listenable. Use watchIt instead');
  observedObject = parentObject;
  _activeWatchItState!.watchPropertyValue<T, R>(
      listenable: observedObject, only: selectProperty);
  return observedProperty;
}

/// [watchStream] subscribes to the `Stream` returned by [select] and returns
/// an `AsyncSnapshot` with the latest received data from the `Stream`
/// Whenever new data is received it triggers a rebuild.
/// When you call [watchStream] a second time on the same `Stream` it will
/// return the last received data but not subscribe another time.
/// To be able to use [watchStream] inside a `build` function we have to pass
/// [initialValue] so that it can return something before it has received the first data
/// if [select] returns a different Stream than on the last call, [watchStream]
/// will cancel the previous subscription and subscribe to the new stream.
/// [preserveState] determines then if the new initial value should be the last
/// value of the previous stream or again [initialValue]
/// If you want to observe a `Stream` that is not registered in get_it you can
/// pass it as [target].
/// if you pass null as [select], T or [target] has to be a Stream<R>.
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
AsyncSnapshot<R> watchStream<T extends Object, R>(
  Stream<R> Function(T)? select, {
  T? target,
  R? initialValue,
  bool preserveState = true,
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'watchStream can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Stream<R>? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  if (select != null) {
    observedObject = select(parentObject);
  } else {
    try {
      observedObject = (parentObject) as Stream<R>;
    } on TypeError catch (_) {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Stream');
    }
  }
  return _activeWatchItState!.watchStream(
      target: observedObject,
      initialValue: initialValue,
      instanceName: instanceName,
      preserveState: preserveState);
}

/// [watchFuture] observes the `Future` returned by [select] and triggers a rebuild as soon
/// as this `Future` completes. After that it returns
/// an `AsyncSnapshot` with the received data from the `Future`
/// When you call [watchFuture] a second time on the same `Future` it will
/// return the last received data but not observe the Future a another time.
/// To be able to use [watchFuture] inside a `build` function
/// we have to pass [initialValue] so that it can return something before
/// the `Future` has completed
/// if [select] returns a different `Future` than on the last call, [watchFuture]
/// will ignore the completion of the previous Future and observe the completion
/// of the new Future.
/// [preserveState] determines then if the new initial value should be the last
/// value of the previous Future or again [initialValue]
/// If you want to observe a `Future` that is not registered in get_it you can
/// pass it as [target].
/// if you pass null as [select], T or [target] has to be a Future<R>.
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
AsyncSnapshot<R?> watchFuture<T extends Object, R>(
  Future<R> Function(T)? select, {
  T? target,
  required R initialValue,
  String? instanceName,
  bool preserveState = true,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'watchFuture can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Future<R>? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  if (select != null) {
    observedObject = select(parentObject);
  } else {
    try {
      observedObject = (observedObject) as Future<R>;
    } on TypeError catch (_) {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Future');
    }
  }
  return _activeWatchItState!.registerFutureHandler<Future<R>, R>(
      target: observedObject,
      initialValueProvider: () => initialValue,
      instanceName: instanceName,
      preserveState: preserveState,
      allowMultipleSubscribers: false);
}

/// [registerHandler] registers a [handler] function for a `ValueListenable`
/// exactly once on the first build
/// and unregister it when the widget is destroyed.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt.
/// If you set [executeImmediately] to `true` the handler will be called immediately
/// with the current value of the `ValueListenable` and not on the first change notification.
/// All handler functions get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
/// If you want to register a handler to a Listenable that is not registered in get_it you can
/// pass it as [target].
/// if you pass null as [select], T or [target] has to be a Listenable or ValueListenable.
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
void registerHandler<T extends Object, R>({
  ValueListenable<R> Function(T)? select,
  required void Function(
          BuildContext context, R newValue, void Function() cancel)
      handler,
  T? target,
  bool executeImmediately = false,
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'registerHandler can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Listenable? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  if (select != null) {
    observedObject = select(parentObject);
  } else {
    try {
      observedObject = (parentObject) as Listenable;
    } on TypeError catch (_) {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Listenable');
    }
  }
  _activeWatchItState!.registerHandler<T, R>(observedObject, handler,
      instanceName: instanceName, executeImmediately: executeImmediately);
}

/// [registerChangeNotifierHandler] registers a [handler] function for a `ChangeNotifier`
/// exactly once on the first build
/// and unregisters it when the widget is destroyed.
/// If you set [executeImmediately] to `true` the handler will be called immediately
/// with the current value of the `ChangeNotifier` and not on the first change notification.
/// All handler functions get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
/// If you want to register a handler to a ChangeNotifier that is not registered in get_it you can
/// pass it as [target].
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
void registerChangeNotifierHandler<T extends ChangeNotifier>({
  required void Function(
          BuildContext context, T newValue, void Function() cancel)
      handler,
  T? target,
  bool executeImmediately = false,
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'registerHandler can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Listenable? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);

  observedObject = parentObject;

  _activeWatchItState!.registerHandler<T, T>(observedObject, handler,
      instanceName: instanceName, executeImmediately: executeImmediately);
}

/// [registerStreamHandler] registers a [handler] function for a `Stream` exactly
/// once on the first build
/// and unregisters it when the widget is destroyed.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt.
/// If you pass [initialValue] your passed handler will be executed immediately
/// with that value
/// All handler functions get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
/// If you want to register a handler to a Stream that is not registered in get_it you can
/// pass it as [target].
/// if you pass null as [select], T or [target] has to be a Stream<R>.
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
void registerStreamHandler<T extends Object, R>({
  Stream<R> Function(T)? select,
  required void Function(BuildContext context, AsyncSnapshot<R?> newValue,
          void Function() cancel)
      handler,
  R? initialValue,
  T? target,
  String? instanceName,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'registerStreamHandler can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Stream<R>? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  if (select != null) {
    observedObject = select(parentObject);
  } else {
    try {
      observedObject = (parentObject) as Stream<R>;
    } on TypeError catch (_) {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Stream');
    }
  }
  _activeWatchItState!.registerStreamHandler(observedObject, handler,
      initialValue: initialValue, instanceName: instanceName);
}

/// [registerFutureHandler] registers a [handler] function for a `Future` exactly
/// once on the first build
/// and unregisters it when the widget is destroyed.
/// This handler will only be called once when the `Future` completes.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt.
/// If you pass [initialValue] your passed handler will be executed immediately
/// with that value.
/// All handlers get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
/// If the Future has completed [handler] will be called every time until
/// the handler calls `cancel` or the widget is destroyed
///
/// If you want to register a handler to a Future that is not registered in get_it you can
/// pass it as [target].
/// if you pass null as [select], T or [target] has to be a Future<R>.
/// [instanceName] is the optional name of the instance if you registered it
/// with a name in get_it.
/// [callHandlerOnlyOnce] determines if the [handler] should be called only once
/// when the future completes or every time the widget rebuilds after the completion
///
/// [getIt] is the optional instance of get_it to use if you don't want to use the
/// default one. 99% of the time you won't need this.
void registerFutureHandler<T extends Object, R>({
  Future<R> Function(T)? select,
  T? target,
  required void Function(BuildContext context, AsyncSnapshot<R?> newValue,
          void Function() cancel)
      handler,
  R? initialValue,
  String? instanceName,
  bool callHandlerOnlyOnce = false,
  GetIt? getIt,
}) {
  assert(_activeWatchItState != null,
      'registerFutureHandler can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  Future<R>? observedObject;

  final getItInstance = getIt ?? di;
  final parentObject = target ?? getItInstance<T>(instanceName: instanceName);
  if (select != null) {
    observedObject = select(parentObject);
  } else {
    try {
      observedObject = (parentObject) as Future<R>;
    } on TypeError catch (_) {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Future');
    }
  }
  _activeWatchItState!.registerFutureHandler<Future<R>, R?>(
      target: observedObject,
      handler: handler,
      initialValueProvider: () => initialValue,
      instanceName: instanceName,
      allowMultipleSubscribers: true,
      callHandlerOnlyOnce: callHandlerOnlyOnce);
}

/// returns `true` if all registered async or dependent objects are ready
/// and call [onReady] and [onError] handlers when the all-ready state is reached.
/// You can force a timeout Exception if [allReady] hasn't
/// returned `true` within [timeout].
/// It will trigger a rebuild if this state changes
/// If no [onError] is passed in it will throw an exception if an error occurs
/// while waiting for the all-ready state.
/// [callHandlerOnlyOnce] determines if the [onReady] and [onError] handlers should
/// be called only once or on every rebuild after the all-ready state has been reached.
bool allReady(
    {void Function(BuildContext context)? onReady,
    void Function(BuildContext context, Object? error)? onError,
    Duration? timeout,
    bool callHandlerOnlyOnce = false}) {
  assert(_activeWatchItState != null,
      'allReady can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  return _activeWatchItState!.allReady(
      onReady: onReady,
      onError: onError,
      timeout: timeout,
      callHandlerOnlyOnce: callHandlerOnlyOnce);
}

/// registers a handler that is called when the all-ready state is reached
/// it does not trigger a rebuild like [allReady] does.
/// You can force a timeout Exception if [allReady] has completed
/// within [timeout] which will call [onError]
/// if no [onError] is passed in it will throw an exception if an error occurs
/// while waiting for the all-ready state.
/// [callHandlerOnlyOnce] determines if the [onReady] and [onError] handlers should
/// be called only once or on every rebuild after the all-ready state has been reached.
void allReadyHandler(
  void Function(BuildContext context)? onReady, {
  void Function(BuildContext context, Object? error)? onError,
  Duration? timeout,
  bool callHandlerOnlyOnce = false,
}) {
  assert(_activeWatchItState != null,
      'allReadyHandler can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  _activeWatchItState!.allReady(
      onReady: onReady,
      onError: onError,
      timeout: timeout,
      shouldRebuild: false,
      callHandlerOnlyOnce: callHandlerOnlyOnce);
}

/// returns `true` if the registered async or dependent object defined by [T] and
/// [instanceName] is ready
/// and calls [onReady] [onError] handlers when the ready state is reached.
/// You can force a timeout Exception if [isReady] hasn't
/// returned `true` within [timeout].
/// It will trigger a rebuild if this state changes.
/// if no [onError] is passed in it will throw an exception if an error occurs
bool isReady<T extends Object>(
    {void Function(BuildContext context)? onReady,
    void Function(BuildContext context, Object? error)? onError,
    Duration? timeout,
    String? instanceName}) {
  assert(_activeWatchItState != null,
      'isReady can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  return _activeWatchItState!.isReady<T>(
      instanceName: instanceName,
      onReady: onReady,
      onError: onError,
      timeout: timeout);
}

/// Pushes a new GetIt-Scope. After pushing, it executes [init] where you can register
/// objects that should only exist as long as this scope exists.
/// Can be called inside the `build` method of a `StatelessWidget`.
/// It ensures that it's only called once in the lifetime of a widget.
/// [isFinal] allows only objects in [init] to be registered so that other components
/// cannot accidentally register to this scope.
/// When the widget is destroyed the scope also gets destroyed after [dispose]
/// is executed. If you use this function and you have registered your objects with
/// an async disposal function, that function won't be awaited.
/// I would recommend doing pushing and popping from your business layer but sometimes
/// this might come in handy.
void pushScope(
    {void Function(GetIt getIt)? init,
    void Function()? dispose,
    bool isFinal = false}) {
  assert(_activeWatchItState != null,
      'pushScope can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  _activeWatchItState!
      .pushScope(init: init, dispose: dispose, isFinal: isFinal);
}

/// Will trigger a rebuild of the Widget if any new GetIt-Scope is pushed or popped.
/// This function will return `true` if the change was a push otherwise `false`.
/// If no change has happened then the return value will be null.
bool? rebuildOnScopeChanges() {
  assert(_activeWatchItState != null,
      'rebuildOnScopeChanges can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  return _activeWatchItState!.rebuildOnScopeChanges();
}

/// If you want to execute a function  only on the first built (even in in a StatelessWidget),
/// you can use the `callOnce` function anywhere in your build function. It has an optional `dispose`
/// handler which will be called when the widget is disposed.
void callOnce(void Function(BuildContext context) init,
    {void Function()? dispose}) {
  assert(_activeWatchItState != null,
      'callOnce can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  _activeWatchItState!.callOnce(init, dispose: dispose);
}

///To dispose anything when the widget is disposed you can use call `onDispose` anywhere in your build function.
void onDispose(void Function() dispose) {
  assert(_activeWatchItState != null,
      'onDispose can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');
  _activeWatchItState!.onDispose(dispose);
}

/// [lifetimeValue] creates a disposable object at the time of the first build
/// and disposes it when the widget is disposed.
/// on every rebuild the same object is returned
/// If can be used to create AnimationControllers or other objects that should
/// be disposed when the widget is disposed.
T lifetimeValue<T extends Object>(T Function() factoryFunc) {
  assert(_activeWatchItState != null,
      'lifetimeValue can only be called inside a build function within a WatchingWidget or a widget using the WatchItMixin');

  return _activeWatchItState!.lifetimeValue(factoryFunc);
}
