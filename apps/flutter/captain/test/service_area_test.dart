import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';
import 'package:washkrew_captain/screens/service_area.dart';
import 'package:washkrew_captain/screens/help.dart' show WorkSlotsEditor;
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
 testWidgets('the time arc moves the nearer end in half-hour steps',(tester)async{
  tester.view.physicalSize=const Size(390,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final s=LiveState(),r=WRouterC();
  var slots=<WorkSlot>[(9*60,18*60)];
  await tester.pumpWidget(CaptainScope(store:s,router:r,child:MaterialApp(home:Scaffold(body:StatefulBuilder(builder:(c,set)=>WorkSlotsEditor(slots:slots,onChanged:(v)=>set(()=>slots=v)))))));
  final sky=find.byWidgetPredicate((w)=>w is GestureDetector&&w.onHorizontalDragUpdate!=null).first;
  final box=tester.getRect(sky);
  // Drag from the left edge (nearer the 9 AM sun) further left: the start moves earlier.
  await tester.dragFrom(Offset(box.left+box.width*0.3,box.center.dy),const Offset(-60,0));await tester.pump();
  expect(slots.single.$1<9*60,isTrue);expect(slots.single.$2,18*60);expect(slots.single.$1%30,0);
  await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
 });
 testWidgets('new area screen explains GPS and has no guessed operational map centre',(tester)async{
  tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final s=LiveState(),r=WRouterC();
  await tester.pumpWidget(CaptainScope(store:s,router:r,child:const MaterialApp(home:ServiceAreaScreen())));
  await tester.pump(const Duration(milliseconds:400));
  // 14 Nov: GPS starts as the screen opens; when it can't, location-off offers search.
  expect(find.text('Location is off'),findsOneWidget);expect(find.text('Turn on location'),findsOneWidget);
  await tester.tap(find.text('Search area'));await tester.pump();
  expect(find.text('Use current location'),findsOneWidget);expect(find.text('Search area or building'),findsOneWidget);
  expect(s.hasServiceArea,false);expect(tester.takeException(),isNull);
  await tester.pumpWidget(const SizedBox());s.dispose();r.dispose();
 });
}
