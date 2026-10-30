import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_customer/screens/common.dart';
import 'package:washkrew_customer/screens/live.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class WalletTestStore extends AppStore {
  @override
  bool get isLive => true;
}

// Only test futures stand in for the authenticated quote/cancel response. No
// Firebase user, booking, payment or app testing control is created.
class QuoteTestStore extends WalletTestStore {
  QuoteTestStore() {
    final o = sampleOrder(OrderStatus.onTheWay);
    o.paymentStatus = 'captured';
    o.liveCancelPolicy = {'kind': 'refundThenCredit', 'refundMinutes': 5, 'lateCreditBps': 5000};
  }
  bool outage = false, crossedBoundary = false;
  int quoteCalls = 0, cancelCalls = 0;
  String? confirmed;
  @override
  Future<Map<String, dynamic>?> cancellationQuote(String id) async {
    quoteCalls++;
    if (outage) throw StateError('Offline');
    return {'orderId': id, 'currency': 'INR', 'kind': crossedBoundary ? 'credit' : 'refund', 'cashRefundPaise': crossedBoundary ? 0 : 14900, 'walletCreditPaise': crossedBoundary ? 7450 : 0, 'feePaise': crossedBoundary ? 7450 : 0, 'freeWashesRestored': 0, 'confirmation': crossedBoundary ? 'late' : 'early'};
  }
  @override
  Future<void> cancel(String id, {String? confirmation}) async {
    cancelCalls++;
    if (!crossedBoundary) { crossedBoundary = true; throw StateError('Cancellation terms have changed. Review the amounts and confirm again.'); }
    confirmed = confirmation;
    currentOrder!.status = OrderStatus.cancelled;
    changed();
  }
}

Future<void> showCancel(WidgetTester tester, QuoteTestStore store, AppRouter router) async {
  tester.view.physicalSize = const Size(430, 1100); tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => openCancelSheet(context, store.currentOrder!), child: const Text('Open cancellation')))))));
  await tester.tap(find.text('Open cancellation')); await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the shipped fonts rather than Ahem when measuring the authored phone layout.
    final fonts = FontLoader('packages/washkrew_ui/Roboto');
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$name.ttf'));
    }
    await fonts.load();
  });
  test('money formatting retains paise and preserves existing whole-rupee labels', () {
    expect(Fmt.rupees(149), '₹149');
    expect(Fmt.rupees(74.5), '₹74.50');
    expect(Fmt.rupees(0.01), '₹0.01');
    expect(Fmt.rupees(123456.75), '₹1,23,456.75');
    expect(Fmt.rupees(-74.5), '−₹74.50');
  });
  test('wallet preview and integer checkout amount agree, including the ₹1 minimum and full coverage', () {
    final d = BookingDraft(type: const VehicleType(VehicleKind.hatchback, 'Hatchback', 20, 149));
    d.applyWalletCredit(74.5);
    expect(d.creditApplied, 74.5); expect(d.pricePaise, 7450); expect(d.price, 74.5);
    d.applyWalletCredit(148.5);
    expect(d.creditApplied, 148); expect(d.pricePaise, 100);
    d.applyWalletCredit(200);
    expect(d.creditApplied, 149); expect(d.pricePaise, 0);
    d.applyWalletCredit(74.5, enabled: false);
    expect(d.creditApplied, 0); expect(d.pricePaise, 14900);
  });
  test('early mixed refunds are not labelled as a late wallet award', () {
    final s = WalletTestStore(), o = s.sampleOrder(OrderStatus.cancelled);
    o.liveCancelPolicy = {'kind': 'refundThenCredit'};
    o.cancellationOutcome = {'kind': 'refund', 'cashRefundPaise': 10000, 'creditPaise': 5000, 'feePaise': 0};
    expect(o.cancellationSummary, contains('₹100 refund requested'));
    expect(o.cancellationSummary, contains('₹50 wallet credit restored'));
    expect(o.cancellationSummary, contains('No cancellation fee'));
    s.dispose();
  });
  testWidgets('existing review credit toggle displays and applies ₹74.50 correctly', (tester) async {
    tester.view.physicalSize = const Size(430, 1100); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final s = WalletTestStore()..draftFull();
    s.liveConfig = {'cancellationPolicy': {'kind': 'refundThenCredit', 'refundMinutes': 5, 'lateCreditBps': 5000}};
    s.customer = Customer(id: 'fixture', phone: '')..credit = 74.5;
    final r = AppRouter();
    await tester.pumpWidget(AppScope(store: s, router: r, child: const MaterialApp(home: ReviewScreen())));
    expect(find.text('₹74.50 credit'), findsOneWidget);
    expect(find.text('₹74.50 off. You pay ₹74.50.'), findsOneWidget);
    expect(find.text('Full refund within 5 minutes of confirmation. Later: 50% fee, 50% to your wallet.'), findsOneWidget);
    expect(s.draft.pricePaise, 7450);
    await tester.ensureVisible(find.byType(WToggle));
    await tester.tap(find.byType(WToggle)); await tester.pump();
    expect(s.draft.pricePaise, 14900);
    await tester.pumpWidget(const SizedBox()); s.dispose(); r.dispose();
  });
  testWidgets('the existing payment sheet exposes all supported non-credit groups', (tester) async {
    tester.view.physicalSize = const Size(430, 1100); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final s = WalletTestStore()..draftFull(), r = AppRouter();
    await tester.pumpWidget(AppScope(store: s, router: r, child: const MaterialApp(home: Scaffold(body: PayMethodSheet()))));
    for (final label in ['Google Pay', 'PhonePe', 'Other UPI app', 'Debit card', 'Netbanking', 'Other wallets']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox()); s.dispose(); r.dispose();
  });
  testWidgets('a changed server quote requires a second explicit cancellation confirmation', (tester) async {
    final s = QuoteTestStore(), r = AppRouter();
    await showCancel(tester, s, r);
    expect(find.textContaining('₹149 returns to your original payment method'), findsOneWidget);
    await tester.tap(find.text('Cancel booking')); await tester.pumpAndSettle();
    expect(s.cancelCalls, 1); expect(s.confirmed, isNull);
    expect(find.textContaining('Cancellation fee: ₹74.50'), findsOneWidget);
    expect(find.textContaining('Cancellation terms have changed'), findsOneWidget);
    await tester.tap(find.text('Cancel booking')); await tester.pumpAndSettle();
    expect(s.cancelCalls, 2); expect(s.confirmed, 'late');
    expect(find.text('Cancel this booking?'), findsNothing);
    await tester.pumpWidget(const SizedBox()); s.dispose(); r.dispose();
  });
  testWidgets('failed quote can retry without issuing a cancellation', (tester) async {
    final s = QuoteTestStore()..outage = true, r = AppRouter();
    await showCancel(tester, s, r);
    expect(find.text('Offline'), findsOneWidget); expect(s.cancelCalls, 0);
    s.outage = false;
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.textContaining('₹149 returns to your original payment method'), findsOneWidget);
    expect(s.cancelCalls, 0);
    await tester.pumpWidget(const SizedBox()); s.dispose(); r.dispose();
  });
  testWidgets('wallet-only service failure shows restored credit rather than a nonexistent bank refund', (tester) async {
    tester.view.physicalSize = const Size(430, 1100); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final s = WalletTestStore(), r = AppRouter();
    final o = Order(id: 'wallet-return', ref: 'WH-FIXTURE', vehicle: AppStore.car(), place: AppStore.homePlace(), slot: TimeSlot(DateTime.now(), 8, 10), price: 0, status: OrderStatus.noCaptain, createdAt: DateTime.now())
      ..liveCancelPolicy = {'kind': 'refundThenCredit'}
      ..walletReleased = true
      ..creditUsed = 149;
    s.orders.add(o); s.currentOrderId = o.id;
    await tester.pumpWidget(AppScope(store: s, router: r, child: const MaterialApp(home: LiveOrderScreen())));
    expect(find.text('Wallet restored'), findsOneWidget);
    expect(find.text('₹149 wallet credit restored.'), findsOneWidget);
    expect(find.text('See refund'), findsNothing);
    expect(find.text('Go home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); s.dispose(); r.dispose();
  });
}
