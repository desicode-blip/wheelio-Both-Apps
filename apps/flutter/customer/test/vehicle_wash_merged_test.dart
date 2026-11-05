import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE (5 Nov): vehicle and wash are asked on one booking screen. No price on
// the vehicles; tapping one opens its washes with the price right below it.
Widget _screen(R r) => switch (r.n) {
  N.vehicleType => VehicleTypeScreen(large: r.large),
  N.vehicleNumber => const VehicleNumberScreen(),
  _ => const SizedBox(),
};

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(LocalFlags.resetForTest);
  testWidgets('Vehicle first without prices, then washes with prices below it', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..signInAsSample();
    store.startNewBooking();
    final router = AppRouter()..go(N.vehicleType);
    await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const SizedBox(), builder: _screen))))));
    await _settle(tester);

    expect(find.text('What should we wash?'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('About '), findsNothing);
    expect(find.text('Wet wash, outside'), findsNothing);
    expect(store.draft.type, isNull);

    await tester.tap(find.text('Sedan or compact SUV'));
    await _settle(tester);
    expect(store.draft.type?.kind, VehicleKind.sedan);
    expect(store.draft.wash, WashKind.wetOutside);
    expect(find.text('Dry wash (dusting)'), findsOneWidget);
    expect(find.text('Wet wash, outside'), findsOneWidget);
    expect(find.text(Fmt.rupees(179)), findsNWidgets(3));

    await tester.tap(find.text('Bike or scooter'));
    await _settle(tester);
    expect(find.text('Wet wash, outside'), findsNothing);
    expect(find.text('Wet wash'), findsOneWidget);
    expect(find.text(Fmt.rupees(69)), findsNWidgets(2));

    await tester.tap(find.text('Dusting'));
    await _settle(tester);
    expect(store.draft.wash, WashKind.dryDusting);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('What’s the number plate?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
