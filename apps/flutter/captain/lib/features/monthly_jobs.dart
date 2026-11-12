import 'dart:async';

import 'package:flutter/material.dart';
import 'package:washkrew_captain_jobs/washkrew_captain_jobs.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';
import '../screens/parts.dart';
import 'preview_features.dart' show sampleRecurringAssignment;
import 'v2_job.dart';

// v2 (13 Nov 2026, Aman): a monthly recurring job rings like a one-time job, but on its
// own gold screen so a Captain sees at once that it is regular work for a month. The Jobs
// tab has two ways in to open jobs: One-time jobs and Monthly jobs (incl. ones missed).
//
// Live: a monthly offer is an ordinary offer whose job document has `plan.totalVisits`
// (and `plan.dates`). It is claimed with the same `claimJob`. BACKEND (Ajay): send these
// offers for monthly plans; push kind `newMonthlyJob` ("Monthly job near you").

const goldDeep = Color(0xFF7A5300);
const gold = Color(0xFFC08A12);
const goldTint = Color(0xFFFFF3D1);
const goldBorder = Color(0xFFF0D48A);
const _goldSky = [Color(0xFFFFF8E6), Color(0xFFFFE7A6)];

/// A monthly job a Captain can take.
class MonthlyOffer {
  const MonthlyOffer({required this.id, required this.assignment, this.job});
  final String id;
  final RecurringAssignment assignment;

  /// The offer's job (live), or the sample's template job.
  final Job? job;

  /// "8–10 AM"
  String get window => job == null ? '' : timeRange(job!.extras.exactWindows.isNotEmpty ? job!.extras.exactWindows.first : job!.window);

  int get perVisitPaise => assignment.terms.netPayPaise ?? 0;
  int get visits => assignment.dates.isNotEmpty ? assignment.dates.length : (assignment.terms.totalVisits ?? 0);
  int get estimatePaise => perVisitPaise * visits;
}

/// "8–10" → "8–10 AM"; labels that already say AM/PM stay as they are.
String timeRange(String w) {
  if (w.contains('AM') || w.contains('PM')) return w;
  final parts = w.split('–');
  if (parts.length != 2) return w;
  final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
  if (a == null || b == null) return w;
  String h(int x) => '${x % 12 == 0 ? 12 : x % 12}';
  String ap(int x) => x < 12 ? 'AM' : 'PM';
  return ap(a) == ap(b) ? '${h(a)}–${h(b)} ${ap(b)}' : '${h(a)} ${ap(a)}–${h(b)} ${ap(b)}';
}

/// Sample monthly jobs (sample builds): a car on Mon/Wed/Fri and a scooter on Tue/Thu/Sat.
List<MonthlyOffer> sampleMonthlyOffers() {
  final car = sampleRecurringAssignment();
  final now = DateTime.now(), start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month + 1, now.day);
  final scooterDates = [
    for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1))
      if ([2, 4, 6].contains(d.weekday)) d,
  ];
  return [
    MonthlyOffer(
      id: car.id,
      assignment: car,
      job: Job(id: car.id, plate: 'TS 09 EA 4521', type: 'Hatchback', isBike: false, pay: 35, tower: 'Tower 3', floor: 'B2', slot: '41', window: '14–16', time: '14:30'),
    ),
    MonthlyOffer(
      id: 'preview-recurring-2',
      assignment: RecurringAssignment(
        id: 'preview-recurring-2',
        terms: VisitTerms(
          quoteId: 'preview-recurring-2',
          policyVersion: 'illustrative-not-approved',
          kind: VisitBookingKind.monthlyPlan,
          service: 'Basic',
          coverage: 'Exterior only',
          estimatedMinutes: 15,
          netPayPaise: 2500,
          visitNumber: 1,
          totalVisits: scooterDates.length,
          illustrative: true,
        ),
        dates: scooterDates,
        vehicle: 'AP 28 BQ 9911 · Scooter',
        place: 'Lanco Hills · Tower 1 · Open parking',
      ),
      job: Job(id: 'preview-recurring-2', plate: 'AP 28 BQ 9911', type: 'Scooter', isBike: true, pay: 25, tower: 'Tower 1', floor: 'Open', slot: '', window: '16–18', time: '16:30', society: 'Lanco Hills', area: 'Manikonda', wash: WashType.dryDusting),
    ),
  ];
}

String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2)}';

/// "Mon, Wed, Fri"
String weekdaysOf(List<DateTime> dates) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final days = {for (final d in dates) d.weekday}.toList()..sort();
  return days.length == 7 ? 'Every day' : days.map((d) => names[d - 1]).join(', ');
}

extension MonthlyJobsStore on CaptainStore {
  bool _isMonthly(Job j) => j.extras.monthly || (j.extras.planVisits ?? 0) > 1 || j.extras.planDates.length > 1;

  MonthlyOffer _fromJob(Job j) {
    final dates = j.extras.planDates;
    return MonthlyOffer(
      id: j.id,
      job: j,
      assignment: RecurringAssignment(
        id: j.id,
        terms: j.visitTerms ??
            VisitTerms(
              quoteId: j.id,
              policyVersion: 'offer',
              kind: VisitBookingKind.monthlyPlan,
              service: j.extras.serviceLevel ?? 'Basic',
              coverage: 'Exterior only',
              estimatedMinutes: 20,
              netPayPaise: (j.pay * 100).round(),
              totalVisits: j.extras.planVisits,
            ),
        dates: dates,
        vehicle: '${j.plate} · ${j.type}',
        place: '${j.society} · ${j.spot}',
      ),
    );
  }

  /// Monthly jobs open to this Captain now.
  List<MonthlyOffer> get monthlyOffers {
    if (isLive) return [for (final j in liveOffers) if (_isMonthly(j)) _fromJob(j)];
    return [
      for (final o in sampleMonthlyOffers())
        if (!declinedMonthly.contains(o.id) && !myAssignments.any((m) => m.id == o.id)) o,
    ];
  }

  /// Accept a monthly job: it joins My recurring assignments, and (sample) its visits for
  /// the coming week join the plan, today's on Home. Live visits come from the server.
  void acceptAssignment(MonthlyOffer o) {
    if (myAssignments.any((m) => m.id == o.id)) return;
    myAssignments = [...myAssignments, o];
    final t = o.job;
    if (!isLive && t != null) {
      final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
      for (final (i, d) in o.assignment.dates.indexed) {
        final day = d.difference(today).inDays;
        if (day < 0 || day > 6 || queue.any((q) => q.id == '${o.id}-$i')) continue;
        final visit = Job(
          id: '${o.id}-$i', plate: t.plate, type: t.type, isBike: t.isBike, pay: o.perVisitPaise / 100, tower: t.tower, floor: t.floor, slot: t.slot,
          window: t.window, time: t.time, society: o.assignment.place.split(' · ').first, area: t.area, wash: t.wash, day: day, status: JobStatus.next,
        )..extras = JobExtras(serviceLevel: o.assignment.terms.service, planVisit: i + 1, planVisits: o.visits);
        final at = queue.lastIndexWhere((x) => x.status != JobStatus.done) + 1;
        queue.insert(at, visit);
      }
    }
    changed();
  }

  /// Visits of [o] within the next 2 days stay with the Captain after cancelling.
  List<DateTime> keptAfterCancel(MonthlyOffer o) {
    final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
    return [for (final d in o.assignment.dates) if (!d.isBefore(today) && d.difference(today).inDays < 2) d];
  }

  /// Cancel an accepted assignment with 2 days' notice: visits from the 3rd day on go back
  /// to other Captains. BACKEND (Ajay): `cancelRecurringAssignment({assignmentId})`.
  Future<String?> cancelAssignment(MonthlyOffer o) async {
    if (isLive) {
      try {
        await live!.call('cancelRecurringAssignment', {'assignmentId': o.id});
      } catch (e) {
        return t('Couldn’t cancel right now. Try again or ask Help.', 'अभी रद्द नहीं हो सका। फिर कोशिश करें या मदद लें।', 'ఇప్పుడు రద్దు కాలేదు. మళ్లీ ప్రయత్నించండి లేదా సహాయం అడగండి.');
      }
    }
    myAssignments = [for (final m in myAssignments) if (m.id != o.id) m];
    queue.removeWhere((q) => q.id.startsWith('${o.id}-') && q.day >= 2 && q.status != JobStatus.done);
    changed();
    return null;
  }

  MonthlyOffer? get openAssignment => myAssignments.where((m) => m.id == openAssignmentId).firstOrNull ?? myAssignments.firstOrNull;

  /// One-time jobs open to this Captain now (live: the ringing offers; sample: nearby jobs).
  List<Job> get oneTimeOffers => isLive
      ? [for (final j in liveOffers) if (!_isMonthly(j)) j]
      : [for (final j in offerPool) if (wantsJob(j) && !queue.any((q) => q.id == j.id)) j];

  MonthlyOffer? get openMonthly {
    final all = monthlyOffers;
    return all.where((o) => o.id == openMonthlyId).firstOrNull ?? all.firstOrNull;
  }
}

/// The gold full-screen alert for a monthly recurring job.
class MonthlyJobAlertScreen extends StatefulWidget {
  const MonthlyJobAlertScreen({super.key});
  @override
  State<MonthlyJobAlertScreen> createState() => _MonthlyJobAlertScreenState();
}

class _MonthlyJobAlertScreenState extends State<MonthlyJobAlertScreen> {
  Timer? _tick;
  bool busy = false, allDates = false;
  late final MonthlyOffer? offer = context.store.openMonthly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (offer == null) return context.router.pop();
      Device.ding();
      Device.buzz(true);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    final store = context.store, router = context.router, o = offer!;
    if (!store.signedUp) {
      store.set(() => store.kycFromJob = true);
      router.replace(const [R(N.steps)]);
      return;
    }
    setState(() => busy = true);
    try {
      if (store.isLive && o.job != null) await store.liveClaim(o.job!.id);
    } catch (_) {
      if (mounted) setState(() => busy = false);
      return;
    }
    store.acceptAssignment(o);
    store.set(() {
      store.toast = store.t('Monthly job added to your calendar', 'मासिक काम आपके कैलेंडर में जोड़ा गया', 'నెలవారీ పని మీ క్యాలెండర్‌లో చేర్చబడింది');
    });
    router.home();
  }

  void _notNow() {
    final store = context.store, o = offer!;
    if (store.isLive && o.job != null) store.liveReject(o.job!.id).catchError((Object _) {});
    store.set(() => store.declinedMonthly.add(o.id));
    context.router.pop();
  }

  Widget _fact(WIcon icon, String big, String small) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: WColor.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14), border: Border.all(color: goldBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WIconView(icon, size: 18, color: gold),
          const SizedBox(height: 6),
          WText(big, WType.title, maxLines: 2),
          const SizedBox(height: 2),
          WText(small, WType.caption, color: goldDeep),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.store, o = offer;
    if (o == null) return const ColoredBox(color: WColor.white);
    final a = o.assignment, dates = a.dates;
    final expiry = o.job == null ? null : store.offerExpiry[o.id];
    final left = expiry?.difference(DateTime.now()).inSeconds;
    final window = o.window.isEmpty ? '—' : o.window;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _goldSky)),
      child: WScreen(
        background: Colors.transparent,
        gutter: WSpace.gutterCaptain,
        header: WAppBar(title: store.t('New monthly job', 'नया मासिक काम', 'కొత్త నెలవారీ పని'), onLeading: _notNow, padding: const EdgeInsets.fromLTRB(4, 4, 4, 0)),
        footer: Container(
          color: WColor.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WFooter(
                child: WButton(
                  store.t('Accept monthly job', 'मासिक काम लें', 'నెలవారీ పని తీసుకోండి'),
                  kind: ButtonKind.success,
                  size: ButtonSize.captain,
                  loading: busy,
                  enabled: !busy && (left == null || left > 0),
                  onTap: _accept,
                ),
              ),
              Padding(padding: const EdgeInsets.only(bottom: 8), child: WLink(store.t('Not now', 'अभी नहीं', 'ఇప్పుడు కాదు'), color: WColor.secondary, onTap: _notNow)),
            ],
          ),
        ),
        children: [
          const SizedBox(height: 8),
          // Badge: says what kind of job this is before anything else.
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const WIconView(WIcon.calendar, size: 15, color: WColor.white),
                const SizedBox(width: 6),
                WText(store.t('MONTHLY · RECURRING', 'मासिक · नियमित', 'నెలవారీ · క్రమమైన'), WType.label, color: WColor.white, letterSpacing: 0.6),
              ]),
            ),
            const Spacer(),
            if (left != null)
              WText('${(left.clamp(0, 5999) ~/ 60)}:${(left.clamp(0, 5999) % 60).toString().padLeft(2, '0')}', WType.title, color: goldDeep, mono: true),
          ]),
          const SizedBox(height: 18),
          WText(store.t('Your pay per visit', 'हर विज़िट की कमाई', 'ఒక్కో విజిట్‌కు సంపాదన'), WType.body, color: goldDeep),
          WText(_rupees(o.perVisitPaise), WType.hugeMoney, mono: true),
          const SizedBox(height: 4),
          WText(
            store.t('${o.visits} visits · about ${_rupees(o.estimatePaise)} this month', '${o.visits} विज़िट · इस महीने लगभग ${_rupees(o.estimatePaise)}', '${o.visits} విజిట్లు · ఈ నెల సుమారు ${_rupees(o.estimatePaise)}'),
            WType.valueStrong,
          ),
          const SizedBox(height: 18),
          Row(children: [
            _fact(WIcon.calendar, dates.isEmpty ? '—' : weekdaysOf(dates), store.t('Days', 'दिन', 'రోజులు')),
            const SizedBox(width: 8),
            _fact(WIcon.clock, window, store.t('Time', 'समय', 'సమయం')),
            const SizedBox(width: 8),
            _fact(WIcon.flag, dates.isEmpty ? '—' : Fmt.date(dates.first).split(', ').last, store.t('Starts', 'शुरू', 'మొదలు')),
          ]),
          const SizedBox(height: 14),
          WCard(
            radius: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const WIconView(WIcon.location, size: 18, color: gold),
                const SizedBox(width: 8),
                Expanded(child: WText(a.place, WType.title)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                WIconView(a.vehicle.contains('Bike') || a.vehicle.contains('Scooter') ? WIcon.bike : WIcon.car, size: 18, color: gold),
                const SizedBox(width: 8),
                Expanded(child: WText('${a.vehicle} · ${a.terms.service}', WType.body)),
              ]),
            ]),
          ),
          if (dates.isNotEmpty) ...[
            const SizedBox(height: 14),
            WText(store.t('Your dates', 'आपकी तारीख़ें', 'మీ తేదీలు'), WType.label, color: goldDeep),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in allDates ? dates : dates.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: goldTint, borderRadius: BorderRadius.circular(10), border: Border.all(color: goldBorder)),
                  child: WText('${d.day} ${Fmt.date(d).split(' ').last}', WType.caption, color: goldDeep),
                ),
              if (!allDates && dates.length > 6)
                Pressable(
                  label: store.t('Show all dates', 'सभी तारीख़ें', 'అన్ని తేదీలు'),
                  onTap: () => setState(() => allDates = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: goldBorder)),
                    child: WText('+${dates.length - 6}', WType.caption, color: goldDeep, weight: FontWeight.w600),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 14),
          WText(
            store.t('An estimate from planned visits, not a fixed salary.', 'तय विज़िट से अनुमान, तय वेतन नहीं।', 'ప్లాన్ చేసిన విజిట్ల అంచనా, స్థిర జీతం కాదు.'),
            WType.caption,
          ),
          if (a.terms.illustrative) WText(store.t('Example pay · rates still need approval', 'उदाहरण कमाई · दरें अभी तय नहीं', 'ఉదాహరణ · రేట్లు ఇంకా ఆమోదం కావాలి'), WType.caption),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Jobs tab → Find new jobs: One-time jobs and Monthly jobs side by side.
class FindJobsTiles extends StatelessWidget {
  const FindJobsTiles({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final oneTime = store.oneTimeOffers.length, monthly = store.monthlyOffers.length;
    Widget tile({required bool isMonthly, required int count}) => Expanded(
      child: Pressable(
        label: isMonthly ? 'Monthly jobs' : 'One-time jobs',
        onTap: () => router.push(R(N.openJobs, flag: isMonthly)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isMonthly ? const LinearGradient(colors: _goldSky, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: isMonthly ? null : WColor.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isMonthly ? goldBorder : WColor.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                WIconBox(isMonthly ? WIcon.calendar : WIcon.drop, size: 40, tone: Tone.info),
                const Spacer(),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: isMonthly ? gold : WColor.primary, borderRadius: BorderRadius.circular(12)),
                    child: WText('$count', WType.label, color: WColor.white),
                  ),
              ]),
              const SizedBox(height: 12),
              WText(isMonthly ? store.t('Monthly jobs', 'मासिक काम', 'నెలవారీ పనులు') : store.t('One-time jobs', 'एक बार के काम', 'ఒక్కసారి పనులు'), WType.title),
              const SizedBox(height: 2),
              WText(
                count == 0
                    ? store.t('None open now', 'अभी कोई नहीं', 'ఇప్పుడు లేవు')
                    : isMonthly
                    ? store.t('$count open · same car, all month', '$count खुले · पूरे महीने', '$count ఉన్నాయి · నెలంతా')
                    : store.t('$count open near you', 'पास में $count खुले', 'దగ్గర్లో $count ఉన్నాయి'),
                WType.caption,
                color: isMonthly ? goldDeep : null,
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WText(store.t('Find new jobs', 'नए काम खोजें', 'కొత్త పనులు చూడండి'), WType.label, color: WColor.muted),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tile(isMonthly: false, count: oneTime), const SizedBox(width: 10), tile(isMonthly: true, count: monthly)]),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// The open jobs of one kind. [monthly]: gold cards that open the monthly alert.
class OpenJobsScreen extends StatefulWidget {
  const OpenJobsScreen({super.key, required this.monthly});
  final bool monthly;
  @override
  State<OpenJobsScreen> createState() => _OpenJobsScreenState();
}

class _OpenJobsScreenState extends State<OpenJobsScreen> {
  String? claiming;

  Future<void> _take(Job j) async {
    final store = context.store, router = context.router;
    if (!store.signedUp) {
      store.set(() => store.kycFromJob = true);
      router.replace(const [R(N.steps)]);
      return;
    }
    setState(() => claiming = j.id);
    try {
      if (store.isLive) {
        await store.liveClaim(j.id);
      } else {
        store.acceptOffer(j);
      }
      store.set(() => store.toast = store.t('Added to your jobs', 'आपके कामों में जोड़ा गया', 'మీ పనుల్లో చేర్చబడింది'));
    } catch (_) {
      // The claim error shows as the app's usual message.
    } finally {
      if (mounted) setState(() => claiming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router, monthly = widget.monthly;
    final oneTime = store.oneTimeOffers, months = store.monthlyOffers;
    final empty = monthly ? months.isEmpty : oneTime.isEmpty;
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WAppBar(title: monthly ? store.t('Monthly jobs', 'मासिक काम', 'నెలవారీ పనులు') : store.t('One-time jobs', 'एक बार के काम', 'ఒక్కసారి పనులు'), onLeading: router.pop, padding: const EdgeInsets.fromLTRB(4, 4, 4, 0)),
      children: [
        const SizedBox(height: 6),
        WText(
          monthly
              ? store.t('Same vehicle, planned visits all month. Open ones, including any you missed.', 'एक ही गाड़ी, पूरे महीने तय विज़िट। खुले काम, छूटे हुए भी।', 'అదే వాహనం, నెలంతా విజిట్లు. తప్పిన వాటితో సహా.')
              : store.t('Single washes near you that are still open, including any you missed.', 'पास के खुले काम, छूटे हुए भी।', 'దగ్గర్లో ఇంకా ఉన్న పనులు, తప్పిన వాటితో సహా.'),
          WType.body,
        ),
        const SizedBox(height: 16),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(children: [
              WStateCircle(monthly ? WIcon.calendar : WIcon.drop, size: 80),
              const SizedBox(height: 12),
              WText(store.t('No open jobs right now', 'अभी कोई खुला काम नहीं', 'ఇప్పుడు పనులు లేవు'), WType.section, weight: FontWeight.w600),
              const SizedBox(height: 8),
              WBody(store.online ? store.t('New ones ring as soon as they are posted.', 'नए काम आते ही बजेंगे।', 'కొత్తవి రాగానే మోగుతాయి.') : store.t('Go Online to get new jobs.', 'नए काम के लिए ऑनलाइन हों।', 'కొత్త పనుల కోసం ఆన్‌లైన్ అవ్వండి.'), center: true),
            ]),
          )
        else if (monthly)
          for (final o in months) ...[
            Pressable(
              label: 'Monthly job ${o.assignment.place}',
              onTap: () {
                store.set(() => store.openMonthlyId = o.id);
                router.push(const R(N.monthlyAlert));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: _goldSky, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), border: Border.all(color: goldBorder)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      WText(o.assignment.place, WType.title),
                      const SizedBox(height: 4),
                      WText('${o.visits} ${store.t('visits', 'विज़िट', 'విజిట్లు')} · ${weekdaysOf(o.assignment.dates)}', WType.caption, color: goldDeep),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    WText(_rupees(o.perVisitPaise), WType.section, weight: FontWeight.w600, mono: true),
                    WText(store.t('per visit', 'हर विज़िट', 'ఒక్కో విజిట్'), WType.small, color: goldDeep),
                  ]),
                  const SizedBox(width: 8),
                  const WIconView(WIcon.chevron, size: 13, color: goldDeep),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ]
        else
          for (final j in oneTime) ...[
            WCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      WText(j.society, WType.title),
                      const SizedBox(height: 4),
                      WText('${j.day == 1 ? store.t('Tomorrow', 'कल', 'రేపు') : store.t('Today', 'आज', 'ఈరోజు')} · ${j.flexible ? store.t('Any time', 'कभी भी', 'ఎప్పుడైనా') : j.whenLabel} · ${j.distance}', WType.caption),
                    ]),
                  ),
                  WText(Fmt.rupees(j.pay), WType.section, weight: FontWeight.w600, mono: true),
                ]),
                const SizedBox(height: 10),
                BookingChip(job: j),
                const SizedBox(height: 12),
                WButton(store.t('Accept', 'लें', 'తీసుకోండి'), kind: ButtonKind.success, size: ButtonSize.captain, loading: claiming == j.id, enabled: claiming == null, onTap: () => _take(j)),
              ]),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
