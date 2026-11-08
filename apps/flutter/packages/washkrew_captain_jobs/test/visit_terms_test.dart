import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain_jobs/washkrew_captain_jobs.dart';

void main() {
  test('Recurring estimate sums only the actual planned visits', () {
    const terms = VisitTerms(
      quoteId: 'q',
      policyVersion: 'p',
      kind: VisitBookingKind.monthlyPlan,
      service: 'Basic',
      coverage: 'Exterior',
      estimatedMinutes: 20,
      netPayPaise: 3501,
    );
    final a = RecurringAssignment(
      id: 'p',
      terms: terms,
      dates: [DateTime(2026, 11, 9), DateTime(2026, 11, 11)],
      vehicle: 'Car',
      place: 'Parking',
    );
    expect(a.estimatedCyclePaise, 7002);
  });

  test('server visit quote keeps fractional rupees through roundtrip', () {
    const t = VisitTerms(
      quoteId: 'q1',
      policyVersion: 'p1',
      kind: VisitBookingKind.monthlyPlan,
      service: 'Premium',
      coverage: 'Exterior',
      estimatedMinutes: 20,
      netPayPaise: 3501,
      visitNumber: 3,
      totalVisits: 13,
    );
    final decoded = VisitTerms.fromJson(t.toJson());
    expect(decoded.netPayPaise, 3501);
    expect(decoded.payLabel, '₹35.01');
    expect(decoded.hasConfirmedPay, isTrue);
    expect(
      () => VisitTerms.fromJson({...t.toJson(), 'netPayPaise': 35.1}),
      throwsFormatException,
    );
  });
  test('unknown pay blocks acceptance', () {
    const t = VisitTerms(
      quoteId: '',
      policyVersion: '',
      kind: VisitBookingKind.oneTime,
      service: 'Basic',
      coverage: 'Exterior',
      estimatedMinutes: 20,
      netPayPaise: null,
    );
    expect(t.hasConfirmedPay, isFalse);
  });
}
