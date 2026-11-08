enum VisitBookingKind { oneTime, monthlyPlan }

enum CaptainLanguage { en, hi, te }

/// Server-supplied immutable terms for ONE visit. Customer plan price is
/// deliberately absent. Never calculate Captain pay as a customer percentage.
class VisitTerms {
  const VisitTerms({
    required this.quoteId,
    required this.policyVersion,
    required this.kind,
    required this.service,
    required this.coverage,
    required this.estimatedMinutes,
    required this.netPayPaise,
    this.visitNumber,
    this.totalVisits,
    this.illustrative = false,
  });
  final String quoteId, policyVersion, service, coverage;
  final VisitBookingKind kind;
  final int estimatedMinutes;
  final int? netPayPaise, visitNumber, totalVisits;
  final bool illustrative;
  bool get hasConfirmedPay =>
      quoteId.isNotEmpty &&
      policyVersion.isNotEmpty &&
      netPayPaise != null &&
      netPayPaise! > 0;
  String get payLabel => netPayPaise == null
      ? '—'
      : '₹${netPayPaise! % 100 == 0 ? netPayPaise! ~/ 100 : (netPayPaise! / 100).toStringAsFixed(2)}';
  Map<String, Object?> toJson() => {
    'quoteId': quoteId,
    'policyVersion': policyVersion,
    'bookingKind': kind.name,
    'service': service,
    'coverage': coverage,
    'estimatedMinutes': estimatedMinutes,
    'netPayPaise': netPayPaise,
    'visitNumber': visitNumber,
    'totalVisits': totalVisits,
  };
  factory VisitTerms.fromJson(Map<String, dynamic> json) {
    final pay = json['netPayPaise'];
    if (pay != null && (pay is! int || pay < 0))
      throw const FormatException('netPayPaise must be integer paise');
    final mins = json['estimatedMinutes'];
    if (mins is! int || mins <= 0)
      throw const FormatException('estimatedMinutes must be positive');
    final kind = VisitBookingKind.values.byName(json['bookingKind'] as String);
    return VisitTerms(
      quoteId: json['quoteId'] as String,
      policyVersion: json['policyVersion'] as String,
      kind: kind,
      service: json['service'] as String,
      coverage: json['coverage'] as String,
      estimatedMinutes: mins,
      netPayPaise: pay as int?,
      visitNumber: json['visitNumber'] as int?,
      totalVisits: json['totalVisits'] as int?,
    );
  }
}

class CaptainJobCopy {
  const CaptainJobCopy(this.language);
  final CaptainLanguage language;
  String t(String en, String hi, String te) => switch (language) {
    CaptainLanguage.en => en,
    CaptainLanguage.hi => hi,
    CaptainLanguage.te => te,
  };
  String booking(VisitBookingKind kind) => kind == VisitBookingKind.oneTime
      ? t('One-time wash', 'एक बार का वॉश', 'ఒక్కసారి వాష్')
      : t('Monthly-plan visit', 'महीने के प्लान का वॉश', 'నెలవారీ ప్లాన్ వాష్');
  String get yourPay =>
      t('You earn for this wash', 'इस वॉश की आपकी कमाई', 'ఈ వాష్‌కు మీ ఆదాయం');
  String get listen => t('Listen', 'सुनें', 'వినండి');
}
