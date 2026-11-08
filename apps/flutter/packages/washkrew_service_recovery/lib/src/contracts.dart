import 'package:flutter/foundation.dart';

enum RecoveryStatus {
  assigned,
  vehicleLocated,
  evidencePending,
  missingApproved,
  missingRejected,
  disputed,
  replacementSearching,
  makeUpOffered,
  makeUpScheduled,
  reassigned,
  walletCredited,
}

enum RecoveryRole { customer, captain, reviewer }

enum EvidenceStep { location, contact, record, ready, failed }

/// One visit, never an entire monthly subscription. Monetary values supplied by server.
class RecoveryVisit {
  const RecoveryVisit({
    required this.id,
    required this.paidVisitPaise,
    required this.captainQuotePaise,
    required this.acceptedAt,
    required this.windowStart,
    this.monthly = false,
  });
  final String id;
  final int paidVisitPaise, captainQuotePaise;
  final DateTime acceptedAt, windowStart;
  final bool monthly;
}

class RecoverySnapshot {
  const RecoverySnapshot({
    this.status = RecoveryStatus.assigned,
    this.step = EvidenceStep.location,
    this.penaltyPaise = 0,
    this.compensationPaise = 0,
    this.creditPaise = 0,
    this.note = '',
    this.revision = 0,
    this.makeUpAt,
  });
  final RecoveryStatus status;
  final EvidenceStep step;
  final int penaltyPaise, compensationPaise, creditPaise, revision;
  final String note;
  final DateTime? makeUpAt;
}

/// Adapter boundary: every mutating call must be authorized, revision-checked,
/// idempotent and persisted server-side. UI never issues money itself.
abstract class RecoveryRepository extends ChangeNotifier {
  RecoveryVisit get visit;
  RecoverySnapshot get snapshot;
  Future<void> verifyArrival();
  Future<void> contactOwner();
  Future<void> prepareVideo();
  Future<void> retakeVideo();
  Future<void> submitEvidence();
  Future<void> ownerLocatedVehicle({String location = 'Original parking spot'});
  Future<void> dispute(String reason);
  Future<void> acceptMakeUp();
  Future<void> declineMakeUp();
  Future<void> cancelCaptain({required String reason});
  int get cancellationPenaltyPaise;
  bool get isDemo;
}

/// Wire-level command envelope for the future authenticated server adapter.
/// The server reads the actor from auth, never from this payload.
class RecoveryCommand {
  const RecoveryCommand({
    required this.visitId,
    required this.idempotencyKey,
    required this.expectedRevision,
  });
  final String visitId, idempotencyKey;
  final int expectedRevision;
}

class CancellationQuote {
  const CancellationQuote({
    required this.id,
    required this.policyVersion,
    required this.penaltyPaise,
    required this.expiresAt,
    required this.assignmentRevision,
  });
  final String id, policyVersion;
  final int penaltyPaise, assignmentRevision;
  final DateTime expiresAt;
}

abstract interface class RecoveryServerPort {
  Future<RecoverySnapshot> readVisit(String visitId);
  Future<CancellationQuote> quoteCancellation(String visitId);
  Future<RecoverySnapshot> confirmCancellation(
    RecoveryCommand command, {
    required String quoteId,
    required String reason,
  });
  Future<RecoverySnapshot> submitMissingVehicle(
    RecoveryCommand command, {
    required String evidenceUploadId,
  });
  Future<RecoverySnapshot> confirmMakeUp(
    RecoveryCommand command, {
    required String offerId,
  });
  Future<RecoverySnapshot> rejectMakeUp(
    RecoveryCommand command, {
    required String offerId,
  });
  Future<RecoverySnapshot> disputeMissingVehicle(
    RecoveryCommand command, {
    required String reason,
  });
}
