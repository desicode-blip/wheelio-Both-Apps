import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'model.dart';

/// A recurring assignment is a calendar commitment, never a salary promise.
class RecurringAssignment {
  const RecurringAssignment({
    required this.id,
    required this.terms,
    required this.dates,
    required this.vehicle,
    required this.place,
  });
  final String id, vehicle, place;
  final VisitTerms terms;
  final List<DateTime> dates;
  int get estimatedCyclePaise => (terms.netPayPaise ?? 0) * dates.length;
}

class RecurringAssignmentScreen extends StatelessWidget {
  const RecurringAssignmentScreen({
    super.key,
    required this.assignment,
    required this.accepted,
    required this.onAccept,
    required this.onBack,
    required this.onCalendar,
  });
  final RecurringAssignment assignment;
  final bool accepted;
  final VoidCallback onAccept, onBack, onCalendar;
  @override
  Widget build(BuildContext context) {
    final a = assignment;
    return WScreen(
      gutter: 16,
      header: WAppBar(
        title: accepted ? 'Your recurring assignment' : 'Recurring assignment',
        onLeading: onBack,
      ),
      footer: WFooterBar(
        captain: true,
        showCall: false,
        child: WButton(
          accepted ? 'See today’s jobs' : 'Accept recurring assignment',
          size: ButtonSize.captain,
            kind:accepted?ButtonKind.primary:ButtonKind.success,
          enabled: a.terms.hasConfirmedPay,
          onTap: accepted ? onCalendar : onAccept,
        ),
      ),
      children: [
        WTitleBlock(
          accepted ? 'Added to your calendar' : 'Regular work. Planned ahead.',
          subtitle: accepted
              ? 'Open Jobs each day and follow that day’s assigned visits.'
              : 'Review the complete calendar before committing.',
        ),
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(a.vehicle, WType.title),
              const Gap(6),
              WText(a.place, WType.body),
              const Gap(6),
              WText(a.terms.service + ' · ' + a.terms.coverage, WType.caption),
            ],
          ),
        ),
        const Gap(16),
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText('${a.terms.payLabel} per completed visit', WType.section),
              const Gap(8),
              WText(
                '${a.dates.length} planned visits · ₹${(a.estimatedCyclePaise / 100).toStringAsFixed(a.estimatedCyclePaise % 100 == 0 ? 0 : 2)} estimated this cycle',
                WType.bodyStrong,
              ),
              const Gap(8),
              const WText(
                'Estimated from planned visits, not a fixed salary. Cancelled or unperformed visits are settled under their own policy.',
                WType.caption,
              ),
              if (a.terms.illustrative) ...[
                const Gap(10),
                const WText(
                  'Example pay · Rates still need approval',
                  WType.caption,
                ),
              ],
            ],
          ),
        ),
        const Gap(20),
        const WText('Your planned dates', WType.section),
        const Gap(8),
        for (final date in a.dates)
          WListRow(
            icon: WIcon.calendar,
            chevron: false,
            title: Fmt.date(date),
            subtitle:
                '${Fmt.window(8, 10)} · About ${a.terms.estimatedMinutes} min',
          ),
        const Gap(16),
        const WText(
          'Each day’s job keeps the same simple flow: travel, before photos, wash, after photos and customer approval. You do not need to accept the whole project again each day.',
          WType.body,
        ),
        const Gap(12),
        const WText(
          'If you cannot do one visit, request help for that visit. We try a replacement Captain, then a customer-confirmed make-up day. Your other assigned visits stay on the calendar.',
          WType.caption,
        ),
      ],
    );
  }
}
