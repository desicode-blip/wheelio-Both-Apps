// Notifications, the live banner and toast, phone and UPI changes, and the no-show result.
// Ported from apps/ios/Captain/Screens/WAccountScreens.swift.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';
import 'parts.dart';

String _blockedTitle(CaptainStore s) => kIsWeb
    ? s.t('Blocked in browser settings.', 'ब्राउज़र सेटिंग में बंद है।', 'బ్రౌజర్ సెట్టింగ్స్‌లో బ్లాక్ అయింది.')
    : s.t('Blocked in phone settings.', 'फ़ोन सेटिंग में बंद है।', 'ఫోన్ సెట్టింగ్స్‌లో బ్లాక్ అయింది.');

// MARK: Notification list

class WNotificationsScreen extends StatefulWidget {
  const WNotificationsScreen({super.key});
  @override
  State<WNotificationsScreen> createState() => _WNotificationsScreenState();
}

class _WNotificationsScreenState extends State<WNotificationsScreen> {
  WNotifCategory? filter;

  void _menu(WNotif n) {
    final store = context.store;
    showWActions(context, title: store.title(n), cancel: store.t('Cancel', 'रद्द करें', 'రద్దు'), actions: [
      n.read ? AlertAction(store.t('Mark unread', '‘नहीं पढ़ा’ करें', 'చదవనిదిగా'), onTap: () => store.markUnread(n.id)) : AlertAction(store.t('Mark read', 'पढ़ा हुआ करें', 'చదివినట్లు'), onTap: () => store.markRead(n.id)),
      AlertAction(store.t('Delete', 'हटाएं', 'తొలగించండి'), destructive: true, onTap: () => store.deleteNotification(n.id)),
    ]);
  }

  String _relative(DateTime d) {
    final store = context.store;
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return store.t('Now', 'अभी', 'ఇప్పుడు');
    if (s < 3600) return '${s ~/ 60} min';
    if (isToday(d)) return '${s ~/ 3600} h';
    if (isYesterday(d)) return Fmt.time(d);
    return Fmt.date(d);
  }

  Widget _row(WNotif n) {
    final store = context.store, router = context.router;
    return Pressable(
      feedback: false,
      label: '${store.title(n)}. ${store.body(n)}',
      onTap: () {
        final m = openWNotif(n, store, router);
        if (m != null) showWAlert(context, title: m);
      },
      onLongPress: () => _menu(n),
      child: Container(
        color: n.read ? Colors.transparent : WColor.primaryTint.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WIconBox(n.kind.icon, size: 44, tone: n.kind.tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: WText(store.title(n), WType.title, weight: n.read ? FontWeight.w400 : semibold, size: 16.5)),
                const SizedBox(width: 6),
                WText(_relative(n.date), WType.small, color: WColor.muted),
              ]),
              const SizedBox(height: 4),
              WText(store.body(n), WType.caption, size: 14.5, maxLines: 3),
            ]),
          ),
          const SizedBox(width: 8),
          // Web: no long-press, so delete / mark unread sit behind a "⋯" button.
          if (kIsWeb)
            Pressable(label: store.t('More', 'और', 'మరిన్ని'), onTap: () => _menu(n), child: const SizedBox(width: 28, height: 28, child: Center(child: WIconView(WIcon.more, size: 18, color: WColor.secondary))))
          else
            Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? Colors.transparent : WColor.primary)),
        ]),
      ),
    );
  }

  Widget? _statusBanner() {
    final store = context.store;
    if (!store.notificationsOn) {
      return WBanner(
        tone: Tone.wait,
        icon: WIcon.bellSlash,
        title: store.t('Alerts are off.', 'अलर्ट बंद हैं।', 'అలర్ట్‌లు ఆఫ్‌లో ఉన్నాయి.'),
        text: store.online ? store.t('New jobs still ring while you’re Online.', 'ऑनलाइन रहते नए काम फिर भी बजेंगे।', 'ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు మోగుతాయి.') : store.t('Messages still come here.', 'संदेश फिर भी यहाँ आएंगे।', 'సందేశాలు ఇక్కడికి వస్తాయి.'),
        actionTitle: store.t('Turn on', 'चालू करें', 'ఆన్ చేయండి'),
        onAction: () => store.setNotifications(true),
      );
    }
    if (store.systemPermission == Permission.denied) {
      return WBanner(tone: Tone.error, icon: WIcon.bellSlash, title: _blockedTitle(store), text: store.t('You may miss new jobs. Allow notifications.', 'नए काम छूट सकते हैं। सूचनाएं चालू करें।', 'కొత్త పనులు మిస్ కావచ్చు. నోటిఫికేషన్లు అనుమతించండి.'));
    }
    final until = store.notifPrefs.mutedUntil;
    if (store.notifPrefs.isMuted && until != null) {
      return WBanner(
        tone: Tone.info,
        icon: WIcon.speakerOff,
        title: '${store.t('Muted till', 'बंद है', 'మ్యూట్')} ${Fmt.time(until)}',
        text: store.t('New jobs still ring while Online.', 'ऑनलाइन रहते नए काम फिर भी बजेंगे।', 'ఆన్‌లైన్‌లో కొత్త పనులు మోగుతాయి.'),
        actionTitle: store.t('Unmute', 'चालू करें', 'అన్‌మ్యూట్'),
        onAction: () => store.mute(null),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final items = store.notifications.where((n) => filter == null || n.kind.category == filter).toList();
    final sections = <(String, List<WNotif>)>[
      (store.t('Today', 'आज', 'ఈరోజు'), items.where((n) => isToday(n.date)).toList()),
      (store.t('Yesterday', 'कल', 'నిన్న'), items.where((n) => isYesterday(n.date)).toList()),
      (store.t('Earlier', 'पहले', 'ఇంతకు ముందు'), items.where((n) => !isToday(n.date) && !isYesterday(n.date)).toList()),
    ].where((s) => s.$2.isNotEmpty).toList();
    final banner = _statusBanner();
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WAppBar(title: store.t('Notifications', 'सूचनाएं', 'నోటిఫికేషన్లు'), trailing: WIcon.gear, onLeading: router.pop, onTrailing: () => router.go(N.notificationSettings), padding: const EdgeInsets.fromLTRB(4, 4, 4, 0)),
      children: [
        if (banner != null) Padding(padding: const EdgeInsets.only(top: 10), child: banner),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              WChip(store.t('All', 'सभी', 'అన్నీ'), selected: filter == null, height: 40, onTap: () => setState(() => filter = null)),
              for (final c in WNotifCategory.values) ...[const SizedBox(width: 8), WChip(store.categoryTitle(c), selected: filter == c, height: 40, onTap: () => setState(() => filter = c))],
            ]),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Column(children: [
              const WStateCircle(WIcon.bell, size: 80),
              const SizedBox(height: 12),
              WText(store.t('Nothing here yet', 'अभी कुछ नहीं', 'ఇంకా ఏమీ లేదు'), WType.section, weight: semibold),
              const SizedBox(height: 12),
              WBody(store.t('New jobs, money and level updates show up here.', 'नए काम, पैसे और लेवल की खबरें यहाँ दिखेंगी।', 'కొత్త పనులు, డబ్బు, స్థాయి వివరాలు ఇక్కడ కనిపిస్తాయి.'), center: true),
            ]),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              WText(store.unreadCount == 0 ? store.t('All read', 'सब पढ़ लिया', 'అన్నీ చదివారు') : store.t('${store.unreadCount} new', '${store.unreadCount} नई', '${store.unreadCount} కొత్తవి'), WType.label),
              const Spacer(),
              if (store.unreadCount > 0) WLink(store.t('Mark all read', 'सब पढ़ा हुआ करें', 'అన్నీ చదివినట్లు'), k: WType.caption, onTap: store.markAllRead),
            ]),
          ),
          for (final s in sections) ...[
            Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: WText(s.$1, WType.label, color: WColor.muted)),
            Container(
              decoration: cardDecoration(radius: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [for (final (i, n) in s.$2.indexed) ...[_row(n), if (i < s.$2.length - 1) const WDivider(inset: 70)]]),
            ),
          ],
          const SizedBox(height: 16),
          WButton(
            store.t('Clear all', 'सब हटाएं', 'అన్నీ తొలగించండి'),
            kind: ButtonKind.text,
            onTap: () => showWActions(context,
                title: store.t('Clear all messages?', 'सब संदेश हटाएं?', 'అన్ని సందేశాలు తొలగించాలా?'),
                message: store.t('Your jobs and money are not affected.', 'आपके काम और पैसे पर असर नहीं होगा।', 'మీ పనులు, డబ్బుపై ప్రభావం ఉండదు.'),
                cancel: store.t('Cancel', 'रद्द करें', 'రద్దు'),
                actions: [AlertAction(store.t('Clear all', 'सब हटाएं', 'అన్నీ తొలగించండి'), destructive: true, onTap: store.clearNotifications)]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: WText(
              kIsWeb
                  ? store.t('Use ⋯ on a message to delete it or mark it unread.', 'संदेश पर ⋯ दबाएं: हटाएं या ‘नहीं पढ़ा’ करें।', 'సందేశంపై ⋯ నొక్కండి: తొలగించండి లేదా చదవనిదిగా మార్చండి.')
                  : store.t('Press and hold a message to delete it or mark it unread.', 'किसी संदेश को दबाकर रखें: हटाएं या ‘नहीं पढ़ा’ करें।', 'సందేశాన్ని నొక్కి పట్టుకోండి: తొలగించండి లేదా చదవనిదిగా మార్చండి.'),
              WType.small,
              color: WColor.muted,
              align: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}

// MARK: Notification settings

class WNotificationSettingsScreen extends StatelessWidget {
  const WNotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final on = store.notificationsOn;
    final prefs = store.notifPrefs;
    Widget toggleCard(bool value, ValueChanged<bool> set, String title, String sub, {double top = 0, bool enabled = true}) => Padding(
          padding: EdgeInsets.only(top: top),
          child: WCard(
            radius: 16,
            padding: 16,
            child: WToggleRow(
              on: value,
              enabled: enabled,
              onChanged: set,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(title, WType.title, size: 18), const SizedBox(height: 2), WText(sub, WType.caption)]),
            ),
          ),
        );
    final until = prefs.mutedUntil;
    return OnAppear(
      onAppear: store.refreshSystemPermission,
      child: WScreen(
        canvas: true,
        gutter: WSpace.gutterCaptain,
        header: WHeader(title: store.t('Notifications', 'सूचनाएं', 'నోటిఫికేషన్లు'), help: false),
        children: [
          toggleCard(on, store.setNotifications, store.t('Alerts', 'अलर्ट', 'అలర్ట్‌లు'),
              on ? store.t('Banner and sound for updates.', 'खबरों पर बैनर और आवाज़।', 'అప్‌డేట్‌లకు బ్యానర్, శబ్దం.') : store.t('Off. Messages still come to the list.', 'बंद। संदेश लिस्ट में आएंगे।', 'ఆఫ్. సందేశాలు లిస్ట్‌లో వస్తాయి.'),
              top: 10),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const WIconView(WIcon.bell, size: 17, color: WColor.heading),
              const SizedBox(width: 12),
              Expanded(
                child: WText(store.t('New jobs always ring while you’re Online. To stop them, go Offline.', 'ऑनलाइन रहते नए काम हमेशा बजेंगे। रोकने के लिए ऑफ़लाइन जाएं।', 'ఆన్‌లైన్‌లో ఉన్నప్పుడు కొత్త పనులు ఎప్పుడూ మోగుతాయి. ఆపడానికి ఆఫ్‌లైన్‌కి వెళ్ళండి.'), WType.caption,
                    color: WColor.inverse, size: 14.5),
              ),
            ]),
          ),
          if (store.systemPermission == Permission.denied && on)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: WBanner(tone: Tone.error, icon: WIcon.bellSlash, title: _blockedTitle(store), text: store.t('Allow notifications so the phone rings for jobs.', 'सूचनाएं चालू करें ताकि काम पर फ़ोन बजे।', 'పనులకు ఫోన్ మోగాలంటే నోటిఫికేషన్లు అనుమతించండి.')),
            ),
          IgnorePointer(
            ignoring: !on,
            child: Opacity(
              opacity: on ? 1 : 0.45,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                toggleCard(prefs.soundOn, (v) => store.set(() => prefs.soundOn = v), store.t('Sound', 'आवाज़', 'శబ్దం'), store.t('Off: banner only, no sound.', 'बंद: सिर्फ़ बैनर, आवाज़ नहीं।', 'ఆఫ్: బ్యానర్ మాత్రమే, శబ్దం లేదు.'), top: 20),
                Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: WText(store.t('Mute for a while', 'कुछ देर बंद करें', 'కాసేపు మ్యూట్'), WType.label)),
                WCard(
                  radius: 16,
                  padding: 16,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (prefs.isMuted && until != null) ...[
                      Row(children: [
                        const WIconView(WIcon.speakerOff, size: 16, color: WColor.primaryStrong),
                        const SizedBox(width: 8),
                        Expanded(child: WText('${store.t('Muted till', 'बंद है', 'మ్యూట్')} ${Fmt.day(until)}, ${Fmt.time(until)}', WType.bodyStrong)),
                        WLink(store.t('Unmute', 'चालू करें', 'అన్‌మ్యూట్'), k: WType.caption, onTap: () => store.mute(null)),
                      ]),
                      const SizedBox(height: 12),
                    ],
                    Row(children: [
                      Expanded(child: WChip(store.t('1 hour', '1 घंटा', '1 గంట'), height: 44, onTap: () => store.mute(3600))),
                      const SizedBox(width: 8),
                      Expanded(child: WChip(store.t('8 hours', '8 घंटे', '8 గంటలు'), height: 44, onTap: () => store.mute(8 * 3600))),
                      const SizedBox(width: 8),
                      Expanded(child: WChip(store.t('Till morning', 'सुबह तक', 'ఉదయం వరకు'), height: 44, onTap: store.muteUntilMorning)),
                    ]),
                  ]),
                ),
                toggleCard(prefs.quietHours, (v) => store.set(() => prefs.quietHours = v), store.t('Quiet at night', 'रात में शांत', 'రాత్రి నిశ్శబ్దం'), store.t('10 PM – 7 AM: no sound.', 'रात 10 – सुबह 7: आवाज़ नहीं।', 'రాత్రి 10 – ఉదయం 7: శబ్దం లేదు.'), top: 12),
                Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: WText(store.t('What you hear about', 'किस बारे में', 'వేటి గురించి'), WType.label)),
                WCard(
                  radius: 16,
                  padding: 16,
                  child: Column(children: [
                    for (final (i, c) in WNotifCategory.values.indexed) ...[
                      WToggleRow(
                        on: c == WNotifCategory.account || !prefs.off.contains(c),
                        enabled: c != WNotifCategory.account,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onChanged: (v) => store.set(() => v ? prefs.off.remove(c) : prefs.off.add(c)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(store.categoryTitle(c), WType.rowTitle, size: 17), const SizedBox(height: 2), WText(store.categoryDetail(c), WType.caption)]),
                      ),
                      if (i < WNotifCategory.values.length - 1) const WDivider(),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: Banner + toast over every screen

class WLiveBanner extends StatefulWidget {
  const WLiveBanner({super.key});
  @override
  State<WLiveBanner> createState() => _WLiveBannerState();
}

class _WLiveBannerState extends State<WLiveBanner> {
  Timer? _bannerTimer;
  Timer? _toastTimer;
  String? _bannerId;
  String? _toast;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final n = store.liveBanner;
    final t = store.toast;
    if (n?.id != _bannerId) {
      _bannerId = n?.id;
      _bannerTimer?.cancel();
      if (n != null) {
        _bannerTimer = Timer(const Duration(seconds: 5), () {
          if (store.liveBanner?.id == n.id) store.set(() => store.liveBanner = null);
        });
      }
    }
    if (t != _toast) {
      _toast = t;
      _toastTimer?.cancel();
      if (t != null) {
        _toastTimer = Timer(const Duration(seconds: 3), () {
          if (store.toast == t) store.set(() => store.toast = null);
        });
      }
    }
    final pad = MediaQuery.paddingOf(context);
    return Stack(children: [
      if (n != null)
        Positioned(
          key: ValueKey(n.id),
          left: 12,
          right: 12,
          top: pad.top + 4,
          child: FadeIn(
            offset: -40,
            child: GestureDetector(
              // Phones: swipe the banner up to dismiss it. Web: the × button does it.
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) store.set(() => store.liveBanner = null);
              },
              child: Pressable(
                onTap: () {
                  final m = openWNotif(n, store, router);
                  if (m != null) showWAlert(context, title: m);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: WColor.shadow, blurRadius: 16, offset: Offset(0, 6))]),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    WIconBox(n.kind.icon, size: 40, tone: n.kind.tone, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(store.title(n), WType.title, size: 16), const SizedBox(height: 2), WText(store.body(n), WType.caption, maxLines: 2)])),
                    if (kIsWeb)
                      Pressable(
                        label: store.t('Dismiss', 'हटाएं', 'మూసివేయండి'),
                        onTap: () => store.set(() => store.liveBanner = null),
                        child: const Padding(padding: EdgeInsets.only(left: 6), child: WIconView(WIcon.close, size: 16, color: WColor.secondary)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      if (t != null)
        Positioned(
          key: ValueKey(t),
          left: 0,
          right: 0,
          bottom: 110 + pad.bottom,
          child: IgnorePointer(
            child: FadeIn(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const ShapeDecoration(color: WColor.inverse, shape: StadiumBorder()),
                  child: WText(t, WType.caption, color: WColor.white, weight: medium, align: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

// MARK: Change phone (code to the new number)

enum _PhoneStage { number, code, done }

class WChangePhoneScreen extends StatefulWidget {
  const WChangePhoneScreen({super.key});
  @override
  State<WChangePhoneScreen> createState() => _WChangePhoneScreenState();
}

class _WChangePhoneScreenState extends State<WChangePhoneScreen> {
  var stage = _PhoneStage.number;
  String phone = '';
  String code = '';
  bool wrong = false;
  bool loading = false;

  String get digits {
    final d = Validators.digitsOnly(phone);
    return d.length > 10 ? d.substring(0, 10) : d;
  }

  bool get canSend => Validators.isValidMobile(phone) && digits != context.store.phone;

  Future<void> _send() async {
    if (!canSend) return;
    setState(() => loading = true);
    await context.store.requestPhoneChange(digits);
    if (!mounted) return;
    setState(() {
      loading = false;
      code = '';
      wrong = false;
      stage = _PhoneStage.code;
    });
  }

  Future<void> _verify() async {
    if (loading || code.length != 6) return;
    setState(() => loading = true);
    final ok = await context.store.confirmPhoneChange(code);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (ok) {
        stage = _PhoneStage.done;
      } else {
        wrong = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: stage != _PhoneStage.done,
      header: WHeader(title: store.t('Phone number', 'फ़ोन नंबर', 'ఫోన్ నంబర్')),
      footer: stage == _PhoneStage.done
          ? null
          : WFooter(
              child: stage == _PhoneStage.number
                  ? WButton(store.t('Send code', 'कोड भेजें', 'కోడ్ పంపండి'), size: ButtonSize.captain, enabled: canSend, loading: loading, onTap: _send)
                  : WButton(store.t('Verify', 'जाँचें', 'ధృవీకరించండి'), size: ButtonSize.captain, enabled: code.length == 6, loading: loading, onTap: _verify),
            ),
      children: switch (stage) {
        _PhoneStage.number => [
            WTitle(store.t('New number', 'नया नंबर', 'కొత్త నంబర్'), top: 10),
            WBody(store.t('Now: ${Fmt.phone(store.phone)}. We send a code to the new number.', 'अभी: ${Fmt.phone(store.phone)}। नए नंबर पर कोड भेजेंगे।', 'ఇప్పుడు: ${Fmt.phone(store.phone)}. కొత్త నంబర్‌కి కోడ్ పంపుతాము.'), top: 6, bottom: 18),
            WPhoneField(number: phone, large: true, onChanged: (v) => setState(() => phone = v)),
            if (digits == store.phone) Padding(padding: const EdgeInsets.only(top: 8), child: WText(store.t('That’s your current number.', 'यह आपका अभी का नंबर है।', 'ఇది మీ ప్రస్తుత నంబర్.'), WType.caption)),
          ],
        _PhoneStage.code => [
            WTitle(store.t('Enter the code', 'कोड डालें', 'కోడ్ ఎంటర్ చేయండి'), top: 10),
            WBody(store.t('Sent to ${Fmt.phone(digits)}.', '${Fmt.phone(digits)} पर भेजा।', '${Fmt.phone(digits)} కి పంపాము.'), top: 6, bottom: 22),
            WOtpField(
              code: code,
              error: wrong,
              boxSize: 48,
              onChanged: (v) {
                setState(() {
                  code = v;
                  if (wrong && v.length < 6) wrong = false;
                });
                if (v.length == 6) _verify();
              },
            ),
            if (wrong) Padding(padding: const EdgeInsets.only(top: 14), child: WText(store.t('Wrong code. Try again.', 'गलत कोड। फिर कोशिश करें।', 'తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.'), WType.caption, color: WColor.destructive)),
            const Padding(padding: EdgeInsets.only(top: 30), child: WText('Demo code: 123456', WType.caption, color: WColor.muted)),
          ],
        _PhoneStage.done => [
            Expanded(
              child: WFullState(
                icon: WIcon.check,
                tone: Tone.ok,
                captain: true,
                title: store.t('Number changed', 'नंबर बदल गया', 'నంబర్ మారింది'),
                message: store.t('Log in with ${Fmt.phone(store.phone)} from now.', 'अब ${Fmt.phone(store.phone)} से लॉग इन करें।', 'ఇకపై ${Fmt.phone(store.phone)} తో లాగిన్ అవ్వండి.'),
                primary: store.t('Done', 'ठीक है', 'సరే'),
                onPrimary: context.router.pop,
              ),
            ),
          ],
      },
    );
  }
}

// MARK: Change payout UPI (code to the registered phone)

class WEditUPIScreen extends StatefulWidget {
  const WEditUPIScreen({super.key});
  @override
  State<WEditUPIScreen> createState() => _WEditUPIScreenState();
}

class _WEditUPIScreenState extends State<WEditUPIScreen> {
  bool codeStage = false;
  String? upi;
  String code = '';
  bool showError = false;
  bool wrong = false;
  bool loading = false;

  bool get valid => Validators.isValidUPI(upi ?? '');
  bool get same => (upi ?? '').toLowerCase() == context.store.upi.toLowerCase();

  Future<void> _send() async {
    if (!valid) {
      setState(() => showError = true);
      return;
    }
    if (same) return;
    setState(() => loading = true);
    await context.store.requestUPIChange(upi!);
    if (!mounted) return;
    setState(() {
      loading = false;
      code = '';
      wrong = false;
      codeStage = true;
    });
  }

  Future<void> _verify() async {
    if (loading || code.length != 6) return;
    final store = context.store, router = context.router;
    setState(() => loading = true);
    final ok = await store.confirmUPIChange(code);
    if (!mounted) return;
    setState(() => loading = false);
    if (ok) {
      store.set(() => store.toast = store.t('UPI saved', 'UPI सेव हो गया', 'UPI సేవ్ అయింది'));
      router.pop();
    } else {
      setState(() => wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    upi ??= store.upi;
    final value = upi!;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Payout UPI', 'पेमेंट UPI', 'చెల్లింపు UPI')),
      footer: WFooter(
        child: !codeStage
            ? WButton(store.t('Send code', 'कोड भेजें', 'కోడ్ పంపండి'), size: ButtonSize.captain, enabled: value.isNotEmpty && !same, loading: loading, onTap: _send)
            : WButton(store.t('Verify and save', 'जाँचें और सेव करें', 'ధృవీకరించి సేవ్ చేయండి'), size: ButtonSize.captain, enabled: code.length == 6, loading: loading, onTap: _verify),
      ),
      children: !codeStage
          ? [
              WTitle(store.t('Where should money go?', 'पैसे कहाँ भेजें?', 'డబ్బు ఎక్కడికి పంపాలి?'), top: 10),
              WBody(store.t('Now: ${store.upi}', 'अभी: ${store.upi}', 'ఇప్పుడు: ${store.upi}'), top: 6, bottom: 18),
              WTextField(
                label: 'UPI ID',
                value: value,
                placeholder: 'name@ybl',
                helper: store.t('Like name@ybl or 9876543210@paytm', 'जैसे name@ybl या 9876543210@paytm', 'ఉదా: name@ybl లేదా 9876543210@paytm'),
                error: showError && !valid ? store.t('Check the UPI ID. It needs an @.', 'UPI ID जाँचें। इसमें @ होना चाहिए।', 'UPI ID చూడండి. అందులో @ ఉండాలి.') : null,
                keyboard: TextInputType.emailAddress,
                large: true,
                autofocus: true,
                onSubmit: _send,
                onChanged: (v) => setState(() {
                  upi = v;
                  showError = false;
                }),
              ),
              if (same && value.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: WText(store.t('That’s your current UPI.', 'यह आपका अभी का UPI है।', 'ఇది మీ ప్రస్తుత UPI.'), WType.caption)),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const WIconView(WIcon.shield, size: 15, color: WColor.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WText(store.t('For safety we send a code to ${Fmt.phone(store.phone)} first.', 'सुरक्षा के लिए पहले ${Fmt.phone(store.phone)} पर कोड भेजेंगे।', 'భద్రత కోసం ముందుగా ${Fmt.phone(store.phone)} కి కోడ్ పంపుతాము.'), WType.caption),
                  ),
                ]),
              ),
            ]
          : [
              WTitle(store.t('Enter the code', 'कोड डालें', 'కోడ్ ఎంటర్ చేయండి'), top: 10),
              WBody(
                  store.t('Sent to ${Fmt.phone(store.phone)}. UPI changes to ${store.pendingUPI} after this.', '${Fmt.phone(store.phone)} पर भेजा। इसके बाद UPI ${store.pendingUPI} होगा।',
                      '${Fmt.phone(store.phone)} కి పంపాము. తర్వాత UPI ${store.pendingUPI} అవుతుంది.'),
                  top: 6,
                  bottom: 22),
              WOtpField(
                code: code,
                error: wrong,
                boxSize: 48,
                onChanged: (v) {
                  setState(() {
                    code = v;
                    if (wrong && v.length < 6) wrong = false;
                  });
                  if (v.length == 6) _verify();
                },
              ),
              if (wrong) Padding(padding: const EdgeInsets.only(top: 14), child: WText(store.t('Wrong code. Try again.', 'गलत कोड। फिर कोशिश करें।', 'తప్పు కోడ్. మళ్ళీ ప్రయత్నించండి.'), WType.caption, color: WColor.destructive)),
              const Padding(padding: EdgeInsets.only(top: 30), child: WText('Demo code: 123456', WType.caption, color: WColor.muted)),
            ],
    );
  }
}

// MARK: Job cancelled: didn't reach in time

class WNoShowCancelledScreen extends StatelessWidget {
  const WNoShowCancelledScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final plate = store.noShowPlate.isEmpty ? store.current.plate : store.noShowPlate;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      footer: WFooter(
        child: WButton(store.t('Back to jobs', 'कामों पर वापस', 'పనులకు తిరిగి'), size: ButtonSize.captain, onTap: () {
          router.home();
          router.tab = 1;
        }),
      ),
      children: [
        const Spacer(),
        const Center(child: WStateCircle(WIcon.ban, tone: Tone.error, size: 112)),
        const SizedBox(height: 14),
        WText(store.t('Job cancelled', 'काम रद्द हुआ', 'పని రద్దయింది'), WType.section, weight: semibold, size: 23, align: TextAlign.center),
        const SizedBox(height: 14),
        Center(child: WPlate(plate)),
        const SizedBox(height: 14),
        WBody(
            store.t('You didn’t reach or update the job in the time slot. The owner got a full refund.', 'आप समय पर नहीं पहुँचे और काम अपडेट नहीं किया। मालिक को पूरे पैसे वापस मिले।',
                'మీరు సమయానికి చేరుకోలేదు, పని అప్‌డేట్ చేయలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది.'),
            center: true),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Tone.error.background, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WIconView(WIcon.rupee, size: 17, color: WColor.destructive),
            const SizedBox(width: 12),
            Expanded(
              child: WText(store.t('Penalty ₹[NO-SHOW PENALTY] is cut from your next payout.', 'जुर्माना ₹[NO-SHOW PENALTY] अगले पेमेंट से कटेगा।', 'జరిమానా ₹[NO-SHOW PENALTY] తదుపరి చెల్లింపు నుండి తగ్గుతుంది.'), WType.caption,
                  color: Tone.error.bannerText, size: 14.5),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        WText(store.t('If you can’t reach a job, tell us in Help before the slot ends.', 'अगर काम पर नहीं पहुँच सकते, तो समय खत्म होने से पहले मदद में बताएं।', 'పనికి చేరుకోలేకపోతే, సమయం ముగియక ముందే సహాయంలో చెప్పండి.'), WType.caption, align: TextAlign.center),
        const Spacer(),
      ],
    );
  }
}
