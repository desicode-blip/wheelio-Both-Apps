// v2 (12 Nov 2026): what the Customer's new choices look like on a Captain's job.
// The Customer app sends these with the booking (see docs/v2/V2-FEATURES.md); the
// server copies them onto the job and offer documents:
//   minuteWindows: [{startMinute, endMinute}]   the owner's exact time windows
//   serviceLevel:  basic | premium | extraPremium
//   coverage:      exterior | exteriorInterior
//   plan:          {visitNumber, totalVisits, dates: ['YYYY-MM-DD']}  a monthly plan (visit or whole offer)
//   gatePassPath:  Storage path of the gate pass image
//   vehicleProfile: {make, model, color, finish, seats, source}  (v2 CU-CARE, 12 Nov)
//   careRoutine:   [{title, detail}]              2–3 care adjustments for this vehicle
// Until the server sends them every field is null/empty and jobs look as before.

/// "8:15 AM – 10:45 AM"
String exactWindowLabel(int startMinute, int endMinute) => '${_clock(startMinute)} – ${_clock(endMinute)}';

String _clock(int minute) {
  final h = minute ~/ 60, m = minute % 60;
  return '${h % 12 == 0 ? 12 : h % 12}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

class JobExtras {
  const JobExtras({this.exactWindows = const [], this.serviceLevel, this.planVisit, this.planVisits, this.vehicleName, this.care = const [], this.planDates = const []});

  /// Every planned visit date of a monthly plan (sent with a monthly job offer).
  final List<DateTime> planDates;

  /// "Hyundai Creta · White · Matte paint", or null when the owner didn't say.
  final String? vehicleName;

  /// The owner's care routine for this vehicle: (title, detail).
  final List<(String, String)> care;

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
    final plan = o['plan'], v = o['vehicleProfile'];
    String? vehicleName;
    if (v is Map) {
      final name = [v['make'], v['model']].whereType<String>().where((x) => x.trim().isNotEmpty).join(' ');
      final finish = switch (v['finish']) { 'matte' => 'Matte paint', 'glossy' => 'Glossy paint', _ => null };
      final seats = v['seats'] == 'leather' ? 'Leather seats' : null;
      final parts = [if (name.isNotEmpty) name, if (v['color'] is String && (v['color'] as String).trim().isNotEmpty) v['color'] as String, ?finish, ?seats];
      vehicleName = parts.isEmpty ? null : parts.join(' · ');
    }
    final dates = [
      if (plan is Map)
        for (final d in plan['dates'] as List? ?? const [])
          if (d is String && DateTime.tryParse(d) != null) DateTime.parse(d),
    ]..sort();
    return JobExtras(
      planDates: dates,
      vehicleName: vehicleName,
      care: [
        for (final c in o['careRoutine'] as List? ?? const [])
          if (c is Map && c['title'] is String) (c['title'] as String, c['detail'] as String? ?? ''),
      ],
      exactWindows: [for (final w in windows) exactWindowLabel(w.$1, w.$2)],
      serviceLevel: switch (o['serviceLevel']) { 'basic' => 'Basic', 'premium' => 'Premium', 'extraPremium' => 'Extra Premium', _ => null },
      planVisit: plan is Map ? (plan['visitNumber'] as num?)?.toInt() : null,
      planVisits: plan is Map ? (plan['totalVisits'] as num?)?.toInt() : null,
    );
  }
}
