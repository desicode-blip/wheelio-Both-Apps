import 'dart:async';
import 'dart:convert';
import '../src/contracts.dart';
import '../src/policy.dart';
import 'storage.dart';

/// Local synthetic review data only. Shared between review tabs, NOT a secure ledger.
/// Do not ship this implementation. It intentionally cannot contact live services.
class DemoRecoveryRepository extends RecoveryRepository {
  DemoRecoveryRepository({this.monthly = false}) {
    _read();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_read()) notifyListeners();
    });
  }
  final bool monthly;
  String get _storageKey =>
      'washkrew-studio-recovery-v2-${monthly ? "monthly" : "once"}';
  Timer? _timer;
  int hoursBefore = 1;
  bool withinGrace = false, failNextUpload = false;
  RecoverySnapshot _snapshot = const RecoverySnapshot();
  @override
  bool get isDemo => true;
  @override
  RecoverySnapshot get snapshot => _snapshot;
  @override
  RecoveryVisit get visit => RecoveryVisit(
    id: 'demo-visit-001',
    paidVisitPaise: monthly
        ? RecoveryPolicy.allocateVisits(51700, 13)[2]
        : 29200,
    captainQuotePaise: monthly ? 3500 : 12000,
    acceptedAt: DateTime.utc(2026, 11, 6, 6),
    windowStart: DateTime.utc(2026, 11, 6, 8).add(Duration(hours: hoursBefore)),
    monthly: monthly,
  );
  DateTime get _now => withinGrace
      ? visit.acceptedAt.add(const Duration(minutes: 5))
      : visit.windowStart.subtract(Duration(hours: hoursBefore));
  @override
  int get cancellationPenaltyPaise => RecoveryPolicy.percentage(
    visit.paidVisitPaise,
    RecoveryPolicy.penaltyPercent(
      acceptedAt: visit.acceptedAt,
      windowStart: visit.windowStart,
      now: _now,
    ),
  );
  bool _read() {
    try {
      final raw = readRecovery(_storageKey);
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['revision'] == _snapshot.revision) return false;
      _snapshot = RecoverySnapshot(
        status: RecoveryStatus.values.byName(m['status']),
        step: EvidenceStep.values.byName(m['step']),
        penaltyPaise: m['penalty'],
        compensationPaise: m['compensation'],
        creditPaise: m['credit'],
        note: m['note'],
        makeUpAt: DateTime.tryParse(m['makeUpAt'] ?? ''),
        revision: m['revision'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _save({
    RecoveryStatus? status,
    EvidenceStep? step,
    int? penalty,
    int? compensation,
    int? credit,
    String? note,
    DateTime? makeUpAt,
  }) {
    final s = _snapshot;
    _snapshot = RecoverySnapshot(
      status: status ?? s.status,
      step: step ?? s.step,
      penaltyPaise: penalty ?? s.penaltyPaise,
      compensationPaise: compensation ?? s.compensationPaise,
      creditPaise: credit ?? s.creditPaise,
      note: note ?? s.note,
      makeUpAt: makeUpAt ?? s.makeUpAt,
      revision: DateTime.now().microsecondsSinceEpoch,
    );
    final n = _snapshot;
    writeRecovery(
      jsonEncode({
        'status': n.status.name,
        'step': n.step.name,
        'penalty': n.penaltyPaise,
        'compensation': n.compensationPaise,
        'credit': n.creditPaise,
        'note': n.note,
        'makeUpAt': n.makeUpAt?.toIso8601String(),
        'revision': n.revision,
      }),
      key: _storageKey,
    );
    notifyListeners();
  }

  void _assigned() {
    _read();
    if (snapshot.status != RecoveryStatus.assigned &&
        snapshot.status != RecoveryStatus.missingRejected)
      throw StateError(
        'This assignment has changed. Refresh before continuing.',
      );
  }

  @override
  Future<void> verifyArrival() async {
    _assigned();
    _save(step: EvidenceStep.contact);
  }

  @override
  Future<void> contactOwner() async {
    _assigned();
    if (snapshot.step != EvidenceStep.contact)
      throw StateError('Confirm your location first.');
    _save(step: EvidenceStep.record);
  }

  @override
  Future<void> prepareVideo() async {
    _assigned();
    if (snapshot.step != EvidenceStep.record &&
        snapshot.step != EvidenceStep.failed)
      throw StateError('Contact the owner first.');
    if (!demoVideoReady())
      throw StateError('Record a video or create the labelled sample first.');
    _save(step: EvidenceStep.ready);
  }

  @override
  Future<void> retakeVideo() async {
    _assigned();
    if (![
      EvidenceStep.record,
      EvidenceStep.ready,
      EvidenceStep.failed,
    ].contains(snapshot.step))
      throw StateError('This evidence cannot be replaced.');
    clearDemoVideo();
    _save(status: RecoveryStatus.assigned, step: EvidenceStep.record);
  }

  @override
  Future<void> submitEvidence() async {
    _assigned();
    if (snapshot.step != EvidenceStep.ready)
      throw StateError('Video evidence is required.');
    if (failNextUpload) {
      failNextUpload = false;
      _save(step: EvidenceStep.failed);
      throw StateError('Upload failed. Your draft is safe. Try again.');
    }
    _save(
      status: RecoveryStatus.evidencePending,
      note: 'Captain checked Tower 3 · B2 · Slot 41 and attempted contact.',
    );
  }

  @override
  Future<void> ownerLocatedVehicle({
    String location = 'Original parking spot',
  }) async {
    if (location.trim().isEmpty)
      throw StateError('Please give the parking location.');
    _read();
    if (snapshot.status != RecoveryStatus.evidencePending)
      throw StateError('This request is already resolved. Contact support.');
    _save(
      status: RecoveryStatus.vehicleLocated,
      step: EvidenceStep.location,
      note:
          'Owner location: ${location.trim()}. Please check with the owner before resuming.',
    );
  }

  @override
  Future<void> dispute(String reason) async {
    _read();
    if (reason.trim().isEmpty)
      throw StateError('Please tell us what happened.');
    if (![
      RecoveryStatus.evidencePending,
      RecoveryStatus.missingApproved,
      RecoveryStatus.missingRejected,
    ].contains(snapshot.status))
      throw StateError('This case is already being reviewed.');
    _save(status: RecoveryStatus.disputed, note: reason.trim());
  }

  @override
  Future<void> cancelCaptain({required String reason}) async {
    _assigned();
    if (reason.trim().isEmpty)
      throw StateError('Select a cancellation reason.');
    _save(
      status: RecoveryStatus.replacementSearching,
      penalty: cancellationPenaltyPaise,
      note: reason,
    );
  }

  /// Review harness only. Real production decisions belong to human admin/server.
  void reviewMissing({required bool approve}) {
    _read();
    if (![
      RecoveryStatus.evidencePending,
      RecoveryStatus.disputed,
    ].contains(snapshot.status))
      throw StateError('No pending review.');
    _save(
      status: approve
          ? RecoveryStatus.missingApproved
          : RecoveryStatus.missingRejected,
      compensation: approve
          ? RecoveryPolicy.missingVehiclePay(visit.captainQuotePaise)
          : 0,
      credit: 0,
      note: approve
          ? 'Human review approved the submitted proof.'
          : 'Evidence could not establish vehicle unavailability. Support will arrange the next step.',
    );
  }

  void resolveDisputeForCustomer() {
    _read();
    if (snapshot.status != RecoveryStatus.disputed)
      throw StateError('No disputed case.');
    _save(
      status: RecoveryStatus.walletCredited,
      credit: visit.paidVisitPaise,
      compensation: 0,
      note:
          'Support upheld the customer dispute. Full visit value returned to wallet.',
    );
  }

  void replacement({required bool found}) {
    _read();
    if (snapshot.status != RecoveryStatus.replacementSearching)
      throw StateError('Replacement search is no longer open.');
    if (found) {
      _save(
        status: RecoveryStatus.reassigned,
        note: 'Maya is your new Captain. Same service and price.',
      );
      return;
    }
    if (monthly) {
      _save(
        status: RecoveryStatus.makeUpOffered,
        makeUpAt: visit.windowStart.add(const Duration(days: 2)),
        note:
            'No replacement fit the original window. An alternate day is available in this sample.',
      );
      return;
    }
    _save(
      status: RecoveryStatus.walletCredited,
      credit: visit.paidVisitPaise,
      note:
          'No replacement was available after search and escalation. Full visit value returned to your wallet.',
    );
  }

  @override
  Future<void> acceptMakeUp() async {
    _read();
    if (snapshot.status != RecoveryStatus.makeUpOffered ||
        snapshot.makeUpAt == null)
      throw StateError('This make-up option is no longer available.');
    _save(
      status: RecoveryStatus.makeUpScheduled,
      note:
          'Customer confirmed the make-up day. No extra charge; remaining plan visits are unchanged.',
    );
  }

  @override
  Future<void> declineMakeUp() async {
    _read();
    if (snapshot.status != RecoveryStatus.makeUpOffered)
      throw StateError('This visit has already been resolved.');
    _save(
      status: RecoveryStatus.walletCredited,
      credit: visit.paidVisitPaise,
      note:
          'The proposed make-up day did not work. This visit’s full paid value was returned to your wallet.',
    );
  }

  void noMakeUpAvailable() {
    _read();
    if (snapshot.status != RecoveryStatus.makeUpOffered)
      throw StateError('No make-up search is open.');
    _save(
      status: RecoveryStatus.walletCredited,
      credit: visit.paidVisitPaise,
      note:
          'No replacement or make-up day was available. This visit’s full paid value was returned to your wallet.',
    );
  }

  void reset() {
    clearDemoVideo();
    _snapshot = const RecoverySnapshot();
    _save();
  }

  void setBand(int hours, {bool grace = false}) {
    hoursBefore = hours;
    withinGrace = grace;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
