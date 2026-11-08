import 'time_windows.dart';
import 'renewals.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'model.dart';

/// Route-agnostic choice screen. Host provides navigation, selected vehicle and state.
class PurchaseChoiceScreen extends StatelessWidget {
  const PurchaseChoiceScreen({
    super.key,
    required this.selection,
    required this.onBack,
    required this.onContinue,
    this.priceFor,
    this.isDraftPrice,
    this.allowMonthly = true,
    this.header,
    this.continueLabel = 'Next',
  });
  final PurchaseSelection selection;
  final VoidCallback onBack, onContinue;

  /// v2 (8 Nov): the host's real price in rupees for a service and coverage, or null
  /// when that option has no approved price yet ("Coming soon"). Null function keeps
  /// the draft fixture prices (previews and tests).
  final num? Function(ServiceLevel level, WashCoverage coverage)? priceFor;

  /// v2: true when the shown price is the handoff's draft (preview only), marked "draft".
  final bool Function(ServiceLevel level)? isDraftPrice;

  /// v2: monthly plans ship in a later phase; the host turns the toggle on.
  final bool allowMonthly;
  final Widget? header;
  final String continueLabel;

  num? _price(PurchaseSelection s, ServiceLevel level) =>
      priceFor == null ? s.quotePaiseFor(level) / 100 : priceFor!(level, s.coverage);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final s = selection;
      if (!allowMonthly && s.monthly) s.mode = PurchaseMode.once;
      final selectedPrice = _price(s, s.level);
      String rupees(num v) => v == v.roundToDouble() ? '₹${v.round()}' : '₹${v.toStringAsFixed(2)}';
      return WScreen(
        header: header ?? WAppBar(title: 'Book a wash', onLeading: onBack),
        footer: WFooterBar(
          showCall: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: WText('Total', WType.caption)),
                  WText(
                    selectedPrice == null ? 'Coming soon' : '${rupees(selectedPrice)} ${s.priceUnit}',
                    WType.valueStrong,
                  ),
                ],
              ),
              const Gap(10),
              WButton(
                continueLabel,
                enabled: selectedPrice != null,
                onTap: () {
                  s.update(() => s.chosen = true);
                  onContinue();
                },
              ),
            ],
          ),
        ),
        children: [
          const WTitleBlock('Choose your wash'),
          Align(
            alignment: Alignment.centerLeft,
            child: WBadge(
              s.vehicleName,
              icon: s.isBike ? WIcon.bike : WIcon.car,
            ),
          ),
          const Gap(18),
          if (s.usingPremiumReward) ...[
            const WBadge('Free Premium wash', icon: WIcon.gift, tone: Tone.ok),
            const Gap(12),
          ],
          if (!s.usingPremiumReward && allowMonthly)
            WSegmented(
              height: 52,
              options: const ['One-time', 'Monthly plan'],
              selection: s.monthly ? 1 : 0,
              onChanged: (i) => s.update(() => s.mode = PurchaseMode.values[i]),
            ),
          if (s.monthly) ...[
            const Gap(16),
            const WText('Days per week', WType.title),
            const Gap(8),
            FrequencyPicker(value: s.frequency, onChanged: s.setFrequency),
          ],
          if (!s.isBike && !s.usingPremiumReward) ...[
            const Gap(18),
            WFlow(
              spacing: 8,
              children: [
                WChip(
                  'Exterior only',
                  height: 48,
                  selected: s.coverage == WashCoverage.exterior,
                  onTap: () =>
                      s.update(() => s.coverage = WashCoverage.exterior),
                ),
                WChip(
                  'Exterior + interior',
                  height: 48,
                  selected: s.coverage == WashCoverage.exteriorInterior,
                  onTap: () => s.update(() {
                    s.coverage = WashCoverage.exteriorInterior;
                    s.interiorPreview = true;
                  }),
                ),
              ],
            ),
          ],
          const Gap(20),
          for (final level in ServiceLevel.values.where(
            (l) => !s.usingPremiumReward || l == ServiceLevel.premium,
          )) ...[
            // v2: an option without an approved price stays visible but can't be picked.
            Builder(builder: (context) {
              final price = _price(s, level);
              return Opacity(
                opacity: price == null ? 0.55 : 1,
                child: WSelectionTile(
                  title: level.label,
                  subtitle: switch (level) {
                    ServiceLevel.basic => 'Body, glass & wheels',
                    ServiceLevel.premium => 'Extra wheel & trim care',
                    ServiceLevel.extraPremium => 'Added protective finish',
                  },
                  trailing: price == null ? 'Coming soon' : '${rupees(price)}${isDraftPrice?.call(level) == true ? ' · draft' : ''}',
                  selected: s.level == level,
                  icon: level == ServiceLevel.basic ? WIcon.drop : WIcon.sparkle,
                  onTap: price == null ? null : () => s.update(() => s.level = level),
                ),
              );
            }),
            const Gap(10),
          ],
          const Gap(6),
          WLink(
            'What’s included?',
            onTap: () => showWSheet<void>(
              context,
              height: 410,
              builder: (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WText('${s.level.label} clean', WType.screen),
                    const Gap(12),
                    WText(s.level.detail, WType.bodyStrong),
                    const Gap(12),
                    WText(
                      s.coverage == WashCoverage.exteriorInterior
                          ? 'Interior preview includes a basic vacuum and accessible-surface wipe; not shampooing or stain extraction.'
                          : 'Exterior cleaning covers the body, outside glass, mirrors and wheel faces.',
                      WType.body,
                    ),
                    const Gap(16),
                    const WText(
                      'Draft service checklist. One-time and monthly visits use the same selected service.',
                      WType.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class FrequencyPicker extends StatelessWidget {
  const FrequencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => WCard(
    outlined: true,
    padding: 12,
    radius: 16,
    child: Row(
      children: [
        Semantics(
          enabled: value > 1,
          child: Opacity(
            opacity: value > 1 ? 1 : .35,
            child: WIconButton(
              WIcon.minus,
              style: IconButtonStyle.tint,
              label: 'Fewer days per week',
              onTap: value > 1 ? () => onChanged(value - 1) : null,
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: WText(
              value == 7
                  ? 'Every day'
                  : '$value ${value == 1 ? 'day' : 'days'} a week',
              WType.valueStrong,
              align: TextAlign.center,
            ),
          ),
        ),
        Semantics(
          enabled: value < 7,
          child: Opacity(
            opacity: value < 7 ? 1 : .35,
            child: WIconButton(
              WIcon.plus,
              style: IconButtonStyle.tint,
              label: 'More days per week',
              onTap: value < 7 ? () => onChanged(value + 1) : null,
            ),
          ),
        ),
      ],
    ),
  );
}

class MonthlyScheduleScreen extends StatelessWidget {
  const MonthlyScheduleScreen({
    super.key,
    required this.selection,
    required this.onBack,
    required this.onContinue,
    this.onChangeFrequency,
    this.allowStartChange = true,
  });
  final PurchaseSelection selection;
  final bool allowStartChange;
  final VoidCallback onBack, onContinue;
  final VoidCallback? onChangeFrequency;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final s = selection;
      return WScreen(
        header: WAppBar(title: 'Choose days', onLeading: onBack),
        footer: WFooterBar(
          showCall: false,
          child: WButton(
            'Next: choose time',
            enabled: s.canChooseTime,
            onTap: onContinue,
          ),
        ),
        children: [
          WTitleBlock(
            'Pick your ${s.frequency} ${s.frequency == 1 ? 'day' : 'days'}',
            subtitle:
                'Choose the weekdays when your vehicle is usually parked and free.',
          ),
          WCard(
            outlined: true,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WText(s.frequencyLabel, WType.title),
                      const Gap(4),
                      WText('${s.money} / month', WType.bodyStrong),
                    ],
                  ),
                ),
                if (onChangeFrequency != null)
                  WLink('Change frequency', onTap: onChangeFrequency),
              ],
            ),
          ),
          const Gap(16),
          WFlow(
            spacing: 8,
            children: [
              for (final d in [1, 2, 3, 4, 5, 6, 7])
                WChip(
                  weekdayLabel(d),
                  height: 48,
                  checkbox: true,
                  selected: s.weekdays.contains(d),
                  onTap: () => s.update(() {
                    if (!s.weekdays.remove(d)) s.weekdays.add(d);
                  }),
                ),
            ],
          ),
          const Gap(14),
          WText(
            '${s.weekdays.length} of ${s.frequency} days selected',
            WType.caption,
            color: s.weekdays.length == s.frequency
                ? WColor.secondary
                : WColor.destructive,
          ),
          const Gap(20),
          WCard(
            outlined: true,
            child: Row(
              children: [
                const WIconBox(WIcon.calendar, size: 42),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WText(
                        allowStartChange ? 'Plan starts' : 'Next cycle starts',
                        WType.caption,
                      ),
                      WText(shortDate(s.start), WType.title),
                    ],
                  ),
                ),
                if (allowStartChange)
                  WLink(
                    'Change',
                    onTap: () async {
                      final today = dateOnly(DateTime.now());
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: s.start.isBefore(today) ? today : s.start,
                        firstDate: today,
                        lastDate: DateTime(
                          today.year + 1,
                          today.month,
                          today.day,
                        ),
                      );
                      if (picked != null)
                        s.update(() => s.start = dateOnly(picked));
                    },
                  ),
              ],
            ),
          ),
          if (!s.canChooseTime) ...[
            const Gap(14),
            WText(
              'Choose exactly ${s.frequency} ${s.frequency == 1 ? 'day' : 'days'} to continue.',
              WType.caption,
              color: WColor.destructive,
            ),
          ],
        ],
      );
    },
  );
}

/// Second scheduling step; reads the same selection without resetting weekdays.
class MonthlyTimeScreen extends StatelessWidget {
  const MonthlyTimeScreen({
    super.key,
    required this.selection,
    required this.onBack,
    required this.onContinue,
    this.continueLabel = 'Next: check and pay',
  });
  final PurchaseSelection selection;
  final String continueLabel;
  final VoidCallback onBack, onContinue;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final s = selection;
      return WScreen(
        header: WAppBar(title: 'Choose time', onLeading: onBack),
        footer: WFooterBar(
          showCall: false,
          child: WButton(
            continueLabel,
            enabled: s.canContinue,
            onTap: onContinue,
          ),
        ),
        children: [
          const WTitleBlock(
            'When is your vehicle free?',
            subtitle: 'Choose the time slots that work on every selected day.',
          ),
          WCard(
            outlined: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WText(s.frequencyLabel, WType.title),
                const Gap(6),
                WText(
                  (s.weekdays.toList()..sort()).map(weekdayLabel).join(', '),
                  WType.bodyStrong,
                ),
                const Gap(4),
                WText(
                  'Starts ${shortDate(s.start)} · ${s.money} / month',
                  WType.caption,
                ),
              ],
            ),
          ),
          const Gap(20),
          CustomTimeWindowEditor(
            windows: s.timeWindows,
            onChanged: (value) => s.update(() => s.customWindows = value),
          ),
          const Gap(16),
          const WText(
            'Availability is simulated in this preview. You’ll review all your choices on the next screen.',
            WType.caption,
          ),
        ],
      );
    },
  );
}

/// Bounded, scrollable policy dialog with bundled typography and a fixed exit.
Future<void> showPlanPolicyPreview(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  builder: (c) => Dialog(
    backgroundColor: WColor.white,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 390,
        maxHeight: MediaQuery.sizeOf(c).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: WText('Plan policy preview', WType.section),
                ),
                WIconButton(
                  WIcon.close,
                  size: 48,
                  label: 'Close policy preview',
                  onTap: () => Navigator.of(c).pop(),
                ),
              ],
            ),
            const Gap(12),
            const Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WText('Renewal & cancellation', WType.title),
                    Gap(12),
                    WText(
                      'UPI AutoPay is recommended. Each monthly cycle is prepaid and renews until you cancel.',
                      WType.body,
                    ),
                    Gap(14),
                    WText(
                      'Cancel renewal anytime to stop the next cycle. The current cycle is already paid: its refund is ₹0 and its washes remain scheduled. This preview does not take payment.',
                      WType.body,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(20),
            WButton('Got it', onTap: () => Navigator.of(c).pop()),
          ],
        ),
      ),
    ),
  ),
);

class PurchaseSummaryCard extends StatelessWidget {
  const PurchaseSummaryCard({
    super.key,
    required this.selection,
    this.onDates,
    this.onChange,
    this.scheduleLabel,
    this.showQuoteStatus = true,
  });
  final String? scheduleLabel;
  final bool showQuoteStatus;
  final PurchaseSelection selection;
  final VoidCallback? onDates, onChange;
  @override
  Widget build(BuildContext context) {
    final s = selection;
    return WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: WText(
                  s.monthly ? 'Monthly plan' : 'One-time wash',
                  WType.title,
                ),
              ),
              if (onChange != null) WLink('Change', onTap: onChange),
            ],
          ),
          const Gap(6),
          WText(s.serviceLabel, WType.bodyStrong),
          if (s.monthly) ...[
            const Gap(10),
            WText(
              '${s.frequencyLabel}${s.weekdays.length == s.frequency ? ' · ${s.visits.length} visits' : ''}',
              WType.valueStrong,
            ),
            const Gap(4),
            WText(scheduleLabel ?? s.daysLabel, WType.caption),
            WText(s.cycleLabel, WType.caption),
            if (onDates != null) ...[
              const Gap(8),
              WLink('See all ${s.visits.length} dates', onTap: onDates),
            ],
          ],
          if (!s.monthly && scheduleLabel != null) ...[
            const Gap(10),
            WText(scheduleLabel!, WType.body),
          ],
          if (showQuoteStatus) ...[
            const Gap(10),
            WText(s.quoteStatus, WType.small),
          ],
        ],
      ),
    );
  }
}

void showVisitDates(BuildContext context, PurchaseSelection s) =>
    showWSheet<void>(
      context,
      height: 570,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children:[Expanded(child:WText('${s.visits.length} planned visits', WType.screen)),WIconButton(WIcon.close,size:48,label:'Close calendar',onTap:()=>Navigator.of(sheetContext).pop())]),
          const Gap(8),
          WText('${s.cycleLabel} · ${s.daysLabel}', WType.caption),
          const Gap(6),
          WText(s.windowLabel,WType.caption),
          const Gap(14),
          for (final d in s.visits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const WIconView(WIcon.calendar, size: 18),
                  const Gap(12),
                  WText(
                    '${weekdayLabel(d.weekday)}, ${shortDate(d)}',
                    WType.bodyStrong,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

class DemoCheckoutScreen extends StatelessWidget {
  const DemoCheckoutScreen({
    super.key,
    required this.selection,
    required this.onBack,
    required this.onSuccess,
    required this.onFailure,
  });
  final PurchaseSelection selection;
  final VoidCallback onBack, onSuccess, onFailure;
  @override
  Widget build(BuildContext context) => WScreen(
    header: WAppBar(title: 'Demo checkout', onLeading: onBack),
    footer: WFooterBar(
      showCall: false,
      child: WButton(
        selection.usingPremiumReward
            ? 'Confirm free Premium wash'
            : selection.monthly &&
                  selection.renewalMethod != RenewalMethod.invoice
            ? 'Simulate payment & approve mandate · ${selection.money}'
            : 'Simulate payment · ${selection.money}',
        onTap: onSuccess,
      ),
    ),
    children: [
      const WTitleBlock(
        'Try the final step',
        subtitle: 'No money moves. No booking is sent to a Captain.',
      ),
      PurchaseSummaryCard(selection: selection),
      const Gap(20),
      WCard(
        child: Row(
          children: [
            const Expanded(child: WText('Demo total', WType.title)),
            WText(selection.money, WType.section),
          ],
        ),
      ),
      const Gap(16),
      const WText(
        'This separate demo does not open Razorpay or use your wallet. Prices, service scope and monthly policies are for review.',
        WType.body,
      ),
      const Gap(16),
      if (!selection.usingPremiumReward)
        WLink('Try a failed payment', onTap: onFailure),
    ],
  );
}

class PurchaseConfirmationScreen extends StatelessWidget {
  const PurchaseConfirmationScreen({
    super.key,
    required this.selection,
    required this.onHome,
    required this.onDetails,
    required this.onTracking,
  });
  final PurchaseSelection selection;
  final VoidCallback onHome, onDetails, onTracking;
  @override
  Widget build(BuildContext context) {
    final s = selection;
    return WScreen(
      header: WAppBar(title: 'Design preview', leading: null),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          s.monthly ? 'View your plan' : 'View wash progress',
          onTap: s.monthly ? onDetails : onTracking,
        ),
      ),
      children: [
        const Gap(14),
        const Center(child: WStateCircle(WIcon.check, tone: Tone.ok)),
        const Gap(20),
        WTitleBlock(
          s.monthly ? 'Your routine is ready' : 'Your wash is booked',
          subtitle:
              'Demo confirmation only. No real booking or payment was made.',
        ),
        PurchaseSummaryCard(
          selection: s,
          onDates: s.monthly ? () => showVisitDates(context, s) : null,
        ),
        const Gap(20),
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WText('What happens next?', WType.title),
              const Gap(6),
              WText(
                s.monthly
                    ? 'Your first preview visit is ${s.firstVisit == null ? 'not selected' : shortDate(s.firstVisit!)}. Each wash follows the same selected checklist.'
                    : 'Follow the existing Captain, photo-review and approval screens using sample data.',
                WType.body,
              ),
            ],
          ),
        ),
        const Gap(18),
        WLink('Back to home', onTap: onHome),
      ],
    );
  }
}

class PlanDetailsScreen extends StatelessWidget {
  const PlanDetailsScreen({
    super.key,
    required this.selection,
    required this.onBack,
    required this.onTracking,
    this.nextCycleSelection,
    this.onAmend,
    this.onUpdated,
  });
  final PurchaseSelection selection;
  final PurchaseSelection? nextCycleSelection;
  final VoidCallback onBack, onTracking;
  final VoidCallback? onAmend, onUpdated;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) => WScreen(
      header: WAppBar(title: 'Your monthly plan', onLeading: onBack),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'View current calendar',
          onTap: () => showVisitDates(context, selection),
        ),
      ),
      children: [
        WBadge(
          selection.autoRenew
              ? 'Current cycle paid'
              : 'Cancelled · Paid visits remain',
          icon: WIcon.calendar,
        ),
        const Gap(16),
        PurchaseSummaryCard(
          selection: selection,
          showQuoteStatus: false,
          scheduleLabel: '${selection.daysLabel} · ${selection.windowLabel}',
        ),
        const Gap(16),
        RenewalManageCard(
          selection: selection,
          nextCycleSelection: nextCycleSelection,
          onChanged: onUpdated,
        ),
        const Gap(16),
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WText('Next cycle schedule', WType.title),
              const Gap(8),
              if (nextCycleSelection == null)
                const WText(
                  'Your current preferences will continue unless you change them.',
                  WType.body,
                )
              else ...[
                WText(
                  '${nextCycleSelection!.frequencyLabel} · ${nextCycleSelection!.daysLabel}',
                  WType.bodyStrong,
                ),
                const Gap(6),
                WText(nextCycleSelection!.windowLabel, WType.body),
                const Gap(6),
                WText(
                  'From ${shortDate(nextCycleSelection!.start)} · ${nextCycleSelection!.money} / month',
                  WType.caption,
                ),
              ],
              const Gap(12),
              WButton(
                'Edit next cycle',
                kind: ButtonKind.outline,
                enabled: onAmend != null,
                onTap: onAmend,
              ),
              const Gap(10),
              WText(
                selection.autoRenew
                    ? 'Changes apply to the next cycle. Your already-paid visits stay unchanged.'
                    : 'Saved preferences won’t restart a cancelled subscription.',
                WType.caption,
              ),
            ],
          ),
        ),
        const Gap(20),
        WLink('Preview a visit', onTap: onTracking),
        const Gap(12),
        const WText(
          'Local preview only. Billing, schedule availability and refunds are not connected to live services.',
          WType.caption,
        ),
      ],
    ),
  );
}
