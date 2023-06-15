part of 'watch_it.dart';

class _WatchEntry<TObservedObject, TValue> {
  TObservedObject observedObject;
  VoidCallback? notificationHandler;
  StreamSubscription? subscription;
  final void Function(_WatchEntry entry) _dispose;
  TValue? lastValue;
  bool isHandlerWatch;
  TValue? Function(TObservedObject)? selector;

  Object? activeCallbackIdentity;
  _WatchEntry(
      {this.notificationHandler,
      this.subscription,
      this.selector,
      required void Function(_WatchEntry entry) dispose,
      this.lastValue,
      this.isHandlerWatch = false,
      required this.observedObject})
      : _dispose = dispose;
  void dispose() {
    _dispose(this);
  }

  bool watchesTheSameAndNotHandler(_WatchEntry entry) {
    // we can't distinguish properties of simple types from each others
    // so we allow multiple watches on them
    if (isHandlerWatch) return false;
    if (entry.observedObject != null) {
      if (entry.observedObject == observedObject) {
        return true;
      }
      return false;
    }
    return false;
  }
}

class _WatchItState {
  Element? _element;

  final _watchList = <_WatchEntry>[];
  int? currentWatchIndex;

  static CustomValueNotifier<bool?>? onScopeChanged;

  // ignore: use_setters_to_change_properties
  void init(Element element) {
    _element = element;

    /// prepare infrastucture to observe scope changes
    if (onScopeChanged == null) {
      onScopeChanged ??=
          CustomValueNotifier(null, mode: CustomNotifierMode.manual);
      GetIt.I.onScopeChanged = (pushed) {
        onScopeChanged!.value = pushed;
        onScopeChanged!.notifyListeners();
      };
    }
  }

  void resetCurrentWatch() {
    // print('resetCurrentWatch');
    currentWatchIndex = _watchList.isNotEmpty ? 0 : null;
  }

  /// if _getWatch returns null it means this is either the very first or the las watch
  /// in this list.
  _WatchEntry? _getWatch() {
    if (currentWatchIndex != null) {
      assert(_watchList.length > currentWatchIndex!);
      final result = _watchList[currentWatchIndex!];
      currentWatchIndex = currentWatchIndex! + 1;
      if (currentWatchIndex! == _watchList.length) {
        currentWatchIndex = null;
      }
      return result;
    }
    return null;
  }

  /// We don't allow multiple watches on the same object but we allow multiple handler
  /// that can be registered to the same observable object
  void _appendWatch<V>(_WatchEntry entry,
      {bool allowMultipleSubcribers = false}) {
    if (!entry.isHandlerWatch && !allowMultipleSubcribers) {
      for (final watch in _watchList) {
        if (watch.watchesTheSameAndNotHandler(entry)) {
          throw ArgumentError('This Object is already watched by watch_it');
        }
      }
    }
    _watchList.add(entry);
    currentWatchIndex = null;
  }

  void watchListenableold<T extends Listenable>(
      {required T target, String? instanceName}) {
    var watch = _getWatch();

    if (watch != null) {
      if (target != watch.observedObject) {
        /// target changed from the the last time
        /// so we have to unregister out handler and subscribe anew
        watch.dispose();
      }
    } else {
      watch = _WatchEntry(
        observedObject: target,
        dispose: (x) => x.observedObject!.removeListener(
          x.notificationHandler!,
        ),
      );
      _appendWatch(watch);
    }

    // ignore: prefer_function_declarations_over_variables
    final handler = () {
      _element!.markNeedsBuild();
    };
    watch.notificationHandler = handler;
    watch.observedObject = target;

    target.addListener(handler);
  }

  /// [handler] and [executeImmediately] are used by [registerHandler]
  void watchListenable<R>({
    required Listenable target,
    void Function(BuildContext contex, R newValue, void Function() dispose)?
        handler,
    bool executeImmediately = false,
  }) {
    var watch = _getWatch() as _WatchEntry<Listenable, R>?;

    if (watch != null) {
      if (target == watch.observedObject) {
        return;
      } else {
        /// select returned a different value than the last time
        /// so we have to unregister out handler and subscribe anew
        watch.dispose();
      }
    } else {
      watch = _WatchEntry(
        observedObject: target,
        dispose: (x) => x.observedObject!.removeListener(
          x.notificationHandler!,
        ),
        isHandlerWatch: handler != null,
      );
      _appendWatch(watch);
    }

    // ignore: prefer_function_declarations_over_variables
    final internalHandler = () {
      if (handler != null) {
        if (target is ValueListenable) {
          handler(_element!, target.value, watch!.dispose);
        } else {
          handler(_element!, target as R, watch!.dispose);
        }
      } else {
        _element!.markNeedsBuild();
      }
    };
    watch.notificationHandler = internalHandler;
    watch.observedObject = target;

    target.addListener(internalHandler);
    if (handler != null && executeImmediately) {
      if (target is ValueListenable) {
        handler(_element!, target.value, watch.dispose);
      } else {
        handler(_element!, target as R, watch.dispose);
      }
    }
  }

  watchOnly<T extends Listenable, R>({
    required T listenable,
    required R Function(T) only,
  }) {
    // final T listenable = target ?? GetIt.I<T>(instanceName: instanceName);

    var watch = _getWatch() as _WatchEntry<Listenable, R>?;

    if (watch != null) {
      if (listenable != watch.observedObject) {
        /// the targetobject has changed probably by passing another instance
        /// so we have to unregister our handler and subscribe anew
        watch.dispose();
      }
    } else {
      watch = _WatchEntry<T, R>(
          observedObject: listenable,
          selector: only,
          lastValue: only(listenable),
          dispose: (x) =>
              x.observedObject!.removeListener(x.notificationHandler!));
      _appendWatch(watch, allowMultipleSubcribers: true);
      // we have to set `allowMultipleSubcribers=true` because we can't differentiate
      // one selector function from another.
    }

    handler() {
      final newValue = only(listenable);
      if (watch!.lastValue != newValue) {
        _element!.markNeedsBuild();
        watch.lastValue = newValue;
      }
    }

    watch.notificationHandler = handler;

    listenable.addListener(handler);
  }

  AsyncSnapshot<R> watchStream<T extends Stream<R>, R>({
    required T target,
    required R? initialValue,
    String? instanceName,
    bool preserveState = true,
    void Function(BuildContext context, AsyncSnapshot<R> snapshot,
            void Function() cancel)?
        handler,
  }) {
    final stream = target;

    var watch = _getWatch() as _WatchEntry<Stream<R>, AsyncSnapshot<R?>>?;

    if (watch != null) {
      if (stream == watch.observedObject) {
        /// Only if this isn't used to register a handler
        ///  still the same stream so we can directly return lastvalue
        if (handler == null) {
          assert(watch.lastValue != null && watch.lastValue!.data != null);
          return AsyncSnapshot<R>.withData(
              watch.lastValue!.connectionState,
              // ignore: null_check_on_nullable_type_parameter
              watch.lastValue!.data!);
        } else {
          return AsyncSnapshot<R>.nothing();
        }
      } else {
        /// select returned a different value than the last time
        /// so we have to unregister out handler and subscribe anew
        watch.dispose();
        initialValue = preserveState
            ? watch.lastValue!.data ?? initialValue
            : initialValue;
      }
    } else {
      watch = _WatchEntry<Stream<R>, AsyncSnapshot<R?>>(
        dispose: (x) => x.subscription!.cancel(),
        observedObject: stream,
        isHandlerWatch: handler != null,
      );
      _appendWatch(
        watch,
      );
    }

    // ignore: cancel_subscriptions
    final subscription = stream.listen(
      (x) {
        if (handler != null) {
          handler(_element!, AsyncSnapshot.withData(ConnectionState.active, x),
              watch!.dispose);
        } else {
          watch!.lastValue = AsyncSnapshot.withData(ConnectionState.active, x);
          _element!.markNeedsBuild();
        }
      },
      onError: (Object error) {
        if (handler != null) {
          handler(
              _element!,
              AsyncSnapshot.withError(ConnectionState.active, error),
              watch!.dispose);
        }
        watch!.lastValue =
            AsyncSnapshot.withError(ConnectionState.active, error);
        _element!.markNeedsBuild();
      },
    );
    watch.subscription = subscription;
    watch.observedObject = stream;
    watch.lastValue =
        AsyncSnapshot<R?>.withData(ConnectionState.waiting, initialValue);

    if (handler != null) {
      if (initialValue != null) {
        handler(
            _element!,
            AsyncSnapshot.withData(ConnectionState.waiting, initialValue),
            watch.dispose);
      }
      return AsyncSnapshot<R>.nothing();
    }
    assert(watch.lastValue != null && watch.lastValue!.data != null);
    return AsyncSnapshot<R>.withData(
        watch.lastValue!.connectionState,
        // ignore: null_check_on_nullable_type_parameter
        watch.lastValue!.data!);
  }

  void registerHandler<T extends Object, R>(
    Listenable target,
    void Function(BuildContext contex, R newValue, void Function() dispose)
        handler, {
    bool executeImmediately = false,
    String? instanceName,
  }) {
    watchListenable<R>(
      target: target,
      handler: handler,
      executeImmediately: executeImmediately,
    );
  }

  void registerStreamHandler<T extends Stream<R>, R>(
    T target,
    void Function(
      BuildContext context,
      AsyncSnapshot<R> snapshot,
      void Function() cancel,
    ) handler, {
    R? initialValue,
    String? instanceName,
  }) {
    watchStream<T, R>(
        target: target,
        initialValue: initialValue,
        instanceName: instanceName,
        handler: handler);
  }

  /// this function is used to implement several others
  /// therefore not all parameters will be always used
  /// [initialValueProvider] can return an initial value that is returned
  /// as long the Future has not completed
  /// [preserveState] if select returns a different value than on the last
  /// build this determines if for the new subscription [initialValueProvider()] or
  /// the last received value should be used as initialValue
  /// [executeImmediately] if the handler should be directly called.
  /// if the Future has completed [handler] will be called every time until
  /// the handler calls `cancel` or the widget is destroyed
  /// [futureProvider] overrides a looked up future. Used to implement [allReady]
  /// We use provider functions here so that [registerFutureHandler] ensure
  /// that they are only called once.
  AsyncSnapshot<R?> registerFutureHandler<T extends Object, R>({
    T? target,
    void Function(BuildContext context, AsyncSnapshot<R?> snapshot,
            void Function() cancel)?
        handler,
    required bool allowMultipleSubscribers,
    R Function()? initialValueProvider,
    bool preserveState = true,
    bool executeImmediately = false,
    Future<R> Function()? futureProvider,
    String? instanceName,
  }) {
    assert(
        futureProvider != null || target != null,
        "target can't be null if you use ${handler != null ? 'registerFutureHandler' : 'watchFuture'} "
        'if you want target directly pass (x)=>x');
    var watch = _getWatch() as _WatchEntry<Future<R>, AsyncSnapshot<R?>>?;

    Future<R>? future;
    if (futureProvider == null && target is Future<R>) {
      /// so we use [select] to get our Future
      future = target;
    }

    R? initialValue;
    if (watch != null) {
      if (future == watch.observedObject || futureProvider != null) {
        ///  still the same Future so we can directly return lastvalue
        /// in case that we got a futureProvider we always keep the first
        /// returned Future
        /// and call the Handler again as the state hasn't changed
        if (handler != null) {
          handler(_element!, watch.lastValue!, watch.dispose);
        }

        return watch.lastValue!;
      } else {
        /// select returned a different value than the last time
        /// so we have to unregister out handler and subscribe anew
        watch.dispose();
        initialValue = preserveState && watch.lastValue!.hasData
            ? watch.lastValue!.data ?? initialValueProvider?.call()
            : initialValueProvider?.call as R?;
      }
    } else {
      /// In case futureProvider != null
      future ??= futureProvider!();

      watch = _WatchEntry<Future<R>, AsyncSnapshot<R?>>(
          observedObject: future,
          isHandlerWatch: handler != null,
          dispose: (x) => x.activeCallbackIdentity = null);
      _appendWatch(watch, allowMultipleSubcribers: allowMultipleSubscribers);
    }
    //if no handler was passed we expect that this is a normal watchFuture
    handler ??= (context, x, cancel) => (context as Element).markNeedsBuild();

    /// in case of a new watch or an changing Future we do the following:
    watch.observedObject = future!;

    /// by using a local variable we ensure that only the value and not the
    /// variable is captured.
    final callbackIdentity = Object();
    watch.activeCallbackIdentity = callbackIdentity;
    future.then(
      (x) {
        if (watch!.activeCallbackIdentity == callbackIdentity) {
          // print('Future completed $x');
          // only update if Future is still valid
          watch.lastValue = AsyncSnapshot.withData(ConnectionState.done, x);
          handler!(_element!, watch.lastValue!, watch.dispose);
        }
      },
      onError: (Object error) {
        if (watch!.activeCallbackIdentity == callbackIdentity) {
          // print('Future error');
          watch.lastValue =
              AsyncSnapshot.withError(ConnectionState.done, error);
          handler!(_element!, watch.lastValue!, watch.dispose);
        }
      },
    );

    watch.lastValue = AsyncSnapshot<R?>.withData(
        ConnectionState.waiting, initialValue ?? initialValueProvider?.call());
    if (executeImmediately) {
      handler(_element!, watch.lastValue!, watch.dispose);
    }

    return watch.lastValue!;
  }

  bool allReady(
      {void Function(BuildContext context)? onReady,
      void Function(BuildContext context, Object? error)? onError,
      Duration? timeout,
      bool shouldRebuild = true}) {
    return registerFutureHandler<Object, bool>(
      handler: (context, x, dispose) {
        if (x.hasError) {
          onError?.call(context, x.error);
        } else {
          onReady?.call(context);
          if (shouldRebuild) {
            (context as Element).markNeedsBuild();
          }
        }
        dispose();
      },
      allowMultipleSubscribers: false,
      initialValueProvider: () => GetIt.I.allReadySync(),

      /// as `GetIt.allReady` returns a Future<void> we convert it
      /// to a bool because if this Future completes the meaning is true.
      futureProvider: () =>
          GetIt.I.allReady(timeout: timeout).then((_) => true),
    ).data!;
  }

  bool isReady<T extends Object>(
      {void Function(BuildContext context)? onReady,
      void Function(BuildContext context, Object? error)? onError,
      Duration? timeout,
      String? instanceName}) {
    return registerFutureHandler<Object, bool>(
        handler: (context, x, cancel) {
          if (x.hasError) {
            onError?.call(context, x.error);
          } else {
            onReady?.call(context);
          }
          (context as Element).markNeedsBuild();
          cancel(); // we want exactly one call.
        },
        allowMultipleSubscribers: false,
        initialValueProvider: () =>
            GetIt.I.isReadySync<T>(instanceName: instanceName),

        /// as `GetIt.allReady` returns a Future<void> we convert it
        /// to a bool because if this Future completes the meaning is true.
        futureProvider: () => GetIt.I
            .isReady<T>(instanceName: instanceName, timeout: timeout)
            .then((_) => true)).data!;
  }

  bool _scopeWasPushed = false;
  String? _scopeName;

  void pushScope({void Function(GetIt getIt)? init, void Function()? dispose}) {
    if (!_scopeWasPushed) {
      _scopeName = 'AutoScope: ${DateTime.now().microsecondsSinceEpoch}';
      GetIt.I.pushNewScope(dispose: dispose, init: init, scopeName: _scopeName);
      _scopeWasPushed = true;
    }
  }

  bool? rebuildOnScopeChanges() {
    final result = onScopeChanged!.value;
    watchListenable(target: onScopeChanged!);
    onScopeChanged!.value = null;
    return result;
  }

  void clearRegistratons() {
    // print('clearRegistration');
    for (var x in _watchList) {
      x.dispose();
    }
    _watchList.clear();
    currentWatchIndex = null;
  }

  void dispose() {
    // print('dispose');
    clearRegistratons();
    if (_scopeWasPushed) {
      GetIt.I.dropScope(_scopeName!);
    }
    _element = null; // making sure the Garbage collector can do its job
  }
}
