import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:functional_listener/functional_listener.dart';
import 'package:get_it/get_it.dart';

part 'elements.dart';
part 'mixins.dart';
part 'watch_it_state.dart';
part 'widgets.dart';

class WatchResult<T extends Object> {
  WatchResult(this.target, this.instanceName);

  final T? target;
  final String? instanceName;

  T get _target => target ?? di<T>(instanceName: instanceName);

  T get value {
    if (_target is Listenable) {
      _activeWatchItState!.watchListenable(target: _target as Listenable);
    }
    return _target;
  }

  R select<R>(ValueListenable<R> Function(T) selector) {
    final property = selector(_target);

    _activeWatchItState!.watchListenable(target: property);
    // Listen to the property here.
    return property.value;
  }

  R selectProperty<R>(R Function(T) selector) {
    final property = selector(_target);

    if (_target is Listenable) {
      _activeWatchItState!
          .watchOnly<T, R>(listenable: _target as Listenable, only: selector);
    }

    // Listen to the [_target] here.
    return property;
  }

  AsyncSnapshot<R> selectStream<R>(
    Stream<R> Function(T) selector, {
    R? initialValue,
    bool preserveState = true,
  }) {
    final observedObject = selector(_target);
    return _activeWatchItState!.watchStream(
        target: observedObject,
        initialValue: initialValue,
        instanceName: instanceName,
        preserveState: preserveState);
  }
}

/// all the following functions can be called inside the build function but also
/// in e.g. in `initState` of a `StatefulWidget`.
/// The mixin takes care that everything is correctly disposed.

/// retrieves or creates an instance of a registered type [T] depending on the registration
/// function used for this type or based on a name.
/// for factories you can pass up to 2 parameters [param1,param2] they have to match the types
/// given at registration with [registerFactoryParam()]
T di<T extends Object>(
        {String? instanceName, dynamic param1, dynamic param2}) =>
    GetIt.I<T>(instanceName: instanceName, param1: param1, param2: param2);

/// like [get] but for async registrations
Future<T> getAsync<T extends Object>(
        {String? instanceName, dynamic param1, dynamic param2}) =>
    GetIt.I.getAsync<T>(
        instanceName: instanceName, param1: param1, param2: param2);

T watch<T extends Listenable>(T target) {
  assert(_activeWatchItState != null,
      'watch can only be called inside a build function');

  _activeWatchItState!.watchListenable(target: target);
  return target;
}

WatchResult<T> watchIt<T extends Object>({T? target, String? instanceName}) {
  assert(_activeWatchItState != null,
      'watch can only be called inside a build function');
  return WatchResult<T>(target, instanceName);
}

/// subscribes to the `Stream` returned by [select] and returns
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
AsyncSnapshot<R> watchStream<T extends Object, R>(
  Stream<R> stream, {
  R? initialValue,
  bool preserveState = true,
  String? instanceName,
}) {
  return _activeWatchItState!.watchStream(
      target: stream,
      initialValue: initialValue,
      instanceName: instanceName,
      preserveState: preserveState);
}

/// awaits the ` Future` returned by [select] and triggers a rebuild as soon
/// as the `Future` completes. After that it returns
/// an `AsyncSnapshot` with the received data from the `Future`
/// When you call [watchFuture] a second time on the same `Future` it will
/// return the last received data but not observe the Future a another time.
/// To be able to use [watchStream] inside a `build` function
/// we have to pass [initialValue] so that it can return something before
/// the `Future` has completed
/// if [select] returns a different `Future` than on the last call, [watchFuture]
/// will ignore the completion of the previous Future and observe the completion
/// of the new Future.
/// [preserveState] determines then if the new initial value should be the last
/// value of the previous Future or again [initialValue]
AsyncSnapshot<R?> watchFuture<T extends Object, R>({
  T? target,
  Future<R> Function(T)? select,
  required R initialValue,
  String? instanceName,
  bool preserveState = true,
}) {
  Future<R>? observedObject;

  if (select != null) {
    observedObject = select(target ?? di<T>(instanceName: instanceName));
  } else {
    if (T is Future<R>) {
      observedObject =
          (target ?? di<T>(instanceName: instanceName)) as Future<R>;
    } else {
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

/// registers a [handler] for a `ValueListenable` exactly once on the first build
/// and unregisters is when the widget is destroyed.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt. If the object itself if the `ValueListenable` pass `(x)=>x` here
/// If you set [executeImmediately] to `true` the handler will be called immediately
/// with the current value of the `ValueListenable`.
/// All handler get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
void registerHandler<T extends Object, R>({
  T? target,
  ValueListenable<R> Function(T)? select,
  required void Function(
          BuildContext context, R newValue, void Function() cancel)
      handler,
  bool executeImmediately = false,
  String? instanceName,
}) {
  Listenable? observedObject;

  if (select != null) {
    observedObject = select(target ?? di<T>(instanceName: instanceName));
  } else {
    if (T is Listenable) {
      observedObject =
          (target ?? di<T>(instanceName: instanceName)) as Listenable;
    } else {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Listenable');
    }
  }
  _activeWatchItState!.registerHandler<T, R>(observedObject, handler,
      instanceName: instanceName, executeImmediately: executeImmediately);
}

/// registers a [handler] for a `Stream` exactly once on the first build
/// and unregisters is when the widget is destroyed.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt. If the object itself if the `Stream` pass `(x)=>x` here
/// If you pass [initialValue] your passed handler will be executes immediately
/// with that value
/// All handler get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
void registerStreamHandler<T extends Object, R>({
  required void Function(BuildContext context, AsyncSnapshot<R?> newValue,
          void Function() cancel)
      handler,
  T? target,
  Stream<R> Function(T)? select,
  R? initialValue,
  String? instanceName,
}) {
  Stream<R>? observedObject;

  if (select != null) {
    observedObject = select(target ?? di<T>(instanceName: instanceName));
  } else {
    if (T is Stream<R>) {
      observedObject =
          (target ?? di<T>(instanceName: instanceName)) as Stream<R>;
    } else {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Stream');
    }
  }
  _activeWatchItState!.registerStreamHandler(observedObject, handler,
      initialValue: initialValue, instanceName: instanceName);
}

/// registers a [handler] for a `Future` exactly once on the first build
/// and unregisters is when the widget is destroyed.
/// This handler will only called once when the `Future` completes.
/// [select] allows you to register the handler to a member of the of the Object
/// stored in GetIt. If the object itself if the `Future` pass `(x)=>x` here
/// If you pass [initialValue] your passed handler will be executes immediately
/// with that value.
/// All handler get passed in a [cancel] function that allows to kill the registration
/// from inside the handler.
/// /// if the Future has completed [handler] will be called every time until
/// the handler calls `cancel` or the widget is destroyed
void registerFutureHandler<T extends Object, R>({
  required void Function(BuildContext context, AsyncSnapshot<R?> newValue,
          void Function() cancel)
      handler,
  T? target,
  Future<R> Function(T)? select,
  R? initialValue,
  String? instanceName,
}) {
  Future<R>? observedObject;

  if (select != null) {
    observedObject = select(target ?? di<T>(instanceName: instanceName));
  } else {
    if (T is Future<R>) {
      observedObject =
          (target ?? di<T>(instanceName: instanceName)) as Future<R>;
    } else {
      throw ArgumentError(
          'Either the return type of the select function or the type T has to be a Future');
    }
  }
  _activeWatchItState!.registerFutureHandler<Future<R>, R?>(
      target: observedObject,
      handler: handler,
      initialValueProvider: () => initialValue,
      instanceName: instanceName,
      allowMultipleSubscribers: true);
}

/// returns `true` if all registered async or dependent objects are ready
/// and call [onReady] [onError] handlers when the all-ready state is reached
/// you can force a timeout Exceptions if [allReady] hasn't
/// return `true` within [timeout]
/// It will trigger a rebuild if this state changes
bool allReady(
        {void Function(BuildContext context)? onReady,
        void Function(BuildContext context, Object? error)? onError,
        Duration? timeout}) =>
    _activeWatchItState!
        .allReady(onReady: onReady, onError: onError, timeout: timeout);

/// registers a handler that is called when the all-ready state is reached
/// it does not trigger a rebuild like [allReady] does
/// you can force a timeout Exceptions if [allReady] completed
/// within [timeout] which will call [onError]
void allReadyHandler(void Function(BuildContext context)? onReady,
        {void Function(BuildContext context, Object? error)? onError,
        Duration? timeout}) =>
    _activeWatchItState!.allReady(
        onReady: onReady,
        onError: onError,
        timeout: timeout,
        shouldRebuild: false);

/// returns `true` if the registered async or dependent object defined by [T] and
/// [instanceName] is ready
/// and call [onReady] [onError] handlers when the ready state is reached
/// you can force a timeout Exceptions if [isReady] hasn't
/// return `true` within [timeout]
/// It will trigger a rebuild if this state changes
bool isReady<T extends Object>(
        {void Function(BuildContext context)? onReady,
        void Function(BuildContext context, Object? error)? onError,
        Duration? timeout,
        String? instanceName}) =>
    _activeWatchItState!.isReady<T>(
        instanceName: instanceName,
        onReady: onReady,
        onError: onError,
        timeout: timeout);

/// Pushes a new GetIt-Scope. After pushing it executes [init] where you can register
/// objects that should only exist as long as this scope exists.
/// Can be called inside the `build` method method of a `StatelessWidget`.
/// It ensures that it's only called once in the lifetime of a widget.
/// When the widget is destroyed the scope too gets destroyed after [dispose]
/// is executed. If you use this function and you have registered your objects with
/// an async disposal function, that functions won't be awaited.
/// I would recommend doing pushing and popping from your business layer but sometimes
/// this might come in handy
void pushScope({void Function(GetIt getIt)? init, void Function()? dispose}) =>
    _activeWatchItState!.pushScope(init: init, dispose: dispose);

/// Will triger a rebuild of the Widget if any new GetIt-Scope is pushed or popped
/// This function will return `true` if the change was a push otherwise `false`
/// If no change has happend the return value will be null
bool? rebuildOnScopeChanges() => _activeWatchItState!.rebuildOnScopeChanges();
