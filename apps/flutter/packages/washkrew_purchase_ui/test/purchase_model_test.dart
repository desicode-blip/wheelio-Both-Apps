import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

void main() {
  test(
    'Owner car one-time anchors keep coverage separate from service tier',
    () {
      final p = PurchaseSelection(today: DateTime(2026, 11, 6));
      expect(p.quotePaise, 29200);
      p.coverage = WashCoverage.exteriorInterior;
      expect(p.quotePaise, 37200);
      p.level = ServiceLevel.premium;
      expect(p.coverage, WashCoverage.exteriorInterior);
      expect(p.quotePaise, greaterThan(37200));
    },
  );
  test('Monthly dates are real calendar weekdays, not four assumed weeks', () {
    final p = PurchaseSelection(today: DateTime(2026, 11, 6))
      ..mode = PurchaseMode.monthly;
    expect(p.quotePaise, 51700);
    expect(p.visits.length, 13);
    expect(p.visits.every((d) => [1, 3, 5].contains(d.weekday)), isTrue);
    expect(p.visits.first, DateTime(2026, 11, 6));
    expect(p.visits.last.isBefore(p.endExclusive), isTrue);
  });
  test(
    'Daily covers every day once and end-of-month anniversary is clamped',
    () {
      final p = PurchaseSelection(today: DateTime(2027, 1, 31))
        ..mode = PurchaseMode.monthly
        ..setFrequency(7);
      expect(p.endExclusive, DateTime(2027, 2, 28));
      expect(p.visits.length, 28);
      expect(p.visits.toSet().length, 28);
    },
  );
  test('No days or no time windows cannot advance to payment', () {
    final p = PurchaseSelection()..mode = PurchaseMode.monthly;
    p.weekdays = {};
    expect(p.canContinue, isFalse);
    expect(p.quotePaise, 51700);
    p.setFrequency(1);
    p.weekdays = {2};
    p.windowStarts = {};
    expect(p.canContinue, isFalse);
    p.windowStarts = {8};
    expect(p.canContinue, isTrue);
  });
  test(
    'Vehicle change removes incompatible interior without losing monthly choices',
    () {
      final p = PurchaseSelection()
        ..mode = PurchaseMode.monthly
        ..level = ServiceLevel.extraPremium
        ..coverage = WashCoverage.exteriorInterior
        ..weekdays = {2, 4};
      p.setVehicle(bike: true, name: 'Bike or scooter');
      expect(p.coverage, WashCoverage.exterior);
      expect(p.mode, PurchaseMode.monthly);
      expect(p.level, ServiceLevel.extraPremium);
      expect(p.weekdays, {2, 4});
    },
  );
  test('Switching booking mode retains selected checklist and coverage', () {
    final p = PurchaseSelection()
      ..level = ServiceLevel.premium
      ..coverage = WashCoverage.exteriorInterior;
    final label = p.serviceLabel;
    p.mode = PurchaseMode.monthly;
    expect(p.serviceLabel, label);
    p.mode = PurchaseMode.once;
    expect(p.serviceLabel, label);
  });
  test(
    'Activated plan snapshot survives a fresh draft and keeps its own dates',
    () {
      final draft = PurchaseSelection(today: DateTime(2026, 11, 6))
        ..mode = PurchaseMode.monthly
        ..confirmed = true;
      final active = draft.snapshot();
      final visits = active.visits;
      draft.reset();
      expect(active.monthly, isTrue);
      expect(active.confirmed, isTrue);
      expect(active.visits, visits);
      expect(active.quotePaise, 51700);
      expect(draft.monthly, isFalse);
    },
  );
  test(
    'Frequency reprices every service without mutating the selected service',
    () {
      final p = PurchaseSelection(today: DateTime(2026, 11, 6))
        ..mode = PurchaseMode.monthly;
      final before = [
        for (final level in ServiceLevel.values) p.quotePaiseFor(level),
      ];
      p.setFrequency(4);
      expect(p.quotePaise, 62300);
      for (final level in ServiceLevel.values)
        expect(p.quotePaiseFor(level), greaterThan(before[level.index]));
      expect(p.level, ServiceLevel.basic);
      expect(p.weekdays.length, 4);
      p.setFrequency(3);
      expect(p.quotePaise, 51700);
    },
  );
  test(
    'Weekday and date selection never silently reprice the chosen frequency',
    () {
      final p = PurchaseSelection(today: DateTime(2026, 11, 6))
        ..mode = PurchaseMode.monthly
        ..level = ServiceLevel.extraPremium
        ..coverage = WashCoverage.exteriorInterior;
      final amount = p.quotePaise;
      p.weekdays = {2, 4};
      expect(p.canContinue, isFalse);
      expect(p.quotePaise, amount);
      p.weekdays = {2, 4, 6};
      expect(p.canContinue, isTrue);
      expect(p.quotePaise, amount);
      p.start = DateTime(2027, 2, 1);
      expect(p.quotePaise, amount);
      expect(p.snapshot().frequency, 3);
    },
  );
  test(
    'Frequency is constrained to 1 through 7 and one-time price is independent',
    () {
      final p = PurchaseSelection();
      expect(() => p.setFrequency(0), throwsRangeError);
      expect(() => p.setFrequency(8), throwsRangeError);
      p.setFrequency(7);
      expect(p.quotePaise, 29200);
      p.mode = PurchaseMode.monthly;
      expect(p.frequency, 7);
      expect(p.weekdays.length, 7);
    },
  );
}
