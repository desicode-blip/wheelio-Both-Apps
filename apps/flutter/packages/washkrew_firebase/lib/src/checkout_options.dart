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
      !['gpay', 'phonepe', 'upi_id', 'card', 'netbanking', 'wallet'].contains(selected)) {
    throw StateError('Choose one of the available payment methods.');
  }
  final first = selected == 'card' ? 'debit' : selected == 'netbanking' ? 'netbanking' : selected == 'wallet' ? 'wallets' : 'upi';
  return {
    'key': key,
    'order_id': options['orderId'],
    'amount': amount,
    'currency': 'INR',
    'name': Brand.name,
    'description': 'Doorstep exterior wash',
    // Open the full method chooser. A default Google Pay selection must not
    // land the customer inside a single app/payment block.
    'prefill': {'contact': phone},
    if (options['checkoutConfigId'] is String)
      'checkout_config_id': options['checkoutConfigId'],
    'config': {
      'display': {
        'blocks': {
          'upi': {'name': 'UPI apps', 'instruments': [{'method': 'upi'}]},
          'debit': {'name': 'Debit cards', 'instruments': [{'method': 'card', 'types': ['debit']}]},
          'netbanking': {'name': 'Netbanking', 'instruments': [{'method': 'netbanking'}]},
          'wallets': {'name': 'Wallets', 'instruments': [{'method': 'wallet'}]},
        },
        'sequence': [
          'block.$first',
          for (final name in ['upi', 'debit', 'netbanking', 'wallets']) if (name != first) 'block.$name',
        ],
        'hide': [
          {
            'method': 'card',
            'types': ['credit'],
          },
          {'method': 'emi'},
          {'method': 'cardless_emi'},
          {'method': 'paylater'},
        ],
        'preferences': {'show_default_blocks': false},
      },
    },
    'theme': {'color': '#0049FF'},
  };
}
