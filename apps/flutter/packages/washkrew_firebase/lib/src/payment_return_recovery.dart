import 'dart:async';
import 'package:flutter/widgets.dart';

/// A bank/UPI switch may return without the SDK callback. Recover only from a
/// server-confirmed capture; foregrounding alone never grants a paid booking.
class PaymentReturnRecovery with WidgetsBindingObserver {
  PaymentReturnRecovery({required this.check, required this.onCaptured}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final Future<bool> Function() check;
  final VoidCallback onCaptured;
  Timer? _timer;
  bool _left = false, _disposed = false, _checking = false;
  int _remaining = 0;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _left = true;
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && _left && !_disposed) {
      _left = false;
      _remaining = 15;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds:500), _poll);
    }
  }
  Future<void> _poll() async {
    if (_disposed || _checking) return;
    _checking = true;
    var captured = false;
    try { captured = await check(); } catch (_) { /* Preserve SDK recovery. */ }
    _checking = false;
    if (_disposed) return;
    if (captured) { onCaptured(); return; }
    if (!_left && --_remaining > 0) _timer = Timer(const Duration(seconds:2), _poll);
  }
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
