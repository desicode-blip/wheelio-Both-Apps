import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/checkout_flow.dart';

void main() {
  const id = 'booking-one';
  final options = <String, dynamic>{'bookingId': id, 'orderId': 'order_one'};
  final captured = <String, dynamic>{
    'bookingId': id,
    'status': 'searching',
    'paymentStatus': 'captured',
  };
  final signed = <String, dynamic>{
    'razorpay_order_id': 'order_one',
    'razorpay_payment_id': 'pay_one',
    'razorpay_signature': 'signed',
  };

  test(
    'no-attachment Pay opens checkout after one callable and verifies only after the SDK result',
    () async {
      final calls = <String>[], stages = <CheckoutStage>[];
      final sdk = Completer<Map<String, dynamic>?>();
      final flow = CheckoutFlow(
        phone: '',
        call: (name, data) async {
          calls.add(name);
          if (name == 'createCheckout') {
            expect(data['booking'], {'requestId': 'stable'});
            return options;
          }
          expect(name, 'verifyPayment');
          expect(data['paymentId'], 'pay_one');
          return captured;
        },
        open: (_, __) => sdk.future,
      );
      final run = flow.run(
        booking: {'requestId': 'stable'},
        onStage: stages.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['createCheckout']);
      expect(stages.last, CheckoutStage.opening);
      sdk.complete(signed);
      expect(await run, captured);
      expect(calls, ['createCheckout', 'verifyPayment']);
      expect(stages.last, CheckoutStage.confirming);
    },
  );

  test(
    'all selected uploads overlap provider preparation and finish before the SDK opens',
    () async {
      final provider = Completer<Map<String, dynamic>>(),
          first = Completer<void>(),
          second = Completer<void>();
      final started = <String>[];
      var opened = false;
      final flow = CheckoutFlow(
        phone: '',
        call: (name, data) async {
          if (name == 'createBooking')
            return {
              'bookingId': id,
              'status': 'pendingPayment',
              'amount': 14900,
            };
          if (name == 'createCheckout') {
            started.add('provider');
            return provider.future;
          }
          return captured;
        },
        open: (_, __) async {
          opened = true;
          return signed;
        },
      );
      final run = flow.run(
        booking: {'requestId': 'stable'},
        uploads: [
          (bookingId) {
            expect(bookingId, id);
            started.add('photo');
            return first.future;
          },
          (_) {
            started.add('note');
            return second.future;
          },
        ],
      );
      await Future<void>.delayed(Duration.zero);
      expect(started.toSet(), {'provider', 'photo', 'note'});
      expect(opened, false);
      provider.complete(options);
      second.complete();
      await Future<void>.delayed(Duration.zero);
      expect(opened, false);
      first.complete();
      expect(await run, captured);
      expect(opened, true);
    },
  );

  test(
    'attachment failure prevents checkout and does not claim a payment outcome',
    () async {
      final calls = <String>[];
      var opened = false;
      final flow = CheckoutFlow(
        phone: '',
        call: (name, data) async {
          calls.add(name);
          return name == 'createBooking'
              ? {'bookingId': id, 'status': 'pendingPayment', 'amount': 14900}
              : options;
        },
        open: (_, __) async {
          opened = true;
          return signed;
        },
      );
      await expectLater(
        flow.run(
          booking: {'requestId': 'stable'},
          uploads: [(_) async => throw StateError('Upload interrupted')],
        ),
        throwsStateError,
      );
      expect(opened, false);
      expect(calls, ['createBooking', 'createCheckout']);
    },
  );

  test(
    'a captured retry skips locked uploads and the SDK, then reads server status',
    () async {
      final calls = <String>[];
      var uploaded = false, opened = false;
      final flow = CheckoutFlow(
        phone: '',
        call: (name, data) async {
          calls.add(name);
          if (name == 'createBooking')
            return {'bookingId': id, 'status': 'searching'};
          if (name == 'createCheckout') return {...options, 'paid': true};
          return captured;
        },
        open: (_, __) async {
          opened = true;
          return signed;
        },
      );
      expect(
        await flow.run(
          booking: {'requestId': 'stable'},
          uploads: [
            (_) async {
              uploaded = true;
            },
          ],
        ),
        captured,
      );
      expect(uploaded, false);
      expect(opened, false);
      expect(calls, ['createBooking', 'createCheckout', 'checkPayment']);
    },
  );

  test(
    'wallet-only checkout waits for all attachments before settling and never opens the SDK',
    () async {
      final upload = Completer<void>(), calls = <String>[];
      var opened = false;
      final flow = CheckoutFlow(
        phone: '',
        call: (name, data) async {
          calls.add(name);
          if (name == 'createBooking')
            return {'bookingId': id, 'status': 'pendingPayment', 'amount': 0};
          if (name == 'createCheckout') return {...options, 'paid': true};
          return captured;
        },
        open: (_, __) async {
          opened = true;
          return signed;
        },
      );
      final run = flow.run(
        booking: {'requestId': 'stable'},
        uploads: [(_) => upload.future],
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['createBooking']);
      upload.complete();
      expect(await run, captured);
      expect(opened, false);
      expect(calls, ['createBooking', 'createCheckout', 'checkPayment']);
    },
  );

  for (final callbackLost in [false, true]) {
    test(
      'dismissed/lost callback ($callbackLost) reconciles the original booking without a second order',
      () async {
        final calls = <String>[];
        final flow = CheckoutFlow(
          phone: '',
          call: (name, data) async {
            calls.add(name);
            expect(data['bookingId'], id);
            return name == 'createCheckout' ? options : captured;
          },
          open: (_, __) async {
            if (callbackLost) throw StateError('Callback lost');
            return null;
          },
        );
        expect(await flow.run(bookingId: id), captured);
        expect(calls, ['createCheckout', 'checkPayment']);
      },
    );
  }

  test('an uncaptured SDK error is preserved after reconciliation', () async {
    final flow = CheckoutFlow(
      phone: '',
      call: (name, data) async =>
          name == 'createCheckout' ? options : {'paymentStatus': 'unpaid'},
      open: (_, __) async => throw StateError('No callback'),
    );
    await expectLater(
      flow.run(bookingId: id),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'No callback'),
      ),
    );
  });
 test('explicit SDK cancellation abandons only the original unpaid checkout',()async{
  final calls=<String>[];
  final flow=CheckoutFlow(phone:'',call:(name,data)async{calls.add(name);if(name=='createCheckout')return options;if(name=='checkPayment')return {'paymentStatus':'unpaid'};expect(name,'abandonCheckout');expect(data['bookingId'],id);return {'checkoutCancelled':true,'status':'cancelled'};},open:(_,__)async=>null);
  expect((await flow.run(bookingId:id))['checkoutCancelled'],true);expect(calls,['createCheckout','checkPayment','abandonCheckout']);
 });

}
