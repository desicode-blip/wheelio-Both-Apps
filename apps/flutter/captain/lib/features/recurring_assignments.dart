import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';
import 'monthly_jobs.dart';

// v2 (13 Nov 2026, Aman): the Captain's accepted monthly jobs. Gold throughout, like a
// golden ticket. List → detail: the monthly package, weekday circles, dates, and Cancel
// (at least 2 days ahead: visits in the next 2 days stay with the Captain).

String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2)}';

const _goldSky = [Color(0xFFFFF8E6), Color(0xFFFFE7A6)];

/// M T W T F S S in circles; the visit days are filled gold.
class WeekdayCircles extends StatelessWidget {
  const WeekdayCircles({super.key, required this.dates, this.size = 36});
  final List<DateTime> dates;
  final double size;
  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'], names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final on = {for (final d in dates) d.weekday};
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Semantics(
            label: '${names[i]}${on.contains(i + 1) ? ', visit day' : ''}',
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on.contains(i + 1) ? gold : WColor.white,
                border: Border.all(color: on.contains(i + 1) ? gold : goldBorder, width: 1.5),
              ),
              child: WText(letters[i], WType.label, size: size * 0.38, color: on.contains(i + 1) ? WColor.white : WColor.muted),
            ),
          ),
      ],
    );
  }
}

/// The small gold "Recurring" tag on job cards.
class RecurringTag extends StatelessWidget {
  const RecurringTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const WIconView(WIcon.calendar, size: 11, color: WColor.white),
      const SizedBox(width: 4),
      WText(context.store.t('Recurring', 'नियमित', 'క్రమమైన'), WType.small, color: WColor.white, weight: FontWeight.w600),
    ]),
  );
}

/// The quiet "One-time" tag on job cards.
class OneTimeTag extends StatelessWidget {
  const OneTimeTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(6)),
    child: WText(context.store.t('One-time', 'एक बार', 'ఒక్కసారి'), WType.small, color: WColor.primaryStrong, weight: FontWeight.w600),
  );
}

String _nextVisit(CaptainStore store, MonthlyOffer o) {
  final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
  final next = o.assignment.dates.where((d) => !d.isBefore(today)).firstOrNull;
  if (next == null) return store.t('No visits left this month', 'इस महीने कोई विज़िट नहीं बची', 'ఈ నెల విజిట్లు లేవు');
  final label = next == today ? store.t('Today', 'आज', 'ఈరోజు') : next.difference(today).inDays == 1 ? store.t('Tomorrow', 'कल', 'రేపు') : Fmt.date(next);
  return '${store.t('Next visit', 'अगली विज़िट', 'తదుపరి విజిట్')}: $label${o.window.isEmpty ? '' : ' · ${o.window}'}';
}

/// Jobs tab / Me → Recurring assignments.
class RecurringListScreen extends StatelessWidget {
  const RecurringListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router, mine = store.myAssignments;
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WAppBar(title: store.t('Recurring assignments', 'नियमित काम', 'క్రమమైన పనులు'), onLeading: router.pop, padding: const EdgeInsets.fromLTRB(4, 4, 4, 0)),
      children: [
        const SizedBox(height: 8),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              const WStateCircle(WIcon.calendar, size: 80),
              const SizedBox(height: 12),
              WText(store.t('No recurring jobs yet', 'अभी कोई नियमित काम नहीं', 'ఇంకా క్రమమైన పనులు లేవు'), WType.section, weight: FontWeight.w600),
              const SizedBox(height: 16),
              WButton(store.t('See monthly jobs', 'मासिक काम देखें', 'నెలవారీ పనులు చూడండి'), kind: ButtonKind.outline, size: ButtonSize.captain, onTap: () => router.push(const R(N.openJobs, flag: true))),
            ]),
          ),
        for (final o in mine) ...[
          Pressable(
            label: o.assignment.place,
            onTap: () {
              store.set(() => store.openAssignmentId = o.id);
              router.push(const R(N.recurringAssignment));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: _goldSky, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), border: Border.all(color: goldBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: WText(o.assignment.place, WType.title, maxLines: 2)),
                  const WIconView(WIcon.chevron, size: 13, color: goldDeep),
                ]),
                const SizedBox(height: 4),
                WText(o.assignment.vehicle, WType.caption, color: goldDeep),
                const SizedBox(height: 12),
                WeekdayCircles(dates: o.assignment.dates, size: 30),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: WText(_nextVisit(store, o), WType.caption, color: WColor.heading)),
                  WText(_rupees(o.estimatePaise), WType.title, mono: true),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One accepted assignment: the monthly package, days, dates, and Cancel.
class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({super.key});
  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  bool allDates = false, cancelling = false;

  Future<void> _cancel(MonthlyOffer o) async {
    final store = context.store, router = context.router;
    final kept = store.keptAfterCancel(o);
    final next = DateTime.now().add(const Duration(days: 2));
    var go = false;
    await showWAlert(
      context,
      title: store.t('Cancel this recurring job?', 'यह नियमित काम रद्द करें?', 'ఈ క్రమమైన పని రద్దు చేయాలా?'),
      message: [
        store.t('Cancel at least 2 days ahead.', 'कम से कम 2 दिन पहले रद्द करें।', 'కనీసం 2 రోజుల ముందు రద్దు చేయండి.'),
        if (kept.isNotEmpty) store.t('You still do: ${kept.map(Fmt.date).join(', ')}.', 'ये विज़िट आप ही करेंगे: ${kept.map(Fmt.date).join(', ')}।', 'ఇవి మీరే చేయాలి: ${kept.map(Fmt.date).join(', ')}.'),
        store.t('From ${Fmt.date(next)}, visits go to other Captains.', '${Fmt.date(next)} से विज़िट दूसरे कैप्टन को जाएंगी।', '${Fmt.date(next)} నుండి విజిట్లు ఇతర కెప్టెన్లకు వెళ్తాయి.'),
      ].join('\n\n'),
      actions: [
        AlertAction(store.t('Keep it', 'रखें', 'ఉంచండి'), cancel: true),
        AlertAction(store.t('Cancel job', 'काम रद्द करें', 'పని రద్దు'), destructive: true, onTap: () => go = true),
      ],
    );
    if (!go || !mounted) return;
    setState(() => cancelling = true);
    final error = await store.cancelAssignment(o);
    if (!mounted) return;
    setState(() => cancelling = false);
    store.set(() => store.toast = error ?? store.t('Recurring job cancelled', 'नियमित काम रद्द हुआ', 'క్రమమైన పని రద్దైంది'));
    if (error == null) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router, o = store.openAssignment;
    if (o == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? router.pop() : null);
      return const ColoredBox(color: WColor.white);
    }
    final a = o.assignment;
    final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
    final upcoming = a.dates.where((d) => !d.isBefore(today)).toList();
    final shown = allDates ? upcoming : upcoming.take(6).toList();
    Widget note(WIcon icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WIconView(icon, size: 16, color: goldDeep),
        const SizedBox(width: 10),
        Expanded(child: WText(text, WType.caption, color: WColor.heading)),
      ]),
    );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WAppBar(title: store.t('Recurring job', 'नियमित काम', 'క్రమమైన పని'), onLeading: router.pop, padding: const EdgeInsets.fromLTRB(4, 4, 4, 0)),
      footer: Container(
        color: WColor.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          WFooterBar(
            captain: true,
            showCall: false,
            child: WButton(
              store.t('See today’s jobs', 'आज के काम देखें', 'ఈరోజు పనులు చూడండి'),
              size: ButtonSize.captain,
              onTap: () {
                router.home();
                router.tab = 0;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WLink(store.t('Cancel this recurring job', 'यह नियमित काम रद्द करें', 'ఈ క్రమమైన పని రద్దు'), color: WColor.destructive, onTap: cancelling ? null : () => _cancel(o)),
          ),
        ]),
      ),
      children: [
        const SizedBox(height: 10),
        // The golden ticket: the monthly package and its days.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: _goldSky, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: goldBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(store.t('Monthly package', 'मासिक पैकेज', 'నెలవారీ ప్యాకేజీ'), WType.label, color: goldDeep),
            const SizedBox(height: 2),
            WText(_rupees(o.estimatePaise), WType.bigMoney, mono: true),
            WText(store.t('${o.visits} visits this month', 'इस महीने ${o.visits} विज़िट', 'ఈ నెల ${o.visits} విజిట్లు'), WType.valueStrong),
            const SizedBox(height: 16),
            WeekdayCircles(dates: a.dates),
            const SizedBox(height: 12),
            Row(children: [
              const WIconView(WIcon.clock, size: 15, color: goldDeep),
              const SizedBox(width: 6),
              Expanded(child: WText('${o.window.isEmpty ? '' : '${o.window} · '}${store.t('about ${a.terms.estimatedMinutes} min each', 'हर बार लगभग ${a.terms.estimatedMinutes} मिनट', 'ఒక్కోసారి సుమారు ${a.terms.estimatedMinutes} నిమి')}', WType.caption, color: WColor.heading)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        WCard(
          radius: 16,
          outlined: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const WIconView(WIcon.location, size: 17, color: gold),
              const SizedBox(width: 8),
              Expanded(child: WText(a.place, WType.title)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              WIconView(a.vehicle.contains('Scooter') || a.vehicle.contains('Bike') ? WIcon.bike : WIcon.car, size: 17, color: gold),
              const SizedBox(width: 8),
              Expanded(child: WText('${a.vehicle} · ${a.terms.service}', WType.body)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        WText(store.t('Visit dates', 'विज़िट की तारीख़ें', 'విజిట్ తేదీలు'), WType.title),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in shown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: d == today ? gold : goldTint, borderRadius: BorderRadius.circular(10), border: Border.all(color: goldBorder)),
              child: WText(d == today ? store.t('Today', 'आज', 'ఈరోజు') : '${d.day} ${Fmt.date(d).split(' ').last}', WType.caption, color: d == today ? WColor.white : goldDeep),
            ),
          if (!allDates && upcoming.length > 6)
            Pressable(
              label: store.t('Show all dates', 'सभी तारीख़ें', 'అన్ని తేదీలు'),
              onTap: () => setState(() => allDates = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: goldBorder)),
                child: WText('+${upcoming.length - 6}', WType.caption, color: goldDeep, weight: FontWeight.w600),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        note(WIcon.help, store.t('Can’t make a visit? Tap Help on that day’s job.', 'किसी दिन नहीं आ सकते? उस दिन के काम पर मदद दबाएं।', 'ఒక రోజు రాలేరా? ఆ రోజు పనిపై సహాయం నొక్కండి.')),
        note(WIcon.calendar, store.t('To stop, cancel at least 2 days ahead.', 'रोकने के लिए कम से कम 2 दिन पहले रद्द करें।', 'ఆపడానికి కనీసం 2 రోజుల ముందు రద్దు చేయండి.')),
        if (a.terms.illustrative) note(WIcon.info, store.t('Example pay · rates still need approval', 'उदाहरण कमाई · दरें अभी तय नहीं', 'ఉదాహరణ · రేట్లు ఇంకా ఆమోదం కావాలి')),
        const SizedBox(height: 12),
      ],
    );
  }
}
