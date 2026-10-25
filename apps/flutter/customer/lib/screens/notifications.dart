import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';

String _relative(DateTime d) {
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return 'Now';
  if (s < 3600) return '${s ~/ 60} min';
  if (isToday(d)) return '${s ~/ 3600} h';
  if (isYesterday(d)) return Fmt.time(d);
  return Fmt.date(d);
}

// MARK: Notification centre (bell on Home)

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationCategory? filter;

  void _menu(AppNotification n) {
    final store = context.store;
    showWActions(context, title: n.title, actions: [
      n.read ? AlertAction('Mark as unread', onTap: () => store.markUnread(n.id)) : AlertAction('Mark as read', onTap: () => store.markRead(n.id)),
      AlertAction('Delete', destructive: true, onTap: () => store.deleteNotification(n.id)),
    ]);
  }

  void _open(AppNotification n) {
    final m = openNotification(n, context.store, context.router);
    if (m != null) showWAlert(context, title: m);
  }

  Widget _row(AppNotification n) {
    final expired = n.expiresAt != null && n.expiresAt!.isBefore(DateTime.now());
    return Pressable(
      feedback: false,
      label: '${n.read ? '' : 'Unread. '}${n.title}. ${n.body}',
      onTap: () => _open(n),
      onLongPress: () => _menu(n),
      child: Container(
        color: n.read ? Colors.transparent : WColor.primaryTint.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WIconBox(n.kind.icon, size: 38, tone: expired ? Tone.mute : n.kind.tone, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: WText(n.title, WType.title, weight: n.read ? FontWeight.w400 : semibold, size: 15.5)),
                const SizedBox(width: 6),
                WText(_relative(n.date), WType.small, color: WColor.muted),
              ]),
              const SizedBox(height: 3),
              WText(n.body, WType.caption, maxLines: 3),
              if (expired) const Padding(padding: EdgeInsets.only(top: 2), child: WText('Offer ended', WType.small, color: WColor.muted)),
            ]),
          ),
          // Web: no long-press, so the delete / mark-unread menu sits behind a "⋯" button.
          if (kIsWeb)
            Pressable(label: 'More', onTap: () => _menu(n), child: const SizedBox(width: 28, height: 28, child: Center(child: WIconView(WIcon.more, size: 18, color: WColor.secondary))))
          else
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: n.read ? Colors.transparent : WColor.primary)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final items = store.notifications.where((n) => filter == null || n.kind.category == filter).toList();
    final sections = [
      ('Today', items.where((n) => isToday(n.date)).toList()),
      ('Yesterday', items.where((n) => isYesterday(n.date)).toList()),
      ('Earlier', items.where((n) => !isToday(n.date) && !isYesterday(n.date)).toList()),
    ].where((s) => s.$2.isNotEmpty);
    final prefs = store.notificationPrefs;
    return WScreen(
      canvas: true,
      header: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: WAppBar(title: 'Notifications', trailing: store.customer == null ? null : WIcon.gear, onLeading: router.pop, onTrailing: () => router.go(N.notificationSettings)),
      ),
      children: store.customer == null
          ? [
              SizedBox(
                height: 460,
                child: WFullState(icon: WIcon.bell, title: 'Log in to see your updates', message: 'Booking updates, refunds and offers show up here once you’re logged in.', primary: 'Log in', onPrimary: () => router.go(N.login)),
              ),
            ]
          : [
              // Why updates might not reach the customer, with the fix one tap away.
              if (!store.notificationsOn)
                Padding(padding: const EdgeInsets.only(top: 10), child: WBanner(tone: Tone.wait, icon: WIcon.bellSlash, title: 'Notifications are off.', text: 'Updates still land here, but we won’t alert you.', actionTitle: 'Turn on', onAction: () => store.setNotifications(true)))
              else if (store.systemPermission == Permission.denied)
                const Padding(padding: EdgeInsets.only(top: 10), child: WBanner(tone: Tone.error, icon: WIcon.bellSlash, title: 'Blocked in settings.', text: 'Allow notifications for ${Brand.name} in your browser or phone settings to get alerts.'))
              else if (prefs.isMuted)
                Padding(padding: const EdgeInsets.only(top: 10), child: WBanner(tone: Tone.info, icon: WIcon.speakerOff, title: 'Muted until ${Fmt.day(prefs.mutedUntil!)}, ${Fmt.time(prefs.mutedUntil!)}.', text: 'Updates land here quietly.', actionTitle: 'Unmute', onAction: () => store.mute(null))),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  WChip('All', selected: filter == null, height: 36, onTap: () => setState(() => filter = null)),
                  for (final c in NotificationCategory.values) ...[const SizedBox(width: 8), WChip(c.filterTitle, selected: filter == c, height: 36, onTap: () => setState(() => filter = c))],
                ]),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 54),
                  child: Column(children: [
                    const WStateCircle(WIcon.bell, size: 72),
                    const SizedBox(height: 12),
                    WText(filter == null ? 'No notifications yet' : 'Nothing here', WType.section, weight: semibold),
                    const SizedBox(height: 12),
                    WText(filter == null ? 'We’ll let you know when a captain accepts, when photos are ready and when money moves.' : 'No ${filter!.filterTitle.toLowerCase()} updates right now.', WType.body, align: TextAlign.center),
                  ]),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Expanded(child: WText(store.unreadCount == 0 ? 'All caught up' : '${store.unreadCount} unread', WType.label)),
                    if (store.unreadCount > 0) WLink('Mark all as read', k: WType.caption, onTap: store.markAllRead),
                  ]),
                ),
                for (final s in sections) ...[
                  Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: WText(s.$1, WType.label, color: WColor.muted)),
                  Container(
                    decoration: cardDecoration(radius: 16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [for (final (i, n) in s.$2.indexed) ...[_row(n), if (i < s.$2.length - 1) const WDivider(inset: 62)]]),
                  ),
                ],
                const SizedBox(height: 16),
                WButton('Clear all', kind: ButtonKind.text, onTap: () => showWActions(context, title: 'Clear all notifications?', message: 'This only clears the list. Your bookings aren’t affected.', actions: [AlertAction('Clear all', destructive: true, onTap: store.clearNotifications)])),
                const SizedBox(height: 2),
                WText(kIsWeb ? 'Use ⋯ on a notification to delete it or mark it unread.' : 'Long-press a notification to delete it or mark it unread.', WType.small, color: WColor.muted, align: TextAlign.center),
              ],
            ],
    );
  }
}

// MARK: Notification settings (Profile → Notifications, or the gear)

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final on = store.notificationsOn;
    final prefs = store.notificationPrefs;
    Widget card(Widget child, {double top = 0}) => Padding(padding: EdgeInsets.only(top: top), child: WCard(radius: 16, padding: 16, child: child));
    return OnAppear(
      onAppear: store.refreshSystemPermission,
      child: WScreen(
        canvas: true,
        header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Notifications', trailing: null, onLeading: context.router.pop)),
        children: [
          card(
            WToggleRow(
              on: on,
              onChanged: store.setNotifications,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const WText('Allow notifications', WType.title),
                WText(on ? 'We’ll alert you about your washes.' : 'Off. Updates still show in the list.', WType.caption),
              ]),
            ),
            top: 14,
          ),
          if (store.systemPermission == Permission.denied && on)
            const Padding(padding: EdgeInsets.only(top: 12), child: WBanner(tone: Tone.error, icon: WIcon.bellSlash, title: 'Blocked in settings.', text: 'We can’t alert you until you allow notifications for ${Brand.name}.')),
          IgnorePointer(
            ignoring: !on,
            child: Opacity(
              opacity: on ? 1 : 0.45,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const WSectionLabel('How they arrive', top: 24),
                WCard(
                  radius: 16,
                  padding: 14,
                  child: Column(children: [
                    for (final (i, s) in AlertStyle.values.indexed) ...[
                      Pressable(
                        feedback: false,
                        onTap: () => store.set(() => store.notificationPrefs.style = s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            SizedBox(width: 24, child: WIconView(s == AlertStyle.soundAndBanner ? WIcon.bell : WIcon.speakerOff, size: 16, color: WColor.primaryStrong)),
                            const SizedBox(width: 12),
                            Expanded(child: WText(s.title, WType.rowTitle)),
                            WRadio(on: prefs.style == s),
                          ]),
                        ),
                      ),
                      if (i < AlertStyle.values.length - 1) const WDivider(inset: 36),
                    ],
                  ]),
                ),
                const WSectionLabel('Mute for a while', top: 24),
                card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (prefs.isMuted)
                    Row(children: [
                      const WIconView(WIcon.speakerOff, size: 15, color: WColor.primaryStrong),
                      const SizedBox(width: 8),
                      Expanded(child: WText('Muted until ${Fmt.day(prefs.mutedUntil!)}, ${Fmt.time(prefs.mutedUntil!)}', WType.bodyStrong)),
                      WLink('Unmute', k: WType.caption, onTap: () => store.mute(null)),
                    ])
                  else
                    const WText('No banners or sounds. Everything still lands in the list.', WType.caption),
                  const SizedBox(height: 12),
                  Row(children: [
                    WChip('1 hour', height: 38, onTap: () => store.mute(3600)),
                    const SizedBox(width: 8),
                    WChip('8 hours', height: 38, onTap: () => store.mute(8 * 3600)),
                    const SizedBox(width: 8),
                    WChip('Till morning', height: 38, onTap: store.muteUntilMorning),
                  ]),
                ])),
                card(
                  WToggleRow(
                    on: prefs.quietHours,
                    onChanged: (v) => store.set(() => store.notificationPrefs.quietHours = v),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText('Quiet hours', WType.title), WText('10 PM – 7 AM: banners arrive without sound.', WType.caption)]),
                  ),
                  top: 12,
                ),
                const WSectionLabel('What you hear about', top: 24),
                card(Column(children: [
                  for (final (i, c) in NotificationCategory.values.indexed) ...[
                    WToggleRow(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      on: c == NotificationCategory.account || prefs.categories.contains(c),
                      enabled: c != NotificationCategory.account,
                      onChanged: (v) {
                        if (c == NotificationCategory.bookings && !v) {
                          showWAlert(context,
                              title: 'Turn off booking updates?',
                              message: 'You might miss when the captain arrives or when photos are ready. If you don’t check them, the wash auto-approves at midnight.',
                              actions: [const AlertAction('Keep them on', cancel: true), AlertAction('Turn off', destructive: true, onTap: () => store.set(() => store.notificationPrefs.categories.remove(c)))]);
                          return;
                        }
                        store.set(() => v ? store.notificationPrefs.categories.add(c) : store.notificationPrefs.categories.remove(c));
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(c.title, WType.rowTitle), WText(c.detail, WType.caption)]),
                    ),
                    if (i < NotificationCategory.values.length - 1) const WDivider(),
                  ],
                ])),
              ]),
            ),
          ),
          const Padding(padding: EdgeInsets.only(top: 14), child: WText('Turning things off here never cancels a booking. Photo checks still auto-approve at midnight.', WType.small, color: WColor.muted)),
        ],
      ),
    );
  }
}

// MARK: In-app banner and toast (shown over every screen)

class LiveNotificationBanner extends StatefulWidget {
  const LiveNotificationBanner({super.key});
  @override
  State<LiveNotificationBanner> createState() => _LiveNotificationBannerState();
}

class _LiveNotificationBannerState extends State<LiveNotificationBanner> {
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
        _bannerTimer = Timer(const Duration(milliseconds: 4500), () {
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
                  final m = openNotification(n, store, router);
                  if (m != null) showWAlert(context, title: m);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: WColor.shadow, blurRadius: 16, offset: Offset(0, 6))]),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    WIconBox(n.kind.icon, size: 36, tone: n.kind.tone, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(n.title, WType.title, size: 15), const SizedBox(height: 2), WText(n.body, WType.caption, maxLines: 2)])),
                    if (kIsWeb) Pressable(label: 'Dismiss', onTap: () => store.set(() => store.liveBanner = null), child: const Padding(padding: EdgeInsets.only(left: 6), child: WIconView(WIcon.close, size: 16, color: WColor.secondary))),
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
          bottom: 100 + pad.bottom,
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
