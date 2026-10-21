import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
  external void close();
  external void on(String event, JSFunction callback);
}

Future<void>? _loading;
Future<void> _load() => _loading ??= () async {
  final complete = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://checkout.razorpay.com/v1/checkout.js'
    ..async = true;
  script.onload = ((web.Event _) => complete.complete()).toJS;
  script.onerror = ((web.Event _) {
    _loading = null;
    complete.completeError(
      StateError(
        'Razorpay could not load. Check your connection and try again.',
      ),
    );
  }).toJS;
  web.document.head!.append(script);
  await complete.future.timeout(const Duration(seconds: 30));
}();

Future<Map<String, dynamic>?> openCheckout(
  Map<String, dynamic> options,
  String phone,
) async {
  await _load();
  final complete = Completer<Map<String, dynamic>?>();
  late _Razorpay instance;
  final handler = ((JSAny result) {
    if (!complete.isCompleted)
      complete.complete(Map<String, dynamic>.from(result.dartify() as Map));
  }).toJS;
  final dismiss = (() {
    if (!complete.isCompleted) complete.complete(null);
  }).toJS;
  instance = _Razorpay(
    {
          'key': options['keyId'],
          'order_id': options['orderId'],
          'amount': options['amount'],
          'currency': 'INR',
          'name': 'Wheelio',
          'description': 'Doorstep exterior wash',
          'handler': handler,
          'prefill': {'contact': phone},
          'theme': {'color': '#3160FF'},
          'modal': {'ondismiss': dismiss},
        }.jsify()
        as JSObject,
  );
  instance.on(
    'payment.failed',
    ((JSAny _) {
      if (!complete.isCompleted)
        complete.completeError(
          StateError(
            'Payment did not complete. You can retry without creating another booking.',
          ),
        );
      instance.close();
    }).toJS,
  );
  instance.open();
  return complete.future;
}
