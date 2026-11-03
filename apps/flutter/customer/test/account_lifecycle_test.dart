import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import '../../packages/washkrew_firebase/test/account_session_fixture.dart';

Future<void> turn()async{await Future<void>.delayed(Duration.zero);await Future<void>.delayed(Duration.zero);}
void main(){
 test('Customer deletion clears drafts/private state and same-UID fresh signup ignores old cached profile/photo',()async{
  final backend=AccountSessionFixture(),store=AppStore(live:backend);
  backend.login('same');await turn();
  backend.profileValue({'roles':['customer'],'phone':'+919000000001','name':'Old','customerName':'Old','customerPhotoPath':'profiles/same/customer.jpg'});await turn();
  expect(store.customer?.name,'Old');
  store.draft.plate='OLD123';store.draftPhotoBytes[PhotoAngle.front]=Uint8List.fromList([1]);store.draftBookingId='old';store.hasSeenWelcome=true;
  backend.profileValue({'roles':['customer'],'deletingRole':'customer','deletionStatus':'pending'});await turn();
  expect(store.customer,isNull);expect(store.orders,isEmpty);expect(store.vehicles,isEmpty);
  expect(store.draft.plate,isEmpty);expect(store.draftPhotoBytes,isEmpty);expect(store.draftBookingId,isNull);expect(store.hasSeenWelcome,false);
  backend.login('same');await turn();
  backend.profileValue({'roles':['customer'],'phone':'+919000000001','name':'Old'},cached:true);await turn();expect(store.customer,isNull);
  backend.profileValue({'roles':['customer'],'phone':'+919000000001','name':'Captain name','customerName':''});await turn();
  expect(store.customer?.name,isEmpty);expect(store.isLoggedIn,true);
  backend.picture.complete(Uint8List.fromList([9]));await turn();expect(store.profilePhoto,isNull);
  expect(store.savedPlaces,isEmpty);expect(backend.signOuts,1);
  store.dispose();await backend.close();
 });
 test('a Captain-only profile is not a Customer account and preserves a new guest booking draft',()async{
  final backend=AccountSessionFixture(),store=AppStore(live:backend);
  store.draft.plate='NEW123';backend.registrationInProgress=true;backend.login('same');await turn();
  backend.profileValue({'roles':['captain'],'phone':'+919000000001','name':'Captain'});await turn();
  expect(store.customer,isNull);expect(store.draft.plate,'NEW123');expect(backend.signOuts,0);
  backend.profileValue({'roles':['captain','customer'],'phone':'+919000000001','name':'Captain','customerName':''});await turn();
  expect(store.customer?.name,isEmpty);expect(store.draft.plate,'NEW123');
  store.dispose();await backend.close();
 });
}
