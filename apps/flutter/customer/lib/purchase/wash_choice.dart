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
      allowMonthly: true,
      priceFor: (level, coverage) => store.purchasePrice(t, level),
      // 13 Nov (Aman): what the server can't sell yet says "coming soon" here, not at Pay.
      levelAvailable: (l) => l == ServiceLevel.basic || store.washTiersLive || p.usingPremiumReward,
      interiorAvailable: store.interiorLive,
      monthlyAvailable: !store.isLive || store.monthlyPlansLive,
      header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
      continueLabel: editing ? 'Done' : 'Next',
      onBack: router.pop,
      onContinue: () {
        store.set(() {
          final d = store.draft;
          d.serviceLevel = p.level;
          d.coverage = p.coverage;
          d.chosenPrice = store.purchasePrice(t, p.level);
          d.useFreeWash = p.usingPremiumReward;
          d.wash = p.coverage == WashCoverage.exteriorInterior ? WashKind.wetOutsideDryInside : WashKind.wetOutside;
        });
        // Back to the schedule after "Change frequency" on the monthly days screen.
        if (store.purchaseReturningToSchedule) {
          store.purchaseReturningToSchedule = false;
          router.pop();
          return;
        }
        if (store.washChoiceFromReview) {
          store.washChoiceFromReview = false;
          // A monthly plan needs its days and times again; one-time goes straight back.
          if (p.monthly) {
            router.go(N.timeSlot);
          } else {
            router.popTo(N.review);
          }
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
    // v2 phase 2: a monthly plan (or editing the next cycle) picks weekdays and a start
    // date first, then its time windows (N.purchaseTime).
    final plan = store.planEditDraft ?? (store.purchase.monthly ? store.purchase : null);
    if (plan != null) {
      return MonthlyScheduleScreen(
        selection: plan,
        allowStartChange: store.planEditDraft == null,
        onBack: () {
          store.planEditDraft = null;
          router.pop();
        },
        onContinue: () => router.go(N.purchaseTime),
        onChangeFrequency: () {
          if (store.planEditDraft != null) {
            showPlanFrequency(context, plan);
            return;
          }
          store.purchaseReturningToSchedule = true;
          router.go(N.washType);
        },
      );
    }
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
      footnote: null,
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

/// v2 phase 2: days per week for the next cycle (Plan details → Edit next cycle).
Future<void> showPlanFrequency(BuildContext context, PurchaseSelection selection) async {
  var value = selection.frequency;
  final result = await showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Days per week'),
        content: FrequencyPicker(value: value, onChanged: (v) => set(() => value = v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(c, value), child: const Text('Use this frequency')),
        ],
      ),
    ),
  );
  if (result != null) selection.setFrequency(result);
}

/// v2 phase 2: monthly time windows (route N.purchaseTime). Saves the next cycle when
/// editing a plan; otherwise goes on to Check and pay.
class PlanTimeStepScreen extends StatelessWidget {
  const PlanTimeStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final selection = store.planEditDraft ?? store.purchase;
    return MonthlyTimeScreen(
      selection: selection,
      onBack: router.pop,
      continueLabel: store.planEditDraft == null ? 'Next: check and pay' : 'Save for next cycle',
      onContinue: () {
        if (store.planEditDraft != null) {
          final current = store.activePlan ?? store.purchase;
          // A different price needs a fresh AutoPay approval.
          if (selection.quotePaiseFor(selection.level) != current.quotePaiseFor(current.level)) selection.renewalAuthorityGranted = false;
          store.set(() {
            store.nextCyclePlan = selection.snapshot();
            store.planEditDraft = null;
          });
          router.popTo(N.planDetails);
          return;
        }
        final p = store.purchase;
        store.set(() {
          p.chosen = true;
          if (p.firstVisit != null && validateWashWindows(p.timeWindows) == null) {
            store.draft.slot = customSlot(p.firstVisit!, p.timeWindows);
          }
        });
        router.go(N.review);
      },
    );
  }
}

/// v2 phase 2 (preview): what a confirmed plan looks like. Opened from Check and pay's
/// preview link; nothing is paid or sent to a Captain.
class PlanConfirmationStepScreen extends StatelessWidget {
  const PlanConfirmationStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return PurchaseConfirmationScreen(
      selection: store.activePlan ?? store.purchase,
      paid: store.isLive,
      testNote: !store.isLive || !store.lastCheckoutTest ? null : store.lastCheckoutLocal
          ? 'Test plan · no payment taken. A preview on this phone only.'
          : 'Test plan · no payment taken. Each visit is on Bookings.',
      onHome: () {
        router.popToRoot();
        router.tab = 1;
        store.changed();
      },
      // 13 Nov: on live, each paid visit is a booking on the Bookings tab (cancel or track
      // it there); plan editing and AutoPay wait for the server's renewal work.
      onDetails: store.isLive ? () { router.popToRoot(); router.tab = 1; store.changed(); } : () => router.go(N.planDetails),
      onTracking: store.isLive ? () { router.popToRoot(); router.tab = 1; store.changed(); } : () => router.go(N.planDetails),
    );
  }
}

/// v2 phase 2: plan management, also reached from Bookings.
class PlanDetailsStepScreen extends StatelessWidget {
  const PlanDetailsStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final current = store.activePlan ?? store.purchase;
    return PlanDetailsScreen(
      selection: current,
      onBack: router.pop,
      onTracking: () => showVisitDates(context, current),
      nextCycleSelection: store.nextCyclePlan,
      onUpdated: store.changed,
      onAmend: () {
        final draft = (store.nextCyclePlan ?? current).snapshot();
        draft.start = current.endExclusive;
        draft.confirmed = false;
        store.set(() => store.planEditDraft = draft);
        router.go(N.timeSlot);
      },
    );
  }
}

/// Preview only: turns the current monthly choice into a plan on this phone.
void previewMonthlyPlan(AppStore store, AppRouter router) {
  store.set(() {
    store.purchase.confirmed = true;
    store.activePlan = store.purchase.snapshot();
    store.nextCyclePlan = null;
  });
  router.go(N.purchaseConfirmation);
}

