import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/auth_pay.dart';

// No Firebase or payment SDK is initialized by this fixture. It supplies the
// server outcome at the point where checkout returns to the Customer screen.
class ResolvedPaymentStore extends AppStore {
  ResolvedPaymentStore(this.resolvedStatus, this.outcome);
  final OrderStatus resolvedStatus;
  final PaymentOutcome outcome;

  @override
  bool get isLive => true;

  Future<PaymentOutcome> resolve() async {
    sampleOrder(resolvedStatus);
    return outcome;
  }

  @override
  Future<PaymentOutcome> createOrderAndPay() => resolve();
  @override
  Future<PaymentOutcome> checkPendingPayment() => resolve();
}

void main() {
  test('unpaid and unconfirmed bookings stay visible for checkout recovery', () {
    expect(OrderStatus.pendingPayment.isUpcoming, isTrue);
    expect(OrderStatus.paymentPending.isUpcoming, isTrue);
    expect(OrderStatus.pendingPayment.isActive, isFalse);
    expect(OrderStatus.approved.isUpcoming, isFalse);
    expect(OrderStatus.cancelled.isUpcoming, isFalse);
  });

  for (final initial in [PayView.processing, PayView.pending]) {
    testWidgets('server cancellation opens its refund details from ${initial.name}', (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ResolvedPaymentStore(OrderStatus.cancelled, PaymentOutcome.pending);
      final router = AppRouter();
      await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: PayingScreen(initial: initial))));
      await tester.pump();
      if (initial == PayView.pending) {
        await tester.tap(find.text('Check again'));
        await tester.pump();
      }
      expect(router.last?.n, N.live);
      expect(router.last?.id, store.currentOrderId);
      expect(router.last?.n, isNot(N.booked));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      router.dispose();
    });
  }

  testWidgets('a captured active booking still opens the booking confirmation', (tester) async {
    final store = ResolvedPaymentStore(OrderStatus.searching, PaymentOutcome.success);
    final router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: PayingScreen())));
    await tester.pump();
    expect(router.last?.n, N.booked);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });
}
