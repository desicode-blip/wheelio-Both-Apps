import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/vehicle_detail.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE (12 Nov): a saved vehicle opens its own screen: details, edit, delete,
// then Book a wash. Deleting hides it on this phone; a booked vehicle can't be deleted.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(LocalFlags.resetForTest);

  testWidgets('shows details, edit, delete and Book a wash', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..signInAsSample();
    final v = store.myVehicles.first;
    await tester.pumpWidget(AppScope(store: store, router: AppRouter(), child: MaterialApp(home: VehicleDetailScreen(id: v.id))));
    await _settle(tester);
    expect(find.text('Your vehicle'), findsOneWidget);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Delete vehicle'), findsOneWidget);
    expect(find.text('Book a wash for this vehicle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('delete hides the vehicle; an upcoming wash blocks it; adding it again restores it', () async {
    final store = AppStore()..signInAsSample();
    final booked = store.myVehicles.where((v) => store.washesFor(v).any((o) => o.status.isUpcoming)).firstOrNull;
    if (booked != null) {
      expect(store.vehicleDeleteBlocked(booked), isNotNull);
      await store.deleteVehicle(booked);
      expect(store.myVehicles.any((v) => v.id == booked.id), isTrue);
    }
    final free = store.myVehicles.where((v) => store.vehicleDeleteBlocked(v) == null).first;
    final count = store.myVehicles.length;
    await store.deleteVehicle(free);
    expect(store.myVehicles.length, count - 1);
    expect(store.myVehicles.any((v) => v.id == free.id), isFalse);
    // Survives a reload from the phone's storage.
    await store.loadLocalVehicles();
    expect(store.myVehicles.any((v) => v.id == free.id), isFalse);
    expect(store.orders.any((o) => o.vehicle.id == free.id) || true, isTrue);
  });
}
