part of 'watch_it.dart';

_WatchItState? _activeWatchItState;

mixin _GetItElement on ComponentElement {
  final _WatchItState _state = _WatchItState();
  @override
  void mount(Element? parent, dynamic newSlot) {
    _state.init(this);
    super.mount(parent, newSlot);
  }

  @override
  Widget build() {
    //print('build');
    _state.resetCurrentWatch();
    _activeWatchItState = _state;
    late Widget result;
    try {
      result = super.build();
    } finally {
      _activeWatchItState = null;
    }
    return result;
  }

  @override
  void unmount() {
    _state.dispose();
    super.unmount();
  }
}

class _StatelessWatchItElement<W extends StatelessWidget>
    extends StatelessElement with _GetItElement {
  _StatelessWatchItElement(W super.widget);
}

class _StatefulWatchItElement<W extends StatefulWidget> extends StatefulElement
    with _GetItElement {
  _StatefulWatchItElement(W super.widget);
}
