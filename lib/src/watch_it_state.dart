part of 'watch_it.dart';

class _WatchEntry<TObservedObject, TValue> {
  TObservedObject observedObject;
  VoidCallback? notificationHandler;
  StreamSubscription? subscription;
  final void Function(_WatchEntry entry)? _dispose;
  TValue? lastValue;
  bool isHandlerWatch;
  TValue? Function(TObservedObject)? selector;
  bool handlerWasCalled = false;

  Object? activeCallbackIdentity;
  _WatchEntry(
      {this.notificationHandler,
      this.subscription,
      this.selector,
      required void Function(_WatchEntry entry)? dispose,
      this.lastValue,
      this.isHandlerWatch = false,
      required this.observedObject})
      : _dispose = dispose;
  void dispose() {
    _dispose?.call(this);
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

    /// prepare infrastructure to observe scope changes
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
      {bool allowMultipleSubscribers = false}) {
    if (!entry.isHandlerWatch && !allowMultipleSubscribers) {
      for (final watch in _watchList) {
        if (watch.watchesTheSameAndNotHandler(entry)) {
          throw ArgumentError('This Object is already watched by watch_it');
        }
      }
    }
    _watchList.add(entry);
    currentWatchIndex = null;
  }

  /// [handler] and [executeImmediately] are used by [registerHandler]
  void watchListenable<R>({
    required Listenable target,
    void Function(BuildContext context, R newValue, void Function() dispose)?
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
      if (_element == null) {
        /// it seems it can happen that a handler is still
        /// registered even after dispose was called
        /// to protect against this we just
        return;
      }
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
      if (_element == null) {
        /// it seems it can happen that a handler is still
        /// registered even after dispose was called
        /// to protect against this we just
        return;
      }
      if (target is ValueListenable) {
        handler(_element!, target.value, watch.dispose);
      } else {
        handler(_element!, target as R, watch.dispose);
      }
    }
  }

  watchPropertyValue<T extends Listenable, R>({
    required T listenable,
    required R Function(T) only,
  }) {
    var watch = _getWatch() as _WatchEntry<Listenable, R>?;

    if (watch != null) {
      if (listenable != watch.observedObject) {
        /// the target object has changed probably by passing another instance
        /// so we have to unregister our handler and subscribe anew
        watch.dispose();
      } else {
        // if the listenable is the same we can directly return
        return;
      }
    } else {
      watch = _WatchEntry<T, R>(
          observedObject: listenable,
          selector: only,
          lastValue: only(listenable),
          dispose: (x) =>
              x.observedObject!.removeListener(x.notificationHandler!));
      _appendWatch(watch, allowMultipleSubscribers: true);
      // we have to set `allowMultipleSubscribers=true` because we can't differentiate
      // one selector function from another.
    }

    handler() {
      if (_element == null) {
        /// it seems it can happen that a handler is still
        /// registered even after dispose was called
        /// to protect against this we just
        return;
      }
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
        ///  still the same stream so we can directly return last value
        if (handler == null) {
          assert(watch.lastValue != null && !watch.lastValue!.hasError);
          return AsyncSnapshot<R>.withData(
              watch.lastValue!.connectionState, watch.lastValue!.data as R);
        } else {
          return AsyncSnapshot<R>.nothing();
        }
      } else {
        /// select returned a different value than the last time
        /// so we have to unregister our handler and subscribe anew
        watch.dispose();
        initialValue = preserveState && watch.lastValue!.hasData
            ? watch.lastValue!.data
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
        if (_element == null) {
          /// it seems it can happen that a handler is still
          /// registered even after dispose was called
          /// to protect against this we just
          return;
        }
        if (handler != null) {
          handler(_element!, AsyncSnapshot.withData(ConnectionState.active, x),
              watch!.dispose);
        } else {
          watch!.lastValue = AsyncSnapshot.withData(ConnectionState.active, x);
          _element!.markNeedsBuild();
        }
      },
      onError: (Object error) {
        if (_element == null) {
          /// it seems it can happen that a handler is still
          /// registered even after dispose was called
          /// to protect against this we just
          return;
        }
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
      if (_element == null) {
        /// it seems it can happen that a handler is still
        /// registered even after dispose was called
        /// to protect against this we just
        return AsyncSnapshot<R>.nothing();
      }
      if (initialValue != null) {
        handler(
            _element!,
            AsyncSnapshot.withData(ConnectionState.waiting, initialValue),
            watch.dispose);
      }
      return AsyncSnapshot<R>.nothing();
    }
    assert(watch.lastValue != null && !watch.lastValue!.hasError);
    return AsyncSnapshot<R>.withData(
        watch.lastValue!.connectionState, watch.lastValue!.data as R);
  }

  void registerHandler<T extends Object, R>(
    Listenable target,
    void Function(BuildContext context, R newValue, void Function() dispose)
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
  AsyncSnapshot<R> registerFutureHandler<T extends Object?, R>(
      {T? target,
      void Function(BuildContext context, AsyncSnapshot<R?> snapshot,
              void Function() cancel)?
          handler,
      required bool allowMultipleSubscribers,
      required R Function() initialValueProvider,
      bool preserveState = true,
      bool executeImmediately = false,
      Future<R> Function()? futureProvider,
      String? instanceName,
      bool callHandlerOnlyOnce = false,
      void Function(R value)? dispose}) {
    assert(
        futureProvider != null || target != null,
        "if you use ${handler != null ? 'registerFutureHandler' : 'watchFuture'} "
        'target or futureProvider has to be provided');
    var watch = _getWatch() as _WatchEntry<Future<R>, AsyncSnapshot<R>>?;

    Future<R>? future;
    if (futureProvider == null && target is Future<R>) {
      future = target;
    }

    R? initialValue;
    if (watch != null) {
      if (future == watch.observedObject || futureProvider != null) {
        ///  still the same Future so we can directly return last value
        /// in case that we got a futureProvider we always keep the first
        /// returned Future
        /// and call the Handler again as the state hasn't changed
        if (handler != null &&
            _element != null &&
            (!watch.handlerWasCalled || !callHandlerOnlyOnce)) {
          handler(_element!, watch.lastValue!, watch.dispose);
          watch.handlerWasCalled = true;
        }

        return watch.lastValue!;
      } else {
        /// select returned a different value than the last time
        /// so we have to unregister out handler and subscribe anew
        watch.dispose();
        initialValue = preserveState && watch.lastValue!.hasData
            ? watch.lastValue!.data
            : initialValueProvider?.call();
      }
    } else {
      /// In case futureProvider != null
      future ??= futureProvider!();

      watch = _WatchEntry<Future<R>, AsyncSnapshot<R>>(
          observedObject: future,
          isHandlerWatch: handler != null,
          dispose: (x) {
            x.activeCallbackIdentity = null;
            if (dispose != null && x.lastValue != null) {
              dispose(x.lastValue!.data as R);
            }
          });
      _appendWatch(watch, allowMultipleSubscribers: allowMultipleSubscribers);
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
        if (_element == null) {
          /// it seems it can happen that a handler is still
          /// registered even after dispose was called
          /// to protect against this we just
          return;
        }

        /// here we compare the captured callbackIdentity with the one that is
        /// currently stored in the watch. If they are different it means that
        /// the future isn't the same anymore and we don't have to call the handler
        if (watch!.activeCallbackIdentity == callbackIdentity) {
          // print('Future completed $x');
          // only update if Future is still valid
          watch.lastValue = AsyncSnapshot.withData(ConnectionState.done, x);
          handler!(_element!, watch.lastValue!, watch.dispose);
          watch.handlerWasCalled = true;
        }
      },
      onError: (Object error) {
        if (_element == null) {
          /// it seems it can happen that a handler is still
          /// registered even after dispose was called
          /// to protect against this we just
          return;
        }
        if (watch!.activeCallbackIdentity == callbackIdentity) {
          // print('Future error');
          watch.lastValue =
              AsyncSnapshot.withError(ConnectionState.done, error);
          handler!(_element!, watch.lastValue!, watch.dispose);
          watch.handlerWasCalled = true;
        }
      },
    );

    watch.lastValue = AsyncSnapshot<R>.withData(
        ConnectionState.waiting, initialValue ?? initialValueProvider.call());
    if (executeImmediately && _element != null) {
      handler(_element!, watch.lastValue!, watch.dispose);
      watch.handlerWasCalled = true;
    }

    return watch.lastValue!;
  }

  bool _testIfDisposable(Object? d) {
    if (d == null) {
      return false;
    }
    Object? dispose;
    try {
      dispose = (d as dynamic).dispose;
      if (dispose is void Function()) {
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  T createOnce<T>(T Function() factoryFunc, {void Function(T value)? dispose}) {
    var watch = _getWatch() as _WatchEntry<void, T>?;

    if (watch == null) {
      final value = factoryFunc();
      watch = _WatchEntry(
        lastValue: value,
        observedObject: null,
        dispose: dispose != null
            ? (x) => dispose(x.lastValue!)
            : (_testIfDisposable(value)
                ? (x) {
                    (x.lastValue as dynamic).dispose();
                  }
                : (_) {
                    assert(() {
                      // ignore: avoid_print
                      print(
                          'WatchIt: Info - createOnce without a dispose function');
                      return true;
                    }());
                  }),
      );
      _appendWatch(watch);
    }
    return watch.lastValue!;
  }

  AsyncSnapshot<T> createOnceAsync<T>(Future<T> Function() factoryFunc,
      {required T initialValue, void Function(T value)? dispose}) {
    return registerFutureHandler<void, T>(
      allowMultipleSubscribers: false,
      initialValueProvider: () => initialValue,
      futureProvider: factoryFunc,
      dispose: (x) {
        if (dispose != null) {
          dispose(x);
        } else {
          if (_testIfDisposable(x)) {
            (x as dynamic).dispose();
          } else {
            assert(() {
              // ignore: avoid_print
              print(
                  'WatchIt: Info - createOnceAsync without a dispose function');
              return true;
            }());
          }
        }
      },
    );
  }

  bool allReady(
      {void Function(BuildContext context)? onReady,
      void Function(BuildContext context, Object? error)? onError,
      Duration? timeout,
      bool shouldRebuild = true,
      bool callHandlerOnlyOnce = false}) {
    final readyResult = registerFutureHandler<Object, bool>(
      handler: (context, x, dispose) {
        if (x.hasError) {
          onError?.call(context, x.error);
        } else {
          onReady?.call(context);
        }
        if (shouldRebuild) {
          (context as Element).markNeedsBuild();
        }
        dispose();
      },
      allowMultipleSubscribers: false,
      initialValueProvider: () => GetIt.I.allReadySync(),

      /// as `GetIt.allReady` returns a Future<void> we convert it
      /// to a bool because if this Future completes the meaning is true.
      futureProvider: () =>
          GetIt.I.allReady(timeout: timeout).then((_) => true),
      callHandlerOnlyOnce: callHandlerOnlyOnce,
    );
    if (readyResult.hasData) {
      return readyResult.data!;
    }
    if (readyResult.hasError && onError != null) {
      return false;
    }
    if (readyResult.error is WaitingTimeOutException) throw readyResult.error!;
    throw Exception(
        'One of your async registrations in GetIt threw an error while waiting for them to finish: \n'
        '${readyResult.error}\n Enable "break on uncaught exceptions" in your debugger to find out more.');
  }

  bool isReady<T extends Object>({
    void Function(BuildContext context)? onReady,
    void Function(BuildContext context, Object? error)? onError,
    Duration? timeout,
    String? instanceName,
    bool callHandlerOnlyOnce = false,
  }) {
    final readyResult = registerFutureHandler<Object, bool>(
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
          .then((_) => true),
      callHandlerOnlyOnce: callHandlerOnlyOnce,
    );

    if (readyResult.hasData) {
      return readyResult.data!;
    }
    if (readyResult.hasError && onError != null) {
      return false;
    }
    if (readyResult.error is WaitingTimeOutException) throw readyResult.error!;
    throw Exception(
        'The factory function of type $T of your registration in GetIt threw an error while waiting for them to finish: \n'
        '${readyResult.error}\n Enable "break on uncaught exceptions" in your debugger to find out more.');
  }

  bool _scopeWasPushed = false;
  String? _scopeName;
  static int _autoScopeCounter = 0;

  void pushScope(
      {void Function(GetIt getIt)? init,
      void Function()? dispose,
      bool isFinal = false}) {
    if (!_scopeWasPushed) {
      _scopeName = 'AutoScope: ${_autoScopeCounter++}';
      GetIt.I.pushNewScope(
          dispose: dispose,
          init: init,
          scopeName: _scopeName,
          isFinal: isFinal);
      _scopeWasPushed = true;
    }
  }

  bool _initWasCalled = false;
  void Function()? _initDispose;

  void callOnce(void Function(BuildContext context) init,
      {void Function()? dispose}) {
    _initDispose = dispose;
    if (!_initWasCalled) {
      init(_element!);
      _initWasCalled = true;
    }
  }

  void Function()? _disposeFunction;
  void onDispose(void Function() dispose) {
    _disposeFunction ??= dispose;
  }

  bool? rebuildOnScopeChanges() {
    final result = onScopeChanged!.value;
    watchListenable(target: onScopeChanged!);
    onScopeChanged!.value = null;
    return result;
  }

  void clearRegistrations() {
    // print('clearRegistration');
    for (var x in _watchList) {
      x.dispose();
    }
    _watchList.clear();
    currentWatchIndex = null;
  }

  void dispose() {
    // print('dispose');
    clearRegistrations();
    if (_scopeWasPushed) {
      GetIt.I.dropScope(_scopeName!);
    }
    _initDispose?.call();
    _disposeFunction?.call();
    _element = null; // making sure the Garbage collector can do its job
  }
}
