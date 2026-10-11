import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'common.dart';

// ---------------------------------------------------------------------------
// C17-PayMethod (+ CA4 "Leave payment?" on Android back, CA3 UPI chooser is
// shown by the payment SDK on Android)

class PayMethodScreen extends StatefulWidget {
  const PayMethodScreen({super.key});

  @override
  State<PayMethodScreen> createState() => _PayMethodScreenState();
}

class _PayMethodScreenState extends State<PayMethodScreen> {
  List<PaymentMethod>? _methods;
  PaymentMethod? _picked;
  bool _creating = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      Future.microtask(_prepare);
    }
  }

  /// Creates the order from the draft (status: pending payment) and loads methods.
  Future<void> _prepare() async {
    final app = AppScope.read(context);
    final d = app.draft;
    final existing = app.currentOrder;
    if (existing == null || existing.status != OrderStatus.pendingPayment) {
      if (d.type == null || d.place == null || d.slot == null) {
        if (mounted) context.go(R.vehicleType);
        return;
      }
      final order = await guarded(
        context,
        () => app.backend.createOrder(
          type: d.type!,
          plate: d.plate,
          place: d.place!,
          slot: d.slot!,
          note: d.note,
          useFreeWash: d.useFreeWash,
        ),
      );
      if (order == null) return;
      app.currentOrder = order;
    }
    final methods = await guarded(context, () => app.backend.paymentMethods());
    if (!mounted || methods == null) return;
    setState(() {
      _methods = methods;
      _picked = app.payMethod ?? methods.first;
      _creating = false;
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await showWDialog(
      context,
      title: 'Leave payment?',
      body: 'Your booking details are saved. No money has been taken.',
      confirmLabel: 'Stay and pay',
      cancelLabel: 'Leave',
    );
    if (!leave && mounted) goBack(context, R.review);
  }

  IconData _icon(PaymentMethod m) => switch (m.kind) {
        'card' => Icons.credit_card_rounded,
        'upi_id' => Icons.alternate_email_rounded,
        _ => Icons.account_balance_wallet_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final amount = app.draft.price;
    final order = app.currentOrder;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: WScreen(
        header: WHeader(
          appBar: WAppBar(title: 'Book a wash', onBack: _confirmLeave, onHelp: () => openHelp(context)),
          progress: const WProgress(step: 5, total: 5, label: 'Pay'),
        ),
        children: [
          WTitleBlock(
            title: amount == 0 ? 'Use a free wash' : 'Pay ${rupees(amount)}',
            subtitle: amount == 0 ? 'Nothing to pay today.' : 'Held until you approve',
          ),
          if (_creating)
            const WGap(children: [WSkeleton(height: 72, radius: 20), WSkeleton(height: 72, radius: 20)])
          else if (amount > 0)
            WGap(
              children: [
                for (final m in _methods!)
                  WSelectionTile(
                    icon: _icon(m),
                    title: m.title,
                    subtitle: m.detail,
                    selected: _picked?.id == m.id,
                    trailing: WRadio(selected: _picked?.id == m.id),
                    onTap: () => setState(() => _picked = m),
                  ),
              ],
            ),
          if (amount > 0)
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: WColors.secondary),
                const SizedBox(width: 6),
                Expanded(child: Text('Secured by Razorpay. Full refund if no washer comes.', style: WText.caption)),
              ],
            ),
        ],
        footer: WFooterBar(
          children: [
            WButton(
              variant: WButtonVariant.success,
              label: amount == 0 ? 'Confirm booking' : 'Pay ${rupees(amount)}',
              onPressed: _creating || order == null
                  ? null
                  : () {
                      app.payMethod = _picked ??
                          const PaymentMethod(id: 'credit', title: 'Free wash', detail: 'Credit', kind: 'credit');
                      context.push(R.paying);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C18-Paying, C18b (failed), C18c (pending)

enum PayView { processing, failed, pending }

class PayingScreen extends StatefulWidget {
  const PayingScreen({super.key, this.initial = PayView.processing});

  final PayView initial;

  @override
  State<PayingScreen> createState() => _PayingScreenState();
}

class _PayingScreenState extends State<PayingScreen> {
  late PayView _view = widget.initial;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && widget.initial == PayView.processing) {
      _started = true;
      Future.microtask(_pay);
    }
  }

  Future<void> _pay({bool recheck = false}) async {
    final app = AppScope.read(context);
    final order = app.currentOrder;
    final method = app.payMethod;
    if (order == null || method == null) {
      context.go(R.review);
      return;
    }
    setState(() => _view = PayView.processing);
    final outcome = await guarded(
      context,
      () => recheck ? app.backend.checkPayment(order.id) : app.backend.pay(order.id, method),
    );
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case PaymentOutcome.success:
        app.currentOrder = await app.backend.getOrder(order.id);
        app.draft.clear();
        app.changed();
        if (mounted) context.go(R.booked);
      case PaymentOutcome.failed:
        setState(() => _view = PayView.failed);
      case PaymentOutcome.pending:
        setState(() => _view = PayView.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case PayView.processing:
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: WColors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 4)),
                    const SizedBox(height: 24),
                    Text('Confirming payment', style: WText.screen, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text('Don’t close the app. This takes a few seconds.', style: WText.body, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
      case PayView.failed:
        return WScreen(
          header: const SimpleHeader(fallback: R.review),
          body: const WStateView(
            icon: Icons.credit_card_off_outlined,
            tone: WTone.error,
            title: 'Payment didn’t go through',
            body: 'Your bank declined it. No money was taken. Try again or use another method.',
          ),
          footer: WFooterBar(vertical: true, children: [
            WButton(label: 'Try again', onPressed: () => _pay()),
            WButton.text(label: 'Change method', onPressed: () => goBack(context, R.payMethod)),
          ]),
        );
      case PayView.pending:
        return WScreen(
          header: const SimpleHeader(fallback: R.review),
          body: const WStateView(
            icon: Icons.hourglass_top_rounded,
            tone: WTone.wait,
            title: 'Waiting for your bank',
            body: 'We haven’t heard back yet. If money left your account, it will be refunded automatically within 3 days.',
          ),
          footer: WFooterBar(vertical: true, children: [
            WButton(label: 'Check again', onPressed: () => _pay(recheck: true)),
            WButton.text(label: 'Call support', onPressed: () => openHelp(context)),
          ]),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// C19-Booked

class BookedScreen extends StatelessWidget {
  const BookedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final o = app.currentOrder;
    if (o == null) return const NoOrderView();
    return WScreen(
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: WColors.successTint, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 52, color: WColors.onSuccess),
          ),
        ),
        Column(
          children: [
            Semantics(header: true, child: Text('You’re booked', style: WText.screen, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Text('${formatDay(o.slot.date)}, ${o.slot.windowLabel} · ${o.vehicle.plate}',
                style: WText.body, textAlign: TextAlign.center),
          ],
        ),
        WCard(
          style: WCardStyle.raised,
          child: WGap(
            gap: 12,
            children: [
              Row(
                children: [
                  const WIconTile(icon: Icons.badge_outlined, tone: WTone.wait),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('One last thing: your gate pass', style: WText.title),
                        Text('We sent you a WhatsApp message', style: WText.caption),
                      ],
                    ),
                  ),
                ],
              ),
              Text('Reply there with your MyGate or society entry pass, so the washer can get in.', style: WText.body),
              WButton(
                variant: WButtonVariant.tonal,
                icon: Icons.chat_outlined,
                label: 'Open WhatsApp',
                onPressed: () => context.push(R.whatsApp),
              ),
            ],
          ),
        ),
        Text('We’re finding a washer now. We’ll notify you when someone accepts.',
            style: WText.body, textAlign: TextAlign.center),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Track booking',
            onPressed: () {
              final notificationsOn = app.customer?.notificationsOn ?? false;
              context.go(notificationsOn ? liveRouteFor(o) : R.notifyAsk);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C19b-WhatsAppBot. Reference only: WhatsApp is outside the app. In the real
// build "Open WhatsApp" launches wa.me with the bot number. Message
// templates are in backend/whatsapp-templates.md.

class WhatsAppReferenceScreen extends StatelessWidget {
  const WhatsAppReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = AppScope.of(context).currentOrder;
    final plate = o?.vehicle.plate ?? 'TS 09 EA 4521';
    final type = o?.vehicle.type.shortName ?? 'Hatchback';
    final when = o == null ? 'Today, 8 – 10 AM' : '${formatDay(o.slot.date)}, ${o.slot.windowLabel}';
    final where = o == null ? 'My Home Avatar, Tower 3, B2 slot 41' : '${o.place.title}, ${o.place.parkingShort}';
    final price = rupees(o?.price ?? 149);

    Widget bubble(String text, {bool mine = false, String time = '7:42 AM'}) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFFD9FDD3) : WColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(text, style: WText.bodyStrong.copyWith(color: WColors.heading)),
                Text(time, style: WText.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        );

    return WScreen(
      background: const Color(0xFFEFE7DD),
      header: Container(
        color: const Color(0xFF075E54),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => goBack(context, R.booked),
              icon: const Icon(Icons.arrow_back_rounded, color: WColors.white),
            ),
            const WAvatar(initials: 'W', size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConfig.brandName, style: WText.title.copyWith(color: WColors.white)),
                Text('Business account', style: WText.caption.copyWith(color: WColors.white)),
              ],
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      gap: 10,
      children: [
        bubble('Booking confirmed\n$plate · $type\n$when\n$where\n$price held safely'),
        bubble('Please reply with your society entry pass (MyGate, NoBrokerHood or a photo of the gate pass). '
            'The washer needs it to get in.'),
        bubble('MyGate pass', mine: true, time: '7:44 AM'),
        bubble('Got it. Pass saved for this booking. We’ll share it with your washer only.', time: '7:44 AM'),
        const WBanner(
          tone: WTone.mute,
          text: 'Reference only: WhatsApp is outside the app. These are the message templates for the bot.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// C49-NotifyAsk

class NotifyAskScreen extends StatelessWidget {
  const NotifyAskScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final app = AppScope.read(context);
    final o = app.currentOrder;
    context.go(o != null && o.status.isActive ? liveRouteFor(o) : R.home);
  }

  @override
  Widget build(BuildContext context) => WScreen(
        header: const SimpleHeader(fallback: R.booked),
        body: const WStateView(
          icon: Icons.notifications_active_outlined,
          title: 'Know when it’s done',
          body: 'We’ll tell you when a washer accepts and when the photos are ready. No spam.',
        ),
        footer: WFooterBar(vertical: true, children: [
          WButton(
            label: 'Turn on notifications',
            onPressed: () async {
              final app = AppScope.read(context);
              final allowed = await app.device.requestNotifications();
              if (allowed && app.isLoggedIn) await guarded(context, () => app.backend.setNotifications(true));
              if (context.mounted) await _continue(context);
            },
          ),
          WButton.text(label: 'Not now', onPressed: () => _continue(context)),
        ]),
      );
}
