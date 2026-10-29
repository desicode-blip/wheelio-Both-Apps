import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';
import 'package:washkrew_captain/screens/wash.dart';

// Exercises the production-state guards without Firebase or a real account.
class FirebaseStateStore extends CaptainStore {
  @override
  bool get isLive => true;
}

void main() {
  testWidgets('completed Firebase job does not promise an unrecorded midnight payout', (tester) async {
    tester.view.physicalSize=const Size(430,1100);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final store=FirebaseStateStore(),router=WRouterC();
    await tester.pumpWidget(CaptainScope(store:store,router:router,child:const MaterialApp(home:JobDoneScreen())));
    expect(find.text('Owner checks the photos. Payouts are confirmed separately.'),findsOneWidget);
    expect(find.textContaining('Money comes tonight'),findsNothing);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
  testWidgets('hidden training leaves three KYC steps leading to review without awarding completion', (tester) async {
    tester.view.physicalSize=const Size(430,1100);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final store=FirebaseStateStore()..registered=true;
    store.liveConfig={'training':{'enabled':false,'required':false}};
    store.steps={KycStep.aadhaar:KycState.done,KycStep.photo:KycState.done,KycStep.bank:KycState.done};
    final router=WRouterC();
    expect(store.nextStep,isNull);expect(store.stepsDone,3);expect(store.kycStagesDone,3);expect(store.kycStageCount,3);
    expect(store.signedUp,isFalse);expect(store.canGoOnline,isFalse);
    expect(store.steps.containsKey(KycStep.training),isFalse);expect(store.steps.containsKey(KycStep.quiz),isFalse);
    await tester.pumpWidget(CaptainScope(store:store,router:router,child:const MaterialApp(home:StepsScreen())));
    expect(find.text('3 steps to take jobs'),findsOneWidget);expect(find.text('Onboarding'),findsNothing);expect(find.text('Short training videos and a quiz'),findsNothing);
    await tester.tap(find.text('Continue'));await tester.pump();expect(router.last?.n,N.rules);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
  test('training can be explicitly restored without counting stale completion toward the hidden KYC stages', () {
    final store=FirebaseStateStore();
    store.liveConfig={'training':{'enabled':false,'required':false}};
    store.steps={KycStep.training:KycState.done,KycStep.quiz:KycState.done};
    expect(store.stepsDone,0);expect(store.kycStagesDone,0);expect(store.trainingEnabled,isFalse);
    store.liveConfig={'training':{'enabled':true,'required':true}};
    expect(store.trainingEnabled,isTrue);expect(store.kycStageCount,4);
    store.steps={KycStep.aadhaar:KycState.done,KycStep.photo:KycState.done,KycStep.bank:KycState.done};
    expect(store.nextStep,KycStep.training);store.dispose();
  });
  test('preview review and onboarding skips cannot grant Firebase approval or Online', () {
    final store=FirebaseStateStore();
    store.registered=true;
    store.testSkipStep(KycStep.training);
    store.testSkipReview();
    store.goOnlineAfterApproval();
    expect(store.testSkipped,isEmpty);
    expect(store.signedUp,isFalse);
    expect(store.online,isFalse);
    store.dispose();
  });
  test('work-period normalization keeps early/late half-hour boundaries and breaks', () {
    expect(mergeSlots([(1230,1320),(240,300),(270,330),(540,600)]),[(240,330),(540,600),(1230,1320)]);
    expect(workDayStart,240);expect(workDayEnd,1320);
  });
  test('a correction request does not remain in the waiting-for-approval state', () {
    final store=FirebaseStateStore()..registered=true;
    store.kycStatus='underReview';
    store.startReview();
    expect(store.underReview,isTrue);
    store.kycStatus='changesRequested';
    expect(store.underReview,isFalse);
    final n=WNotif(id:'review',kind:WNotifKind.applicationReview,date:DateTime.now(),reviewTitle:'Your application needs corrections',reviewBody:'Please upload a clear selfie.');
    expect(store.title(n),'Your application needs corrections');
    expect(store.body(n),'Please upload a clear selfie.');
    final router=WRouterC();
    openWNotif(n,store,router);
    expect(router.last?.n,N.steps);
    store.dispose();router.dispose();
  });
}
