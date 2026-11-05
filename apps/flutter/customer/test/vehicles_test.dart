import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 CU-VEHICLE: add a vehicle without booking; book from a saved vehicle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(LocalFlags.resetForTest);

  test('Adding a vehicle saves it to the list without a booking', () async {
    final store = AppStore()..signInAsSample();
    final before = store.myVehicles.length;
    store.startAddVehicle();
    expect(store.draft.addingVehicle, isTrue);
    store.draft.type = VehicleType.all.first;
    store.draft.plate = 'KA 01 AB 1234';
    expect(await store.saveNewVehicle(), isNull);
    expect(store.myVehicles.length, before + 1);
    expect(store.myVehicles.last.plate, 'KA 01 AB 1234');
    expect(store.draft.addingVehicle, isFalse);
    expect(store.orders.where((o) => o.vehicle.plate == 'KA 01 AB 1234'), isEmpty);
  });

  test('The same number plate cannot be saved twice', () async {
    final store = AppStore()..signInAsSample();
    store.startAddVehicle();
    store.draft.type = VehicleType.all.first;
    store.draft.plate = store.myVehicles.first.plate;
    expect(await store.saveNewVehicle(), isNotNull);
  });

  test('Saved vehicles start the booking with Which vehicle?', () {
    final store = AppStore()..signInAsSample();
    expect(store.firstBookingStep, store.myVehicles.isEmpty ? N.vehicleType : N.vehiclePick);
  });

  test('Booking a saved vehicle fills type and plate and offers its last photos', () {
    final store = AppStore()..signInAsSample();
    final o = store.orders.first;
    o.customerPhotoPaths = {'front': 'orders/x/front.jpg'};
    store.pickVehicleForBooking(o.vehicle);
    expect(store.draft.type, o.vehicle.type);
    expect(store.draft.plate, o.vehicle.plate);
    expect(store.draft.pickedVehicleId, o.vehicle.id);
    expect(store.draft.lastPhotoPaths, isNotEmpty);
    expect(store.draft.isRepeat, isFalse);
  });
}
