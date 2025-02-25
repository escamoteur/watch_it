part of 'watch_it.dart';

abstract class WatchingWidget extends StatelessWidget {
  const WatchingWidget({super.key});

  @override
  StatelessElement createElement() =>
      _StatelessWatchItElement<WatchingWidget>(this);
}

abstract class WatchingStatefulWidget extends StatefulWidget {
  const WatchingStatefulWidget({super.key});

  @override
  StatefulElement createElement() => _StatefulWatchItElement(this);
}
