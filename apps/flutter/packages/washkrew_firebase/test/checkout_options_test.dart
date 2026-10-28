import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/checkout_options.dart';

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
  test(
    'selected checkout method keeps the verified order and offers compatible instruments',
    () {
      for (final selected in ['gpay', 'phonepe', 'upi_id', 'card']) {
        final result = checkoutOptions({
          ...options,
          'selectedMethod': selected,
        }, '+919000000001');
        expect(result['order_id'], 'order_123');
        expect(
          (result['prefill'] as Map)['method'],
          selected == 'card' ? 'card' : 'upi',
        );
        final display = (result['config'] as Map)['display'] as Map;
        final instrument =
            (((display['blocks'] as Map)['selected'] as Map)['instruments']
                        as List)
                    .single
                as Map;
        if (selected == 'gpay' || selected == 'phonepe')
          expect(instrument['apps'], [
            selected == 'gpay' ? 'google_pay' : 'phonepe',
          ]);
        expect((display['preferences'] as Map)['show_default_blocks'], false);
        if (selected == 'card') expect(instrument['types'], ['debit']);
      }
      expect(
        () => checkoutOptions({...options, 'selectedMethod': 'invented'}, ''),
        throwsStateError,
      );
    },
  );
  test(
    'all checkout paths exclude credit cards and retain a server configuration',
    () {
      for (final selected in [null, 'gpay', 'phonepe', 'upi_id', 'card']) {
        final result = checkoutOptions({
          ...options,
          'selectedMethod': selected,
          'checkoutConfigId': 'config_no_credit',
        }, '');
        expect(result['checkout_config_id'], 'config_no_credit');
        final display = (result['config'] as Map)['display'] as Map;
        expect((display['preferences'] as Map)['show_default_blocks'], false);
        for (final block in (display['blocks'] as Map).values) {
          for (final instrument in (block as Map)['instruments'] as List) {
            if (instrument['method'] == 'card')
              expect(instrument['types'], ['debit']);
            expect(
              [
                'emi',
                'paylater',
                'cardless_emi',
              ].contains(instrument['method']),
              false,
            );
          }
        }
      }
    },
  );
}
