// v2 (12 Nov 2026): what the Customer's new choices look like on a Captain's job.
// The Customer app sends these with the booking (see docs/v2/V2-FEATURES.md); the
// server copies them onto the job and offer documents:
//   minuteWindows: [{startMinute, endMinute}]   the owner's exact time windows
//   serviceLevel:  basic | premium | extraPremium
//   coverage:      exterior | exteriorInterior
//   plan:          {visitNumber, totalVisits}    a visit of a monthly plan
//   gatePassPath:  Storage path of the gate pass image
// Until the server sends them every field is null/empty and jobs look as before.

/// "8:15 AM – 10:45 AM"
String exactWindowLabel(int startMinute, int endMinute) => '${_clock(startMinute)} – ${_clock(endMinute)}';

String _clock(int minute) {
  final h = minute ~/ 60, m = minute % 60;
  return '${h % 12 == 0 ? 12 : h % 12}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

class JobExtras {
  const JobExtras({this.exactWindows = const [], this.serviceLevel, this.planVisit, this.planVisits});

  /// The owner's own windows, in order. Empty = the server's fixed windows apply.
  final List<String> exactWindows;

  /// 'Basic', 'Premium' or 'Extra Premium'; null on today's jobs.
  final String? serviceLevel;

  /// Visit n of N of a monthly plan; null for a one-time wash.
  final int? planVisit, planVisits;

  bool get monthly => planVisit != null && planVisits != null;

  static const none = JobExtras();

  /// Reads the v2 fields from a job or offer document.
  factory JobExtras.fromOrder(Map<String, dynamic> o) {
    final windows = [
      for (final w in o['minuteWindows'] as List? ?? const [])
        if (w is Map && w['startMinute'] is num && w['endMinute'] is num) ((w['startMinute'] as num).toInt(), (w['endMinute'] as num).toInt()),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final plan = o['plan'];
    return JobExtras(
      exactWindows: [for (final w in windows) exactWindowLabel(w.$1, w.$2)],
      serviceLevel: switch (o['serviceLevel']) { 'basic' => 'Basic', 'premium' => 'Premium', 'extraPremium' => 'Extra Premium', _ => null },
      planVisit: plan is Map ? (plan['visitNumber'] as num?)?.toInt() : null,
      planVisits: plan is Map ? (plan['totalVisits'] as num?)?.toInt() : null,
    );
  }
}
