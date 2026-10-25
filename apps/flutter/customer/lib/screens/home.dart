import 'dart:async';

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'booking.dart';
import 'common.dart';

// MARK: Tabs

class MainTabs extends StatelessWidget {
  const MainTabs({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return Material(
      color: WColor.canvas,
      child: Column(
        children: [
          Expanded(
            child: switch (router.tab) {
              1 => const BookingsTab(),
              2 => const VehiclesTab(),
              3 => const ProfileTab(),
              _ => const HomeTab(),
            },
          ),
          WBottomNav(
            selection: router.tab,
            onSelect: (t) => router.tab = t,
            items: [
              const NavItem(0, 'Home', WIcon.home),
              NavItem(1, 'Bookings', WIcon.calendar, badge: store.activeOrder == null ? 0 : 1),
              const NavItem(2, 'Vehicles', WIcon.car),
              const NavItem(3, 'Profile', WIcon.user),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scrolling tab body on the canvas, under the status bar.
class TabScroll extends StatelessWidget {
  const TabScroll({super.key, required this.children, this.gutter = WSpace.gutter});
  final List<Widget> children;
  final double gutter;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: WColor.canvas,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, MediaQuery.paddingOf(context).top, gutter, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

// MARK: C40 / C41 / C42 Home (C55 loading)

class _BookAgainEntry {
  _BookAgainEntry(this.order);
  final Order order;
  bool placeDiffers = false;
  bool washDiffers = false;
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool loading = true;
  late final Timer _t = Timer(const Duration(milliseconds: 600), () => setState(() => loading = false));

  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  void _book() {
    context.store.startNewBooking();
    context.router.go(N.vehicleType);
  }

  /// One entry per vehicle + place + wash, newest first. When the same vehicle has other
  /// entries, the part that's different (place or wash) is highlighted.
  List<_BookAgainEntry> _entries(AppStore store) {
    final seen = <String>{};
    final list = <_BookAgainEntry>[];
    for (final o in store.pastOrders) {
      if (o.status == OrderStatus.cancelled) continue; // nothing was washed
      if (seen.add('${o.vehicle.id}#${o.placeKey}#${o.washKind.name}')) list.add(_BookAgainEntry(o));
    }
    for (final e in list) {
      final sib = list.where((x) => x.order.vehicle.id == e.order.vehicle.id && x.order.id != e.order.id);
      e.placeDiffers = sib.any((x) => x.order.placeKey != e.order.placeKey);
      e.washDiffers = sib.any((x) => x.order.washKind != e.order.washKind);
    }
    return list;
  }

  Widget _highlight(String text, bool on, {WIcon? icon}) => Container(
    padding: on ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3) : EdgeInsets.zero,
    decoration: ShapeDecoration(color: on ? WColor.primaryTint : Colors.transparent, shape: const StadiumBorder()),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[WIconView(icon, size: 11, color: on ? WColor.primaryStrong : WColor.secondary), const SizedBox(width: 4)],
        Flexible(
          child: WText(text, WType.caption, color: on ? WColor.primaryStrong : null, weight: on ? semibold : null, maxLines: 2),
        ),
      ],
    ),
  );

  String _activeTitle(Order o) {
    final n = o.captain?.name ?? 'Captain';
    return switch (o.status) {
      OrderStatus.searching when o.slotAhead => 'Booked. Captain comes in your slot',
      OrderStatus.searching => 'Finding a captain',
      OrderStatus.onTheWay => context.store.isLive && o.entryPassReceived ? '$n has arrived' : '$n is on the way',
      OrderStatus.washing => '$n is washing',
      OrderStatus.photosReady => 'Check the photos',
      _ => 'Booking',
    };
  }

  Widget _skeleton() {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: WColor.disabled, borderRadius: BorderRadius.circular(6)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        bar(160, 26),
        const SizedBox(height: 18),
        WCard(
          padding: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(120, 12),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: WColor.disabled, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(180, 12), const SizedBox(height: 8), bar(130, 10)]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const WCard(child: SizedBox(height: 50)),
        const SizedBox(height: 18),
        const WCard(child: SizedBox(height: 50)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final c = store.customer;
    final hasHistory = store.pastOrders.isNotEmpty || store.activeOrder != null;
    // First-time customer and the first-wash Home is hidden (DesignFlags.firstWashHome):
    // go straight to the first booking step.
    if ((c == null || !hasHistory) && !store.showFirstWashHome) {
      return OnAppear(
        onAppear: () {
          if (store.draft.place == null && store.draft.slot == null) store.startNewBooking();
        },
        child: const VehicleTypeScreen(asRoot: true),
      );
    }
    final a = store.activeOrder;
    final entries = _entries(store);
    return TabScroll(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [const BrandMark(), const Spacer(), const NotificationBell()]),
        ),
        if (loading)
          _skeleton()
        else
          FadeIn(
            offset: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                WText(c == null || c.firstName.isEmpty ? 'Hi there' : 'Hi ${c.firstName}', WType.screen),
                if (!hasHistory || c == null) ...[
                  const SizedBox(height: 4),
                  const WText('Your wheels are waiting.', WType.body),
                  const SizedBox(height: 24),
                  WCard(
                    padding: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WStateCircle(WIcon.drop, size: 64),
                        const SizedBox(height: 22),
                        const WText('Book your first wash', WType.section, weight: semibold),
                        const SizedBox(height: 6),
                        const WText('Car from ₹149, bike ₹69. Pay only after you see the photos.', WType.body),
                        const SizedBox(height: 20),
                        WButton('Book a wash', onTap: _book),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  const WText('How it works', WType.section, weight: semibold),
                  for (final (i, t) in const [
                    'Tell us where it’s parked and pick a time',
                    'A verified captain cleans it, before and after photos',
                    'You approve the photos, then the captain is paid',
                  ].indexed) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: WText('${i + 1}', WType.label, color: WColor.primaryStrong),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: WText(t, WType.bodyStrong, size: 15.5)),
                      ],
                    ),
                  ],
                ] else ...[
                  if (c.freeWashes > 0) ...[
                    const SizedBox(height: 20),
                    WBanner(
                      tone: Tone.ok,
                      icon: WIcon.gift,
                      title: c.freeWashes == 1 ? 'You have 1 free wash.' : 'You have ${c.freeWashes} free washes.',
                      text: 'They’re applied at checkout.',
                      actionTitle: 'Use one',
                      onAction: _book,
                    ),
                  ],
                  if (c.credit > 0) ...[
                    const SizedBox(height: 20),
                    WBanner(
                      tone: Tone.ok,
                      icon: WIcon.rupee,
                      title: '${Fmt.rupees(c.credit)} credit',
                      text: 'Comes off your next booking.',
                      actionTitle: 'Book',
                      onAction: _book,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Booking a wash is always the main action, even while another wash is running.
                  WCard(
                    padding: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WText('Book a wash', WType.section, weight: semibold),
                        const SizedBox(height: 16),
                        WButton('Book a wash', onTap: _book),
                      ],
                    ),
                  ),
                  if (a != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 30, bottom: 14),
                      child: WText(a.slotAhead ? 'Upcoming' : 'In progress', WType.section, weight: semibold),
                    ),
                    WCard(
                      radius: 16,
                      onTap: () {
                        store.set(() => store.currentOrderId = a.id);
                        router.go(N.live);
                      },
                      child: Column(
                        children: [
                          Row(
                            children: [
                              WText('${a.slot.dayLabel} · ${a.slot.label}', WType.label, color: WColor.heading),
                              const Spacer(),
                              StatusBadge(a.status, slotAhead: a.slotAhead),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (a.captain == null) WIconBox(a.slotAhead ? WIcon.calendar : WIcon.search, size: 40, radius: 10) else WAvatar(a.captain!.initials, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    WText(_activeTitle(a), WType.title, weight: medium),
                                    WText('${a.vehicle.plate} · ${a.place.parkingShort}', WType.caption),
                                  ],
                                ),
                              ),
                              const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
                            ],
                          ),
                          const SizedBox(height: 12),
                          WProgress(fraction: (a.status.stepIndex + 1) / 4),
                          if (a.canCancel()) Align(alignment: Alignment.centerLeft, child: CancelLink(order: a, compact: true)),
                        ],
                      ),
                    ),
                  ],
                ],
                if (c != null && entries.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 30, bottom: 14),
                    child: WText('Book again', WType.section, weight: semibold),
                  ),
                  for (final e in entries) ...[
                    WCard(
                      radius: 16,
                      onTap: () => router.push(R(N.repeatBooking, id: e.order.id)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WIconBox(e.order.vehicle.type.icon, size: 48),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: WPlate(e.order.vehicle.plate)),
                                    const Spacer(),
                                    WText(Fmt.rupees(e.order.price), WType.valueStrong, mono: true),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    WText('${e.order.vehicle.type.shortName} ·', WType.caption),
                                    const SizedBox(width: 4),
                                    Flexible(child: _highlight(e.order.washKind.name(e.order.vehicle.type.kind == VehicleKind.bike), e.washDiffers)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _highlight('${e.order.place.title} · ${e.order.place.parkingShort}', e.placeDiffers, icon: WIcon.location),
                                const SizedBox(height: 6),
                                WText('Last booked ${Fmt.day(e.order.slot.date)}', WType.small, color: WColor.muted),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 10, left: 8),
                            child: WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// MARK: C43 Bookings (C43b empty, C43c past)

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});
  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  int tab = 0;

  String _subtitle(Order o) {
    final t = o.vehicle.type.shortName;
    return switch (o.status) {
      OrderStatus.pendingPayment || OrderStatus.paymentPending => '$t · payment not confirmed',
      OrderStatus.cancelled => '$t · cancelled',
      OrderStatus.noCaptain || OrderStatus.disputeUpheld || OrderStatus.captainNoShow => '$t · ${Fmt.rupees(o.price)} refunded',
      OrderStatus.approved || OrderStatus.autoApproved || OrderStatus.disputeRejected => '$t · ${Fmt.rupees(o.price)} paid',
      _ => '$t · ${Fmt.rupees(o.price)} held',
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final list = tab == 0 ? store.upcomingOrders : store.pastOrders;
    return ColoredBox(
      color: WColor.canvas,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(WSpace.gutter, 20, WSpace.gutter, 0), child: WText('Bookings', WType.screen)),
            Padding(
              padding: const EdgeInsets.fromLTRB(WSpace.gutter, 14, WSpace.gutter, 0),
              child: WTabs(options: const ['Upcoming', 'Past'], selection: tab, onChanged: (i) => setState(() => tab = i)),
            ),
            Expanded(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
                      child: WFullState(
                        icon: WIcon.calendar,
                        title: tab == 0 ? 'Nothing booked' : 'No past washes',
                        message: 'Your wheels are waiting. Book a wash and we’ll find a captain nearby.',
                        primary: 'Book a wash',
                        onPrimary: () {
                          store.startNewBooking();
                          router.go(N.vehicleType);
                        },
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter, vertical: 18),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (c, i) {
                        final o = list[i];
                        return WCard(
                          outlined: true,
                          radius: 16,
                          onTap: () {
                            store.set(() => store.currentOrderId = o.id);
                            router.push(o.status.isUpcoming ? const R(N.live) : R(N.bookingDetail, id: o.id));
                          },
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  WText(
                                    o.status.isUpcoming ? '${o.slot.dayLabel} · ${o.slot.label}' : Fmt.date(o.slot.date),
                                    WType.label,
                                    color: WColor.heading,
                                  ),
                                  const Spacer(),
                                  StatusBadge(o.status, slotAhead: o.slotAhead),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  WIconBox(o.vehicle.type.icon, size: 40, radius: 10),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        WText(o.vehicle.plate, WType.title, weight: FontWeight.w400, size: 16.5),
                                        WText(_subtitle(o), WType.caption),
                                      ],
                                    ),
                                  ),
                                  const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
                                ],
                              ),
                              if (o.canCancel()) Align(alignment: Alignment.centerLeft, child: CancelLink(order: o, compact: true)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: C44 Booking detail

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.order(orderId);
    if (o == null) return const SizedBox();
    final until = o.reportUntil ?? DateTime.now();
    return WScreen(
      header: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: WAppBar(title: Fmt.date(o.slot.date), subtitle: 'Booking #${o.ref}', onLeading: router.pop, onTrailing: () => router.go(N.help)),
      ),
      footer: WFooterBar(
        onCall: callSupport,
        child: WButton(
          'Book again',
          icon: WIcon.refresh,
          onTap: () => router.push(R(N.repeatBooking, id: o.id)),
        ),
      ),
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            StatusBadge(o.status),
            if (o.status == OrderStatus.approved) ...[const SizedBox(width: 8), WBadge('${Fmt.rupees(o.price)} paid', tone: Tone.ok, icon: WIcon.check)],
          ],
        ),
        if (o.status != OrderStatus.cancelled) ...[
          const Padding(padding: EdgeInsets.only(top: 20, bottom: 8), child: WText('Photos', WType.label)),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: DesignPhoto(
                    path: o.evidence(i.isEven ? 'before' : 'after', i ~/ 2),
                    height: 70,
                    icon: i.isEven ? WIcon.car : WIcon.sparkle,
                    tag: i.isEven ? 'Before' : 'After',
                    tagTone: i.isEven ? Tone.mute : Tone.ok,
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 20),
        WKeyValueCard(
          rows: [
            ('Vehicle', o.vehicle.plate),
            ('Captain', o.captain == null ? '—' : '${o.captain!.name}${o.rating != null ? ' · you rated ${o.rating}' : ''}'),
            ('Time', '${Fmt.time(o.startedAt ?? o.slot.start)} – ${Fmt.time(o.finishedAt ?? o.slot.start)}'),
            (o.refund != null ? 'Refunded' : 'Paid', '${Fmt.rupees(o.price)} · ${o.paidWith?.title ?? 'UPI'}'),
          ],
        ),
        const SizedBox(height: 16),
        const WListRow(icon: WIcon.receipt, title: 'Download receipt'),
        const WDivider(),
        if (o.refund != null)
          WListRow(icon: WIcon.rupee, title: 'Track refund', onTap: () => router.go(N.refund))
        else
          WListRow(
            icon: WIcon.flag,
            title: 'Report a problem',
            subtitle: 'Until ${Fmt.time(until)}, ${Fmt.date(until)}',
            onTap: () => router.go(N.reportProblem),
          ),
      ],
    );
  }
}

// MARK: C45 Book again

class RepeatScreen extends StatelessWidget {
  const RepeatScreen({super.key, required this.id});

  /// An order id (repeat that exact booking) or a vehicle id.
  final String id;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final from = store.order(id);
    final v0 = from?.vehicle ?? store.vehicles.where((v) => v.id == id).firstOrNull ?? AppStore.car();
    final v = Vehicle(v0.id, v0.plate, v0.type, from?.place ?? v0.place);
    final lastNote = store.orders.where((o) => o.vehicle.id == v.id && !o.note.isEmpty).firstOrNull?.note ?? (store.isLive ? EntryNote() : EntryNote(voiceSeconds: 12));
    final place = v.place;
    return WScreen(
      header: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: WAppBar(title: 'Book again', onLeading: router.pop, onTrailing: () => router.go(N.help)),
      ),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Take photos',
          onTap: () {
            store.startRepeat(v, place: place, wash: from?.wash);
            store.set(() => store.draft.note = lastNote.copy());
            router.go(N.photos);
          },
        ),
      ),
      children: [
        const WTitleBlock('Same wash, new time', subtitle: 'We kept your vehicle and parking details.', top: 14),
        WCard(
          radius: 16,
          child: Row(
            children: [
              WIconBox(v.type.icon, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WPlate(v.plate),
                    const SizedBox(height: 6),
                    WText('${v.type.shortName} · ${place?.tower ?? ''} · ${place?.parkingShort ?? ''}', WType.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WKeyValueCard(
          rows: [
            ('Wash', (from?.washKind ?? WashKind.wetOutside).name(v.type.kind == VehicleKind.bike)),
            ('Place', place?.title ?? ''),
            ('Parking', '${place?.tower ?? ''} · ${place?.parkingShort ?? ''}'),
            ('Notes', lastNote.summary),
          ],
        ),
        Padding(padding: const EdgeInsets.only(top: 22, bottom: 4), child: const WText('Still needed for this wash', WType.label)),
        const WListRow(icon: WIcon.camera, title: '4 fresh photos', subtitle: 'Every wash starts with new photos'),
        const WDivider(),
        const WListRow(icon: WIcon.door, title: 'Gate pass', subtitle: 'We’ll ask on WhatsApp after you pay', trailing: 'Later', chevron: false),
      ],
    );
  }
}

// MARK: C46 Vehicles

class VehiclesTab extends StatelessWidget {
  const VehiclesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return TabScroll(
      children: [
        const SizedBox(height: 20),
        const WText('Your vehicles', WType.screen),
        const SizedBox(height: 12),
        WText('${store.myVehicles.length} saved · tap one to book', WType.caption),
        const SizedBox(height: 18),
        for (final v in store.myVehicles) ...[
          WCard(
            radius: 16,
            onTap: () => router.push(R(N.repeatBooking, id: v.id)),
            child: Row(
              children: [
                WIconBox(v.type.icon, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WPlate(v.plate),
                      const SizedBox(height: 6),
                      WText('${v.type.shortName} · ${v.place?.tower ?? ''} · ${v.place?.parkingShort ?? ''}', WType.caption),
                    ],
                  ),
                ),
                const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Pressable(
          onTap: () {
            store.startNewBooking();
            router.go(N.vehicleType);
          },
          child: const DashedBorder(
            child: SizedBox(
              height: 62,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WIconView(WIcon.plus, size: 16, color: WColor.primaryStrong, weight: semibold),
                  SizedBox(width: 10),
                  WText('Add a vehicle', WType.title, color: WColor.primaryStrong),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// MARK: C47 Profile (C53 delete account)

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool showDelete = false;
  bool deleteBlocked = false;

  String _notificationSummary(AppStore store) {
    if (!store.notificationsOn) return 'Off';
    if (store.systemPermission == Permission.denied) return 'Blocked in settings';
    if (store.notificationPrefs.isMuted) return 'Muted until ${Fmt.time(store.notificationPrefs.mutedUntil!)}';
    return store.notificationPrefs.style == AlertStyle.bannerOnly ? 'On, no sound' : 'On';
  }

  void _editName(AppStore store) {
    var name = store.customer?.name ?? '';
    showWAlert(
      context,
      title: 'Edit name',
      field: CupertinoNameField(initial: name, onChanged: (v) => name = v),
      actions: [
        const AlertAction('Cancel', cancel: true),
        AlertAction('Save', onTap: () => store.updateName(name)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final c = store.customer;
    Widget group(List<Widget> rows) => WCard(padding: 14, radius: 16, child: Column(children: rows));
    return Stack(
      children: [
        TabScroll(
          children: [
            if (c != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  ProfilePhotoPicker(initials: c.initials),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WText(c.name.isEmpty ? 'Your profile' : c.name, WType.section, weight: semibold),
                        WText(Fmt.phone(c.phone), WType.caption),
                      ],
                    ),
                  ),
                ],
              ),
              if (c.freeWashes > 0) ...[
                const SizedBox(height: 14),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const WIconView(WIcon.gift, size: 15, color: WColor.onSuccess),
                      const SizedBox(width: 10),
                      WText(c.freeWashes == 1 ? '1 free wash left' : '${c.freeWashes} free washes left', WType.caption, color: WColor.onSuccess, weight: medium),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              group([
                WListRow(icon: WIcon.edit, title: 'Edit name', onTap: () => _editName(store)),
                const WDivider(inset: 54),
                WListRow(icon: WIcon.phone, title: 'Phone number', subtitle: Fmt.phone(c.phone), onTap: () => router.go(N.changePhone)),
                const WDivider(inset: 54),
                // Only appears once we've needed a refund UPI ID.
                if (c.refundUPI != null) ...[
                  WListRow(icon: WIcon.rupee, title: 'Refund UPI ID', subtitle: c.refundUPI, onTap: () => router.push(const R(N.refundUPI))),
                  const WDivider(inset: 54),
                ],
                WListRow(icon: WIcon.home, title: 'Saved places', subtitle: store.isLive ? (store.orders.firstOrNull == null ? 'None yet' : store.orders.first.place.title) : 'My Home Avatar, Tower 3'),
                const WDivider(inset: 54),
                WListRow(icon: WIcon.bell, title: 'Notifications', subtitle: _notificationSummary(store), onTap: () => router.go(N.notificationSettings)),
              ]),
            ] else ...[
              const SizedBox(height: 20),
              const WText('Profile', WType.screen),
              const SizedBox(height: 14),
              WCard(
                padding: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WText('Log in to see your bookings and free washes.', WType.body),
                    const SizedBox(height: 14),
                    WButton('Log in', onTap: () => router.go(N.login)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            group([
              WListRow(icon: WIcon.help, title: 'Help and support', onTap: () => router.go(N.help)),
              const WDivider(inset: 54),
              const WListRow(icon: WIcon.doc, title: 'Terms and privacy'),
            ]),
            if (c != null) ...[
              const SizedBox(height: 14),
              group([
                WListRow(
                  icon: WIcon.logout,
                  title: 'Log out',
                  onTap: () {
                    store.signOut();
                    store.set(() => store.hasSeenWelcome = true);
                    router.tab = 0;
                  },
                ),
                const WDivider(inset: 54),
                WListRow(icon: WIcon.trash, title: 'Delete account', tone: Tone.error, onTap: () => setState(() => showDelete = true)),
              ]),
            ],
          ],
        ),
        if (showDelete)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => showDelete = false),
                    child: const ColoredBox(color: WColor.scrim),
                  ),
                ),
                Center(
                  child: FadeIn(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(28)),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const WIconBox(WIcon.trash, size: 52, tone: Tone.error, radius: 26),
                            const SizedBox(height: 12),
                            const WText('Delete your account?', WType.section, weight: semibold),
                            const SizedBox(height: 12),
                            WText(
                              deleteBlocked
                                  ? 'You can’t do this while a wash is in progress. Try again after it’s approved.'
                                  : 'Your vehicles, bookings and ${c?.freeWashes ?? 0} free washes go with it. You can’t do this while a wash is in progress.',
                              WType.body,
                            ),
                            const SizedBox(height: 18),
                            WButton(
                              'Delete account',
                              kind: ButtonKind.danger,
                              enabled: !deleteBlocked,
                              onTap: () async {
                                bool ok;
                                try {
                                  ok = await store.deleteAccount();
                                } catch (e) {
                                  store.set(() => store.toast = backendError(e));
                                  setState(() => showDelete = false);
                                  return;
                                }
                                if (!mounted) return;
                                if (ok) {
                                  setState(() => showDelete = false);
                                  router.tab = 0;
                                } else {
                                  setState(() => deleteBlocked = true);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            WButton(
                              'Keep my account',
                              kind: ButtonKind.text,
                              onTap: () => setState(() {
                                showDelete = false;
                                deleteBlocked = false;
                              }),
                            ),
                          ],
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

/// Text field inside an iOS alert (Edit name).
class CupertinoNameField extends StatelessWidget {
  const CupertinoNameField({super.key, required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: TextField(
      controller: TextEditingController(text: initial),
      autofocus: true,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(isDense: true, hintText: 'Your name', filled: true, fillColor: WColor.white, border: OutlineInputBorder()),
    ),
  );
}

// MARK: C50 Offline · C51 Server error · C54 Session expired

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
    scrolls: false,
    header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
    children: [
      Expanded(
        child: WFullState(
          icon: WIcon.wifiOff,
          tone: Tone.mute,
          title: 'You’re offline',
          message: 'Check your internet. Anything you entered is saved on this phone.',
          primary: 'Retry',
          onPrimary: () {
            context.store.set(() => context.store.demo.offline = false);
            context.router.pop();
          },
        ),
      ),
    ],
  );
}

class ServerErrorScreen extends StatelessWidget {
  const ServerErrorScreen({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
    scrolls: false,
    header: const PlainHeader(),
    children: [
      Expanded(
        child: WFullState(
          icon: WIcon.warning,
          tone: Tone.error,
          title: 'Something went wrong on our side',
          message: 'It’s not you. Try again in a minute, or call us and we’ll sort it out.',
          primary: 'Try again',
          secondary: 'Call support',
          onPrimary: context.router.pop,
          onSecondary: callSupport,
        ),
      ),
    ],
  );
}

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
    scrolls: false,
    header: const SizedBox(height: 56),
    children: [
      Expanded(
        child: WFullState(
          icon: WIcon.lock,
          title: 'Please log in again',
          message: 'For your safety we log you out after 30 days. Your bookings are safe.',
          primary: 'Log in',
          onPrimary: () {
            context.store.signOut();
            context.router.replace(const [R(N.login)]);
          },
        ),
      ),
    ],
  );
}
