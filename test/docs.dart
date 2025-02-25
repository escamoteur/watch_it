// Create a ChangeNotifier based model
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

class UserModel extends ChangeNotifier {
  String get name => _name;
  String _name = '';
  set name(String value) {
    _name = value;
    notifyListeners();
  }

  Stream<String> get userNameUpdates =>
      Stream.periodic(const Duration(seconds: 1)).map((_) => _name);
}

class AppModel {
  Future<bool> get initializationReady =>
      Future.delayed(const Duration(seconds: 1), () => true);
}

void init() {
  // Register it
  di.registerSingleton<UserModel>(UserModel());
}

// Watch it
class UserNameText extends WatchingWidget {
  const UserNameText({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = watchPropertyValue((UserModel m) => m.name);
    return Text(userName);
  }
}

// instead of
class UserNameText2 extends WatchingWidget {
  const UserNameText2({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: di<UserModel>(),
      builder: (context, child) {
        return Text(di<UserModel>().name);
      },
    );
  }
}

class MyWidget extends StatelessWidget with WatchItMixin {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser =
        watchStream((UserModel x) => x.userNameUpdates, initialValue: 'NoUser');
    final ready =
        watchFuture((AppModel x) => x.initializationReady, initialValue: false)
            .data;
    bool appIsLoading = ready == false || currentUser.hasData == false;

    if (appIsLoading) return CircularProgressIndicator();
    return Text(currentUser.data!);
  }
}

class MyWidgetWithBuilders extends StatelessWidget {
  const MyWidgetWithBuilders({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: di<AppModel>().initializationReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        return StreamBuilder(
          stream: di<UserModel>().userNameUpdates,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }
            return Text(snapshot.data!);
          },
        );
      },
    );
  }
}

class MyWidgetWithCreateOnce extends StatelessWidget with WatchItMixin {
  const MyWidgetWithCreateOnce({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        createOnce<TextEditingController>(() => TextEditingController());
    return Row(
      children: [
        TextField(
          controller: controller,
        ),
        ElevatedButton(
          onPressed: () => controller.clear(),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
