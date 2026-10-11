import 'package:flutter_test/flutter_test.dart';
import 'package:wheelio_customer/data/backend.dart';
import 'package:wheelio_customer/data/mock_backend.dart';
import 'package:wheelio_customer/data/models.dart';
import 'package:wheelio_customer/data/validators.dart';
import 'package:wheelio_customer/routes.dart';

void main() {
  group('plates', () {
    test('accepts common Indian formats', () {
      for (final p in ['TS 09 EA 4521', 'ts09ea4521', 'KA 01 A 1234', 'DL 3C AB 1234', '22 BH 1234 AA']) {
        expect(Validators.isValidPlate(p), isTrue, reason: p);
      }
    });

    test('rejects partial numbers', () {
      for (final p in ['TS 09', '', '1234', 'TS EA 4521X']) {
        expect(Validators.isValidPlate(p), isFalse, reason: p);
      }
    });

    test('formats with spaces', () {
      expect(Validators.formatPlate('ts09ea4521'), 'TS 09 EA 4521');
    });
  });

  group('phone', () {
    test('10 digits starting 6-9', () {
      expect(Validators.isValidMobile('98480 11223'), isTrue);
      expect(Validators.isValidMobile('+91 98480 11223'), isTrue);
      expect(Validators.isValidMobile('58480 11223'), isFalse);
      expect(Validators.isValidMobile('98480 112'), isFalse);
    });

    test('formats for display', () {
      expect(formatPhone('9848011223'), '+91 98480 11223');
    });
  });

  group('time labels', () {
    test('windows', () {
      expect(formatWindow(8, 10), '8 – 10 AM');
      expect(formatWindow(10, 12), '10 AM – 12 PM');
      expect(formatWindow(12, 14), '12 – 2 PM');
    });

    test('day names', () {
      final now = DateTime(2026, 10, 10, 9);
      expect(formatDay(DateTime(2026, 10, 10), now: now), 'Today');
      expect(formatDay(DateTime(2026, 10, 11), now: now), 'Tomorrow');
      expect(formatDay(DateTime(2026, 10, 12), now: now), 'Mon, 12 Oct');
    });
  });

  group('mock backend', () {
    test('OTP: wrong, expired and correct codes', () async {
      final b = MockBackend();
      expect((await b.verifyOtp('9848011223', '111111')).status, OtpStatus.wrong);
      expect((await b.verifyOtp('9848011223', MockBackend.expiredOtp)).status, OtpStatus.expired);
      final ok = await b.verifyOtp('9848011223', MockBackend.demoOtp);
      expect(ok.status, OtpStatus.ok);
      expect(b.currentCustomer?.firstName, 'Ananya');
    });

    test('paid order goes searching → on the way → washing → photos ready', () async {
      final b = MockBackend()..demo.stepSeconds = 0;
      b.signInAsSample();
      final now = DateTime.now();
      final order = await b.createOrder(
        type: MockBackend.types[1],
        plate: 'TS 09 EA 4521',
        place: MockBackend.homePlace,
        slot: TimeSlot(date: now, startHour: 8, endHour: 10),
        note: const EntryNote(),
        useFreeWash: false,
      );
      final seen = <OrderStatus>[];
      final sub = b.watchOrder(order.id).listen((o) => seen.add(o.status));
      final methods = await b.paymentMethods();
      expect(await b.pay(order.id, methods.first), PaymentOutcome.success);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await sub.cancel();
      expect(seen, containsAllInOrder([
        OrderStatus.searching,
        OrderStatus.onTheWay,
        OrderStatus.washing,
        OrderStatus.photosReady,
      ]));
      final done = await b.getOrder(order.id);
      expect(done.autoApproveAt, isNotNull);
      expect(liveRouteFor(done), R.checkPhotos);
      b.dispose();
    });

    test('cancel before accept refunds the full price', () async {
      final b = MockBackend()..demo.stepSeconds = 60;
      b.signInAsSample();
      final o = b.sampleOrder(OrderStatus.searching);
      final cancelled = await b.cancelOrder(o.id);
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.refund?.amount, o.price);
      b.dispose();
    });
  });
}
