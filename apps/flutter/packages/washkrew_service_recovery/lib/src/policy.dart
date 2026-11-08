/// Owner-confirmed 6 November 2026. All amounts are INTEGER PAISE.
/// Call only on the trusted server with immutable acceptance/window snapshots.
class RecoveryPolicy {
  static const version = 'owner-2026-11-06-v1';
  static int penaltyPercent({
    required DateTime acceptedAt,
    required DateTime windowStart,
    required DateTime now,
  }) {
    if (now.isBefore(acceptedAt) || !windowStart.isAfter(acceptedAt)) {
      throw ArgumentError('Invalid server timestamps');
    }
    if (now.difference(acceptedAt) <= const Duration(minutes: 5)) return 0;
    final lead = windowStart.difference(now);
    if (lead >= const Duration(hours: 24)) return 10;
    if (lead >= const Duration(hours: 2)) return 50;
    return 100;
  }

  /// Round half a paise down; retain full precision until this ledger boundary.
  static int percentage(int paise, int percent) {
    if (paise < 0 || percent < 0 || percent > 100)
      throw ArgumentError('Invalid amount');
    return paise * percent ~/ 100;
  }

  static int missingVehiclePay(int quotedCaptainPaise) =>
      percentage(quotedCaptainPaise, 50);

  /// Allocates a subscription's paid value without losing remainder paise.
  /// Use the immutable paid total/visit count, never the current list price.
  static List<int> allocateVisits(int paidPaise, int visits) {
    if (paidPaise < 0 || visits <= 0) throw ArgumentError('Invalid plan');
    return List.generate(
      visits,
      (i) => paidPaise ~/ visits + (i < paidPaise % visits ? 1 : 0),
    );
  }
}

String recoveryMoney(int paise) =>
    '₹${paise % 100 == 0 ? paise ~/ 100 : (paise / 100).toStringAsFixed(2)}';
