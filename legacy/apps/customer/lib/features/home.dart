import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'booking.dart' show vehicleIcon;
import 'common.dart';

({String label, WTone tone, IconData icon}) statusBadge(Order o) => switch (o.status) {
      OrderStatus.searching => (label: 'Searching', tone: WTone.wait, icon: Icons.person_search_outlined),
      OrderStatus.paymentPending => (label: 'Payment pending', tone: WTone.wait, icon: Icons.hourglass_top_rounded),
      OrderStatus.onTheWay => (label: 'On the way', tone: WTone.info, icon: Icons.directions_walk_rounded),
      OrderStatus.washing => (label: 'Washing', tone: WTone.info, icon: Icons.water_drop_outlined),
      OrderStatus.photosReady => (label: 'Check photos', tone: WTone.wait, icon: Icons.photo_library_outlined),
      OrderStatus.approved || OrderStatus.autoApproved => (label: 'Done', tone: WTone.ok, icon: Icons.check_circle_outline_rounded),
      OrderStatus.disputed => (label: 'Under review', tone: WTone.wait, icon: Icons.gavel_rounded),
      OrderStatus.disputeUpheld || OrderStatus.noWasher => (label: 'Refunded', tone: WTone.mute, icon: Icons.undo_rounded),
      OrderStatus.disputeRejected => (label: 'Done', tone: WTone.ok, icon: Icons.check_circle_outline_rounded),
      OrderStatus.cancelled => (label: 'Cancelled', tone: WTone.mute, icon: Icons.cancel_outlined),
      OrderStatus.pendingPayment => (label: 'Not paid', tone: WTone.mute, icon: Icons.remove_circle_outline_rounded),
    };

WBadge badgeFor(Order o) {
  final b = statusBadge(o);
  return WBadge(label: b.label, tone: b.tone, icon: b.icon);
}

/// Opens an order on the right screen.
void openOrder(BuildContext context, Order o) {
  AppScope.read(context).setOrder(o);
  context.push(o.status.isUpcoming ? liveRouteFor(o) : R.bookingDetail);
}

// ---------------------------------------------------------------------------
// C40-HomeEmpty, C41-HomeActive, C42-HomeCredits, C55-Loading, CA1 (Android)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.forceLoading = false});

  final bool forceLoading;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Order>, List<Vehicle>)> _data = _load();

  Future<(List<Order>, List<Vehicle>)> _load() async {
    final b = AppScope.read(context).backend;
    final results = await Future.wait([b.myOrders(), b.myVehicles()]);
    return (results[0] as List<Order>, results[1] as List<Vehicle>);
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  void _book(BuildContext context) {
    AppScope.read(context).draft.clear();
    context.push(R.vehicleType);
  }

  void _repeat(BuildContext context, Vehicle v) {
    AppScope.read(context).draft.startRepeat(v);
    context.push(R.repeat);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final customer = app.customer;
    return FutureBuilder<(List<Order>, List<Vehicle>)>(
      future: widget.forceLoading ? null : _data,
      builder: (context, snap) {
        final loaded = snap.hasData;
        final orders = snap.data?.$1 ?? const <Order>[];
        final vehicles = snap.data?.$2 ?? const <Vehicle>[];
        final active = orders.where((o) => o.status.isActive).toList();
        final upcomingCount = orders.where((o) => o.status.isUpcoming).length;
        final last = orders.where((o) => !o.status.isUpcoming).firstOrNull;

        return WScreen(
          background: WColors.canvas,
          bottomNav: CustomerNav(index: 0, bookingsBadge: upcomingCount == 0 ? null : upcomingCount),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(WSpace.gutter, 16, WSpace.gutter, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: WLogo(brandName: AppConfig.brandName, size: 28)),
                const SizedBox(height: 20),
                if (!loaded) ..._skeleton() else ...[
                  Text(customer == null || customer.firstName.isEmpty ? 'Hi there' : 'Hi ${customer.firstName}',
                      style: WText.screen),
                  if (orders.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Your wheels are waiting.', style: WText.body),
                  ],
                  const SizedBox(height: 20),
                  if ((customer?.freeWashes ?? 0) > 0) ...[
                    WBanner(
                      tone: WTone.ok,
                      icon: Icons.card_giftcard_rounded,
                      text: 'You have ${customer!.freeWashes} free washes. They’re applied at checkout.',
                      action: last == null
                          ? null
                          : WLinkButton(label: 'Use one', onTap: () => _repeat(context, last.vehicle)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final o in active) ...[
                    _ActiveCard(order: o, onTap: () => openOrder(context, o)),
                    const SizedBox(height: 16),
                  ],
                  if (orders.isEmpty) ..._firstTime(context) else ...[
                    if (active.isEmpty)
                      WCard(
                        style: WCardStyle.raised,
                        child: WButton(label: 'Book a wash', onPressed: () => _book(context)),
                      ),
                    const SizedBox(height: 24),
                    Text('Book again', style: WText.section),
                    const SizedBox(height: 12),
                    WCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: WRowGroup(children: [
                        if (last != null)
                          WListRow(
                            leading: WIconTile(icon: Icons.replay_rounded, size: 40),
                            title: 'Same as last time',
                            subtitle: '${last.vehicle.plate} · ${last.place.parkingShort} · ${rupees(last.price)}',
                            onTap: () => _repeat(context, last.vehicle),
                          ),
                        for (final v in vehicles.where((v) => last == null || v.id != last.vehicle.id))
                          WListRow(
                            leading: WIconTile(icon: vehicleIcon(v.type.kind), size: 40),
                            title: v.plate,
                            subtitle: '${v.type.shortName} · ${v.place?.tower ?? ''} · ${v.place?.floor ?? ''}',
                            onTap: () => _repeat(context, v),
                          ),
                      ]),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _skeleton() => const [
        WSkeleton(height: 28, width: 160),
        SizedBox(height: 20),
        WSkeleton(height: 150, radius: 20),
        SizedBox(height: 24),
        WSkeleton(height: 22, width: 120),
        SizedBox(height: 12),
        WSkeleton(height: 64, radius: 20),
        SizedBox(height: 10),
        WSkeleton(height: 64, radius: 20),
      ];

  List<Widget> _firstTime(BuildContext context) {
    Widget howStep(int n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WAvatar(initials: '$n', size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: WText.bodyStrong)),
            ],
          ),
        );
    return [
      WCard(
        style: WCardStyle.raised,
        padding: const EdgeInsets.all(20),
        child: WGap(gap: 14, children: [
          Text('Book your first wash', style: WText.section),
          Text('Car from ₹149, bike ₹69. Pay only after you see the photos.', style: WText.body),
          WButton(label: 'Book a wash', onPressed: () => _book(context)),
        ]),
      ),
      const SizedBox(height: 24),
      Text('How it works', style: WText.section),
      const SizedBox(height: 8),
      howStep(1, 'Tell us where it’s parked and pick a time'),
      howStep(2, 'A verified washer cleans it, before and after photos'),
      howStep(3, 'You approve the photos, then the washer is paid'),
    ];
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final w = o.washer;
    final title = switch (o.status) {
      OrderStatus.searching => 'Finding a washer',
      OrderStatus.onTheWay => '${w?.name ?? 'Washer'} is on the way',
      OrderStatus.washing => '${w?.name ?? 'Washer'} is washing',
      OrderStatus.photosReady => 'Photos are ready to check',
      _ => 'Your booking',
    };
    return WCard(
      style: WCardStyle.raised,
      onTap: onTap,
      child: WGap(gap: 12, children: [
        Row(children: [
          Expanded(child: Text('${formatDay(o.slot.date)} · ${o.slot.windowLabel}', style: WText.label)),
          badgeFor(o),
        ]),
        Row(children: [
          WAvatar(initials: w?.initials ?? '…', size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: WText.title),
              Text('${o.vehicle.plate} · ${o.place.parkingShort}', style: WText.caption),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: WColors.muted),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// C43-Bookings, C43b (empty), C43c (past)

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late int _tab = widget.initialTab;
  late final Future<List<Order>> _orders = AppScope.read(context).backend.myOrders();

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: WHeader(appBar: const WAppBar(title: 'Bookings')),
      bottomNav: const CustomerNav(index: 1),
      body: Column(
        children: [
          WTabs(labels: const ['Upcoming', 'Past'], index: _tab, onTap: (i) => setState(() => _tab = i)),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _orders,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!.where((o) => _tab == 0 ? o.status.isUpcoming : !o.status.isUpcoming).toList();
                if (list.isEmpty) {
                  return WStateView(
                    icon: Icons.event_available_outlined,
                    tone: WTone.mute,
                    title: _tab == 0 ? 'Nothing booked' : 'No past washes yet',
                    body: 'Your wheels are waiting. Book a wash and we’ll find a washer nearby.',
                    children: [
                      WButton(
                        label: 'Book a wash',
                        expand: false,
                        onPressed: () {
                          AppScope.read(context).draft.clear();
                          context.push(R.vehicleType);
                        },
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(WSpace.gutter),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final o = list[i];
                    final money = switch (o.status) {
                      OrderStatus.cancelled => 'cancelled',
                      OrderStatus.noWasher || OrderStatus.disputeUpheld => '${rupees(o.price)} refunded',
                      _ when o.status.isUpcoming => '${rupees(o.price)} held',
                      _ => '${rupees(o.price)} paid',
                    };
                    return WCard(
                      onTap: () => openOrder(context, o),
                      child: WGap(gap: 10, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              _tab == 0 ? '${formatDay(o.slot.date)} · ${o.slot.windowLabel}' : formatDate(o.slot.date),
                              style: WText.title,
                            ),
                          ),
                          badgeFor(o),
                        ]),
                        Row(children: [
                          WPlate(number: o.vehicle.plate),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${o.vehicle.type.shortName} · $money', style: WText.caption)),
                        ]),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C44-BookingDetail

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    if (o == null) return const NoOrderView();
    final reportUntil = o.reportUntil;
    final canReport = reportUntil != null &&
        reportUntil.isAfter(DateTime.now()) &&
        (o.status == OrderStatus.approved || o.status == OrderStatus.autoApproved);
    final hasPhotos = o.afterPhotos > 0 && o.status != OrderStatus.cancelled;
    return WScreen(
      header: WHeader(
        appBar: WAppBar(
          title: formatDate(o.slot.date),
          subtitle: 'Booking #${o.ref}',
          onBack: () => goBack(context, R.bookings),
          onHelp: () => openHelp(context),
        ),
      ),
      children: [
        Row(children: [
          badgeFor(o),
          const SizedBox(width: 10),
          Text(
            o.refund != null ? '${rupees(o.refund!.amount)} refunded' : '${rupees(o.price)} paid',
            style: WText.money(WText.valueStrong),
          ),
        ]),
        if (hasPhotos)
          WGap(gap: 10, children: [
            Text('Photos', style: WText.label),
            for (final a in const [PhotoAngle.front, PhotoAngle.left])
              Row(children: [
                Expanded(child: WPhotoSlot(label: a.label, state: WPhotoState.filled, tag: WPhotoTag.before)),
                const SizedBox(width: 10),
                Expanded(child: WPhotoSlot(label: a.label, state: WPhotoState.filled, tag: WPhotoTag.after)),
              ]),
          ]),
        WRowGroup(children: [
          WKeyValue(label: 'Vehicle', value: o.vehicle.plate),
          if (o.washer != null)
            WKeyValue(label: 'Washer', value: o.rating == null ? o.washer!.name : '${o.washer!.name} · you rated ${o.rating}'),
          if (o.startedAt != null && o.finishedAt != null && hasPhotos)
            WKeyValue(label: 'Time', value: '${formatTime(o.startedAt!)} – ${formatTime(o.finishedAt!)}'),
          WKeyValue(label: 'Paid', value: '${rupees(o.price)} · ${o.paidWith?.title ?? 'UPI'}'),
        ]),
        if (o.refund != null)
          WListRow(
            leading: const Icon(Icons.undo_rounded, color: WColors.primaryStrong),
            title: 'Refund status',
            onTap: () => context.push(R.refund),
          ),
        WListRow(
          leading: const Icon(Icons.receipt_long_outlined, color: WColors.primaryStrong),
          title: 'Download receipt',
          onTap: () => showWSnack(context, 'Receipts are generated by the server once connected'),
        ),
        if (canReport)
          WListRow(
            leading: const Icon(Icons.flag_outlined, color: WColors.destructive),
            title: 'Report a problem',
            subtitle: 'Until ${formatTime(reportUntil!)}, ${formatDate(reportUntil!)}',
            onTap: () => context.push(R.reportProblem),
          ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Book again',
            onPressed: () {
              AppScope.read(context).draft.startRepeat(o.vehicle);
              context.push(R.repeat);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C45-Repeat

class RepeatScreen extends StatelessWidget {
  const RepeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.draft;
    final type = d.type;
    final place = d.place;
    if (type == null || place == null) {
      return WScreen(
        header: const SimpleHeader(),
        body: WStateView(
          icon: Icons.directions_car_outlined,
          title: 'Pick a vehicle',
          children: [WButton(label: 'Your vehicles', onPressed: () => context.go(R.vehicles))],
        ),
      );
    }
    return WScreen(
      header: WHeader(
        appBar: WAppBar(title: 'Book again', onBack: () => goBack(context), onHelp: () => openHelp(context)),
      ),
      children: [
        const WTitleBlock(title: 'Same wash, new time', subtitle: 'We kept your vehicle and parking details.'),
        WCard(
          child: Row(children: [
            WIconTile(icon: vehicleIcon(type.kind)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WPlate(number: d.plate),
                const SizedBox(height: 6),
                Text('${type.shortName} · ${place.tower} · ${place.parkingShort}', style: WText.caption),
              ]),
            ),
          ]),
        ),
        WRowGroup(children: [
          WKeyValue(label: 'Parking', value: '${place.tower} · ${place.parkingShort}'),
          WKeyValue(label: 'Notes', value: d.note.summary),
          if (d.useFreeWash) const WKeyValue(label: 'Price', value: 'Free wash', strong: true),
        ]),
        Text('Still needed for this wash', style: WText.label),
        WCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: WRowGroup(children: [
            WListRow(
              leading: const WIconTile(icon: Icons.photo_camera_outlined, size: 40),
              title: '4 fresh photos',
              subtitle: 'Every wash starts with new photos',
              onTap: () => context.push(R.photos),
            ),
            const WListRow(
              leading: WIconTile(icon: Icons.badge_outlined, size: 40, tone: WTone.mute),
              title: 'Gate pass',
              subtitle: 'We’ll ask on WhatsApp after you pay',
              trailing: WBadge(label: 'Later', tone: WTone.mute),
            ),
          ]),
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Take photos', onPressed: () => context.push(R.photos))],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C46-Vehicles

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return WScreen(
      bottomNav: const CustomerNav(index: 2),
      body: FutureBuilder<List<Vehicle>>(
        future: app.backend.myVehicles(),
        builder: (context, snap) {
          final list = snap.data ?? const <Vehicle>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(WSpace.gutter, 24, WSpace.gutter, 24),
            children: [
              Text('Your vehicles', style: WText.screen),
              Text(list.isEmpty ? 'Add one to book faster' : '${list.length} saved · tap one to book', style: WText.body),
              const SizedBox(height: 20),
              for (final v in list) ...[
                WCard(
                  onTap: () {
                    app.draft.startRepeat(v);
                    context.push(R.repeat);
                  },
                  child: Row(children: [
                    WIconTile(icon: vehicleIcon(v.type.kind)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        WPlate(number: v.plate),
                        const SizedBox(height: 6),
                        Text('${v.type.shortName} · ${v.place?.tower ?? ''} · ${v.place?.parkingShort ?? ''}',
                            style: WText.caption),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: WColors.muted),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              WButton(
                variant: WButtonVariant.outline,
                icon: Icons.add_rounded,
                label: 'Add a vehicle',
                onPressed: () {
                  app.draft.clear();
                  context.push(R.vehicleType);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C47-Profile, C53-DeleteAccount (dialog)

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Future<void> confirmDelete(BuildContext context) async {
    final app = AppScope.read(context);
    final credits = app.customer?.freeWashes ?? 0;
    final yes = await showWDialog(
      context,
      title: 'Delete your account?',
      body: 'Your vehicles, bookings${credits > 0 ? ' and $credits free washes' : ''} go with it. '
          'You can’t do this while a wash is in progress.',
      confirmLabel: 'Delete account',
      cancelLabel: 'Keep my account',
      destructive: true,
    );
    if (!yes || !context.mounted) return;
    final ok = await guarded(context, () => app.backend.deleteAccount());
    if (!context.mounted) return;
    if (ok == true) {
      app.changed();
      context.go(R.welcome);
    } else if (ok == false) {
      showWSnack(context, 'You can’t delete your account while a wash is in progress');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = app.customer;
    if (c == null) {
      return WScreen(
        bottomNav: const CustomerNav(index: 3),
        body: WStateView(
          icon: Icons.person_outline_rounded,
          title: 'Log in to see your profile',
          body: 'Your bookings, vehicles and free washes live here.',
          children: [
            WButton(
              label: 'Log in',
              onPressed: () {
                app.afterLogin = R.profile;
                context.push(R.login);
              },
            ),
          ],
        ),
      );
    }
    return WScreen(
      bottomNav: const CustomerNav(index: 3),
      children: [
        Row(children: [
          WAvatar(initials: c.initials, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name.isEmpty ? 'Add your name' : c.name, style: WText.section),
              Text(formatPhone(c.phone), style: WText.body),
            ]),
          ),
        ]),
        if (c.freeWashes > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: WBadge(tone: WTone.ok, icon: Icons.card_giftcard_rounded, label: '${c.freeWashes} free washes left'),
          ),
        WRowGroup(children: [
          WListRow(
            leading: const Icon(Icons.edit_outlined, color: WColors.secondary),
            title: 'Edit name',
            onTap: () {
              app.afterLogin = R.profile;
              context.push(R.name);
            },
          ),
          WListRow(
            leading: const Icon(Icons.place_outlined, color: WColors.secondary),
            title: 'Saved places',
            subtitle: 'My Home Avatar, Tower 3',
          ),
          WListRow(
            leading: const Icon(Icons.notifications_none_rounded, color: WColors.secondary),
            title: 'Notifications',
            subtitle: c.notificationsOn ? 'Booking updates on' : 'Off',
            trailing: Switch(
              value: c.notificationsOn,
              onChanged: (v) async {
                if (v) await app.device.requestNotifications();
                await app.backend.setNotifications(v);
                app.changed();
              },
            ),
          ),
          WListRow(
            leading: const Icon(Icons.help_outline_rounded, color: WColors.secondary),
            title: 'Help and support',
            onTap: () => context.push(R.help),
          ),
          WListRow(
            leading: const Icon(Icons.description_outlined, color: WColors.secondary),
            title: 'Terms and privacy',
            onTap: () => app.device.openExternal(Uri.parse(AppConfig.termsUrl)),
          ),
          WListRow(
            leading: const Icon(Icons.logout_rounded, color: WColors.secondary),
            title: 'Log out',
            showChevron: false,
            onTap: () async {
              await app.backend.logout();
              app.changed();
              if (context.mounted) context.go(R.welcome);
            },
          ),
          WListRow(
            leading: const Icon(Icons.delete_outline_rounded, color: WColors.destructive),
            title: 'Delete account',
            titleColor: WColors.destructive,
            showChevron: false,
            onTap: () => confirmDelete(context),
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// C48-Help

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const faqs = [
    (
      'When is my money taken?',
      'You pay when you book, but the money is held safely. It goes to the washer only after you approve the '
          'after-photos, or automatically 2 hours after the wash if we don’t hear from you.'
    ),
    (
      'What if the washer doesn’t come?',
      'If nobody arrives in your time window, we tell you and refund the full amount to your UPI or card.'
    ),
    (
      'Can I cancel?',
      'Yes. Before a washer accepts you get everything back. After a washer accepts, a small trip fee goes to the washer.'
    ),
    (
      'Something got damaged',
      'Report it from the booking within 24 hours. A person from our team calls you within an hour and we use the '
          'time-stamped photos to sort it out.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final device = AppScope.read(context).device;
    return WScreen(
      header: WHeader(appBar: WAppBar(title: 'Help', onBack: () => goBack(context, R.profile))),
      children: [
        const WTitleBlock(title: 'How can we help?'),
        Row(children: [
          Expanded(
            child: WButton(
              icon: Icons.phone_outlined,
              label: 'Call us',
              onPressed: () => device.openExternal(Uri(scheme: 'tel', path: AppConfig.supportPhone)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: WButton(
              variant: WButtonVariant.tonal,
              icon: Icons.chat_outlined,
              label: 'WhatsApp',
              onPressed: () => device.openExternal(Uri.parse('https://wa.me/${AppConfig.supportWhatsApp.replaceAll('+', '')}')),
            ),
          ),
        ]),
        Text(AppConfig.supportHours, style: WText.caption),
        Text('Common questions', style: WText.section),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(children: [
            for (final (q, a) in faqs)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedAlignment: Alignment.centerLeft,
                title: Text(q, style: WText.rowTitle),
                children: [Text(a, style: WText.body)],
              ),
          ]),
        ),
      ],
    );
  }
}

/// C53: Profile with the delete-account dialog open (gallery and deep link).
class ProfileWithDeleteDialog extends StatefulWidget {
  const ProfileWithDeleteDialog({super.key});

  @override
  State<ProfileWithDeleteDialog> createState() => _ProfileWithDeleteDialogState();
}

class _ProfileWithDeleteDialogState extends State<ProfileWithDeleteDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileScreen.confirmDelete(context);
    });
  }

  @override
  Widget build(BuildContext context) => const ProfileScreen();
}
