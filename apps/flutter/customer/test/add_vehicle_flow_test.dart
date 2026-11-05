import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/auth_pay.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_customer/screens/home.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE: tap through Vehicles > Add a vehicle as a customer would.
Widget _screen(R r) => switch (r.n) {
  N.vehicleType => VehicleTypeScreen(large: r.large),
  N.vehicleNumber => const VehicleNumberScreen(),
  N.photos => const PhotosScreen(),
  N.notifyFirst => const NotifyFirstScreen(),
  N.vehicleEdit => VehicleEditScreen(id: r.id!),
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
  testWidgets('Add a vehicle opens the add flow, not the booking flow', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => LocalFlags.set('notifyAsked', true));
    final store = AppStore()..signInAsSample();
    final router = AppRouter()..tab = 2;
    await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const MainTabs(), builder: _screen))))));
    await _settle(tester);
    expect(find.text('Your vehicles'), findsOneWidget);
        await tester.tap(find.text('Add new vehicle'));
    await _settle(tester);
    expect(find.text('What kind of vehicle?'), findsOneWidget);
    expect(find.text('Add a vehicle'), findsOneWidget); // header title
    expect(find.textContaining('₹'), findsNothing); // no prices when only adding a vehicle
    expect(find.textContaining('About '), findsNothing);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('What’s the number plate?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'KA01AB1234');
    await _settle(tester);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Add photos (optional)'), findsOneWidget);
    expect(find.text('Skip, add photos later'), findsOneWidget);
    await tester.tap(find.text('Skip, add photos later'));
    await _settle(tester);
    expect(find.text('Your vehicles'), findsOneWidget);
    expect(store.myVehicles.any((v) => v.plate.replaceAll(' ', '') == 'KA01AB1234'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('The number plate can be skipped', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => LocalFlags.set('notifyAsked', true));
    final store = AppStore()..signInAsSample();
    final router = AppRouter()..tab = 2;
    final before = store.myVehicles.length;
    await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const MainTabs(), builder: _screen))))));
    await _settle(tester);
    await tester.tap(find.text('Add new vehicle'));
    await _settle(tester);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    await tester.tap(find.text('Skip for now'));
    await _settle(tester);
    expect(find.text('Add photos (optional)'), findsOneWidget);
    await tester.tap(find.text('Skip, add photos later'));
    await _settle(tester);
    expect(store.myVehicles.length, before + 1);
    expect(find.text('Number plate not added'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('With many vehicles, Add new vehicle stays visible at the bottom', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => LocalFlags.set('notifyAsked', true));
    final store = AppStore()..signInAsSample();
    final router = AppRouter()..tab = 2;
    await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: Material(child: ListenableBuilder(listenable: Listenable.merge([router, store]), builder: (_, _) => WNavStack<R>(router: router, root: const MainTabs(), builder: _screen))))));
    await _settle(tester);
    store.set(() {
      for (var i = 0; i < 12; i++) {
        store.localVehicles.add(Vehicle('local_t$i', 'KA 0$i AB 12$i', VehicleType.all.first, null));
      }
    });
    await _settle(tester);
    final button = tester.getRect(find.text('Add new vehicle'));
    expect(button.bottom, lessThanOrEqualTo(900));
    expect(button.top, greaterThan(500)); // pinned near the bottom, above the tab bar
    await tester.pumpWidget(const SizedBox());
  });
}
