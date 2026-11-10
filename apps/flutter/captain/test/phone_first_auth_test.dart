import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/welcome.dart';
import '../../packages/washkrew_firebase/test/account_session_fixture.dart';

class PhoneStore extends CaptainStore {
 @override bool get isLive=>true;
 String? requested;
 @override Future<void> liveRequestOtp(String number)async{requested=number;}
}
class LoginFixture extends AccountSessionFixture {
 LoginFixture(this.needsName);
 final bool needsName;
 String? submittedName;
 @override Future<Map<String,dynamic>> verifyOtp(String code,{required String role,String name=''})async{
  submittedName=name;expect(role,'captain');return {'name':needsName?'':'Existing Captain','needsName':needsName};
 }
}
void main(){
 testWidgets('Captain entry requests only phone before OTP for both new and existing accounts',(tester)async{
  final store=PhoneStore(),router=WRouterC();
  await tester.pumpWidget(CaptainScope(store:store,router:router,child:const MaterialApp(home:SignUpScreen())));
  expect(find.text('Your name'),findsNothing);expect(find.text('What’s your number?'),findsOneWidget);
  await tester.enterText(find.byType(TextField),'9000000001');await tester.pump();
  await tester.ensureVisible(find.text('Get code'));await tester.tap(find.text('Get code'));await tester.pump();
  expect(store.requested,'9000000001');expect(router.last?.n,N.otp);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 for(final needsName in [false,true]){
  test('verified role determines signup; a cached name cannot overwrite an existing Captain ($needsName)',()async{
   final backend=LoginFixture(needsName)..account='captain',store=CaptainStore(live:backend)..name='Cached other name';
   expect(await store.liveVerifyOtp('123456'),needsName);expect(backend.submittedName,'');expect(store.name,needsName?'':'Existing Captain');
   store.dispose();await backend.close();
  });
 }
}
