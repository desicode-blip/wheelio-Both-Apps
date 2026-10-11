import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';

/// Back if there is somewhere to go back to, otherwise go to [fallback].
void goBack(BuildContext context, [String fallback = R.home]) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

void openHelp(BuildContext context) => context.push(R.help);

/// Call/help sits bottom-left on task screens.
Widget supportButton(BuildContext context, {String label = 'Call support'}) => WIconButton(
      icon: Icons.phone_outlined,
      label: label,
      onPressed: () => openHelp(context),
    );

/// Header for the 5-step booking flow.
class BookingHeader extends StatelessWidget {
  const BookingHeader({super.key, required this.step, required this.label, this.onBack});

  final int step;
  final String label;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => WHeader(
        appBar: WAppBar(
          title: 'Book a wash',
          onBack: onBack ?? () => goBack(context, R.home),
          onHelp: () => openHelp(context),
        ),
        progress: WProgress(step: step, total: 5, label: label),
      );
}

/// Plain header: back + help, optional title.
class SimpleHeader extends StatelessWidget {
  const SimpleHeader({super.key, this.title, this.subtitle, this.fallback = R.home, this.showBack = true, this.onBack});

  final String? title;
  final String? subtitle;
  final String fallback;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => WHeader(
        appBar: WAppBar(
          title: title,
          subtitle: subtitle,
          onBack: showBack ? (onBack ?? () => goBack(context, fallback)) : null,
          onHelp: () => openHelp(context),
        ),
      );
}

/// Header on live-order screens: "Today, 8 – 10 AM" / "TS 09 EA 4521 · Hatchback".
class OrderHeader extends StatelessWidget {
  const OrderHeader({super.key, required this.order, this.onBack});

  final Order order;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => WHeader(
        appBar: WAppBar(
          title: '${formatDay(order.slot.date)}, ${order.slot.windowLabel}',
          subtitle: '${order.vehicle.plate} · ${order.vehicle.type.shortName}',
          onBack: onBack ?? () => context.go(R.home),
          backIcon: Icons.close_rounded,
          backLabel: 'Close',
          onHelp: () => openHelp(context),
        ),
      );
}

/// Washer card: avatar, name, rating, status.
class WasherCard extends StatelessWidget {
  const WasherCard({super.key, required this.washer, required this.badge, this.detail});

  final Washer washer;
  final WBadge badge;
  final String? detail;

  @override
  Widget build(BuildContext context) => WCard(
        style: WCardStyle.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WAvatar(initials: washer.initials, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(washer.name, style: WText.section),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: WColors.wait),
                          const SizedBox(width: 4),
                          Text('${washer.rating.toStringAsFixed(1)} · ${washer.washes} washes', style: WText.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [badge, if (detail != null) Text(detail!, style: WText.valueStrong)],
            ),
          ],
        ),
      );
}

const orderSteps = ['Booked', 'Washer on the way', 'Washing', 'Check photos'];

/// Money copy on every payment screen: held safely, released only after approval.
class HeldSafelyBanner extends StatelessWidget {
  const HeldSafelyBanner({super.key, required this.amount, this.text});

  final int amount;
  final String? text;

  @override
  Widget build(BuildContext context) => WBanner(
        tone: WTone.ok,
        icon: Icons.verified_user_outlined,
        text: text ?? '${rupees(amount)} is held safely. It’s released to the washer only after you approve the after-photos.',
      );
}

/// Customer bottom navigation: Home · Bookings · Vehicles · Profile.
class CustomerNav extends StatelessWidget {
  const CustomerNav({super.key, required this.index, this.bookingsBadge});

  final int index;
  final int? bookingsBadge;

  @override
  Widget build(BuildContext context) => WBottomNav(
        index: index,
        items: [
          const WNavItem(icon: Icons.home_outlined, label: 'Home'),
          WNavItem(icon: Icons.event_note_outlined, label: 'Bookings', badge: bookingsBadge),
          const WNavItem(icon: Icons.directions_car_outlined, label: 'Vehicles'),
          const WNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
        onTap: (i) {
          if (i == index) return;
          context.go(const [R.home, R.bookings, R.vehicles, R.profile][i]);
        },
      );
}

/// Shown when a screen needs an order but none is selected.
class NoOrderView extends StatelessWidget {
  const NoOrderView({super.key});

  @override
  Widget build(BuildContext context) => WScreen(
        header: const SimpleHeader(),
        body: WStateView(
          icon: Icons.event_busy_outlined,
          tone: WTone.mute,
          title: 'No booking selected',
          body: 'Open a booking from the Bookings tab.',
          children: [WButton(label: 'Go to bookings', onPressed: () => context.go(R.bookings))],
        ),
      );
}

/// Rebuilds with live updates for the current order and moves to the right
/// screen when the status changes (searching → on the way → washing → photos).
class OrderWatcher extends StatefulWidget {
  const OrderWatcher({super.key, required this.route, required this.builder});

  /// The route this screen is shown at; navigation happens when the order's
  /// live route differs from it.
  final String route;
  final Widget Function(BuildContext context, Order order) builder;

  @override
  State<OrderWatcher> createState() => _OrderWatcherState();
}

class _OrderWatcherState extends State<OrderWatcher> {
  StreamSubscription<Order>? _sub;
  Order? _order;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final app = AppScope.read(context);
    _order = app.currentOrder;
    final id = _order?.id;
    if (id == null) return;
    _sub = app.backend.watchOrder(id).listen((o) {
      if (!mounted) return;
      app.currentOrder = o;
      final target = liveRouteFor(o);
      final targetPath = target.split('?').first;
      if (targetPath != widget.route) {
        context.go(target);
      } else {
        setState(() => _order = o);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    if (o == null) return const NoOrderView();
    return widget.builder(context, o);
  }
}

/// Runs a backend call and routes the standard failures to the designed
/// offline (C50) and error (C51) screens.
Future<T?> guarded<T>(BuildContext context, Future<T> Function() call) async {
  try {
    return await call();
  } on BackendException catch (e) {
    if (context.mounted) context.push(e.offline ? R.offline : R.error);
    return null;
  }
}
