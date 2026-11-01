import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';
import 'package:washkrew_captain/screens/service_area.dart';
class LiveState extends CaptainStore { @override bool get isLive=>true; }
void main(){
 testWidgets('document steps lead to area setup, without granting approval or training', (tester)async{
  final s=LiveState()..registered=true;
  s.liveConfig={'coveragePolicy':'captainAreaV1','training':{'enabled':false,'required':false}};
  s.steps={KycStep.aadhaar:KycState.done,KycStep.photo:KycState.done,KycStep.bank:KycState.done};
  final r=WRouterC();
  await tester.pumpWidget(CaptainScope(store:s,router:r,child:const MaterialApp(home:StepsScreen())));
  expect(s.nextStep,KycStep.area);expect(s.kycStageCount,4);expect(s.signedUp,false);
  expect(find.text('Serving area'),findsOneWidget);
  await tester.tap(find.text('Continue'));await tester.pump();expect(r.last?.n,N.workSetup);
  expect(s.trainingEnabled,false);expect(s.online,false);
  await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
 });
 testWidgets('new area screen explains GPS and has no guessed operational map centre',(tester)async{
  tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final s=LiveState(),r=WRouterC();
  await tester.pumpWidget(CaptainScope(store:s,router:r,child:const MaterialApp(home:ServiceAreaScreen())));
  await tester.pump(const Duration(milliseconds:400));
  expect(find.text('Why we ask for location'),findsOneWidget);expect(find.text('Use current location'),findsOneWidget);
  expect(s.hasServiceArea,false);expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
 });
}
