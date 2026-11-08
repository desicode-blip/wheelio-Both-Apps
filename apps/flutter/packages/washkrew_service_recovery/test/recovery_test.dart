import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_service_recovery/washkrew_service_recovery.dart';
import 'package:washkrew_service_recovery/demo_tools.dart';

void main() {
  final accepted = DateTime.utc(2026, 11, 1), start = DateTime.utc(2026, 11, 3);
  int band(DateTime now) => RecoveryPolicy.penaltyPercent(
    acceptedAt: accepted,
    windowStart: start,
    now: now,
  );
  test(
    '5 minute grace includes exact boundary; next microsecond leaves grace',
    () {
      expect(band(accepted.add(const Duration(minutes: 5))), 0);
      expect(
        band(accepted.add(const Duration(minutes: 5, microseconds: 1))),
        10,
      );
    },
  );
  test('24 hour and 2 hour lead boundaries', () {
    expect(band(start.subtract(const Duration(hours: 24))), 10);
    expect(
      band(
        start
            .subtract(const Duration(hours: 24))
            .add(const Duration(microseconds: 1)),
      ),
      50,
    );
    expect(band(start.subtract(const Duration(hours: 2))), 50);
    expect(
      band(
        start
            .subtract(const Duration(hours: 2))
            .add(const Duration(microseconds: 1)),
      ),
      100,
    );
    expect(band(start), 100);
  });
  test('invalid times rejected', () {
    expect(
      () => band(accepted.subtract(const Duration(seconds: 1))),
      throwsArgumentError,
    );
  });
  test('half of quoted earnings, not paid booking price; floor odd paise', () {
    expect(RecoveryPolicy.missingVehiclePay(12000), 6000);
    expect(RecoveryPolicy.missingVehiclePay(3501), 1750);
  });
  test('monthly allocation conserves every paid paise', () {
    for (final n in [1, 13, 28, 31]) {
      final a = RecoveryPolicy.allocateVisits(51700, n);
      expect(a.reduce((a, b) => a + b), 51700);
      expect(
        a.reduce((a, b) => a > b ? a : b) - a.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
      );
    }
    expect(() => RecoveryPolicy.allocateVisits(100, 0), throwsArgumentError);
  });
  test('missing vehicle cannot skip location, contact and proof', () async {
    final r = DemoRecoveryRepository();
    addTearDown(r.dispose);
    await expectLater(r.submitEvidence(), throwsStateError);
    await expectLater(r.contactOwner(), throwsStateError);
    await r.verifyArrival();
    await r.contactOwner();
    await r.prepareVideo();
    await r.submitEvidence();
    expect(r.snapshot.status, RecoveryStatus.evidencePending);
    expect(r.snapshot.compensationPaise, 0);
    r.reviewMissing(approve: true);
    expect(r.snapshot.compensationPaise, 6000);
    expect(r.snapshot.creditPaise, 0);
    expect(() => r.reviewMissing(approve: true), throwsStateError);
    await r.dispute('Vehicle was in the correct spot');
    r.resolveDisputeForCustomer();
    expect(r.snapshot.creditPaise, 29200);
    expect(r.snapshot.compensationPaise, 0);
  });
  test('upload failure retains retry and does not settle', () async {
    final r = DemoRecoveryRepository();
    addTearDown(r.dispose);
    await r.verifyArrival();
    await r.contactOwner();
    await r.prepareVideo();
    r.failNextUpload = true;
    await expectLater(r.submitEvidence(), throwsStateError);
    expect(r.snapshot.step, EvidenceStep.failed);
    expect(r.snapshot.compensationPaise, 0);
    await r.prepareVideo();
    await r.submitEvidence();
    expect(r.snapshot.status, RecoveryStatus.evidencePending);
  });
  test(
    'replacement winner prevents stale finalization and former captain activity',
    () async {
      final r = DemoRecoveryRepository();
      addTearDown(r.dispose);
      await r.cancelCaptain(reason: 'Emergency');
      expect(r.snapshot.status, RecoveryStatus.replacementSearching);
      r.replacement(found: true);
      expect(r.snapshot.creditPaise, 0);
      expect(() => r.replacement(found: false), throwsStateError);
      await expectLater(r.submitEvidence(), throwsStateError);
    },
  );
  test(
    'failed replacement returns allocated monthly value exactly once',
    () async {
      final r = DemoRecoveryRepository(monthly: true);
      addTearDown(r.dispose);
      await r.cancelCaptain(reason: 'Change of plans');
      r.replacement(found: false);
      expect(r.snapshot.status, RecoveryStatus.makeUpOffered);
      expect(r.snapshot.creditPaise, 0);
      await r.declineMakeUp();
      expect(r.snapshot.creditPaise, r.visit.paidVisitPaise);
      expect(r.snapshot.creditPaise, lessThan(51700));
      expect(() => r.replacement(found: false), throwsStateError);
    },
  );
  test(
    'customer location response cannot erase an approved decision',
    () async {
      final r = DemoRecoveryRepository();
      addTearDown(r.dispose);
      await r.verifyArrival();
      await r.contactOwner();
      await r.prepareVideo();
      await r.submitEvidence();
      await r.ownerLocatedVehicle();
      expect(r.snapshot.status, RecoveryStatus.vehicleLocated);
      expect(r.snapshot.creditPaise, 0);
    },
  );
}
