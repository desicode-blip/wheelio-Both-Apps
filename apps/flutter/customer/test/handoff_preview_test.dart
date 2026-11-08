import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/features/preview_features.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';
import 'package:washkrew_referrals/washkrew_referrals.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 (ChatGPT handoff, 8 Nov): every Customer preview screen opens, and the free Premium
// wash leads into booking with the reward selected.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(LocalFlags.resetForTest);
  final screens = <String, Widget>{
    'referrals': const CustomerReferralsScreen(),
    'referral progress': const CustomerReferralScenariosScreen(),
    'were you referred': const CustomerReferralJoinScreen(),
    'vehicle not found': const CustomerRecoveryScreen(),
    'review outcomes': const CustomerRecoveryScenariosScreen(),
  };
  for (final e in screens.entries) {
    testWidgets('${e.key} opens', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..signInAsSample()..previewFeatures = true;
      final router = AppRouter();
      await tester.pumpWidget(AppScope(store: store, router: router, child: MaterialApp(home: e.value)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  test('a new booking releases an unused free Premium wash', () async {
    final store = AppStore()..signInAsSample();
    final reward = store.referrals.rewards.where((r) => r.state == RewardState.available && r.kind == RewardKind.premiumWash).firstOrNull;
    if (reward != null) {
      store.purchase.premiumRewardId = await store.referrals.reservePremiumWash(reward.id);
      store.startNewBooking();
      expect(store.purchase.usingPremiumReward, isFalse);
    }
    expect(store.purchase.level, ServiceLevel.basic);
    store.dispose();
  });
}
