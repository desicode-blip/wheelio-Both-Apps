import 'dart:typed_data';

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

  test('Photos added with a vehicle are kept and offered when booking it', () async {
    final store = AppStore()..signInAsSample();
    store.startAddVehicle();
    store.draft.type = VehicleType.all.first;
    store.draft.plate = 'KA 02 CD 5678';
    store.keepPhoto(PhotoAngle.front, Uint8List.fromList([1, 2, 3]));
    expect(await store.finishVehiclePhotos(withPhotos: true), isNull);
    final v = store.myVehicles.firstWhere((x) => x.plate == 'KA 02 CD 5678');
    expect(v.photos.keys, [PhotoAngle.front]);
    store.pickVehicleForBooking(v);
    expect(store.draft.lastPhotoBytes.keys, [PhotoAngle.front]);
  });

  test('Photos can be skipped and added later', () async {
    final store = AppStore()..signInAsSample();
    store.startAddVehicle();
    store.draft.type = VehicleType.all.first;
    store.draft.plate = 'KA 03 EF 9012';
    expect(await store.finishVehiclePhotos(withPhotos: false), isNull);
    final v = store.myVehicles.firstWhere((x) => x.plate == 'KA 03 EF 9012');
    expect(v.photos, isEmpty);
    store.startAddVehiclePhotos(v);
    store.keepPhoto(PhotoAngle.back, Uint8List.fromList([4]));
    expect(await store.finishVehiclePhotos(withPhotos: true), isNull);
    expect(v.photos.keys, [PhotoAngle.back]);
    expect(store.myVehicles.where((x) => x.plate == 'KA 03 EF 9012').length, 1);
  });

  test('Editing a vehicle changes its plate and photos on this phone only', () async {
    final store = AppStore()..signInAsSample();
    store.startAddVehicle();
    store.draft.type = VehicleType.all.first;
    store.draft.plate = 'KA 04 GH 3456';
    await store.finishVehiclePhotos(withPhotos: false);
    final v = store.myVehicles.firstWhere((x) => x.plate == 'KA 04 GH 3456');
    final error = await store.updateVehicle(v, plate: 'KA 04 GH 7777', photos: {PhotoAngle.left: Uint8List.fromList([9])});
    expect(error, isNull);
    final edited = store.myVehicles.firstWhere((x) => x.id == v.id);
    expect(edited.plate, 'KA 04 GH 7777');
    expect(edited.photos.keys, [PhotoAngle.left]);
    expect(store.orders.where((o) => o.vehicle.id == v.id), isEmpty);
  });

  test('Photos can be added to a vehicle from a past booking', () async {
    final store = AppStore()..signInAsSample();
    final v = store.myVehicles.first;
    await store.updateVehicle(v, photos: {PhotoAngle.front: Uint8List.fromList([1])});
    expect(store.myVehicles.firstWhere((x) => x.id == v.id).photos.keys, [PhotoAngle.front]);
    expect(store.myVehicles.where((x) => x.plate == v.plate).length, 1);
  });
}
