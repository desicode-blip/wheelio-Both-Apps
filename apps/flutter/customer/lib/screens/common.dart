// Pieces shared by several customer screens: brand mark, headers, captain card, status badge,
// bell, profile photo picker.

import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/models.dart';
import '../data/store.dart';

void callSupport() => Support.call();

/// Brand mark: blue rounded square with the ring, plus the name token.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.light = false, this.showName = true});
  final double size;
  final bool light;
  final bool showName;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: light ? Colors.transparent : WColor.primary, borderRadius: BorderRadius.circular(size * 0.24)),
          alignment: Alignment.center,
          child: Container(
            width: size * 0.56,
            height: size * 0.56,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.white, width: size * 0.1)),
            alignment: Alignment.center,
            child: Container(width: size * 0.2, height: size * 0.2, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
          ),
        ),
        if (showName) ...[
          SizedBox(width: size * 0.3),
          Text(Brand.name, style: wStyle(WType.screen, weight: bold, size: size * (light ? 1.2 : 0.8), color: light ? WColor.white : WColor.heading)),
        ],
      ]);
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
  const BookingHeader({super.key, required this.step, required this.label, this.title = 'Book a wash', this.fraction});
  final int step;
  final String label;
  final String title;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final total = StepTotal.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(children: [
        WAppBar(title: title, onLeading: context.router.pop, onTrailing: () => context.router.go(N.help)),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter), child: WProgress(fraction: fraction ?? step / total, label: 'Step $step of $total · $label')),
      ]),
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
        child: WAppBar(title: order.slot.full, subtitle: order.vehicleLine, onLeading: onBack ?? context.router.popToRoot, onTrailing: () => context.router.go(N.help)),
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
      child: Column(children: [
        Row(children: [
          WAvatar(c?.initials ?? 'RY', size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WText(c?.name ?? 'Raju', WType.title, weight: semibold, size: 17),
              const SizedBox(height: 2),
              Row(children: [
                const WIconView(WIcon.starFill, size: 11, color: WColor.star),
                const SizedBox(width: 4),
                WText('${(c?.rating ?? 4.8).toStringAsFixed(1)} · ${c?.washes ?? 212} washes', WType.caption),
              ]),
            ]),
          ),
          WIconButton(WIcon.phone, style: IconButtonStyle.tint, label: 'Call ${c?.name ?? 'captain'}', onTap: () => Support.call()),
        ]),
        const SizedBox(height: 14),
        Row(children: [badge, const Spacer(), WText(timeText, WType.caption, color: WColor.heading, weight: medium)]),
      ]),
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: WIconView(WIcon.shield, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: WRich([('${Fmt.rupees(amount)} is held safely. ', semibold), ('It’s released to the captain only after you approve the after-photos.', null)], WType.caption, color: WColor.inverse, size: 14)),
        ]),
      );
}

/// Status badge for an order (icon + word).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final OrderStatus status;
  @override
  Widget build(BuildContext context) => switch (status) {
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
        child: Stack(clipBehavior: Clip.none, children: [
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
                child: Text(n > 9 ? '9+' : '$n', style: wStyle(WType.small, weight: bold, size: 10, color: WColor.white)),
              ),
            ),
        ]),
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
        child: Stack(clipBehavior: Clip.none, children: [
          WAvatar(initials, size: size, photo: store.profilePhoto),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: WColor.primary, shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 2)),
              alignment: Alignment.center,
              child: const WIconView(WIcon.camera, size: 10, color: WColor.white),
            ),
          ),
        ]),
      ),
    );
  }
}
