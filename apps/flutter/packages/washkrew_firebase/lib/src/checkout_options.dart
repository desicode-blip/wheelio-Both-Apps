import 'package:washkrew_ui/washkrew_ui.dart' show Brand;

Map<String, dynamic> checkoutOptions(
  Map<String, dynamic> options,
  String phone,
) {
  final key = options['keyId'], amount = options['amount'];
  if (key is! String ||
      !RegExp(r'^rzp_(test|live)_[A-Za-z0-9]+$').hasMatch(key) ||
      amount is! int ||
      amount < 100 ||
      options['currency'] != 'INR' ||
      options['orderId'] is! String ||
      !(options['orderId'] as String).startsWith('order_') ||
      options['testMode'] != key.startsWith('rzp_test_')) {
    throw StateError(
      'Payment configuration is unavailable. Reopen this booking and try again.',
    );
  }
  return {
    'key': key,
    'order_id': options['orderId'],
    'amount': amount,
    'currency': 'INR',
    'name': Brand.name,
    'description': 'Doorstep exterior wash',
    'prefill': {'contact': phone},
    'theme': {'color': '#0049FF'},
  };
}
