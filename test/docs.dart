// Create a ChangeNotifier based model
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:watch_it/watch_it.dart';

class UserModel extends ChangeNotifier {
  String get name => _name;
  String _name = '';
  set name(String value) {
    _name = value;
    notifyListeners();
  }
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
