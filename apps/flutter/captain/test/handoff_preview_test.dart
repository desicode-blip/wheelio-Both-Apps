import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/features/preview_features.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

// v2 (ChatGPT handoff, 8 Nov): every Captain preview screen opens; real jobs carry no
// illustrative pay.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(LocalFlags.resetForTest);
  final screens = <String, (Widget, String)>{
    'referrals': (const CaptainReferralsScreen(), 'WK'),
    'pay guide': (const PayGuidePreview(), '₹'),
    'offer terms': (const OfferTermsPreview(), '₹120'),
    'recurring': (const RecurringAssignmentPreview(), '₹35'),
    'vehicle not found': (const CaptainRecoveryScreen(), ''),
    'review outcomes': (const CaptainRecoveryScenariosScreen(), ''),
    'admin referrals': (const ReferralAdminPreview(), ''),
  };
  for (final e in screens.entries) {
    testWidgets('${e.key} opens', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = CaptainStore()..previewFeatures = true;
      final router = WRouterC();
      await tester.pumpWidget(CaptainScope(store: store, router: router, child: MaterialApp(home: e.value.$1)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      if (e.value.$2.isNotEmpty) expect(find.textContaining(e.value.$2), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  test('today’s jobs have no visit terms, so Accept is unchanged', () {
    final store = CaptainStore();
    expect([...store.queue].every((j) => j.visitTerms == null), isTrue);
    expect(exampleOnce.hasConfirmedPay, isTrue);
  });
}
