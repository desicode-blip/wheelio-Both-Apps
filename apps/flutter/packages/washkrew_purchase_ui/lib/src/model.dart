import 'time_windows.dart';
import 'package:flutter/foundation.dart';

enum RenewalMethod { upiAutopay, debitMandate, invoice }

enum PurchaseMode { once, monthly }

enum ServiceLevel { basic, premium, extraPremium }

enum WashCoverage { exterior, exteriorInterior }

extension ServiceName on ServiceLevel {
  String get label => switch (this) {
    ServiceLevel.basic => 'Basic',
    ServiceLevel.premium => 'Premium',
    ServiceLevel.extraPremium => 'Extra Premium',
  };
  String get detail => switch (this) {
    ServiceLevel.basic => 'Body, glass and wheels, cleaned and dried.',
    ServiceLevel.premium => 'Basic, with extra attention to wheels and trim.',
    ServiceLevel.extraPremium => 'Premium, with a protective finishing spray.',
  };
}

String shortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

String weekdayLabel(int d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime nextMonth(DateTime d) {
  final last = DateTime(d.year, d.month + 2, 0).day;
  return DateTime(d.year, d.month + 1, d.day.clamp(1, last));
}

/// Feature state is independent of app routes, Firebase and checkout.
/// All prices beyond the three owner anchors are design fixtures, not a tariff.
class PurchaseSelection extends ChangeNotifier {
  PurchaseSelection({DateTime? today})
    : start = dateOnly(today ?? DateTime.now());
  PurchaseMode mode = PurchaseMode.once;
  ServiceLevel level = ServiceLevel.basic;
  WashCoverage coverage = WashCoverage.exterior;
  bool isBike = false;
  String? premiumRewardId;
  bool get usingPremiumReward => premiumRewardId != null;
  bool chosen = false;
  bool confirmed = false;
  bool autoRenew = true;
  bool renewalAuthorityGranted = false;
  RenewalMethod renewalMethod = RenewalMethod.upiAutopay;
  bool interiorPreview = false;
  DateTime start;
  Set<int> weekdays = {1, 3, 5};
  // Legacy hour-only fixtures; custom windows are authoritative once edited.
  Set<int> windowStarts = {8};
  List<WashTimeWindow>? customWindows;
  List<WashTimeWindow> get timeWindows =>
      customWindows ??
      [
        for (final h in windowStarts)
          WashTimeWindow(startMinute: h * 60, endMinute: (h + 2) * 60),
      ];

  String vehicleName = 'Hatchback';
  String get coverageLabel => coverage == WashCoverage.exterior
      ? 'Exterior only'
      : 'Exterior + interior';
  String get serviceLabel => '${level.label} · $coverageLabel';
  bool get monthly => mode == PurchaseMode.monthly;
  int _frequency = 3;
  int get frequency => _frequency;
  String get frequencyLabel => frequency == 7
      ? 'Every day'
      : '$frequency ${frequency == 1 ? 'day' : 'days'} a week';
  void setFrequency(int days) {
    if (days < 1 || days > 7) throw RangeError.range(days, 1, 7, 'days');
    _frequency = days;
    const suggestions = {
      1: [1],
      2: [1, 4],
      3: [1, 3, 5],
      4: [1, 2, 4, 6],
      5: [1, 2, 3, 4, 5],
      6: [1, 2, 3, 4, 5, 6],
      7: [1, 2, 3, 4, 5, 6, 7],
    };
    weekdays = {...suggestions[days]!};
    notifyListeners();
  }

  DateTime get endExclusive => nextMonth(start);
  List<DateTime> get visits {
    final result = <DateTime>[];
    for (
      var d = start;
      d.isBefore(endExclusive);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (weekdays.contains(d.weekday)) result.add(d);
    }
    return result;
  }

  DateTime? get firstVisit => visits.firstOrNull;
  String get daysLabel =>
      [for (final d in weekdays.toList()..sort()) weekdayLabel(d)].join(', ');
  String get cycleLabel =>
      '${shortDate(start)} – ${shortDate(endExclusive.subtract(const Duration(days: 1)))}';
  String get windowLabel =>
      orderedWashWindows(timeWindows).map((w) => w.label).join(', ');
  int get quotePaise => quotePaiseFor(level);
  int quotePaiseFor(ServiceLevel service) {
    if (usingPremiumReward &&
        service == ServiceLevel.premium &&
        coverage == WashCoverage.exterior &&
        !monthly)
      return 0;
    if (!monthly) {
      return ((isBike ? 149 : 292) +
              service.index * (isBike ? 50 : 100) +
              (coverage == WashCoverage.exteriorInterior ? 80 : 0)) *
          100;
    }
    // Frequency-priced demo tariff, independent of which weekdays occur in a cycle.
    // These provisional allowances are NOT a four-week service/visit limit.
    final base = (isBike ? 99 : 199) + (isBike ? 66 : 106) * frequency;
    final tierAllowance = frequency * service.index * (isBike ? 40 : 72);
    final interiorAllowance = coverage == WashCoverage.exteriorInterior
        ? frequency * 80
        : 0;
    return (base + tierAllowance + interiorAllowance) * 100;
  }

  String get money => '₹${quotePaise ~/ 100}';
  String get priceUnit => monthly ? '/ month' : '/ wash';
  String get quoteStatus => usingPremiumReward
      ? 'Premium referral reward'
      : monthly &&
            !isBike &&
            level == ServiceLevel.basic &&
            coverage == WashCoverage.exterior &&
            frequency == 3
      ? '₹517 target · not cost-validated'
      : 'Draft price · for design review';
  bool get canChooseTime =>
      !monthly || (weekdays.length == frequency && visits.isNotEmpty);
  bool get canContinue =>
      !monthly ||
      (weekdays.length == frequency &&
          validateWashWindows(timeWindows) == null &&
          visits.isNotEmpty);
  void update(void Function() f) {
    f();
    notifyListeners();
  }

  void setVehicle({required bool bike, required String name}) {
    isBike = bike;
    vehicleName = name;
    if (bike) {
      coverage = WashCoverage.exterior;
      interiorPreview = false;
    }
    notifyListeners();
  }

  PurchaseSelection snapshot() {
    final copy = PurchaseSelection(today: start);
    copy.premiumRewardId = premiumRewardId;
    copy._frequency = _frequency;
    copy.mode = mode;
    copy.level = level;
    copy.coverage = coverage;
    copy.isBike = isBike;
    copy.chosen = chosen;
    copy.confirmed = confirmed;
    copy.autoRenew = autoRenew;
    copy.renewalAuthorityGranted = renewalAuthorityGranted;
    copy.renewalMethod = renewalMethod;
    copy.interiorPreview = interiorPreview;
    copy.vehicleName = vehicleName;
    copy.weekdays = {...weekdays};
    copy.windowStarts = {...windowStarts};
    copy.customWindows = customWindows == null ? null : List.of(customWindows!);
    return copy;
  }

  void reset() {
    premiumRewardId = null;
    _frequency = 3;
    mode = PurchaseMode.once;
    level = ServiceLevel.basic;
    coverage = WashCoverage.exterior;
    chosen = false;
    confirmed = false;
    autoRenew = true;
    renewalAuthorityGranted = false;
    renewalMethod = RenewalMethod.upiAutopay;
    weekdays = {1, 3, 5};
    windowStarts = {8};
    customWindows = null;
    start = dateOnly(DateTime.now());
    notifyListeners();
  }
}
