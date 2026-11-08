import 'package:flutter/material.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../screens/booking.dart';
import '../screens/common.dart';

// v2 CU-WASHCHOICE (8 Nov 2026): the ChatGPT handoff's "Choose your wash" and custom
// time windows, wired into the existing booking steps. When AppStore.washChoiceV2 is
// off these fall back to today's screens, so nothing changes for customers until Ajay
// turns it on (or "Preview new features" is on for this phone).

/// The wash step (route N.washType).
class WashStepScreen extends StatelessWidget {
  const WashStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final t = store.draft.type;
    if (!store.washChoiceV2 || t == null) return const WashTypeScreen();
    final p = store.purchase;
    final bike = t.kind == VehicleKind.bike;
    if (p.isBike != bike || p.vehicleName != t.name) p.setVehicle(bike: bike, name: t.name);
    final editing = store.draft.editing == RepeatEdit.wash || store.washChoiceFromReview;
    return PurchaseChoiceScreen(
      selection: p,
      allowMonthly: store.monthlyPlansLive,
      priceFor: (level, coverage) => store.washPrice(t, level, coverage),
      header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
      continueLabel: editing ? 'Done' : 'Next',
      onBack: router.pop,
      onContinue: () {
        store.set(() {
          final d = store.draft;
          d.serviceLevel = p.level;
          d.coverage = p.coverage;
          d.chosenPrice = store.washPrice(t, p.level, p.coverage);
          d.wash = p.coverage == WashCoverage.exteriorInterior ? WashKind.wetOutsideDryInside : WashKind.wetOutside;
        });
        if (store.washChoiceFromReview) {
          store.washChoiceFromReview = false;
          router.popTo(N.review);
          return;
        }
        if (store.finishRepeatEdit(RepeatEdit.wash)) {
          router.popTo(N.repeatBooking);
          return;
        }
        router.go(store.draft.pickedVehicleId != null && store.draft.plate.isNotEmpty ? N.repeatPhotos : N.vehicleNumber);
      },
    );
  }
}

/// The time step (route N.timeSlot): custom windows, at least 1 hour, 4 AM – 11 PM.
class TimeStepScreen extends StatelessWidget {
  const TimeStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    if (!store.washChoiceV2) return const TimeSlotScreen();
    final s = store.draft.slot;
    final today = DateUtils.dateOnly(DateTime.now());
    return CustomOneTimeScheduleScreen(
      header: const BookingHeader(step: 4, label: 'Time', fraction: 0.8),
      earliest: store.washDayStart,
      latest: store.washDayEnd,
      onBack: router.pop,
      // A slot from an earlier day (Book again) is not reused.
      initialDate: s == null || s.date.isBefore(today) ? null : s.date,
      initialWindows: s == null || s.date.isBefore(today)
          ? null
          : s.minuteWindows.isNotEmpty
          ? [for (final w in s.orderedMinuteWindows) WashTimeWindow(startMinute: w.$1, endMinute: w.$2)]
          : [for (final w in s.windows.isEmpty ? [(s.startHour, s.endHour)] : s.windows) WashTimeWindow(startMinute: w.$1 * 60, endMinute: w.$2 * 60)],
      footnote: store.isLive && !store.customTimesLive ? 'Preview: booking with your own times needs the server update. You can look around; nothing will be charged.' : null,
      onContinue: (date, windows) {
        store.set(() => store.draft.slot = customSlot(date, windows));
        router.go(N.review);
      },
    );
  }
}

/// A booking slot from custom windows. Hours only span the windows (for older readers).
TimeSlot customSlot(DateTime date, List<WashTimeWindow> value) {
  final windows = orderedWashWindows(value);
  return TimeSlot(
    date,
    windows.first.startMinute! ~/ 60,
    (windows.last.endMinute! / 60).ceil(),
    minuteWindows: [for (final w in windows) (w.startMinute!, w.endMinute!)],
  );
}
