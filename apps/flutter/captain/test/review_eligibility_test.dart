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
}
