import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';

// Exercises the production-state guards without Firebase or a real account.
class FirebaseStateStore extends CaptainStore {
  @override
  bool get isLive => true;
}

void main() {
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
