import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import '../../packages/washkrew_firebase/test/account_session_fixture.dart';

Future<void> turn()async{await Future<void>.delayed(Duration.zero);await Future<void>.delayed(Duration.zero);}
void main(){
 test('Captain deletion clears personal/KYC/work data; fresh same-UID session cannot restore cached approval',()async{
  final backend=AccountSessionFixture(),store=CaptainStore(live:backend);
  backend.login('same');await turn();
  backend.profileValue({'roles':['captain'],'phone':'+919000000001'});await turn();
  backend.captainValue({'name':'Old','phone':'+919000000001','approved':true,'online':false,'upi':'old@bank','kycStatus':'underReview','workingSlots':[{'startMinute':540,'endMinute':1080}]});await turn();
  expect(store.name,'Old');expect(store.signedUp,true);expect(store.workSlots,isNotEmpty);
  store.beforeDone={0,1};store.chosenSocieties={'Old place'};store.workPlace='Old';
  backend.profileValue({'roles':['captain'],'deletingRole':'captain','deletionStatus':'pending'});await turn();
  expect(store.name,isEmpty);expect(store.phone,isEmpty);expect(store.upi,isEmpty);expect(store.registered,false);expect(store.signedUp,false);
  expect(store.workSlots,isEmpty);expect(store.chosenSocieties,isEmpty);expect(store.workPlace,isEmpty);expect(store.beforeDone,isEmpty);expect(store.kycUploaded,isEmpty);
  backend.login('same');await turn();backend.profileValue({'roles':['captain'],'phone':'+919000000001'});await turn();
  backend.captainValue({'name':'Old','approved':true},cached:true);await turn();expect(store.signedUp,false);expect(store.name,isEmpty);
  backend.captainValue({'name':'','phone':'+919000000001','approved':false,'online':false,'kycStatus':'notSubmitted'});await turn();
  expect(store.signedUp,false);expect(store.name,isEmpty);expect(store.upi,isEmpty);expect(store.underReview,false);expect(store.workSlots,isEmpty);
  store.dispose();await backend.close();
 });
}
