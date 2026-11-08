import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_referrals/washkrew_referrals.dart';
import 'package:washkrew_referrals/demo_tools.dart';

void main() {
  test('captain milestones are additional, invitee earns only first bonus', () {
    expect(ReferralPolicy.referrerCashEntitlement(4), 0);
    expect(ReferralPolicy.referrerCashEntitlement(5), 5000);
    expect(ReferralPolicy.referrerCashEntitlement(49), 5000);
    expect(ReferralPolicy.referrerCashEntitlement(50), 55000);
    expect(ReferralPolicy.inviteeCashEntitlement(50), 5000);
  });
  test('duplicate events and ineligible washes cannot double award', () {
    final r = DemoReferralRepository(actorId: 'customer_ananya');
    final p = r.outgoing.first;
    for (final i in [1, 2]) {
      r.simulateVerifiedCompletion(
        referralId: p.id,
        washId: 'free$i',
        freeRewardWash: true,
      );
      r.simulateVerifiedCompletion(
        referralId: p.id,
        washId: 'unpaid$i',
        paid: false,
      );
    }
    expect(r.outgoing.first.completedWashes, 4);
    r.simulateVerifiedCompletion(referralId: p.id, washId: 'paid5');
    r.simulateVerifiedCompletion(referralId: p.id, washId: 'paid5');
    expect(r.outgoing.first.completedWashes, 5);
    expect(r.availablePremiumWashes.length, 1);
  });
  test(
    'captain gets 550 total; new captain gets 50; immutable attribution',
    () async {
      final r = DemoReferralRepository(actorId: 'captain_raju', progress: 50);
      expect(r.pendingCashPaise, 55000);
      final n = DemoReferralRepository(actorId: 'captain_new');
      await n.attachCode(' wkraju7x ');
      await n.attachCode('WKRAJU7X');
      expect(n.incoming!.referrerId, 'captain_raju');
      expect(n.validateCode('WKMAYA42'), isNotNull);
      expect(n.validateCode('WKNEW8K2'), isNotNull);
      expect(n.validateCode('WKANAY84'), isNotNull);
      expect(n.validateCode('BADCODE'), isNotNull);
    },
  );
  test(
    'customer premium reward reservation, release and redeem are idempotent',
    () async {
      final r = DemoReferralRepository(actorId: 'customer_ananya', progress: 5);
      final id = r.availablePremiumWashes.single.id;
      await r.reservePremiumWash(id);
      await r.reservePremiumWash(id);
      expect(r.availablePremiumWashes, isEmpty);
      await r.releasePremiumWash(id);
      expect(r.availablePremiumWashes.length, 1);
      await r.reservePremiumWash(id);
      await r.confirmPremiumWashUse(id);
      await r.confirmPremiumWashUse(id);
      expect(r.rewards.single.state, RewardState.redeemed);
      await expectLater(r.reservePremiumWash(id), throwsStateError);
    },
  );
}
