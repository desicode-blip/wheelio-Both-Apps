import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/store.dart';
import 'money.dart';
import 'parts.dart';
import 'welcome.dart';

// MARK: Tabs (Home · Jobs · Money · Me)

class CaptainTabs extends StatefulWidget {
  const CaptainTabs({super.key});
  @override
  State<CaptainTabs> createState() => _CaptainTabsState();
}

class _CaptainTabsState extends State<CaptainTabs> {
  Timer? _nudge;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // After a guest has looked around for a while, offer the light sign-up once.
    final store = context.store;
    if (_nudge != null || !store.exploring || store.registered || store.nudgeShown) return;
    _nudge = Timer(const Duration(seconds: 45), () {
      if (!mounted || store.registered || store.nudgeShown || context.router.path.isNotEmpty) return;
      store.set(() => store.nudgeShown = true);
      showWSheet<void>(context, height: 400, gutter: WSpace.gutterCaptain, builder: (_) => const SignUpNudge());
    });
  }

  @override
  void dispose() {
    _nudge?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return Material(
      color: WColor.canvas,
      child: Column(
        children: [
          Expanded(
            child: switch (router.tab) {
              1 => const JobsTab(),
              2 => const MoneyTab(),
              3 => const MeTab(),
              _ => const CaptainHome(),
            },
          ),
          WBottomNav(
            selection: router.tab,
            onSelect: (t) => router.tab = t,
            items: [
              NavItem(0, store.t('Home', 'होम', 'హోమ్'), WIcon.home),
              NavItem(1, store.t('Jobs', 'काम', 'పనులు'), WIcon.list),
              NavItem(2, store.t('Money', 'पैसे', 'డబ్బు'), WIcon.rupee),
              NavItem(3, store.t('Me', 'मैं', 'నేను'), WIcon.user),
            ],
          ),
        ],
      ),
    );
  }
}

// MARK: W20 offline · W21 online · W24 daily limit · W50 low signal

class CaptainHome extends StatefulWidget {
  const CaptainHome({super.key});
  @override
  State<CaptainHome> createState() => _CaptainHomeState();
}

class _CaptainHomeState extends State<CaptainHome> {
  Timer? _ring;
  String? _ringKey;

  /// Demo: a job rings a few seconds after going online (and again each time Home is back on top).
  void _scheduleRing(bool want) {
    final key = want ? 'on' : null;
    if (key == _ringKey) return;
    _ringKey = key;
    _ring?.cancel();
    if (!want) return;
    _ring = Timer(const Duration(seconds: 4), () {
      final store = context.store, router = context.router;
      _ringKey = null;
      if (!mounted || !store.online || router.path.isNotEmpty || router.tab != 0) return;
      store.notify(WNotifKind.newJob, job: offerPool[0], deliver: false);
      router.push(R(N.jobAlert, flag: store.batchedAlert));
    });
  }

  @override
  void dispose() {
    _ring?.cancel();
    super.dispose();
  }

  /// Guests sign up (name, number, code) before going online.
  void _setOnline(bool on) {
    final store = context.store;
    if (on && !store.registered) {
      store.set(() => store.onlineAfterSignUp = true);
      context.router.push(const R(N.signUp));
    } else {
      store.set(() => store.online = on);
    }
  }

  Widget _alertBox(WIcon icon, Tone tone, String title, String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WIconView(icon, size: 17, color: tone.bannerText),
        const SizedBox(width: 12),
        Expanded(child: WRich([('$title ', bold), (text, null)], WType.caption, color: tone.bannerText, size: 14.5)),
      ],
    ),
  );

  Widget _miniStat(WIcon icon, String big, String small) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WIconView(icon, size: 15, color: WColor.primaryStrong),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(big, WType.title, size: 17, mono: true, maxLines: 1), WText(small, WType.small)]),
      ],
    ),
  );

  Widget _stat(WIcon icon, Tone tone, String big, String small) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WIconView(icon, size: 21, color: tone == Tone.ok ? WColor.heading : WColor.primaryStrong),
          const SizedBox(height: 6),
          WText(big, WType.section, weight: semibold),
          const SizedBox(height: 6),
          WText(small, WType.caption, color: WColor.heading),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final limitReached = store.jobsToday >= store.jobLimit;
    final hasPlan = store.signedUp && store.queue.isNotEmpty;
    _scheduleRing(store.online && isTopScreen(context) && router.tab == 0 && !limitReached);
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: WColor.canvas,
      child: Column(
        children: [
          // Header stays put while the page scrolls.
          Container(
            padding: EdgeInsets.fromLTRB(WSpace.gutterCaptain, pad.top + 10, WSpace.gutterCaptain, 10),
            decoration: const BoxDecoration(
              color: WColor.canvas,
              border: Border(bottom: BorderSide(color: WColor.divider)),
            ),
            child: Row(
              children: [
                if (store.registered) ...[
                  const WProfilePhoto(size: 40, badge: false),
                  const SizedBox(width: 10),
                  Flexible(child: WText(store.firstName, WType.title, size: 18, maxLines: 1)),
                ] else
                  // Guest: tap to sign up (name, number, code), then back to Home.
                  Pressable(
                    label: store.t('Guest. Tap to sign up', 'मेहमान। साइन अप के लिए दबाएं', 'అతిథి. సైన్ అప్‌కి నొక్కండి'),
                    onTap: () => router.push(const R(N.signUp)),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: const WIconView(WIcon.user, size: 18, color: WColor.primaryStrong),
                        ),
                        const SizedBox(width: 10),
                        WText(store.t('Guest', 'मेहमान', 'అతిథి'), WType.title, size: 18),
                      ],
                    ),
                  ),
                const Spacer(),
                OnlineSwitch(online: store.online, label: store.online ? store.t('Online', 'ऑनलाइन', 'ఆన్‌లైన్') : store.t('Offline', 'ऑफ़लाइन', 'ఆఫ్‌లైన్'), set: _setOnline),
                if (store.registered) const WNotificationBell(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 12, WSpace.gutterCaptain, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WorkAreaChip(),
                  if (store.lowSignal) ...[
                    const SizedBox(height: 14),
                    _alertBox(
                      WIcon.battery,
                      Tone.wait,
                      store.t('Battery 12%.', 'बैटरी 12%।', 'బ్యాటరీ 12%.'),
                      store.t('Plug in soon. Jobs stop at 5%.', 'जल्दी चार्ज करें। 5% पर काम रुक जाएगा।', 'త్వరగా ఛార్జ్ చేయండి. 5% వద్ద పనులు ఆగుతాయి.'),
                    ),
                    const SizedBox(height: 14),
                    _alertBox(
                      WIcon.wifiOff,
                      Tone.error,
                      store.t('No internet.', 'इंटरनेट नहीं।', 'ఇంటర్నెట్ లేదు.'),
                      store.t(
                        '2 photos saved on phone. They upload when signal comes back.',
                        '2 फ़ोटो फ़ोन में सेव हैं। सिग्नल आने पर अपलोड होंगी।',
                        '2 ఫోటోలు ఫోన్‌లో ఉన్నాయి. సిగ్నల్ వచ్చాక అప్‌లోడ్ అవుతాయి.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (store.signedUp)
                    if (store.queue.isEmpty)
                      WCard(
                        padding: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WText(store.t('Today', 'आज', 'ఈరోజు'), WType.body),
                            const SizedBox(height: 10),
                            WText(Fmt.rupees(store.online || store.jobsToday > 0 ? store.earnedToday : 0), WType.hugeMoney, mono: true),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _stat(WIcon.check, Tone.ok, '${store.jobsToday} ${store.t('of', '/', '/')} ${store.jobLimit}', store.t('Jobs done', 'काम पूरे', 'పూర్తైన పనులు')),
                                const SizedBox(width: 10),
                                _stat(WIcon.star, Tone.info, store.rating.toStringAsFixed(1), store.t('Rating', 'रेटिंग', 'రేటింగ్')),
                              ],
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Once jobs come in, money/jobs/rating shrink to one line and the day's plan takes the space.
                      Pressable(
                        onTap: () => router.tab = 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: outlinedDecoration(radius: 16),
                          child: Row(
                            children: [
                              _miniStat(WIcon.rupee, Fmt.rupees(store.earnedToday), store.t('Today', 'आज', 'ఈరోజు')),
                              Container(width: 1, height: 30, color: WColor.divider),
                              _miniStat(WIcon.check, '${store.jobsToday}/${store.jobLimit}', store.t('Jobs', 'काम', 'పనులు')),
                              Container(width: 1, height: 30, color: WColor.divider),
                              _miniStat(WIcon.star, store.rating.toStringAsFixed(1), store.t('Rating', 'रेटिंग', 'రేటింగ్')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const DayPlan(),
                    ]
                  else ...[
                    const _WelcomeBanner(),
                    if (store.registered) ...[
                      const SizedBox(height: 14),
                      WCard(
                        onTap: () {
                          store.set(() => store.kycFromJob = false);
                          router.push(const R(N.steps));
                        },
                        child: Row(
                          children: [
                            const WIconBox(WIcon.idCard, size: 48, tone: Tone.wait),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  WText(store.t('Finish KYC to take jobs', 'काम लेने के लिए KYC पूरा करें', 'పనులకు KYC పూర్తి చేయండి'), WType.title, size: 17),
                                  const SizedBox(height: 3),
                                  WText('${store.kycStagesDone}/4 · ${store.t('Aadhaar, photo, bank, training', 'आधार, फ़ोटो, बैंक, ट्रेनिंग', 'ఆధార్, ఫోటో, బ్యాంక్, శిక్షణ')}', WType.caption),
                                ],
                              ),
                            ),
                            const WIconView(WIcon.chevron, size: 14, color: WColor.secondary),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (limitReached && store.online && store.signedUp) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WIconView(WIcon.calendar, size: 17),
                          const SizedBox(width: 12),
                          Expanded(
                            child: WRich(
                              [
                                (
                                  store.t(
                                    'Day ${store.levelDay} limit done: ${store.jobsToday} of ${store.jobLimit}. ',
                                    'दिन ${store.levelDay} की सीमा पूरी: ${store.jobsToday}/${store.jobLimit}। ',
                                    'రోజు ${store.levelDay} పరిమితి పూర్తి: ${store.jobsToday}/${store.jobLimit}. ',
                                  ),
                                  bold,
                                ),
                                (store.t('All good ratings? Tomorrow you get 6 to 8 jobs.', 'सब रेटिंग अच्छी? कल 6 से 8 काम मिलेंगे।', 'అన్ని రేటింగ్‌లు బాగుంటే రేపు 6 నుండి 8 పనులు.'), null),
                              ],
                              WType.caption,
                              color: WColor.inverse,
                              size: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!store.online && !hasPlan)
                    Padding(
                      padding: const EdgeInsets.only(top: 34),
                      child: Column(
                        children: [
                          const WIconView(WIcon.power, size: 34, color: WColor.secondary),
                          const SizedBox(height: 8),
                          WText(store.t('You’re offline', 'आप ऑफ़लाइन हैं', 'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు'), WType.section, weight: semibold),
                          const SizedBox(height: 8),
                          WText(store.t('Go online to get jobs near you', 'पास के काम पाने के लिए ऑनलाइन जाएं', 'దగ్గరి పనుల కోసం ఆన్‌లైన్‌కి వెళ్ళండి'), WType.body),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (store.online && !store.lowSignal && !(limitReached && store.signedUp))
            _LiveStrip(text: store.t('Online · Looking for jobs near you', 'ऑनलाइन · आपके पास काम ढूँढ रहे हैं', 'ఆన్‌లైన్ · మీ దగ్గర పనులు వెతుకుతున్నాం')),
          if (!store.online && !hasPlan)
            WFooter(
              child: WButton(store.t('Go online', 'ऑनलाइन जाएं', 'ఆన్‌లైన్‌కి వెళ్ళండి'), icon: WIcon.power, size: ButtonSize.captain, onTap: () => _setOnline(true)),
            ),
        ],
      ),
    );
  }
}

/// Soft welcome for guests and new captains, with a quiet hint of what's possible.
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 58, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [WColor.primaryTint, Color(0xFFFFF6E3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const WIconView(WIcon.sparkleFill, size: 14, color: WColor.primaryStrong),
                  const SizedBox(width: 8),
                  Flexible(
                    child: WText(
                      store.registered
                          ? store.t('Welcome, ${store.firstName}', 'स्वागत है, ${store.firstName}', 'స్వాగతం, ${store.firstName}')
                          : store.t('Welcome to ${Brand.name}', '${Brand.name} में स्वागत है', '${Brand.name} కి స్వాగతం'),
                      WType.label,
                      color: WColor.primaryStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              WRich(
                [
                  (store.t('Captains here earn up to ', 'यहाँ कैप्टन महीने में ', 'ఇక్కడ కెప్టెన్లు నెలకు '), null),
                  ('₹80,000', bold),
                  (store.t(' a month.', ' तक कमाते हैं।', ' వరకు సంపాదిస్తారు.'), null),
                ],
                WType.title,
                color: WColor.heading,
                size: 18,
              ).withWeight(FontWeight.w400),
              const SizedBox(height: 8),
              WText(store.t('Your hours, jobs near home, money every night.', 'आपका समय, घर के पास काम, हर रात पैसे।', 'మీ సమయం, ఇంటి దగ్గర పని, ప్రతి రాత్రి డబ్బు.'), WType.caption),
            ],
          ),
          Positioned(right: -44, bottom: -4, child: WIconView(WIcon.figure, size: 54, color: WColor.primary.withValues(alpha: 0.14))),
        ],
      ),
    );
  }
}

extension on WRich {
  /// WRich with the base weight lowered (title type is semibold by default).
  Widget withWeight(FontWeight w) => Builder(
    builder: (c) {
      final base = wStyle(k, color: color, size: size).copyWith(fontWeight: w);
      return Text.rich(
        TextSpan(
          children: [
            for (final s in spans)
              TextSpan(
                text: s.$1,
                style: s.$2 == null ? base : base.copyWith(fontWeight: s.$2),
              ),
          ],
        ),
      );
    },
  );
}

// MARK: Online / Offline switch with a subtle, always-on animation

/// Online: a green dot sends out a slow ripple ("you're live").
/// Offline: a grey dot gently breathes and the switch glows softly ("tap to go online").
class OnlineSwitch extends StatelessWidget {
  const OnlineSwitch({super.key, required this.online, required this.label, required this.set});
  final bool online;
  final String label;
  final ValueChanged<bool> set;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 14,
        height: 14,
        child: Pulse(
          key: ValueKey(online),
          duration: Duration(milliseconds: online ? 1600 : 1400),
          reverse: !online,
          builder: (c, t) => Stack(
            alignment: Alignment.center,
            children: [
              if (online)
                Transform.scale(
                  scale: 1 + 1.6 * t,
                  child: Opacity(
                    opacity: 0.8 * (1 - t),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: WColor.success, width: 2),
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: online ? 1 : 1 - 0.65 * t,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: online ? WColor.success : WColor.muted),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      WText(label, WType.title, color: online ? WColor.heading : WColor.secondary),
      const SizedBox(width: 6),
      Pulse(
        key: ValueKey('g$online'),
        duration: Duration(milliseconds: online ? 1600 : 1400),
        builder: (c, t) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (online ? WColor.success : WColor.primary).withValues(alpha: online ? 0.1 + 0.35 * t : 0.35 * t),
                blurRadius: 2 + 6 * t,
              ),
            ],
          ),
          child: WToggle(on: online, onChanged: set, tint: WColor.success),
        ),
      ),
      const SizedBox(width: 4),
    ],
  );
}

// MARK: Today's plan (calendar): one job after another, by time

int _minutes(String t) {
  final p = t.split(':').map(int.tryParse).toList();
  return (p.isNotEmpty ? p[0] ?? 0 : 0) * 60 + (p.length > 1 ? p[1] ?? 0 : 0);
}

/// A simple day calendar: time on the left, a line with dots, and each job as a compact card.
/// A done job shows a small summary; any other job opens "Go to vehicle".
class DayPlan extends StatelessWidget {
  const DayPlan({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final jobs = [...store.queue]..sort((a, b) => _minutes(a.time).compareTo(_minutes(b.time)));
    final done = store.queue.where((j) => j.status == JobStatus.done).length;
    void open(Job j) {
      switch (j.status) {
        case JobStatus.done:
          showWSheet<void>(context, height: 330, gutter: 20, builder: (_) => _DoneJobSheet(job: j));
        case JobStatus.now:
          router.go(N.goToVehicle);
        case JobStatus.next:
          // Captain chose to do this one first: it becomes the current job.
          store.startJob(j.id);
          router.go(N.goToVehicle);
      }
    }

    Widget dot(JobStatus s) => switch (s) {
      JobStatus.done => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const WIconView(WIcon.check, size: 11, color: WColor.onSuccess, weight: bold),
      ),
      JobStatus.now => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: WColor.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: WColor.primary.withValues(alpha: 0.25), spreadRadius: 5)],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle),
        ),
      ),
      JobStatus.next => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: WColor.white,
          shape: BoxShape.circle,
          border: Border.all(color: WColor.muted, width: 2.5),
        ),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WText(store.t('Today’s plan', 'आज का प्लान', 'ఈరోజు ప్లాన్'), WType.section, weight: semibold, size: 21),
                  const SizedBox(height: 2),
                  WText(
                    '${Fmt.day(DateTime.now())} · ${store.t('$done of ${store.queue.length} done', '${store.queue.length} में से $done पूरे', '${store.queue.length} లో $done పూర్తి')}',
                    WType.caption,
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const WIconView(WIcon.calendar, size: 18, color: WColor.primaryStrong),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, j) in jobs.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 46,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        WText(
                          () {
                            final m = _minutes(j.time), h = m ~/ 60;
                            return '${h % 12 == 0 ? 12 : h % 12}:${(m % 60).toString().padLeft(2, '0')}';
                          }(),
                          WType.title,
                          size: 17,
                          mono: true,
                          color: j.status == JobStatus.done ? WColor.secondary : WColor.heading,
                        ),
                        WText(_minutes(j.time) ~/ 60 < 12 ? 'AM' : 'PM', WType.small),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      dot(j.status),
                      if (i < jobs.length - 1) Expanded(child: Container(width: 3, color: j.status == JobStatus.done ? WColor.success : WColor.border)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == jobs.length - 1 ? 0 : 10),
                    child: Pressable(
                      onTap: () => open(j),
                      child: Opacity(
                        opacity: j.status == JobStatus.done ? 0.8 : 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: outlinedDecoration(
                            radius: 14,
                            fill: j.status == JobStatus.now
                                ? WColor.primaryTint
                                : j.status == JobStatus.done
                                ? WColor.canvas
                                : WColor.white,
                            stroke: j.status == JobStatus.now ? WColor.primary : WColor.border,
                            width: j.status == JobStatus.now ? 2 : 1,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  WIconView(WIcon.location, size: 13, color: j.status == JobStatus.done ? WColor.muted : WColor.primaryStrong),
                                  const SizedBox(width: 6),
                                  Expanded(child: WText(j.society, WType.title, size: 16, maxLines: 1, color: j.status == JobStatus.done ? WColor.secondary : WColor.heading)),
                                  WText(Fmt.rupees(j.pay), WType.title, size: 16, mono: true, color: j.status == JobStatus.done ? WColor.secondary : WColor.heading),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  WIconView(j.isBike ? WIcon.bike : WIcon.carFill, size: 13, color: j.status == JobStatus.done ? WColor.muted : WColor.secondary),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: j.status == JobStatus.done ? WColor.border : WColor.heading, width: 1.2),
                                    ),
                                    child: Text(
                                      j.plate,
                                      style: wStyle(WType.label, weight: semibold, size: 13, color: j.status == JobStatus.done ? WColor.secondary : WColor.heading).copyWith(letterSpacing: 1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: WText('${j.tower} · ${j.floor}', WType.caption, size: 13.5, maxLines: 1)),
                                  if (j.status == JobStatus.done)
                                    WText(store.t('Done', 'पूरा', 'పూర్తి'), WType.small, color: WColor.onSuccess, weight: semibold)
                                  else
                                    WIconView(WIcon.chevron, size: 11, color: j.status == JobStatus.now ? WColor.primaryStrong : WColor.muted),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small pop-up for a finished job.
class _DoneJobSheet extends StatelessWidget {
  const _DoneJobSheet({required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const WIconView(WIcon.check, size: 18, color: WColor.onSuccess, weight: bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WText(store.t('Completed', 'पूरा हुआ', 'పూర్తయింది'), WType.section, weight: semibold),
                  WText('${job.time} · ${job.society}', WType.caption),
                ],
              ),
            ),
            WText(Fmt.rupees(job.pay), WType.section, weight: semibold, mono: true),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            WPlate(job.plate),
            const SizedBox(width: 10),
            Expanded(child: WText(job.spot, WType.caption)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: WPhotoPlaceholder(height: 76, icon: job.isBike ? WIcon.bike : WIcon.car, tag: store.t('Before', 'पहले', 'ముందు')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: WPhotoPlaceholder(height: 76, icon: WIcon.sparkle, tag: store.t('After', 'बाद', 'తర్వాత'), tagTone: Tone.ok),
            ),
          ],
        ),
        const SizedBox(height: 14),
        WBadge(store.t('Waiting for owner’s OK · paid tonight', 'मालिक की मंज़ूरी का इंतज़ार · आज रात भुगतान', 'యజమాని ఆమోదం కోసం · ఈ రాత్రి చెల్లింపు'), tone: Tone.wait, icon: WIcon.clock),
      ],
    );
  }
}

/// Slim, edge-to-edge strip shown only while online: a live green dot and one line.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => FadeIn(
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: WSpace.gutterCaptain),
      decoration: BoxDecoration(
        color: WColor.successTint,
        border: Border(top: BorderSide(color: WColor.success.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Pulse(
              duration: const Duration(milliseconds: 1500),
              reverse: false,
              builder: (c, t) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1 + 1.4 * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: WColor.success.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: WColor.success),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: WText(text, WType.label, color: WColor.onSuccess, size: 14, maxLines: 1)),
        ],
      ),
    ),
  );
}

// MARK: W22 New job alert: a stack of offers (W22b batched, W22h Hindi, W22t Telugu, W22m many)

const _offerSeconds = 30;

class _Offer {
  _Offer(this.job, this.arrived);
  final Job job;
  final DateTime arrived;
}

/// Every job that rings gets its own 30-second timer. New jobs arriving while the alert is open
/// slide in behind the top card. Reject sends the top card to the back of the stack; Accept adds
/// it to today's jobs on Home and shows the next one. When a timer runs out, that job goes to
/// someone else. Phones can also swipe the top card left; the web shows "See next job" instead.
class JobAlertScreen extends StatefulWidget {
  const JobAlertScreen({super.key, this.batched = false});
  final bool batched;
  @override
  State<JobAlertScreen> createState() => _JobAlertScreenState();
}

class _JobAlertScreenState extends State<JobAlertScreen> {
  final offers = <_Offer>[];
  DateTime now = DateTime.now();
  double drag = 0;
  bool newPill = false;
  bool handled = false;
  int acceptedHere = 0;
  Timer? _tick;
  final _timers = <Timer>[];

  double _left(_Offer o) => (_offerSeconds - now.difference(o.arrived).inMilliseconds / 1000).clamp(0, _offerSeconds).toDouble();

  void _nudge() {
    Device.ding();
    Device.buzz(true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _run() {
    final store = context.store, router = context.router;
    // Only jobs that match "Where I work".
    final pool = offerPool.where(store.wantsJob).toList();
    if (pool.isEmpty) {
      handled = true;
      store.set(() => store.toast = store.t('No jobs in your area right now', 'अभी आपके इलाके में काम नहीं', 'ఇప్పుడు మీ ప్రాంతంలో పనులు లేవు'));
      router.pop();
      return;
    }
    setState(() => offers.add(_Offer(pool.first, DateTime.now())));
    _nudge();
    // Demo: more jobs ring while this one is open.
    final extra = pool.skip(1).take(store.extraOffers).toList();
    for (final (i, s) in [6, 13].indexed) {
      if (i >= extra.length) break;
      _timers.add(
        Timer(Duration(seconds: s), () {
          if (handled || !mounted) return;
          setState(() {
            offers.add(_Offer(extra[i], DateTime.now()));
            newPill = true;
          });
          store.notify(WNotifKind.newJob, job: extra[i], deliver: false);
          _nudge();
          _timers.add(Timer(const Duration(milliseconds: 1600), () => mounted ? setState(() => newPill = false) : null));
        }),
      );
    }
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (handled || !mounted) return;
      setState(() => now = DateTime.now());
      // Jobs whose 30 seconds ran out go to someone else.
      final expired = offers.where((o) => _left(o) <= 0).toList();
      if (expired.isEmpty) return;
      for (final o in expired) {
        store.notify(WNotifKind.jobTaken, job: o.job, deliver: false);
      }
      setState(() => offers.removeWhere(expired.contains));
      if (offers.isEmpty) {
        handled = true;
        if (acceptedHere > 0) {
          router.home();
        } else {
          router.replace(const [R(N.jobMissed)]);
        }
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _leave() {
    if (handled) return;
    handled = true;
    context.router.home();
  }

  /// Reject: the top card goes to the back of the stack (its timer keeps running).
  /// With only one card left, Reject closes the alert.
  void _reject() {
    if (handled || offers.isEmpty) return;
    if (offers.length == 1) {
      _leave();
      return;
    }
    Device.buzz();
    setState(() => offers.add(offers.removeAt(0)));
  }

  /// Accept: the job moves to Home (today's jobs) and the next offer shows.
  void _accept() {
    final store = context.store, router = context.router;
    if (handled || offers.isEmpty) return;
    final top = offers.first;
    if (!store.signedUp) {
      // First job: a quick KYC before accepting.
      handled = true;
      store.set(() => store.kycFromJob = true);
      router.replace(const [R(N.steps)]);
      return;
    }
    store.acceptOffer(top.job);
    Device.buzz();
    setState(() {
      offers.removeAt(0);
      acceptedHere++;
    });
    if (offers.isEmpty) {
      handled = true;
      store.set(() => store.toast = store.t('Added to your jobs', 'आपके कामों में जोड़ा गया', 'మీ పనుల్లో చేర్చబడింది'));
      Future.delayed(const Duration(milliseconds: 400), router.home);
    }
  }

  Widget _fact(WIcon icon, String big, String small) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WIconView(icon, size: 20, color: WColor.primaryStrong),
          const SizedBox(height: 4),
          WText(big, WType.section, weight: semibold, maxLines: 1),
          const SizedBox(height: 4),
          WText(small, WType.caption, color: WColor.heading),
        ],
      ),
    ),
  );

  Widget _card(_Offer o, int i) {
    final store = context.store;
    final j = o.job;
    final isTop = i == 0;
    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WColor.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isTop ? 0.12 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WIconBox(j.isBike ? WIcon.bike : WIcon.car, size: 72, radius: 16, iconSize: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [WText(store.t('Your pay', 'आपकी कमाई', 'మీ సంపాదన'), WType.body), WText(Fmt.rupees(j.pay), WType.bigMoney, mono: true)],
                ),
              ),
              if (!isTop) WText('0:${_left(o).ceil().toString().padLeft(2, '0')}', WType.label, mono: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _fact(WIcon.location, j.distance, store.t('away', 'दूर', 'దూరం')),
              const SizedBox(width: 8),
              _fact(WIcon.layers, j.floor, store.t('Floor', 'फ्लोर', 'ఫ్లోర్')),
              const SizedBox(width: 8),
              _fact(WIcon.clock, j.window, store.t('Today', 'आज', 'ఈరోజు')),
            ],
          ),
          const SizedBox(height: 14),
          // Where the job is: society first, then the full address.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: WIconView(WIcon.location, size: 18, color: WColor.primaryStrong),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [WText(j.society, WType.title, size: 17.5), const SizedBox(height: 3), WText(j.fullAddress, WType.caption, size: 14)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [WPlate(j.plate), const SizedBox(width: 10), WText(j.type, WType.caption)]),
          const SizedBox(height: 14),
          BookingChip(job: j),
          if (widget.batched && isTop && offers.length == 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WIconView(WIcon.list, size: 15, color: WColor.onSuccess),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WRich(
                      [
                        (store.t('Next to your current job. ', 'आपके अभी के काम के पास। ', 'మీ ప్రస్తుత పని పక్కనే. '), bold),
                        (store.t('Starts after you finish at 8:55 AM.', '8:55 AM पर ख़त्म होने के बाद शुरू।', '8:55 AM కి పూర్తయ్యాక మొదలు.'), null),
                      ],
                      WType.caption,
                      color: WColor.onSuccess,
                      size: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final dx = isTop ? drag : 0.0;
    Widget out = AnimatedContainer(
      duration: Duration(milliseconds: isTop && drag != 0 && drag > -600 ? 0 : 350),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translateByDouble(dx, i * 14.0, 0, 1)
        ..rotateZ(isTop ? drag / 22 * 3.14159 / 180 : 0),
      transformAlignment: Alignment.bottomCenter,
      child: Transform.scale(
        scale: 1 - i * 0.05,
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: i == 0
              ? 1
              : i == 1
              ? 0.85
              : 0.6,
          child: card,
        ),
      ),
    );
    if (isTop && drag < -30) {
      out = Stack(
        children: [
          out,
          Positioned(
            top: 18,
            right: 18,
            child: Transform.rotate(
              angle: 0.2,
              child: Opacity(
                opacity: ((-drag - 30) / 60).clamp(0, 1),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const ShapeDecoration(
                    shape: StadiumBorder(side: BorderSide(color: WColor.destructive, width: 2)),
                  ),
                  alignment: Alignment.center,
                  child: WText(store.t('LATER', 'बाद में', 'తర్వాత'), WType.label, color: WColor.destructive, weight: bold),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // Phones: swipe the top card left to see the next job. The web has no swipes.
    if (isTop && !kIsWeb) {
      out = GestureDetector(
        onHorizontalDragUpdate: (d) => setState(() => drag = (drag + d.delta.dx).clamp(-600, 40)),
        onHorizontalDragEnd: (d) {
          if (drag < -110 || (d.primaryVelocity ?? 0) < -800) {
            setState(() => drag = -600);
            Future.delayed(const Duration(milliseconds: 220), () {
              if (!mounted) return;
              setState(() => drag = 0);
              _reject();
            });
          } else {
            setState(() => drag = 0);
          }
        },
        child: out,
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pad = MediaQuery.paddingOf(context);
    final top = offers.isEmpty ? null : offers.first;
    final shown = offers.take(3).toList();
    return Material(
      color: WColor.primary,
      child: Padding(
        padding: EdgeInsets.fromLTRB(WSpace.gutterCaptain, pad.top, WSpace.gutterCaptain, pad.bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Pressable(
                    label: store.t('Close', 'बंद करें', 'మూసివేయండి'),
                    onTap: _leave,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const WIconView(WIcon.close, size: 16, color: WColor.white, weight: semibold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  WText(offers.length > 1 ? store.t('New jobs', 'नए काम', 'కొత్త పనులు') : store.t('New job', 'नया काम', 'కొత్త పని'), WType.screen, color: WColor.white, size: 23),
                  if (offers.length > 1) ...[
                    const SizedBox(width: 10),
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: const ShapeDecoration(color: WColor.white, shape: StadiumBorder()),
                      alignment: Alignment.center,
                      child: WText('1 / ${offers.length}', WType.label, color: WColor.primaryStrong),
                    ),
                  ],
                  const Spacer(),
                  if (top != null) WText('0:${_left(top).ceil().toString().padLeft(2, '0')}', WType.screen, color: WColor.white, size: 23, mono: true),
                ],
              ),
            ),
            if (top != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(color: Colors.white38),
                        FractionallySizedBox(
                          widthFactor: _left(top) / _offerSeconds,
                          child: Container(color: _left(top) / _offerSeconds < 0.25 ? const Color(0xFFFFD27A) : WColor.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Cards scroll on short screens so Reject and Accept always stay in view.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = shown.length - 1; i >= 0; i--)
                          i == 0
                              ? KeyedSubtree(key: ValueKey(shown[i].job.id), child: _card(shown[i], i))
                              : Positioned(key: ValueKey(shown[i].job.id), left: 0, right: 0, top: 0, child: _card(shown[i], i)),
                        if (newPill)
                          Positioned(
                            top: -16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: FadeIn(
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: const ShapeDecoration(
                                    color: WColor.white,
                                    shape: StadiumBorder(),
                                    shadows: [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))],
                                  ),
                                  alignment: Alignment.center,
                                  child: WText(store.t('+1 new job', '+1 नया काम', '+1 కొత్త పని'), WType.label, color: WColor.primaryStrong),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (offers.length > 1)
                      Padding(
                        padding: EdgeInsets.only(top: (offers.length.clamp(1, 3) - 1) * 12.0 + 18),
                        child: kIsWeb
                            // Web: a button instead of the swipe (same result as Reject: this card goes to the back).
                            ? Center(
                                child: Pressable(
                                  onTap: _reject,
                                  child: Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: const ShapeDecoration(color: Colors.white24, shape: StadiumBorder()),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        WText(store.t('See next job', 'अगला काम देखें', 'తదుపరి పని చూడండి'), WType.label, color: WColor.white, size: 14),
                                        const SizedBox(width: 6),
                                        const WIconView(WIcon.arrowRight, size: 14, color: WColor.white, weight: semibold),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const WIconView(WIcon.swipe, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  WText(
                                    store.t('Swipe left to see the next job', 'अगला काम देखने के लिए बाएँ स्वाइप करें', 'తదుపరి పని చూడటానికి ఎడమకు స్వైప్ చేయండి'),
                                    WType.caption,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ),
            if (acceptedHere > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const WIconView(WIcon.checkCircle, size: 16, color: WColor.white),
                    const SizedBox(width: 8),
                    WText(store.t('$acceptedHere accepted · on your Home', '$acceptedHere स्वीकार · होम पर', '$acceptedHere అంగీకరించారు · హోమ్‌లో'), WType.label, color: WColor.white),
                  ],
                ),
              ),
            const Padding(padding: EdgeInsets.only(bottom: 12), child: WorkAreaChip(onDark: true)),
            // Reject on the left, Accept (primary) on the right.
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Pressable(
                    enabled: offers.isNotEmpty,
                    onTap: _reject,
                    child: Container(
                      height: 72,
                      decoration: ShapeDecoration(
                        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.85), width: 2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const WIconView(WIcon.close, size: 18, color: WColor.white, weight: semibold),
                          const SizedBox(width: 8),
                          WText(store.t('Reject', 'मना करें', 'తిరస్కరించు'), WType.section, color: WColor.white, weight: semibold),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WButton(store.t('Accept', 'स्वीकार करें', 'అంగీకరించండి'), icon: WIcon.check, kind: ButtonKind.success, size: ButtonSize.accept, enabled: offers.isNotEmpty, onTap: _accept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: W23 Job went to someone else

class JobMissedScreen extends StatelessWidget {
  const JobMissedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      children: [
        Expanded(
          child: WFullState(
            icon: WIcon.clock,
            tone: Tone.mute,
            captain: true,
            title: store.t('Job went to someone else', 'काम किसी और को मिल गया', 'పని వేరొకరికి వెళ్ళింది'),
            message: store.t(
              'Time ran out. Keep the app open. Next job comes soon.',
              'समय ख़त्म हो गया। ऐप खुला रखें। अगला काम जल्दी आएगा।',
              'సమయం ముగిసింది. యాప్ తెరిచి ఉంచండి. త్వరలో పని వస్తుంది.',
            ),
            primary: store.t('Back to home', 'होम पर वापस', 'హోమ్‌కి తిరిగి'),
            onPrimary: context.router.home,
          ),
        ),
      ],
    );
  }
}

// MARK: W25 Today's jobs

class JobsTab extends StatelessWidget {
  const JobsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    Widget status(JobStatus s) => switch (s) {
      JobStatus.now => WBadge(store.t('Now', 'अभी', 'ఇప్పుడు'), tone: Tone.info, icon: WIcon.drop),
      JobStatus.next => WBadge(store.t('Next', 'अगला', 'తదుపరి'), tone: Tone.info, icon: WIcon.check),
      JobStatus.done => WBadge(store.t('Done', 'पूरा', 'పూర్తి'), tone: Tone.ok, icon: WIcon.sparkle),
    };
    return ColoredBox(
      color: WColor.canvas,
      child: ListView(
        padding: EdgeInsets.fromLTRB(WSpace.gutterCaptain, MediaQuery.paddingOf(context).top, WSpace.gutterCaptain, 20),
        children: [
          WTitle(store.t('Today’s jobs', 'आज के काम', 'ఈరోజు పనులు'), top: 22, bottom: 16),
          if (!store.signedUp) ...[
            GuestNotice(
              store.t(
                'This is an example day. Your real jobs show here once you start.',
                'यह एक उदाहरण दिन है। शुरू करने के बाद आपके असली काम यहाँ दिखेंगे।',
                'ఇది ఒక ఉదాహరణ రోజు. మొదలుపెట్టాక మీ నిజమైన పనులు ఇక్కడ కనిపిస్తాయి.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final j in store.queue) ...[
            WCard(
              onTap: () {
                if (j.status == JobStatus.now && store.signedUp) router.go(N.goToVehicle);
              },
              child: Row(
                children: [
                  SizedBox(width: 46, child: WText(j.time, WType.title, size: 17, mono: true)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WPlate(j.plate),
                        const SizedBox(height: 6),
                        WText(j.society, WType.title, size: 16),
                        const SizedBox(height: 6),
                        WText(j.spot, WType.caption),
                        const SizedBox(height: 6),
                        status(j.status),
                      ],
                    ),
                  ),
                  WText(Fmt.rupees(j.pay), WType.section, weight: semibold, mono: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// MARK: W26 Go to vehicle

class GoToVehicleScreen extends StatefulWidget {
  const GoToVehicleScreen({super.key});
  @override
  State<GoToVehicleScreen> createState() => _GoToVehicleScreenState();
}

class _GoToVehicleScreenState extends State<GoToVehicleScreen> {
  @override
  void initState() {
    super.initState();
    // Demo: "I don't show up" switch in Screens runs late → slot over → cancelled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.store, router = context.router;
      if (!store.noShowDemo) return;
      store.startNoShowDemo(() {
        if (router.isAt(N.goToVehicle)) router.replace(const [R(N.noShowCancelled)]);
      });
    });
  }

  Widget _place(WIcon icon, String big, String small) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WIconView(icon, size: 20, color: WColor.primaryStrong),
          const SizedBox(height: 4),
          WText(big, WType.section, weight: semibold, maxLines: 2),
          const SizedBox(height: 4),
          WText(small, WType.caption, color: WColor.heading),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final j = store.current;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WAppBar(
        title: store.t('Go to vehicle', 'गाड़ी तक जाएं', 'వాహనం దగ్గరికి వెళ్ళండి'),
        subtitle: '${store.t('Reach by', 'पहुँचें', 'చేరుకోండి')} ${j.reachBy}',
        onLeading: router.home,
        onTrailing: () => router.go(N.help),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WFooter(
            child: WButton(
              store.t('I’m at the vehicle', 'मैं गाड़ी के पास हूँ', 'నేను వాహనం దగ్గర ఉన్నాను'),
              size: ButtonSize.captain,
              onTap: () {
                store.captainArrived();
                store.resetJob();
                store.set(() => store.ownerNoteHeard = false);
                // The owner's voice note plays first (must listen once).
                router.go(N.ownerNote);
              },
            ),
          ),
          Container(
            color: WColor.white,
            padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 0, WSpace.gutterCaptain, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                WLink(store.t('Can’t get in', 'अंदर नहीं जा पा रहे', 'లోపలికి వెళ్ళలేకపోతున్నాను'), onTap: () => router.go(N.gateProblem)),
                WLink(store.t('Can’t find vehicle', 'गाड़ी नहीं मिल रही', 'వాహనం కనబడట్లేదు'), onTap: () => router.go(N.cantFind)),
              ],
            ),
          ),
        ],
      ),
      children: [
        if (store.slotEnded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: WBanner(
              tone: Tone.error,
              icon: WIcon.warning,
              title: store.t('Slot is over.', 'समय खत्म।', 'సమయం ముగిసింది.'),
              text: store.t(
                'Tap I’m at the vehicle now, or tell us in Help. Otherwise the job is cancelled and a penalty applies.',
                'अभी ‘मैं गाड़ी के पास हूँ’ दबाएं या मदद में बताएं। नहीं तो काम रद्द होगा और जुर्माना लगेगा।',
                'ఇప్పుడే ‘నేను వాహనం దగ్గర ఉన్నాను’ నొక్కండి లేదా సహాయంలో చెప్పండి. లేదంటే పని రద్దు, జరిమానా.',
              ),
              actionTitle: store.t('Get help', 'मदद लें', 'సహాయం పొందండి'),
              onAction: () => router.push(const R(N.helpFlow, topic: HelpTopic.job)),
            ),
          )
        else if (store.jobLate)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: WBanner(
              tone: Tone.wait,
              icon: WIcon.clock,
              title: store.t('You’re late.', 'आप लेट हैं।', 'మీరు ఆలస్యం.'),
              text: store.t('Reach now. −₹1 for every late minute.', 'अभी पहुँचें। हर लेट मिनट पर −₹1।', 'ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1.'),
            ),
          ),
        const SizedBox(height: 10),
        WCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address + plate on the left, the owner's vehicle photo on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: WIconView(WIcon.location, size: 17, color: WColor.primaryStrong),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [WText(j.society, WType.title, size: 18), const SizedBox(height: 3), WText(j.fullAddress, WType.caption, size: 13.5)],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        WPlate(j.plate),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Pressable(
                    label: store.t('Vehicle photos', 'गाड़ी की फ़ोटो', 'వాహనం ఫోటోలు'),
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: true,
                        pageBuilder: (c, a, b) => CaptainScope(
                          store: store,
                          router: router,
                          child: VehiclePhotosViewer(isBike: j.isBike, plate: j.plate),
                        ),
                        transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 112,
                        height: 132,
                        child: Stack(
                          children: [
                            Positioned.fill(child: VehiclePhotoView(side: 0, isBike: j.isBike, compact: true)),
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  height: 22,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: const ShapeDecoration(color: Color(0x8C000000), shape: StadiumBorder()),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      WIconView(WIcon.photos, size: 10, color: WColor.white, weight: semibold),
                                      SizedBox(width: 4),
                                      WText('4', WType.small, size: 11, weight: semibold, color: WColor.white),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const WIconView(WIcon.expand, size: 10, color: WColor.white, weight: bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BookingChip(job: j),
              const SizedBox(height: 14),
              Row(
                children: [
                  _place(WIcon.building, j.tower, store.t('Building', 'बिल्डिंग', 'భవనం')),
                  const SizedBox(width: 8),
                  _place(WIcon.layers, j.floor, store.t('Floor', 'फ्लोर', 'ఫ్లోర్')),
                  const SizedBox(width: 8),
                  _place(WIcon.parking, j.slot.isEmpty ? '—' : j.slot, store.t('Slot', 'स्लॉट', 'స్లాట్')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Pressable(
          onTap: () => router.go(N.gateProblem),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: outlinedDecoration(radius: 16),
            child: Row(
              children: [
                const WIconView(WIcon.door, size: 22),
                const SizedBox(width: 12),
                Expanded(child: WText(store.t('Gate pass', 'गेट पास', 'గేట్ పాస్'), WType.title)),
                WBadge(store.t('Ready', 'तैयार', 'సిద్ధం'), tone: Tone.ok, icon: WIcon.check),
                const SizedBox(width: 12),
                const WIconView(WIcon.chevron, size: 12, color: WColor.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// MARK: W27 Can't get in

class GateProblemScreen extends StatelessWidget {
  const GateProblemScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Can’t get in', 'अंदर नहीं जा पा रहे', 'లోపలికి వెళ్ళలేకపోతున్నాను')),
      footer: WFooter(
        child: WButton(store.t('Call owner', 'मालिक को कॉल करें', 'యజమానికి కాల్ చేయండి'), icon: WIcon.phone, size: ButtonSize.captain, onTap: () => Support.call()),
      ),
      children: [
        const SizedBox(height: 30),
        const Center(child: WStateCircle(WIcon.door, tone: Tone.wait, size: 112)),
        const SizedBox(height: 12),
        WText(store.t('Show this at the gate', 'यह गेट पर दिखाएं', 'ఇది గేట్ వద్ద చూపించండి'), WType.section, weight: semibold, size: 23, align: TextAlign.center),
        const SizedBox(height: 12),
        WBody(store.t('Owner’s MyGate pass for today.', 'आज के लिए मालिक का MyGate पास।', 'ఈరోజు కోసం యజమాని MyGate పాస్.'), center: true),
        const SizedBox(height: 26),
        Container(
          height: 196,
          decoration: BoxDecoration(
            color: WColor.photo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WColor.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const WIconView(WIcon.image, size: 32, color: WColor.secondary),
              const SizedBox(height: 10),
              WText('MyGate pass · ${store.current.owner}, ${store.current.tower}', WType.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// MARK: W28 Can't find vehicle

class CantFindScreen extends StatelessWidget {
  const CantFindScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget option(WIcon icon, String title) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: () => context.router.go(N.ownerCancelled),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: outlinedDecoration(radius: 16),
          child: Row(
            children: [
              WIconBox(icon, size: 52),
              const SizedBox(width: 16),
              Expanded(child: WText(title, WType.value, size: 18)),
            ],
          ),
        ),
      ),
    );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Can’t find vehicle', 'गाड़ी नहीं मिल रही', 'వాహనం కనబడట్లేదు')),
      footer: WFooter(
        child: WButton(store.t('Call owner', 'मालिक को कॉल करें', 'యజమానికి కాల్ చేయండి'), icon: WIcon.phone, size: ButtonSize.captain, onTap: () => Support.call()),
      ),
      children: [
        WTitle(store.t('What do you see?', 'आपको क्या दिख रहा है?', 'మీకు ఏం కనిపిస్తోంది?'), top: 10, bottom: 16),
        option(WIcon.parking, store.t('Slot is empty', 'स्लॉट खाली है', 'స్లాట్ ఖాళీగా ఉంది')),
        option(WIcon.car, store.t('Different car in slot', 'स्लॉट में दूसरी गाड़ी है', 'స్లాట్‌లో వేరే కారు ఉంది')),
        option(WIcon.layers, store.t('Can’t find the floor', 'फ्लोर नहीं मिल रहा', 'ఫ్లోర్ కనబడట్లేదు')),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: WText(
            store.t(
              'We tell the owner and wait 10 minutes. You still get ₹[WAIT FEE] if the car isn’t there.',
              'हम मालिक को बताएंगे और 10 मिनट रुकेंगे। गाड़ी न मिले तो भी आपको ₹[WAIT FEE] मिलेंगे।',
              'మేము యజమానికి చెప్పి 10 నిమిషాలు ఆగుతాము. కారు లేకపోయినా మీకు ₹[WAIT FEE] వస్తుంది.',
            ),
            WType.caption,
          ),
        ),
      ],
    );
  }
}

// MARK: W29 Owner cancelled

class OwnerCancelledScreen extends StatefulWidget {
  const OwnerCancelledScreen({super.key});
  @override
  State<OwnerCancelledScreen> createState() => _OwnerCancelledScreenState();
}

class _OwnerCancelledScreenState extends State<OwnerCancelledScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.store.notify(WNotifKind.ownerCancelled, job: context.store.current, deliver: false));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      children: [
        Expanded(
          child: WFullState(
            icon: WIcon.close,
            tone: Tone.mute,
            captain: true,
            title: store.t('Owner cancelled this job', 'मालिक ने यह काम रद्द किया', 'యజమాని ఈ పని రద్దు చేశారు'),
            message: store.t(
              'You were on the way, so you get ₹[CANCELLATION FEE] for the trip.',
              'आप रास्ते में थे, इसलिए आपको सफ़र के ₹[CANCELLATION FEE] मिलेंगे।',
              'మీరు దారిలో ఉన్నారు, కాబట్టి ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది.',
            ),
            primary: store.t('Back to jobs', 'कामों पर वापस', 'పనులకు తిరిగి'),
            onPrimary: () {
              context.router.home();
              context.router.tab = 1;
            },
          ),
        ),
      ],
    );
  }
}
