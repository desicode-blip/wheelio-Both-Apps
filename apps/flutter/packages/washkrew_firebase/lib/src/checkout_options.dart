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
  final selected = options['selectedMethod'];
  if (selected != null &&
      !['gpay', 'phonepe', 'upi_id', 'card'].contains(selected)) {
    throw StateError('Choose one of the available payment methods.');
  }
  final method = selected == 'card' ? 'card' : 'upi';
  return {
    'key': key,
    'order_id': options['orderId'],
    'amount': amount,
    'currency': 'INR',
    'name': Brand.name,
    'description': 'Doorstep exterior wash',
    'prefill': {'contact': phone, if (selected != null) 'method': method},
    if (selected != null)
      'config': {
        'display': {
          'blocks': {
            'selected': {
              'name': selected == 'gpay'
                  ? 'Google Pay'
                  : selected == 'phonepe'
                  ? 'PhonePe'
                  : selected == 'card'
                  ? 'Card'
                  : 'UPI',
              'instruments': [
                {
                  'method': method,
                  if (selected == 'gpay' || selected == 'phonepe')
                    'apps': [selected == 'gpay' ? 'google_pay' : 'phonepe'],
                },
              ],
            },
          },
          'sequence': ['block.selected'],
          'preferences': {'show_default_blocks': true},
        },
      },
    'theme': {'color': '#0049FF'},
  };
}
