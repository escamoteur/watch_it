part of 'watch_it.dart';

abstract class WatchingWidget extends StatelessWidget {
  const WatchingWidget({Key? key}) : super(key: key);

  @override
  StatelessElement createElement() =>
      _StatelessWatchItElement<WatchingWidget>(this);
}

abstract class WatchingStatefulWidget extends StatefulWidget {
  const WatchingStatefulWidget({Key? key}) : super(key: key);

  @override
  StatefulElement createElement() => _StatefulWatchItElement(this);
}
