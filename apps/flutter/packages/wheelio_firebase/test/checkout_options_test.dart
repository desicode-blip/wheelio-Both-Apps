import 'package:flutter_test/flutter_test.dart';
import 'package:wheelio_firebase/src/checkout_options.dart';

void main() {
  final options = {
    'keyId': 'rzp_test_dummy',
    'orderId': 'order_123',
    'amount': 14900,
    'currency': 'INR',
    'testMode': true,
  };
  test(
    'native and browser checkout retain the server order and integer paise',
    () {
      final result = checkoutOptions(options, '+919000000001');
      expect(result['order_id'], 'order_123');
      expect(result['amount'], 14900);
      expect(result.containsKey('key_secret'), false);
    },
  );
  test(
    'checkout rejects mode mismatches, unsupported amounts and missing orders',
    () {
      for (final changes in [
        {'testMode': false},
        {'keyId': 'rzp_live_dummy'},
        {'amount': 1},
        {'amount': 149.0},
        {'orderId': ''},
        {'currency': 'USD'},
      ]) {
        expect(
          () => checkoutOptions({...options, ...changes}, ''),
          throwsStateError,
        );
      }
    },
  );
}
