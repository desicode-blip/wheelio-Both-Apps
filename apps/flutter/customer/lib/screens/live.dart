import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/models.dart';
import '../data/refund_status.dart';
import '../data/store.dart';
import 'auth_pay.dart';
import 'common.dart';
import 'problem.dart';

const _liveSteps = [('Booked', null), ('Captain on the way', null), ('Washing', null), ('Check photos', null)];

/// Booked and live screens tell the store which order is open, so no banner shows for it.
class ViewingOrder extends StatelessWidget {
  const ViewingOrder({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return OnAppear(
      onAppear: () => store.viewingOrderId = store.currentOrderId,
      onDisappear: () {
        if (!router.isAt(N.live) && !router.isAt(N.booked)) store.viewingOrderId = null;
      },
      child: child,
    );
  }
}

// MARK: Live order (C20, C21, C22, C22b, C23, C24, C25, C28, C29b, C30)

class LiveOrderScreen extends StatefulWidget {
  const LiveOrderScreen({super.key});
  @override
  State<LiveOrderScreen> createState() => _LiveOrderScreenState();
}

class _LiveOrderScreenState extends State<LiveOrderScreen> {
  OrderStatus? _lastStatus;


  void _again(Order o) {
    context.store.startRepeat(o.vehicle);
    context.router.replace(const [R(N.timeSlot)]);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    // Approved from elsewhere (e.g. the photo compare screen): go to Rate.
    if (o != null && _lastStatus != null && _lastStatus != o.status && o.status == OrderStatus.approved && o.rating == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => router.replace(const [R(N.rate)]));
    }
    _lastStatus = o?.status;

    Widget body;
    if (o == null) {
      body = WScreen(scrolls: false, header: const PlainHeader(), children: [Expanded(child: WFullState(icon: WIcon.calendar, title: 'No active booking', primary: 'Go home', onPrimary: router.popToRoot))]);
    } else {
      body = switch (o.status) {
        OrderStatus.searching when o.slotAhead => _booked(o),
        // An unpaid live booking opens the designed payment screen so it can be paid again.
        OrderStatus.paymentPending || OrderStatus.pendingPayment when store.isLive => const PayingScreen(initial: PayView.failed),
        OrderStatus.searching || OrderStatus.paymentPending || OrderStatus.pendingPayment => _searching(o),
        OrderStatus.noCaptain => _autoCancelled(o, WIcon.search, 'No captain could take your wash', 'We couldn’t find a free captain, so we’ve cancelled the booking.'),
        OrderStatus.captainNoShow => _autoCancelled(o, WIcon.clock, '${o.captain?.name ?? 'Your captain'} didn’t turn up',
            'The wash wasn’t done in your slot. We’re sorry. You get the full amount back by 11:59 PM tonight, and we’ve taken action with the captain.'),
        OrderStatus.onTheWay => o.captainCantFind ? _cantFind(o) : _onTheWay(o),
        OrderStatus.washing => _washing(o),
        OrderStatus.photosReady => CheckWashView(order: o),
        OrderStatus.cancelled when o.creditGiven > 0 => _state(WFullState(
            icon: WIcon.rupee,
            tone: Tone.ok,
            title: 'Booking cancelled',
            message: '${Fmt.rupees(o.creditGiven)} (${BusinessRules.lateCancelCreditPercent}% of ${Fmt.rupees(o.value)}) is added as credit. It comes off your next booking, so you pay only the rest.',
            primary: 'Book again',
            secondary: 'Go home',
            onPrimary: () => _again(o),
            onSecondary: router.popToRoot,
          )),
        OrderStatus.cancelled => _state(o.freeWashGiven
            ? WFullState(
                icon: WIcon.gift,
                tone: Tone.ok,
                title: 'Booking cancelled',
                message: 'We’ve added 1 free wash to your account. It’s used automatically when you book next, so you pay nothing.',
                primary: 'Book with free wash',
                secondary: 'Go home',
                onPrimary: () => _again(o),
                onSecondary: router.popToRoot,
              )
            : WFullState(
                icon: WIcon.check,
                tone: Tone.ok,
                title: 'Booking cancelled',
                message: store.isLive?'${Fmt.rupees(o.refund?.amount ?? o.price)} · ${refundStatusText(o.refundStatus,null).detail}':'${Fmt.rupees(o.refund?.amount ?? o.price)} is on its way back to your UPI. It usually takes 2 to 3 working days.',
                primary: 'Book another time',
                secondary: 'Track refund',
                onPrimary: () => _again(o),
                onSecondary: () => router.go(N.refund),
              )),
        OrderStatus.autoApproved => _state(WFullState(
            icon: WIcon.clock,
            title: 'Approved automatically',
            message: 'We didn’t hear from you by midnight, so the wash was approved and ${Fmt.rupees(o.price)} went to ${o.captain?.name ?? 'Raju'}. Something wrong? You can still report it until midnight tomorrow.',
            primary: 'Rate ${o.captain?.name ?? 'Raju'}',
            secondary: 'Report a problem',
            onPrimary: () => router.go(N.rate),
            onSecondary: () => router.go(N.reportProblem),
          )),
        OrderStatus.approved => _state(WFullState(icon: WIcon.sparkle, tone: Tone.ok, title: 'Wash approved', message: '${Fmt.rupees(o.price)} released to ${o.captain?.name ?? 'Raju'}.', primary: 'Go home', onPrimary: router.popToRoot)),
        _ => const DisputeStatusScreen(),
      };
    }
    return ViewingOrder(child: body);
  }

  Widget _state(Widget s) => WScreen(scrolls: false, header: const PlainHeader(), children: [Expanded(child: s)]);

  /// No captain / captain no-show: cancelled automatically, full refund to the customer's UPI.
  Widget _autoCancelled(Order o, WIcon icon, String title, String why) {
    final router = context.router;
    final r = o.refund;
    final waiting = !context.store.isLive && (r?.awaitingUPI ?? true);
    return WScreen(
      scrolls: false,
      header: const PlainHeader(),
      footer: WStackedFooter(children: waiting
          ? [WButton('Add UPI ID for refund', icon: WIcon.rupee, onTap: () => router.push(R(N.refundUPI, id: o.id))), WButton('Book another time', kind: ButtonKind.text, onTap: () => _again(o))]
          : [WButton('Book another time', onTap: () => _again(o)), WButton('See refund', kind: ButtonKind.text, onTap: () => router.go(N.refund))]),
      children: [
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: WStateCircle(icon, tone: Tone.wait, size: 72)),
        const SizedBox(height: 18),
        WText(title, WType.screen),
        const SizedBox(height: 8),
        WText(why, WType.body),
        const SizedBox(height: 20),
        WCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const WText('Full refund', WType.label), const Spacer(), WText(Fmt.rupees(r?.amount ?? o.price), WType.valueStrong, mono: true)]),
            const SizedBox(height: 8),
            WText(context.store.isLive?refundStatusText(o.refundStatus,null).detail:waiting ? 'Tell us your UPI ID and we’ll send it there.' : 'Going to ${r?.upi ?? 'your UPI'}. Usually within 2 to 3 working days.', WType.caption),
          ]),
        ),
      ],
    );
  }

  // C20a Booked for a later slot: what's booked, the customer's own photos, and cancel (15 min).
  Widget _booked(Order o) {
    final notes = o.note.summary;
    return WScreen(
      canvas: true,
      header: OrderHeader(order: o),
      footer: WStackedFooter(children: [WButton('Done', onTap: context.router.popToRoot), CancelLink(order: o)]),
      children: [
        const SizedBox(height: 14),
        WCard(
          padding: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WBadge('Booked', tone: Tone.info, icon: WIcon.calendar),
            const SizedBox(height: 12),
            WText(o.slot.full, WType.section, weight: semibold),
            const SizedBox(height: 6),
            const WText('We’ll assign a captain before your slot and let you know.', WType.body),
            const SizedBox(height: 14),
            WBadge(o.usedFreeWash ? 'Free wash' : '${Fmt.rupees(o.price)} held safely', tone: Tone.mute, icon: o.usedFreeWash ? WIcon.gift : WIcon.shield),
          ]),
        ),
        const SizedBox(height: 22),
        // Only the photos the customer took: before/after come after the wash.
        const WText('Your photos', WType.label, color: WColor.heading),
        const SizedBox(height: 10),
        Row(children: [
          for (final a in PhotoAngle.values) ...[
            if (a != PhotoAngle.values.first) const SizedBox(width: 8),
            Expanded(child: DesignPhoto(path: o.customerPhotoPaths[a.name], height: 64, icon: o.vehicle.type.icon, tag: a.label.split(' ').first)),
          ],
        ]),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 18),
          WKeyValueCard(rows: [('Place', '${o.place.title} · ${o.place.parkingShort}'), ('Notes', notes)]),
        ],
        const SizedBox(height: 26),
        const WStatusSteps(steps: _liveSteps, current: 0),
      ],
    );
  }

  // C20 Finding a captain
  Widget _searching(Order o) => WScreen(
        canvas: true,
        header: OrderHeader(order: o),
        footer: WStackedFooter(children: [WButton('Keep me posted', onTap: context.router.popToRoot), CancelLink(order: o)]),
        children: [
          const SizedBox(height: 14),
          WCard(
            padding: 22,
            child: Column(children: [
              const SearchPulse(),
              const SizedBox(height: 22),
              const WText('Finding a captain…', WType.section, weight: semibold),
              const SizedBox(height: 8),
              const WText('Usually under 5 minutes. You can leave this screen; we’ll notify you.', WType.body, align: TextAlign.center),
              const SizedBox(height: 14),
              WBadge('${Fmt.rupees(o.price)} held safely', tone: Tone.mute, icon: WIcon.shield),
            ]),
          ),
          const SizedBox(height: 28),
          const WStatusSteps(steps: _liveSteps, current: 0),
        ],
      );

  // C22 on the way, C22b pass missing, C24 running late
  Widget _onTheWay(Order o) {
    final router = context.router;
    final late = o.runningLateMinutes != null;
    final hasEta=!context.store.isLive||o.etaFresh;
    final arrives = o.arrivesBy ?? DateTime.now();
    final name = o.captain?.name ?? (context.store.isLive?'Your captain':'Raju');
    return WScreen(
      canvas: true,
      header: OrderHeader(order: o),
      footer: WStackedFooter(children: [
        if (late)
          WButton('Call $name', icon: WIcon.phone, kind: ButtonKind.outline, onTap: () => Support.call())
        else if (o.entryPassReceived)
          WButton('Message on WhatsApp', icon: WIcon.whatsapp, kind: ButtonKind.outline, onTap: () => context.store.blockLive() ? null : router.go(N.whatsApp))
        else
          WButton('Send pass on WhatsApp', icon: WIcon.whatsapp, onTap: () => context.store.blockLive() ? null : router.go(N.whatsApp)),
        CancelLink(order: o),
      ]),
      children: [
        const SizedBox(height: 14),
        if (late) ...[
          CaptainCard(
            order: o,
            badge: o.noShowChecking ? const WBadge('Checking', tone: Tone.wait, icon: WIcon.search) : const WBadge('Running late', tone: Tone.wait, icon: WIcon.clock),
            timeText:hasEta?'Now arriving ${Fmt.time(arrives)}':'Checking arrival time',
          ),
          const SizedBox(height: 16),
          o.noShowChecking
              ? WBanner(tone: Tone.wait, icon: WIcon.search, title: 'We’re checking on your wash.',
                  text: 'Your slot ended at ${Fmt.time(o.slot.end)} and $name hasn’t updated it. If the wash doesn’t happen, you get a full refund by 11:59 PM tonight.')
              : WBanner(tone: Tone.wait, icon: WIcon.clock,
                  text: '$name is running about ${o.runningLateMinutes ?? 15} minutes late. If the wash doesn’t happen in your slot (till ${Fmt.time(o.slot.end)}), we’ll check with him. No wash means a full refund.'),
        ] else ...[
          CaptainCard(order: o, badge: const WBadge('Accepted', tone: Tone.info, icon: WIcon.check), timeText:hasEta?'Arrives by ${Fmt.time(arrives)}':'Arrival estimate unavailable'),
          const SizedBox(height: 16),
          if (o.entryPassReceived)
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [const WIconView(WIcon.check, size: 15, color: WColor.onSuccess, weight: semibold), const SizedBox(width: 12), Expanded(child: WText('Entry pass received. $name can get in.', WType.caption, color: WColor.onSuccess, size: 14))]),
            )
          else
            WBanner(tone: Tone.wait, icon: WIcon.door, title: 'We still need your gate pass.', text: 'Without it $name may be stopped at the gate.', actionTitle: 'Send now', onAction: () => context.store.blockLive() ? null : router.go(N.whatsApp)),
        ],
        const SizedBox(height: 26),
        const WStatusSteps(steps: _liveSteps, current: 1),
      ],
    );
  }

  // C30 Captain can't find vehicle
  Widget _cantFind(Order o) {
    final store = context.store;
    final name = o.captain?.name ?? 'Raju';
    Widget answer(WIcon icon, String title, String code) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable(
            onTap: () => store.answerCantFind(code),
            child: Container(
              height: 48,
              decoration: outlinedDecoration(radius: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [WIconView(icon, size: 15), const SizedBox(width: 10), WText(title, WType.bodyStrong, color: WColor.heading, weight: medium)]),
            ),
          ),
        );
    return WScreen(
      canvas: true,
      header: OrderHeader(order: o),
      footer: WFooterBar(showCall: false, child: WButton('Call $name', icon: WIcon.phone, onTap: () => Support.call())),
      children: [
        const SizedBox(height: 14),
        WCard(
          padding: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const WIconBox(WIcon.warning, size: 44, tone: Tone.wait), const SizedBox(width: 12), Expanded(child: WText('$name can’t find your vehicle', WType.title))]),
            const SizedBox(height: 12),
            WText('He’s at ${o.place.floor ?? 'B2'} near slot ${o.place.slot.isEmpty ? '41' : o.place.slot} and doesn’t see ${o.vehicle.plate}. Is it parked somewhere else today?', WType.body),
          ]),
        ),
        const SizedBox(height: 18),
        answer(WIcon.layers, 'It’s on a different floor', 'other_floor'),
        answer(WIcon.location, 'I moved it outside', 'outside'),
        answer(WIcon.close, 'It’s not here today', 'not_here'),
      ],
    );
  }

  // C23 Washing
  Widget _washing(Order o) {
    final store = context.store, router = context.router;
    return WScreen(
      canvas: true,
      header: OrderHeader(order: o),
      // Calling the captain lives in the card above; the footer moves the customer on.
      footer: WStackedFooter(children: [
        WButton('Book another wash', kind: ButtonKind.outline, onTap: () {
          store.startNewBooking();
          router.replace(const [R(N.vehicleType)]);
        }),
        WButton('Go home', kind: ButtonKind.text, onTap: () {
          router.tab = 0;
          router.popToRoot();
        }),
      ]),
      children: [
        const SizedBox(height: 14),
        CaptainCard(order: o, badge: const WBadge('Cleaning', tone: Tone.info, icon: WIcon.drop), timeText: 'Started ${Fmt.time(o.startedAt ?? DateTime.now())}'),
        const SizedBox(height: 16),
        WCard(
          outlined: true,
          child: Column(children: [
            Row(children: [const Expanded(child: WText('Before photos', WType.title)), WText(context.store.isLive ? '${[for (var i = 0; i < 4; i++) o.evidence('before', i)].nonNulls.length} of 4' : '4 of 4', WType.caption)]),
            const SizedBox(height: 12),
            Row(children: [for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: DesignPhoto(path: o.evidence('before', i), height: 56))]]),
          ]),
        ),
        const SizedBox(height: 24),
        const WStatusSteps(steps: _liveSteps, current: 2),
      ],
    );
  }
}

/// Pulsing search circle for "Finding a captain…".
class SearchPulse extends StatelessWidget {
  const SearchPulse({super.key, this.size = 96});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 1.1,
        height: size * 1.1,
        child: Pulse(
          builder: (c, t) => Stack(alignment: Alignment.center, children: [
            Transform.scale(scale: 0.94 + 0.14 * t, child: Container(width: size, height: size, decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle))),
            WIconView(WIcon.search, size: size * 0.36, color: WColor.primaryStrong, weight: medium),
          ]),
        ),
      );
}

// MARK: C25 Check the wash

class CheckWashView extends StatefulWidget {
  const CheckWashView({super.key, required this.order});
  final Order order;
  @override
  State<CheckWashView> createState() => _CheckWashViewState();
}

class _CheckWashViewState extends State<CheckWashView> {
  bool approving = false;

  Widget _pair(String label, int side) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WText(label, WType.label, color: WColor.heading, weight: medium),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => context.router.go(N.photoCompare),
          child: Row(children: [
            Expanded(child: DesignPhoto(path: widget.order.evidence('before', side), height: 110, icon: WIcon.car, tag: 'Before')),
            const SizedBox(width: 10),
            Expanded(child: DesignPhoto(path: widget.order.evidence('after', side), height: 110, icon: WIcon.sparkle, tag: 'After', tagTone: Tone.ok)),
          ]),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = widget.order;
    final name = o.captain?.name ?? 'Raju';
    return WScreen(
      header: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: WAppBar(title: 'Check the wash', subtitle: '$name finished at ${Fmt.time(o.finishedAt ?? DateTime.now())}', onLeading: router.popToRoot, onTrailing: () => router.go(N.help)),
      ),
      footer: WStackedFooter(children: [
        WButton('Approve', icon: WIcon.check, kind: ButtonKind.success, loading: approving, onTap: () async {
          setState(() => approving = true);
          try {
            await store.approve(o.id);
          } catch (e) {store.set(()=>store.toast=backendError(e));if(mounted)setState(()=>approving=false);return;}
          router.replace(const [R(N.rate)]);
        }),
        const Padding(padding: EdgeInsets.only(top: 6), child: WText('Auto-approves at 12 midnight if you don’t respond', WType.small, color: WColor.muted)),
        WButton('Something’s wrong', kind: ButtonKind.text, onTap: () => router.go(N.reportProblem)),
      ]),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 18),
          child: Row(children: [
            const WIconBox(WIcon.sparkle, size: 48, tone: Tone.ok, radius: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const WText('Shine restored', WType.section, weight: semibold), WText('Approve to release ${Fmt.rupees(o.price)} to $name', WType.caption)])),
          ]),
        ),
        _pair('Front', 0),
        const SizedBox(height: 14),
        _pair('Left side', 2),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: WLink('See all 4 angles', onTap: () => router.go(N.photoCompare))),
      ],
    );
  }
}

// MARK: C26 Photo compare

class PhotoCompareScreen extends StatefulWidget {
  const PhotoCompareScreen({super.key});
  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: WColor.camera,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(children: [
          WAppBar(title: '${PhotoAngle.values[page].label.replaceAll(' side', '')} · ${page + 1} of 4', leading: WIcon.close, trailing: null, dark: true, onLeading: router.pop),
          Expanded(
            child: WPager(
              count: 4,
              index: page,
              onIndex: (i) => setState(() => page = i),
              builder: (c, i) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: CompareSlider(before: o?.evidence('before', i), after: o?.evidence('after', i), beforeTime: o?.startedAt, afterTime: o?.finishedAt)),
            ),
          ),
          PageDots(count: 4, index: page, onTap: (i) => setState(() => page = i)),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(6),
            decoration: const ShapeDecoration(color: WColor.inverse, shape: StadiumBorder()),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Pressable(label: 'Zoom', child: SizedBox(width: 48, height: 48, child: Center(child: WIconView(WIcon.zoom, size: 18, color: WColor.white)))),
              Pressable(
                label: 'Report a problem',
                onTap: () {
                  router.pop();
                  router.go(N.reportProblem);
                },
                child: const SizedBox(width: 48, height: 48, child: Center(child: WIconView(WIcon.flag, size: 18, color: WColor.white))),
              ),
              WButton('Approve', icon: WIcon.check, kind: ButtonKind.success, fullWidth: false, onTap: () async {
                if (o == null) return;
                try {
                  await store.approve(o.id);
                } catch (e) {store.set(()=>store.toast=backendError(e));return;}
                router.replace(const [R(N.rate)]);
              }),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Before / after split with a draggable divider (drag or click to move it).
class CompareSlider extends StatefulWidget {
  const CompareSlider({super.key, this.before, this.after, this.beforeTime, this.afterTime});
  final String? before, after;
  final DateTime? beforeTime, afterTime;
  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider> {
  double split = 0.5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
        final w = box.maxWidth, h = box.maxHeight;
        void move(double x) => setState(() => split = (x / w).clamp(0.1, 0.9));
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => move(d.localPosition.dx),
            onTapDown: (d) => move(d.localPosition.dx),
            child: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFF2A3A50))),
              if (widget.before != null) Positioned.fill(child: DesignPhoto(path: widget.before, height: h, radius: 0)),
              Positioned(top: 0, bottom: 0, right: 0, width: w * (1 - split), child: const ColoredBox(color: Color(0xFF33445C))),
              // The after photo is drawn at full width and clipped to the right of the divider.
              if (widget.after != null) Positioned(top: 0, bottom: 0, right: 0, width: w * (1 - split), child: ClipRect(child: OverflowBox(alignment: Alignment.centerRight, minWidth: w, maxWidth: w, child: DesignPhoto(path: widget.after, height: h, radius: 0)))),
              if (widget.before == null) Positioned(left: w * 0.25 - 23, top: h / 2 - 23, child: WIconView(WIcon.car, size: 46, color: Colors.white.withValues(alpha: 0.55))),
              if (widget.after == null) Positioned(left: w * 0.75 - 23, top: h / 2 - 23, child: WIconView(WIcon.sparkle, size: 46, color: Colors.white.withValues(alpha: 0.9))),
              Positioned(left: w * split - 1, top: 0, bottom: 0, child: Container(width: 2, color: WColor.white)),
              Positioned(
                left: w * split - 22,
                top: h / 2 - 22,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.chevron, size: 12)),
                ),
              ),
              Positioned(left: 12, top: 12, child: WBadge('Before · ${widget.beforeTime == null ? '8:33 AM' : Fmt.time(widget.beforeTime!)}', tone: Tone.mute, solid: true)),
              Positioned(right: 12, top: 12, child: WBadge('After · ${widget.afterTime == null ? '8:53 AM' : Fmt.time(widget.afterTime!)}', tone: Tone.ok)),
            ]),
          ),
        );
      });
}

// MARK: C27 Rate

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});
  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  int stars = 4;
  final tags = {'Spotless', 'On time'};

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    final name = o?.captain?.name ?? 'Raju';
    return WScreen(
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(leading: null, trailing: WIcon.close, onTrailing: router.popToRoot)),
      footer: WFooterBar(showCall: false, child: WButton('Submit', onTap: () async {
        try { if (o != null) await store.rate(o.id, stars, tags); }
        catch (e) { store.set(()=>store.toast=backendError(e)); return; }
        if (!context.mounted) return;
        router.popToRoot();
      })),
      children: [
        Column(children: [
          const SizedBox(height: 20),
          WAvatar(o?.captain?.initials ?? 'RY', size: 72),
          const SizedBox(height: 18),
          WText('How did $name do?', WType.screen),
          const SizedBox(height: 8),
          WText('${Fmt.rupees(o?.price ?? 149)} released to $name. Thanks for approving.', WType.body, align: TextAlign.center),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 14),
              Pressable(label: '$i stars', onTap: () => setState(() => stars = i), child: WIconView(i <= stars ? WIcon.starFill : WIcon.star, size: 34, color: i <= stars ? WColor.star : WColor.muted)),
            ],
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: 320,
            child: WFlow(children: [
              for (final t in const ['Spotless', 'On time', 'Polite', 'Missed a spot', 'Late'])
                WChip(t, selected: tags.contains(t), onTap: () => setState(() => tags.contains(t) ? tags.remove(t) : tags.add(t))),
            ]),
          ),
        ]),
      ],
    );
  }
}
