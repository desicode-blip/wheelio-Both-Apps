import 'dart:async';
import 'package:flutter/widgets.dart';

/// A bank/UPI switch may return without the SDK callback. Recover only from a
/// server-confirmed capture; foregrounding alone never grants a paid booking.
class PaymentReturnRecovery with WidgetsBindingObserver {
  PaymentReturnRecovery({required this.check, required this.onCaptured, this.onReturned}) {
    WidgetsBinding.instance.addObserver(this);
  }
  final Future<bool> Function() check;
  final VoidCallback onCaptured;
  /// 13 Nov (Aman): the customer came back from the UPI app; show "Confirming your payment".
  final VoidCallback? onReturned;
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
      // Webhooks can take a few seconds after the UPI app says "paid": keep checking for
      // about 90 s, quickly at first, so the next step opens by itself.
      _remaining = 60;
      _timer?.cancel();
      onReturned?.call();
      _timer = Timer(const Duration(milliseconds:300), _poll);
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
    if (!_left && --_remaining > 0) _timer = Timer(const Duration(milliseconds:1500), _poll);
  }
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
