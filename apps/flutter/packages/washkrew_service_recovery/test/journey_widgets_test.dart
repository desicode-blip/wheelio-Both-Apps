import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_service_recovery/washkrew_service_recovery.dart';
import 'package:washkrew_service_recovery/demo_tools.dart';

void main() {
  test(
    'Monthly replacement failure offers make-up before credit and accepted date cannot refund twice',
    () async {
      final r = DemoRecoveryRepository(monthly: true);
      addTearDown(r.dispose);
      await r.cancelCaptain(reason: 'Emergency');
      r.replacement(found: false);
      expect(r.snapshot.status, RecoveryStatus.makeUpOffered);
      expect(r.snapshot.creditPaise, 0);
      await r.acceptMakeUp();
      expect(r.snapshot.status, RecoveryStatus.makeUpScheduled);
      expect(r.snapshot.creditPaise, 0);
      await expectLater(r.declineMakeUp(), throwsStateError);
      expect(() => r.noMakeUpAvailable(), throwsStateError);
    },
  );
  test('Only exhausted make-up search returns a monthly visit value', () async {
    final r = DemoRecoveryRepository(monthly: true);
    addTearDown(r.dispose);
    await r.cancelCaptain(reason: 'Emergency');
    r.replacement(found: false);
    r.noMakeUpAvailable();
    expect(r.snapshot.creditPaise, r.visit.paidVisitPaise);
    expect(() => r.noMakeUpAvailable(), throwsStateError);
  });

  testWidgets(
    'Video has a fixed next action and report reaches review and earnings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = DemoRecoveryRepository();

      await r.verifyArrival();
      await r.contactOwner();
      var earnings = false;
      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryScreen(
            repository: r,
            role: RecoveryRole.captain,
            onBack: () {},
            onDone: () {},
            onEarnings: () => earnings = true,
            capture: const SizedBox(height: 360, child: Text('Capture video')),
            evidence: const SizedBox(
              height: 260,
              child: Text('Read-only video'),
            ),
          ),
        ),
      );
      final use = find.text('Use this video');
      expect(tester.getRect(use).bottom, lessThan(844));
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(find.text('Review your report'), findsOneWidget);
      expect(find.text('Capture video'), findsNothing);
      await tester.tap(find.text('Send proof for review'));
      await tester.pumpAndSettle();
      expect(find.text('Proof sent for review'), findsOneWidget);
      expect(find.text('Back to jobs'), findsOneWidget);
      expect(r.snapshot.compensationPaise, 0);
      r.reviewMissing(approve: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View earnings'));
      expect(earnings, isTrue);
      expect(r.snapshot.compensationPaise, 6000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      r.dispose();
      await tester.pumpAndSettle();
    },
  );
  test(
    'Rejected proof can be retaken, submitted evidence cannot be overwritten',
    () async {
      final r = DemoRecoveryRepository();
      addTearDown(r.dispose);
      await r.verifyArrival();
      await r.contactOwner();
      await r.prepareVideo();
      await r.submitEvidence();
      await expectLater(r.retakeVideo(), throwsStateError);
      r.reviewMissing(approve: false);
      await r.retakeVideo();
      expect(r.snapshot.status, RecoveryStatus.assigned);
      expect(r.snapshot.step, EvidenceStep.record);
      expect(r.snapshot.compensationPaise, 0);
    },
  );
}
