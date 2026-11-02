import 'dart:async';

/// Refreshes server presence at activation, without waiting for the heartbeat.
/// A profile update caused by our own refresh must not trigger another request.
class CaptainPresence {
  CaptainPresence(this.send);
  final Future<void> Function(String account) send;
  String? _account;
  bool _online = false, _foreground = true;
  Future<void>? _pending;

  void profile(String account, {required bool online}) {
    final activated = _account != account || (!_online && online);
    if (_account != account) _pending = null;
    _account = account;
    _online = online;
    if (online && activated) unawaited(refresh());
  }

  void foreground(bool value) {
    final resumed = value && !_foreground;
    _foreground = value;
    if (resumed) unawaited(refresh());
  }

  Future<void> refresh() {
    final account = _account;
    if (account == null || !_online) return Future.value();
    if (_pending != null) return _pending!;
    final task = Future<void>.sync(() => send(account))
        .catchError((Object _) {});
    _pending = task;
    unawaited(task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    }));
    return task;
  }

  void clear() {
    _account = null;
    _online = false;
    _pending = null;
  }
}
