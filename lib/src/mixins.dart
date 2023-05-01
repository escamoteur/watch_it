part of 'watch_it.dart';

mixin WatchItMixin on StatelessWidget {
  @override
  StatelessElement createElement() => _StatelessWatchItElement(this);
}

mixin WatchItStatefulWidgetMixin on StatefulWidget {
  @override
  StatefulElement createElement() => _StatefulWatchItElement(this);
}
