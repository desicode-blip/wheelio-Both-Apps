import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/purchase/wash_choice.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-WASHCHOICE (8 Nov): with the new flow on, vehicle → Choose your wash (server
// prices; options without one say "Coming soon") → … → custom time windows → Check and pay.
Widget _screen(R r) => switch (r.n) {
  N.vehicleType => VehicleTypeScreen(large: r.large),
  N.washType => const WashStepScreen(),
  N.vehicleNumber => const VehicleNumberScreen(),
  N.timeSlot => const TimeStepScreen(),
  N.review => const ReviewScreen(),
  N.purchaseTime => const PlanTimeStepScreen(),
  N.purchaseConfirmation => const PlanConfirmationStepScreen(),
  N.planDetails => const PlanDetailsStepScreen(),
  _ => const SizedBox(),
};

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<(AppStore, AppRouter)> _pump(WidgetTester tester, N start, {void Function(AppStore)? setUp}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = AppStore()..signInAsSample();
  store.startNewBooking();
  store.previewFeatures = true;
  setUp?.call(store);
  final router = AppRouter()..go(start);
  await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const SizedBox(), builder: _screen))))));
  await _settle(tester);
  return (store, router);
}

void main() {
  setUp(LocalFlags.resetForTest);

  testWidgets('vehicle alone, then Choose your wash with server prices only', (tester) async {
    final (store, _) = await _pump(tester, N.vehicleType);
    expect(find.text('What should we wash?'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    await tester.tap(find.text('Sedan or compact SUV'));
    await _settle(tester);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Choose your wash'), findsOneWidget);
    expect(find.text('Monthly plan'), findsOneWidget, reason: 'preview shows monthly plans');
    final sedan = store.draft.type!;
    expect(find.text('₹${sedan.price}'), findsOneWidget);
    // Tiers the server has no price for show the sample price.
    expect(find.text('Coming soon'), findsNothing);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(store.draft.serviceLevel, ServiceLevel.basic);
    expect(store.draft.coverage, WashCoverage.exterior);
    expect(store.draft.basePrice, sedan.price);
    expect(find.text('What’s the number plate?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('own time windows lead to Check and pay with one summary card', (tester) async {
    final (store, _) = await _pump(tester, N.timeSlot, setUp: (s) {
      s.draftFull();
      s.draft.serviceLevel = ServiceLevel.basic;
      s.draft.coverage = WashCoverage.exterior;
      s.purchase.chosen = true;
      s.draft.slot = null;
    });
    expect(find.text('When is your vehicle free?'), findsOneWidget);
    expect(find.textContaining('at least 1 hour each'), findsOneWidget);
    await tester.tap(find.text('Next: check and pay'));
    await _settle(tester);
    expect(store.draft.slot!.minuteWindows, [(480, 600)]);
    expect(find.text('One-time wash'), findsOneWidget);
    expect(find.text('Basic · Exterior only'), findsOneWidget);
    expect(find.textContaining('8 AM – 10 AM'), findsOneWidget);
    expect(find.textContaining('Pay now'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('custom windows keep exact minutes and gaps', () {
    final slot = customSlot(DateTime(2026, 11, 9), const [WashTimeWindow(startMinute: 1140, endMinute: 1380), WashTimeWindow(startMinute: 495, endMinute: 645)]);
    expect(slot.label, '8:15 AM – 10:45 AM, 7 PM – 11 PM');
    expect(slot.startHour, 8);
    expect(slot.endHour, 23);
  });

  test('v2 is standard; the server can switch it off', () {
    final store = AppStore()..signInAsSample();
    expect(store.washChoiceV2, isTrue);
    store.liveConfig['v2Features'] = false;
    expect(store.washChoiceV2, isFalse);
  });

  test('own windows that line up with server slots can be booked today', () {
    final store = AppStore()..signInAsSample();
    store.liveWindows = [(6, 8), (8, 10), (10, 12), (16, 18)];
    final day = DateTime(2026, 11, 13);
    expect(store.serverWindowsFor(customSlot(day, const [WashTimeWindow(startMinute: 480, endMinute: 600)])), [(8, 10)]);
    expect(store.serverWindowsFor(customSlot(day, const [WashTimeWindow(startMinute: 480, endMinute: 720), WashTimeWindow(startMinute: 960, endMinute: 1080)])), [(8, 10), (10, 12), (16, 18)]);
    expect(store.serverWindowsFor(customSlot(day, const [WashTimeWindow(startMinute: 495, endMinute: 645)])), isNull);
    expect(store.serverWindowsFor(customSlot(day, const [WashTimeWindow(startMinute: 720, endMinute: 840)])), isNull);
  });

  test('Basic exterior uses the server price; other tiers a sample price until the server has one', () {
    final store = AppStore()..signInAsSample();
    final t = VehicleType.all[2];
    expect(store.purchasePrice(t, ServiceLevel.basic), t.price);
    expect(store.purchasePrice(t, ServiceLevel.premium), isNotNull);
    store.liveConfig['washPrices'] = {t.kind.name: {'premium': {'exterior': 249}}};
    expect(store.purchasePrice(t, ServiceLevel.premium), 249);
  });

  test('sample builds are never blocked', () {
    final store = AppStore()..signInAsSample();
    store.purchase..chosen = true..mode = PurchaseMode.monthly;
    expect(store.washChoiceBlockedReason, isNull);
  });

  testWidgets('monthly plan: days, times, Check and pay (blocked), plan screens preview', (tester) async {
    final (store, router) = await _pump(tester, N.washType, setUp: (s) {
      s.draftFull();
      s.draft.slot = null;
    });
    await tester.tap(find.text('Monthly plan'));
    await _settle(tester);
    expect(find.text('Days per week'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(store.purchase.monthly, isTrue);
    store.washChoiceFromReview = false;
    router.go(N.timeSlot);
    await _settle(tester);
    expect(find.text('Pick your 3 days'), findsOneWidget);
    await tester.tap(find.text('Next: choose time'));
    await _settle(tester);
    expect(find.text('When is your vehicle free?'), findsOneWidget);
    await tester.tap(find.text('Next: check and pay'));
    await _settle(tester);
    expect(find.text('Monthly plan'), findsOneWidget);
    expect(find.text('Renews monthly'), findsOneWidget);
    await tester.tap(find.textContaining('Pay now'));
    await _settle(tester);
    expect(find.text('Your routine is ready'), findsOneWidget);
    await tester.tap(find.text('View your plan'));
    await _settle(tester);
    expect(find.text('Cancel subscription'), findsOneWidget);
    expect(store.activePlan, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
