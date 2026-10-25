import 'dart:async';

// Pieces shared by several customer screens: brand mark, headers, captain card, status badge,
// bell, profile photo picker.

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/models.dart';
import '../data/store.dart';

void callSupport() => Support.call();

/// WashKrew logo. [size] is the old mark size; the logo scales from it.
/// showName: false gives the door mark alone. light: true is for dark backgrounds.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.light = false, this.showName = true});
  final double size;
  final bool light;
  final bool showName;

  @override
  Widget build(BuildContext context) => showName
      ? WLogo(height: size * 1.4, onDark: light)
      : WLogo(kind: WLogoKind.mark, height: size, onDark: light);
}

/// Total steps shown in BookingHeader ("Step 1 of 2").
class StepTotal extends InheritedWidget {
  const StepTotal({super.key, required this.total, required super.child});
  final int total;
  static int of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StepTotal>()?.total ?? 5;
  @override
  bool updateShouldNotify(StepTotal old) => old.total != total;
}

/// Header used by every booking step: app bar + "Step n of 5 · Label".
class BookingHeader extends StatelessWidget {
  const BookingHeader({
    super.key,
    required this.step,
    required this.label,
    this.title = 'Book a wash',
    this.fraction,
    this.showBack = true,
    this.showProgress = true,
  });
  final int step;
  final String label;
  final String title;
  final double? fraction;
  final bool showBack;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final total = StepTotal.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          WAppBar(title: title, leading: showBack ? WIcon.left : null, onLeading: context.router.pop, onTrailing: () => context.router.go(N.help)),
          if (showProgress) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
              child: WProgress(fraction: fraction ?? step / total, label: 'Step $step of $total · $label'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain header with back and help, no title (login screens).
class PlainHeader extends StatelessWidget {
  const PlainHeader({super.key, this.leading = WIcon.left});
  final WIcon? leading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: WAppBar(leading: leading, onLeading: context.router.pop, onTrailing: () => context.router.go(N.help)),
  );
}

/// Order header: "Today, 8 – 10 AM" over "TS 09 EA 4521 · Hatchback".
class OrderHeader extends StatelessWidget {
  const OrderHeader({super.key, required this.order, this.onBack});
  final Order order;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: WAppBar(
      title: order.slot.full,
      subtitle: order.vehicleLine,
      onLeading: onBack ?? context.router.popToRoot,
      onTrailing: () => context.router.go(N.help),
    ),
  );
}

/// Captain card: avatar, name, rating, call button, status badge and time.
class CaptainCard extends StatelessWidget {
  const CaptainCard({super.key, required this.order, required this.badge, required this.timeText});
  final Order order;
  final Widget badge;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final c = order.captain;
    return WCard(
      child: Column(
        children: [
          Row(
            children: [
              WAvatar(c?.initials ?? 'RY', size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WText(c?.name ?? 'Raju', WType.title, weight: semibold, size: 17),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const WIconView(WIcon.starFill, size: 11, color: WColor.star),
                        const SizedBox(width: 4),
                        WText('${(c?.rating ?? 4.8).toStringAsFixed(1)} · ${c?.washes ?? 212} washes', WType.caption),
                      ],
                    ),
                  ],
                ),
              ),
              WIconButton(WIcon.phone, style: IconButtonStyle.tint, label: 'Call ${c?.name ?? 'captain'}', onTap: () => Support.call()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              badge,
              const Spacer(),
              WText(timeText, WType.caption, color: WColor.heading, weight: medium),
            ],
          ),
        ],
      ),
    );
  }
}

/// "₹149 is held safely. It's released to the captain only after you approve the after-photos."
class HeldSafelyBanner extends StatelessWidget {
  const HeldSafelyBanner({super.key, required this.amount});
  final int amount;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: WIconView(WIcon.shield, size: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: WRich(
            context.store.isLive
                ? [
                    ('Pay ${Fmt.rupees(amount)} through Razorpay. ', semibold),
                    ('The captain’s earnings stay pending until you approve the after photos.', null),
                  ]
                : [('${Fmt.rupees(amount)} is held safely. ', semibold), ('It’s released to the captain only after you approve the after-photos.', null)],
            WType.caption,
            color: WColor.inverse,
            size: 14,
          ),
        ),
      ],
    ),
  );
}

/// Status badge for an order (icon + word).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.slotAhead = false});
  final OrderStatus status;

  /// Booked for a later slot: shows "Booked" instead of "Searching".
  final bool slotAhead;
  @override
  Widget build(BuildContext context) => switch (status) {
    OrderStatus.searching when slotAhead => const WBadge('Booked', tone: Tone.info, icon: WIcon.calendar),
    OrderStatus.searching => const WBadge('Searching', tone: Tone.mute, icon: WIcon.search),
    OrderStatus.onTheWay => const WBadge('On the way', tone: Tone.info, icon: WIcon.check),
    OrderStatus.washing => const WBadge('Washing', tone: Tone.info, icon: WIcon.drop),
    OrderStatus.photosReady => const WBadge('Check photos', tone: Tone.ok, icon: WIcon.image),
    OrderStatus.approved || OrderStatus.autoApproved || OrderStatus.disputeRejected => const WBadge('Done', tone: Tone.ok, icon: WIcon.sparkle),
    OrderStatus.cancelled => const WBadge('Cancelled', tone: Tone.error, icon: WIcon.close),
    OrderStatus.noCaptain || OrderStatus.disputeUpheld || OrderStatus.captainNoShow => const WBadge('Refunded', tone: Tone.ok, icon: WIcon.rupee),
    OrderStatus.disputed => const WBadge('Under review', tone: Tone.wait, icon: WIcon.eye),
    OrderStatus.paymentPending => const WBadge('Payment pending', tone: Tone.wait, icon: WIcon.clock),
    OrderStatus.pendingPayment => const WBadge('Not paid', tone: Tone.mute, icon: WIcon.clock),
  };
}

/// Bell with unread count, for the Home header.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final n = store.unreadCount;
    return Pressable(
      label: n > 0 ? 'Notifications, $n unread' : 'Notifications',
      onTap: () => context.router.go(N.notifications),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: WIconView(store.notificationsOn ? WIcon.bell : WIcon.bellSlash, size: 20)),
            if (n > 0)
              Positioned(
                top: 4,
                right: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: WColor.destructive, borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text(
                    n > 9 ? '9+' : '$n',
                    style: wStyle(WType.small, weight: bold, size: 10, color: WColor.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tap the profile circle to pick a photo. Long-press (or right-click) to remove it.
class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({super.key, required this.initials, this.size = 56});
  final String initials;
  final double size;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Pressable(
      label: store.profilePhoto == null ? 'Add a profile photo' : 'Change profile photo',
      onTap: () async {
        final d = await Device.pickImage();
        if (d != null) store.set(() => store.profilePhoto = d);
      },
      onLongPress: store.profilePhoto == null
          ? null
          : () => showWActions(context, actions: [AlertAction('Remove photo', destructive: true, onTap: () => store.set(() => store.profilePhoto = null))]),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            WAvatar(initials, size: size, photo: store.profilePhoto),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: WColor.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: WColor.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const WIconView(WIcon.camera, size: 10, color: WColor.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// "Cancel booking · 12 min left". Shown only while the 15-minute cancel window is open;
/// opens the cancel sheet for this order. Counts down by itself.
class CancelLink extends StatefulWidget {
  const CancelLink({super.key, required this.order, this.compact = false});
  final Order order;

  /// Small text link (cards) instead of a full-width text button (order screen).
  final bool compact;
  @override
  State<CancelLink> createState() => _CancelLinkState();
}

class _CancelLinkState extends State<CancelLink> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 15), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (!o.canCancel()) return const SizedBox.shrink();
    const label = 'Cancel booking'; // details only in the sheet, to keep cards clean
    void open() => openCancelSheet(context, o);
    return widget.compact
        ? WLink(label, k: WType.caption, color: WColor.destructive, onTap: open)
        : WButton(label, kind: ButtonKind.text, onTap: open);
  }
}

/// Opens the cancel sheet for [o] (it becomes the current order).
void openCancelSheet(BuildContext context, Order o) {
  final store = context.store;
  store.set(() => store.currentOrderId = o.id);
  showWSheet<void>(context, height: 480, builder: (c) => AppScope(store: store, router: context.router, child: const CancelSheet()));
}

// MARK: C29 Cancel sheet: within 15 minutes of booking, no refund, 1 free wash instead.

class CancelSheet extends StatefulWidget {
  const CancelSheet({super.key});
  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  String? reason;
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final o = store.currentOrder;
    final open = o?.canCancel() ?? false;
    if (!open) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WText('The wash has started', WType.section, weight: semibold),
        const SizedBox(height: 12),
        const WText('A booking can’t be cancelled once the captain starts washing. Something wrong? Use Help.', WType.body),
        const SizedBox(height: 22),
        WButton('OK', onTap: () => Navigator.of(context).pop()),
      ]);
    }
    final early = o!.inFreeCancelWindow();
    final credit = BusinessRules.lateCancelCredit(o.value);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WText('Cancel this booking?', WType.section, weight: semibold),
        const SizedBox(height: 14),
        // Say exactly what they get back before they confirm.
        if (store.isLive)
          WBanner(tone: Tone.info, icon: WIcon.info, text: o.cancellationTerms)
        else if (early)
          const WBanner(tone: Tone.ok, icon: WIcon.gift, title: 'You get 1 free wash', text: 'For your next booking. No cash refund.')
        else
          WBanner(
            tone: Tone.ok,
            icon: WIcon.rupee,
            title: 'You get ${Fmt.rupees(credit)} credit',
            text: '${BusinessRules.lateCancelCreditPercent}% of ${Fmt.rupees(o.value)}, taken off your next booking. No cash refund.',
          ),
        const SizedBox(height: 16),
        const WText('Why are you cancelling? (optional)', WType.label),
        const SizedBox(height: 10),
        WFlow(children: [for (final r in const ['Changed plans', 'Booked by mistake', 'Wrong time', 'Other']) WChip(r, selected: reason == r, onTap: () => setState(() => reason = r))]),
        if (error != null) ...[const SizedBox(height: 12), WText(error!, WType.caption, color: WColor.destructive)],
        const SizedBox(height: 18),
        WButton('Cancel booking', kind: ButtonKind.danger, loading: loading, onTap: () async {
          final nav = Navigator.of(context);
          setState(() {
            loading = true;
            error = null;
          });
          try {
            await store.cancel(o.id);
            store.set(() => store.toast = store.isLive ? 'Booking cancelled. Check your booking for the confirmed outcome.' : early ? 'Booking cancelled. 1 free wash added.' : 'Booking cancelled. ${Fmt.rupees(credit)} credit added.');
            nav.pop();
          } catch (e) {
            setState(() {
              loading = false;
              error = e is StateError ? e.message : 'Couldn’t cancel. Please try again.';
            });
          }
        }),
        const SizedBox(height: 10),
        WButton('Keep booking', kind: ButtonKind.text, onTap: () => Navigator.of(context).pop()),
      ]),
    );
  }
}
