// ignore_for_file: unused_local_variable
// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_it/watch_it.dart';

class Model extends ChangeNotifier {
  String? constantValue;
  String? _country;
  set country(String? val) {
    _country = val;
    notifyListeners();
  }

  String? get country => _country;
  String? _country2;
  set country2(String? val) {
    _country2 = val;
    notifyListeners();
  }

  void setNameNull() {
    name = null;
  }

  ValueNotifier<String>? nullValueNotifier;

  String? get country2 => _country2;
  ValueNotifier<String>? name;
  final Model? nestedModel;
  // ignore: close_sinks
  final StreamController<String> streamController =
      StreamController<String>.broadcast();

  Model(
      {this.constantValue,
      String? country,
      this.name,
      this.nestedModel,
      String? country2})
      : _country = country,
        _country2 = country2;

  Stream<String> get stream => streamController.stream;
  final Completer<String?> completer = Completer<String?>();
  Future<String?> get future => completer.future;
}

class TestStateLessWidget extends StatelessWidget with WatchItMixin {
  final bool watchTwice;
  final bool watchListenableInGetIt;
  final bool watchOnlyTwice;
  final bool watchValueTwice;
  final bool watchStreamTwice;
  final bool watchFutureTwice;
  final bool testIsReady;
  final bool testAllReady;
  final bool testAllReadyHandler;
  final bool watchListenableWithWatchPropertyValue;
  final bool testNullValueNotifier;
  final ValueListenable<int>? localTarget;
  final bool callAllReadyHandlerOnlyOnce;
  TestStateLessWidget(
      {Key? key,
      this.localTarget,
      this.watchTwice = false,
      this.watchListenableInGetIt = false,
      this.watchOnlyTwice = false,
      this.watchValueTwice = false,
      this.watchStreamTwice = false,
      this.watchFutureTwice = false,
      this.testIsReady = false,
      this.testAllReady = false,
      this.watchListenableWithWatchPropertyValue = false,
      this.testNullValueNotifier = false,
      this.testAllReadyHandler = false,
      this.callAllReadyHandlerOnlyOnce = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    callOnce(
      (context) {
        initCount++;
      },
      dispose: () {
        initDiposeCount++;
      },
    );
    onDispose(() {
      disposeCount++;
    });
    final wasScopePushed = rebuildOnScopeChanges();
    buildCount++;
    final onlyRead = di<Model>().constantValue!;
    final notifierVal = watch(di<ValueNotifier<String>>()).value;

    String? country;
    String country2;
    if (watchListenableInGetIt) {
      final model = watchIt<Model>();
      country = model.country!;
      country2 = model.country2!;
    }
    if (watchListenableWithWatchPropertyValue) {
      final name2 = watchPropertyValue((Model x) => x.name);
    }
    country = watchPropertyValue((Model x) => x.country);
    country2 = watchPropertyValue((Model x) => x.country2)!;
    final name = watchValue((Model x) => x.name!);
    final nestedCountry =
        watchPropertyValue(target: di<Model>().nestedModel, (x) => x.country)!;

    final localTargetValue =
        localTarget != null ? watch(localTarget!).value : 0;
    final streamResult =
        watchStream((Model x) => x.stream, initialValue: 'streamResult');
    final futureResult =
        watchFuture((Model x) => x.future, initialValue: 'futureResult');
    registerStreamHandler<Model, String>(
        select: (x) => x.stream,
        handler: (context, x, cancel) {
          streamHandlerResult = x.data;
          if (streamHandlerResult == 'Cancel') {
            cancel();
          }
        });
    registerFutureHandler<Model, String?>(
        select: (Model x) => x.future,
        handler: (context, x, cancel) {
          futureHandlerResult = x.data;
          if (streamHandlerResult == 'Cancel') {
            cancel();
          }
        });
    registerHandler(
        select: (Model x) => x.name!,
        handler: (context, String x, cancel) {
          listenableHandlerResult = x;
          if (x == 'Cancel') {
            cancel();
          }
        });
    bool? allReadyResult;
    if (testAllReady) {
      allReadyResult =
          allReady(onReady: (context) => allReadyHandlerResult = 'Ready');
    }
    if (testAllReadyHandler) {
      allReadyHandler((context) {
        allReadyHandlerCount++;
        allReadyHandlerResult2 = 'Ready';
      }, callHandlerOnlyOnce: callAllReadyHandlerOnlyOnce);
    }
    bool? isReadyResult;

    if (testIsReady) {
      isReadyResult = isReady<Model>(
          instanceName: 'isReadyTest',
          onReady: (context) => isReadyHandlerResult = 'Ready');
    }
    if (watchTwice) {
      final notifierVal = watchIt<ValueNotifier<String>>().value;
    }
    if (watchOnlyTwice) {
      final country = watchPropertyValue((Model x) => x.country);
    }
    if (watchValueTwice) {
      final name = watchValue((Model x) => x.name!);
    }
    if (watchStreamTwice) {
      final streamResult =
          watchStream((Model x) => x.stream, initialValue: 'streamResult');
    }
    if (watchFutureTwice) {
      final futureResult =
          watchFuture((Model x) => x.future, initialValue: 'futureResult');
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Text(onlyRead, key: const Key('onlyRead')),
          Text(notifierVal, key: const Key('notifierVal')),
          Text(country ?? 'null', key: const Key('country')),
          Text(country2, key: const Key('country2')),
          Text(name, key: const Key('name')),
          Text(nestedCountry, key: const Key('nestedCountry')),
          Text(localTargetValue.toString(), key: const Key('localTarget')),
          Text(streamResult.data!, key: const Key('streamResult')),
          Text(futureResult.data!, key: const Key('futureResult')),
          Text(allReadyResult.toString(), key: const Key('allReadyResult')),
          Text(isReadyResult.toString(), key: const Key('isReadyResult')),
          Text(wasScopePushed.toString(), key: const Key('wasScopePushed')),
        ],
      ),
    );
  }
}

late Model theModel;
late ValueNotifier<String> valNotifier;
int buildCount = 0;
String? streamHandlerResult;
String? futureHandlerResult;
String? listenableHandlerResult;
String? allReadyHandlerResult;
String? allReadyHandlerResult2;
String? isReadyHandlerResult;
int allReadyHandlerCount = 0;
int initCount = 0;
int initDiposeCount = 0;
int disposeCount = 0;

void main() {
  setUp(() async {
    buildCount = 0;
    allReadyHandlerCount = 0;
    streamHandlerResult = null;
    listenableHandlerResult = null;
    streamHandlerResult = null;
    futureHandlerResult = null;
    allReadyHandlerResult = null;
    allReadyHandlerResult2 = null;
    isReadyHandlerResult = null;
    allReadyHandlerCount = 0;
    initCount = 0;
    initDiposeCount = 0;
    disposeCount = 0;
    await GetIt.I.reset();
    valNotifier = ValueNotifier<String>('notifierVal');
    theModel = Model(
        constantValue: 'onlyRead',
        country: 'country',
        country2: 'country',

        /// check if watchOnly can differentiate between the two country fields
        name: ValueNotifier('name'),
        nestedModel: Model(country: 'nestedCountry'));
    GetIt.I.registerSingleton<Model>(theModel);
    GetIt.I.registerSingleton(valNotifier);
  });

  testWidgets('onetime access without any data changes', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final country2 =
        tester.widget<Text>(find.byKey(const Key('country2'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;
    final scopeResult =
        tester.widget<Text>(find.byKey(const Key('wasScopePushed'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(country2, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(scopeResult, 'null');
    expect(buildCount, 1);
  });
  testWidgets('rebuild on scope changes', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    await tester.pump();

    var scopeResult =
        tester.widget<Text>(find.byKey(const Key('wasScopePushed'))).data;
    expect(scopeResult, 'null');

    GetIt.I.pushNewScope();
    await tester.pump();

    scopeResult =
        tester.widget<Text>(find.byKey(const Key('wasScopePushed'))).data;
    expect(scopeResult, 'true');

    /// trigger a rebuild without changing any scopes
    valNotifier.value = '42';

    await tester.pump();

    scopeResult =
        tester.widget<Text>(find.byKey(const Key('wasScopePushed'))).data;
    expect(scopeResult, 'null');
    expect(buildCount, 3);

    await GetIt.I.popScope();
    await tester.pump();

    scopeResult =
        tester.widget<Text>(find.byKey(const Key('wasScopePushed'))).data;
    expect(scopeResult, 'false');
    expect(buildCount, 4);
  });
  testWidgets('callOnce test', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    valNotifier.value = '1';
    await tester.pump();
    valNotifier.value = '2';
    await tester.pump();

    expect(buildCount, 3);
    expect(initCount, 1);
    await tester.pumpWidget(Container());
    await tester.pump();
    expect(initDiposeCount, 1);
  });
  testWidgets('onDispose test', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    valNotifier.value = '1';
    await tester.pump();
    valNotifier.value = '2';
    await tester.pump();

    expect(buildCount, 3);
    await tester.pumpWidget(Container());
    await tester.pump();
    expect(disposeCount, 1);
  });

  testWidgets('watchTwice', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchTwice: true,
    ));
    await tester.pump();

    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('watchValueTwice', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchValueTwice: true,
    ));
    await tester.pump();

    expect(tester.takeException(), isA<ArgumentError>());
  });

// Unfortunately we can't check if two selectors point to the same
// object.
  // testWidgets('watchOnlyTwice', (tester) async {
  //   await tester.pumpWidget(TestStateLessWidget(
  //     watchOnlyTwice: true,
  //   ));
  //   await tester.pump();

  //   expect(tester.takeException(), isA<ArgumentError>());
  // });

  // testWidgets('watchXOnlyTwice', (tester) async {
  //   await tester.pumpWidget(TestStateLessWidget(
  //     watchXOnlyTwice: true,
  //   ));
  //   await tester.pump();

  //   expect(tester.takeException(), isA<ArgumentError>());
  // });

  testWidgets('watchStream twice', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchStreamTwice: true,
    ));
    await tester.pump();

    expect(tester.takeException(), isA<ArgumentError>());
  });
  testWidgets('watchFuture twice', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchFutureTwice: true,
    ));
    await tester.pump();

    expect(tester.takeException(), isA<ArgumentError>());
  });
  testWidgets('useWatchPropertyValue on a listenable', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchListenableWithWatchPropertyValue: true,
    ));
    await tester.pump();

    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('update of non watched field', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.constantValue = '42';
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 1);
  });

  testWidgets('test watchValue', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    valNotifier.value = '42';
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, '42');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('test watch local target', (tester) async {
    final localTarget = ValueNotifier(0);
    await tester.pumpWidget(TestStateLessWidget(
      localTarget: localTarget,
    ));
    localTarget.value = 42;
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final localTargetValue =
        tester.widget<Text>(find.byKey(const Key('localTarget'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(localTargetValue, '42');

    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('test watchValue', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.name!.value = '42';
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    // final futureResult = tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, '42');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    // expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });

  testWidgets('test watchPropertyValue', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.nestedModel!.country = '42';
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, '42');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('test watchPropertyValue with null value', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.country = null;
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'null');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('test watchPropertyValue with notification but no value change',
      (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.notifyListeners();
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 1);
  });
  testWidgets('test watchIt', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      watchListenableInGetIt: true,
    ));
    theModel.notifyListeners();
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('watchStream', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.streamController.sink.add('42');
    await tester.pump();
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, '42');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('watchFuture', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());
    theModel.completer.complete('42');
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    final error = tester.takeException();
    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'country');
    expect(name, 'name');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, '42');
    expect(buildCount, 2);
  });
  testWidgets('change multiple data', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());

    theModel.country = 'Lummerland';
    theModel.name!.value = '42';
    await tester.pump();

    final onlyRead =
        tester.widget<Text>(find.byKey(const Key('onlyRead'))).data;
    final notifierVal =
        tester.widget<Text>(find.byKey(const Key('notifierVal'))).data;
    final country = tester.widget<Text>(find.byKey(const Key('country'))).data;
    final name = tester.widget<Text>(find.byKey(const Key('name'))).data;
    final nestedCountry =
        tester.widget<Text>(find.byKey(const Key('nestedCountry'))).data;
    final streamResult =
        tester.widget<Text>(find.byKey(const Key('streamResult'))).data;
    final futureResult =
        tester.widget<Text>(find.byKey(const Key('futureResult'))).data;

    expect(onlyRead, 'onlyRead');
    expect(notifierVal, 'notifierVal');
    expect(country, 'Lummerland');
    expect(name, '42');
    expect(nestedCountry, 'nestedCountry');
    expect(streamResult, 'streamResult');
    expect(futureResult, 'futureResult');
    expect(buildCount, 2);
  });
  testWidgets('check that everything is released', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());

    expect(theModel.hasListeners, true);
    expect(theModel.name!.hasListeners, true);
    expect(theModel.streamController.hasListener, true);
    expect(valNotifier.hasListeners, true);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(theModel.hasListeners, false);
    expect(theModel.name!.hasListeners, false);
    expect(theModel.streamController.hasListener, false);
    expect(valNotifier.hasListeners, false);

    expect(buildCount, 1);
  });
  testWidgets('test handlers', (tester) async {
    await tester.pumpWidget(TestStateLessWidget());

    theModel.name!.value = '42';
    theModel.streamController.sink.add('4711');
    theModel.completer.complete('66');

    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

    expect(streamHandlerResult, '4711');
    expect(listenableHandlerResult, '42');
    expect(futureHandlerResult, '66');

    theModel.name!.value = 'Cancel';
    theModel.streamController.sink.add('Cancel');
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

    theModel.name!.value = '42';
    theModel.streamController.sink.add('4711');
    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

    expect(streamHandlerResult, 'Cancel');
    expect(listenableHandlerResult, 'Cancel');
    expect(buildCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(theModel.hasListeners, false);
    expect(theModel.name!.hasListeners, false);
    expect(theModel.streamController.hasListener, false);
    expect(valNotifier.hasListeners, false);
  });
  testWidgets('allReady no async object', (tester) async {
    await tester.pumpWidget(TestStateLessWidget(
      testAllReady: true,
    ));
    await tester.pump(const Duration(milliseconds: 10));

    final allReadyResult =
        tester.widget<Text>(find.byKey(const Key('allReadyResult'))).data;

    expect(allReadyResult, 'true');
    expect(allReadyHandlerResult, 'Ready');

    expect(buildCount, 2);
  });
  testWidgets('allReady async object that is finished', (tester) async {
    GetIt.I.registerSingletonAsync(
        () => Future.delayed(const Duration(milliseconds: 10), () => Model()),
        instanceName: 'asyncObject');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(TestStateLessWidget(
      testAllReady: true,
    ));
    await tester.pump();

    final allReadyResult =
        tester.widget<Text>(find.byKey(const Key('allReadyResult'))).data;

    expect(allReadyResult, 'true');
    expect(allReadyHandlerResult, 'Ready');

    expect(buildCount, 2);
  });
  testWidgets('allReady async object that is not finished at the start',
      (tester) async {
    GetIt.I.registerSingletonAsync(
        () => Future.delayed(const Duration(milliseconds: 40), () => Model()),
        instanceName: 'asyncObject');
    await tester.pumpWidget(TestStateLessWidget(
      testAllReady: true,
    ));
    await tester.pump(const Duration(milliseconds: 20));

    var allReadyResult =
        tester.widget<Text>(find.byKey(const Key('allReadyResult'))).data;

    expect(allReadyResult, 'false');
    expect(allReadyHandlerResult, null);

    await tester.pump(const Duration(milliseconds: 120));
    allReadyResult =
        tester.widget<Text>(find.byKey(const Key('allReadyResult'))).data;

    expect(allReadyResult, 'true');
    expect(allReadyHandlerResult, 'Ready');
    expect(buildCount, 2);
  });
  testWidgets('allReadyHandler test', (tester) async {
    GetIt.I.registerSingletonAsync(
        () => Future.delayed(const Duration(milliseconds: 10), () => Model()),
        instanceName: 'asyncObject');
    var testStateLessWidget = TestStateLessWidget(
      testAllReadyHandler: true,
    );
    await tester.pumpWidget(testStateLessWidget);
    await tester.pump();

    expect(allReadyHandlerResult2, null);

    await tester.pump(const Duration(milliseconds: 120));
    expect(allReadyHandlerResult2, 'Ready');
    expect(allReadyHandlerCount, 1);
    expect(buildCount, 1);

    valNotifier.value = '000'; // should trigger a rebuild
    await tester.pump(const Duration(milliseconds: 120));
    expect(allReadyHandlerCount, 2);
    expect(buildCount, 2);
  });
  testWidgets('allReadyHandler test: callHandlerOnlyOnce == true',
      (tester) async {
    GetIt.I.registerSingletonAsync(
        () => Future.delayed(const Duration(milliseconds: 10), () => Model()),
        instanceName: 'asyncObject');
    await tester.pumpWidget(TestStateLessWidget(
      testAllReadyHandler: true,
      callAllReadyHandlerOnlyOnce: true,
    ));
    await tester.pump();

    expect(allReadyHandlerResult2, null);

    await tester.pump(const Duration(milliseconds: 120));
    expect(allReadyHandlerResult2, 'Ready');
    expect(allReadyHandlerCount, 1);
    expect(buildCount, 1);

    valNotifier.value = '000'; // should trigger a rebuild
    await tester.pump(const Duration(milliseconds: 120));
    expect(allReadyHandlerCount, 1);
    expect(buildCount, 2);
  });
  testWidgets('isReady async object that is finished', (tester) async {
    GetIt.I.registerSingletonAsync<Model>(
        () => Future.delayed(const Duration(milliseconds: 10), () => Model()),
        instanceName: 'isReadyTest');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpWidget(TestStateLessWidget(
      testIsReady: true,
    ));
    await tester.pump();

    final isReadyResult =
        tester.widget<Text>(find.byKey(const Key('isReadyResult'))).data;

    expect(isReadyResult, 'true');
    expect(isReadyHandlerResult, 'Ready');

    expect(buildCount, 2);
  });
  testWidgets('isReady async object that is not finished at the start',
      (tester) async {
    GetIt.I.registerSingletonAsync(
        () => Future.delayed(const Duration(milliseconds: 10), () => Model()),
        instanceName: 'isReadyTest');
    await tester.pumpWidget(TestStateLessWidget(
      testIsReady: true,
    ));
    await tester.pump();
    await tester.pump();

    var isReadyResult =
        tester.widget<Text>(find.byKey(const Key('isReadyResult'))).data;

    expect(isReadyResult, 'false');
    expect(isReadyHandlerResult, null);

    await tester.pump(const Duration(milliseconds: 120));
    isReadyResult =
        tester.widget<Text>(find.byKey(const Key('isReadyResult'))).data;

    expect(isReadyResult, 'true');
    expect(isReadyHandlerResult, 'Ready');
    expect(buildCount, 2);
  });
}
