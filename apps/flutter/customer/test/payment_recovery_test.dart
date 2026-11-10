import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/auth_pay.dart';
import 'package:washkrew_customer/screens/live.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart' show CheckoutStage;
import 'dart:async';

class DirectCheckoutStore extends AppStore {
  @override
  bool get isLive => true;
  @override
  void prefetchPaymentResources() {}
  final payment = Completer<PaymentOutcome>();
  @override
  Future<PaymentOutcome> createOrderAndPay() => payment.future;
}

class UnavailableCheckoutStore extends AppStore {
  @override
  bool get isLive => true;
  @override
  Future<PaymentOutcome> createOrderAndPay() async =>
      throw StateError('This is taking longer than expected. Please try again.');
}

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
  testWidgets('live Review opens payment once without the repeated method sheet', (tester) async {
    final sample = AppStore()..signInAsSample()..draftFull();
    final store = DirectCheckoutStore()..customer = sample.customer..draft = sample.draft;
    final router = AppRouter();
    sample.dispose();
    store.customer!.freeWashes = 0;
    store.customer!.credit = 0;
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: ReviewScreen())));
    await tester.tap(find.text('Pay via Razorpay · ₹149'));
    await tester.tap(find.text('Pay via Razorpay · ₹149'));
    expect(router.last?.n, N.paying); expect(router.showPaySheet, false);
    expect(router.path.where((e) => e.route.n == N.paying).length, 1);
    expect(find.byType(PayMethodSheet), findsNothing);
    await tester.pumpWidget(const SizedBox()); store.dispose(); router.dispose();
  });

  testWidgets('payment state describes opening and uploads before actual confirmation', (tester) async {
    final store = DirectCheckoutStore(), router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: PayingScreen())));
    await tester.pump();
    expect(find.text('Opening secure payment'), findsOneWidget);
    expect(find.text('Confirming payment'), findsNothing);
    store.set(() => store.checkoutStage = CheckoutStage.savingAttachments); await tester.pump();
    expect(find.text('Saving your photos and notes'), findsOneWidget);
    store.set(() => store.checkoutStage = CheckoutStage.confirming); await tester.pump();
    expect(find.text('Confirming payment'), findsOneWidget);
    store.payment.complete(PaymentOutcome.pending); await tester.pump();
    await tester.pumpWidget(const SizedBox()); store.dispose(); router.dispose();
  });

  testWidgets('checkout errors stay visible without inventing a bank decline or no-charge result', (tester) async {
    final store = UnavailableCheckoutStore(), router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: PayingScreen())));
    await tester.pump();
    expect(find.text('This is taking longer than expected. Please try again.'), findsOneWidget);
    expect(find.textContaining('Your bank declined'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Back to booking'), findsOneWidget);
    expect(router.last, isNull);
    await tester.tap(find.text('Back to booking'));
    expect(router.last?.n,N.review);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });

  testWidgets('unsupported funding keeps the designed cancellation and refund action', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ResolvedPaymentStore(OrderStatus.cancelled, PaymentOutcome.pending);
    store.sampleOrder(OrderStatus.cancelled);
    store.currentOrder!
      ..cancellationReason = 'paymentMethodNotAllowed'
      ..refundStatus = 'pending';
    final router = AppRouter();
    await tester.pumpWidget(AppScope(store: store, router: router, child: const MaterialApp(home: LiveOrderScreen())));
    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.textContaining('Credit-card checkout is not accepted.'), findsOneWidget);
    await tester.tap(find.text('Track refund'));
    expect(router.last?.n, N.refund);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    router.dispose();
  });

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
