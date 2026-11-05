import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';

// v2 CU-BOOKINGS: prefilled Book again.
void main() {
  test('Book again prefills vehicle, wash and place, and keeps edits on return', () {
    final store = AppStore()..signInAsSample();
    store.openRepeat('veh_car');
    final d = store.draft;
    expect(d.isRepeat, isTrue);
    expect(d.repeatFrom, 'veh_car');
    expect(d.type, isNotNull);
    expect(d.plate, isNotEmpty);
    expect(d.wash, isNotNull);
    expect(d.photos, isEmpty);
    expect(d.freshPhotos, isNull);

    d.plate = 'TS 09 AB 1234';
    store.openRepeat('veh_car'); // returning to the same Book again keeps the edit
    expect(store.draft.plate, 'TS 09 AB 1234');
  });

  test('Change returns to Book again only for the part being changed', () {
    final store = AppStore()..signInAsSample();
    store.openRepeat('veh_car');
    expect(store.finishRepeatEdit(RepeatEdit.wash), isFalse); // not editing anything
    store.editRepeat(RepeatEdit.wash);
    expect(store.finishRepeatEdit(RepeatEdit.place), isFalse);
    expect(store.finishRepeatEdit(RepeatEdit.wash), isTrue);
    expect(store.draft.editing, isNull);
  });

  test('Changing the vehicle keeps a wash that suits it', () {
    final store = AppStore()..signInAsSample();
    store.openRepeat('veh_car');
    store.editRepeat(RepeatEdit.vehicle);
    store.draft.type = VehicleType.all.first;
    expect(store.finishRepeatEdit(RepeatEdit.vehicle), isTrue);
    expect(WashKind.options(store.draft.type?.kind), contains(store.draft.wash));
  });

  test('A new booking is not a Book again', () {
    final store = AppStore()..signInAsSample();
    store.openRepeat('veh_car');
    store.startNewBooking();
    expect(store.draft.isRepeat, isFalse);
    expect(store.finishRepeatEdit(RepeatEdit.wash), isFalse);
  });
}
