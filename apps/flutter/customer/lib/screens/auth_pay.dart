import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';
import 'package:wheelio_firebase/wheelio_firebase.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

// MARK: C14 Log in (C14b invalid)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showError = false});
  final bool showError;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String phone = widget.showError ? '98480112' : '';
  bool error = false;
  bool loading = false;
  String? backendMessage;

  bool get valid => Validators.isValidMobile(phone);

  Future<void> _submit() async {
    if (!valid) {
      setState(() => error = true);
      return;
    }
    setState(() => loading = true);
    try {
      await context.store.requestOtp(Validators.digitsOnly(phone).substring(0, 10));
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          backendMessage = backendError(e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => loading = false);
    context.router.push(const R(N.otp));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final showErr = error || widget.showError;
    return WScreen(
      header: const PlainHeader(),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Get code', enabled: phone.isNotEmpty && (valid || !showErr), loading: loading, onTap: _submit),
      ),
      children: [
        WTitleBlock(
          'Almost done. What’s your number?',
          top: 8,
          subtitle: store.returningCustomer ? 'We’ll send a 6-digit code to find your account.' : 'We’ll send a 6-digit code. Then just your name.',
        ),
        WSegmented(
          options: const ['I’m new here', 'I’ve booked before'],
          selection: store.returningCustomer ? 1 : 0,
          onChanged: (i) => store.set(() => store.returningCustomer = i == 1),
        ),
        const SizedBox(height: 18),
        if (backendMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: WText(backendMessage!, WType.caption, color: WColor.destructive),
          ),
        if (store.isLive)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: WText(
              'By continuing, you agree to receive an SMS verification code. Your phone number is processed by Firebase for verification and abuse prevention.',
              WType.small,
              color: WColor.secondary,
            ),
          ),
        WPhoneField(
          number: phone,
          error: showErr && !valid ? 'Enter all 10 digits' : null,
          onChanged: (v) => setState(() {
            phone = v;
            error = false;
          }),
        ),
      ],
    );
  }
}

// MARK: C15 Enter the code (C15b wrong, C15c expired)

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.start = OtpStart.entering});
  final OtpStart start;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late String code = widget.start == OtpStart.wrong ? '482190' : '';
  late OtpStart state = widget.start;
  int triesLeft = 2;
  int seconds = 24;
  bool loading = false;
  String? backendMessage;

  Future<void> _resend() async {
    if (loading) return;
    setState(() {
      loading = true;
      backendMessage = null;
    });
    try {
      await context.store.requestOtp(context.store.pendingPhone);
      if (mounted) {
        setState(() {
          seconds = 30;
          state = OtpStart.entering;
          code = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => backendMessage = backendError(e));
    }
    if (mounted) setState(() => loading = false);
  }

  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (seconds > 0) setState(() => seconds--);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _verify([String? c]) async {
    final v = c ?? code;
    if (loading || v.length != 6) return;
    setState(() => loading = true);
    OtpResult? r;
    try {
      r = await context.store.verifyOtp(v);
    } catch (e) {
      if (mounted) setState(() => backendMessage = backendError(e));
    }
    if (!mounted) return;
    setState(() => loading = false);
    final router = context.router;
    if (r == null) {
      if (!context.store.isLive) router.go(N.offline);
    } else if (r.kind == 'ok') {
      // Returning customers: phone + code only. New customers also give their name.
      if (r.isNew && (context.store.isLive || !context.store.returningCustomer)) {
        router.go(N.name);
      } else {
        router.finishLogin();
      }
    } else if (r.kind == 'wrong') {
      setState(() {
        triesLeft = r!.triesLeft;
        state = OtpStart.wrong;
      });
    } else {
      setState(() {
        state = OtpStart.expired;
        code = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      header: const PlainHeader(),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Verify', enabled: code.length == 6 && state == OtpStart.entering, loading: loading, onTap: _verify),
      ),
      children: [
        const Padding(padding: EdgeInsets.only(top: 8), child: WText('Enter the code', WType.screen)),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 22),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WText('Sent to ${Fmt.phone(store.pendingPhone.isEmpty ? AppStore.samplePhone : store.pendingPhone)}. ', WType.body),
              WLink(
                'Change',
                minHeight: 22,
                onTap: () {
                  store.live?.invalidateOtp();
                  context.router.pop();
                },
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: WOtpField(
            code: code,
            error: state == OtpStart.wrong,
            boxSize: 46,
            onChanged: (v) {
              setState(() {
                code = v;
                if (state == OtpStart.wrong && v.length < 6) state = OtpStart.entering;
              });
              if (v.length == 6) _verify(v);
            },
          ),
        ),
        if (state == OtpStart.entering) ...[
          Padding(padding: const EdgeInsets.only(top: 22), child: WText(seconds > 0 ? 'Resend code in ${Fmt.clock(seconds)}' : '', WType.caption)),
          if (seconds == 0)
            Align(
              alignment: Alignment.centerLeft,
              child: WLink('Resend code', onTap: _resend),
            ),
        ],
        if (state == OtpStart.wrong)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                const WIconView(WIcon.warning, size: 13, color: WColor.destructive),
                const SizedBox(width: 6),
                WText('That code doesn’t match. $triesLeft tries left.', WType.caption, color: WColor.destructive),
              ],
            ),
          ),
        if (state == OtpStart.expired) ...[
          const SizedBox(height: 22),
          WBanner(tone: Tone.wait, icon: WIcon.clock, text: 'That code expired. Get a new one.', actionTitle: 'Resend', onAction: _resend),
          const SizedBox(height: 20),
          if (!store.isLive)
            const Align(
              alignment: Alignment.centerLeft,
              child: WButton('Get the code on a call instead', kind: ButtonKind.text, fullWidth: false),
            ),
        ],
        if (backendMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: WText(backendMessage!, WType.caption, color: WColor.destructive),
          ),
        if (!store.isLive)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: WText('Demo code: 123456', WType.caption, color: WColor.muted),
          ),
      ],
    );
  }
}

// MARK: C16 Your name

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});
  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late String name = context.store.customer?.name ?? '';
  @override
  Widget build(BuildContext context) => WScreen(
    header: const PlainHeader(),
    footer: WFooterBar(
      showCall: false,
      child: WButton(
        'Continue',
        enabled: Validators.isValidName(name),
        onTap: () async {
          final router = context.router, store = context.store;
          try {
            await store.updateName(name);
          } catch (e) {
            store.set(() => store.toast = backendError(e));
            return;
          }
          router.finishLogin();
        },
      ),
    ),
    children: [
      const WTitleBlock('What should we call you?', subtitle: 'Your captain sees your first name only.', top: 8),
      WTextField(
        label: 'Your name',
        value: name,
        placeholder: 'Your name',
        caps: TextCapitalization.words,
        autofocus: true,
        onChanged: (v) => setState(() => name = v),
      ),
    ],
  );
}

// MARK: C18 Paying (C18b failed, C18c pending)

class PayingScreen extends StatefulWidget {
  const PayingScreen({super.key, this.initial = PayView.processing});
  final PayView initial;
  @override
  State<PayingScreen> createState() => _PayingScreenState();
}

class _PayingScreenState extends State<PayingScreen> {
  late PayView view = widget.initial;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == PayView.processing) WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final store = context.store, router = context.router;
    PaymentOutcome outcome;
    try {
      outcome = await store.createOrderAndPay();
    } catch (e) {
      store.set(() => store.toast = backendError(e));
      outcome = PaymentOutcome.failed;
    }
    if (!mounted) return;
    if (!_openResolvedBooking(store, router, outcome)) {
      setState(() => view = outcome == PaymentOutcome.failed ? PayView.failed : PayView.pending);
    }
  }

  Future<void> _check() async {
    final store = context.store, router = context.router;
    setState(() => checking = true);
    try {
      final outcome = await store.checkPendingPayment();
      if (!mounted) return;
      _openResolvedBooking(store, router, outcome);
    } catch (e) {
      store.set(() => store.toast = backendError(e));
    }
    if (!mounted) return;
    setState(() => checking = false);
  }

  bool _openResolvedBooking(AppStore store, AppRouter router, PaymentOutcome outcome) {
    final order = store.currentOrder;
    if (store.isLive && order?.status == OrderStatus.cancelled) {
      router.replace([R(N.live, id: order!.id)]);
      return true;
    }
    if (outcome == PaymentOutcome.success) {
      router.replace(const [R(N.booked)]);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return PopScope(
      canPop: false,
      child: WScreen(
        scrolls: false,
        header: view == PayView.processing ? const SizedBox(height: 56) : const PlainHeader(),
        children: [
          Expanded(
            child: switch (view) {
              PayView.processing => const WFullState(
                icon: WIcon.clock,
                title: 'Confirming payment',
                message: 'Don’t close the app. This takes a few seconds.',
                spinning: true,
              ),
              PayView.failed => WFullState(
                icon: WIcon.receipt,
                tone: Tone.error,
                title: 'Payment didn’t go through',
                message: store.isLive
                    ? 'Payment could not be confirmed. Check your booking before retrying if money was deducted.'
                    : 'Your bank declined it. No money was taken. Try again or use another method.',
                primary: 'Try again',
                secondary: 'Change method',
                onPrimary: () {
                  store.set(() => store.demo.payment = PaymentOutcome.success);
                  setState(() => view = PayView.processing);
                  _run();
                },
                onSecondary: () {
                  router.pop();
                  Future.delayed(const Duration(milliseconds: 450), () => router.openPaySheet(true));
                },
              ),
              PayView.pending => WFullState(
                icon: WIcon.clock,
                tone: Tone.wait,
                title: store.isLive ? 'Payment not confirmed' : 'Waiting for your bank',
                message: store.isLive
                    ? 'Payment has not been confirmed. Check again, or return home to view the booking and retry checkout.'
                    : 'We haven’t heard back yet. If money left your account, it will be refunded automatically within 3 days.',
                primary: checking ? 'Checking…' : 'Check again',
                secondary: store.isLive ? 'Go home' : 'Call support',
                onPrimary: _check,
                onSecondary: store.isLive ? router.popToRoot : callSupport,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// MARK: C19 You're booked

class BookedScreen extends StatelessWidget {
  const BookedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    // The booking details open tracking; there's no separate "Track" button.
    void track() => router.replace([R(store.customer?.notificationsOn == true ? N.live : N.notifyAsk)]);
    return WScreen(
      header: const SizedBox(height: 30),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Go home',
          onTap: () {
            router.tab = 0;
            router.popToRoot();
          },
        ),
      ),
      children: [
        Column(
          children: [
            const WStateCircle(WIcon.check, tone: Tone.ok),
            const SizedBox(height: 20),
            const WText('You’re booked', WType.screen),
            const SizedBox(height: 10),
            Pressable(
              label: 'Track this booking',
              onTap: track,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: ShapeDecoration(
                  color: WColor.canvas,
                  shape: const StadiumBorder(side: BorderSide(color: WColor.border)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: WText('${o?.slot.full ?? 'Today, 8 – 10 AM'} · ${o?.vehicle.plate ?? 'TS 09 EA 4521'}', WType.body, color: WColor.heading)),
                    const SizedBox(width: 6),
                    const WIconView(WIcon.chevron, size: 11, color: WColor.secondary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        WCard(
          padding: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  WIconBox(WIcon.whatsapp, size: 44, tone: Tone.ok),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [WText('One last thing: your gate pass', WType.title), WText('We sent you a WhatsApp message', WType.caption)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const WText('Reply there with your MyGate or society entry pass, so the captain can get in.', WType.body),
              const SizedBox(height: 14),
              WButton('Open WhatsApp', icon: WIcon.whatsapp, kind: ButtonKind.outline, onTap: () => router.go(N.whatsApp)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (o != null && o.slotAhead)
          const WBanner(tone: Tone.info, icon: WIcon.calendar, text: 'We’ll assign a captain before your slot and notify you. Changed your mind? You can cancel in the first 15 minutes.')
        else
          const WBanner(tone: Tone.info, icon: WIcon.search, text: 'We’re finding a captain now. We’ll notify you when someone accepts.'),
      ],
    );
  }
}

// MARK: C19b WhatsApp bot (reference)

class WhatsAppScreen extends StatelessWidget {
  const WhatsAppScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    final pad = MediaQuery.paddingOf(context);
    final base = wStyle(WType.body, size: 14.5, color: WColor.heading);
    Widget bubble(String time, List<(String, FontWeight?)> spans) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  for (final s in spans)
                    TextSpan(
                      text: s.$1,
                      style: s.$2 == null ? base : base.copyWith(fontWeight: s.$2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            WText(time, WType.small),
          ],
        ),
      ),
    );
    return Material(
      color: const Color(0xFFECE5DD),
      child: Column(
        children: [
          Container(
            color: WColor.white,
            padding: EdgeInsets.fromLTRB(12, pad.top + 6, 12, 6),
            child: Row(
              children: [
                Pressable(
                  onTap: router.pop,
                  label: 'Go back',
                  child: const SizedBox(width: 36, height: 44, child: Center(child: WIconView(WIcon.left, size: 18))),
                ),
                const SizedBox(width: 10),
                const BrandMark(size: 26, showName: false),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [WText(Brand.name, WType.title), WText('Business account', WType.caption)],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                bubble('7:42 AM', [
                  ('Booking confirmed\n', null),
                  (o?.vehicle.plate ?? 'TS 09 EA 4521', bold),
                  (
                    ' · ${o?.vehicle.type.shortName ?? 'Hatchback'}\n${o?.slot.full ?? 'Today, 8 – 10 AM'}\n${o?.place.title ?? 'My Home Avatar, Tower 3'}, ${o?.place.parkingShort ?? 'B2 slot 41'}\n${Fmt.rupees(o?.price ?? 149)} held safely',
                    null,
                  ),
                ]),
                const SizedBox(height: 12),
                bubble('7:42 AM', [
                  ('Please reply with your ', null),
                  ('society entry pass', bold),
                  (' (MyGate, NoBrokerHood or a photo of the gate pass). The captain needs it to get in.', null),
                ]),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      width: 160,
                      height: 110,
                      decoration: BoxDecoration(color: WColor.photo, borderRadius: BorderRadius.circular(10)),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          WIconView(WIcon.image, size: 20, color: WColor.secondary),
                          SizedBox(height: 6),
                          WText('MyGate pass', WType.small),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                bubble('7:44 AM', [('Got it. Pass saved for this booking. We’ll share it with your captain only.', null)]),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad.bottom),
            child: const WText('Reference only: WhatsApp is outside the app. Message templates for the bot.', WType.caption, align: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// MARK: C49 Notifications ask

class NotifyAskScreen extends StatelessWidget {
  const NotifyAskScreen({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
    scrolls: false,
    header: const PlainHeader(),
    children: [
      Expanded(
        child: WFullState(
          icon: WIcon.bell,
          title: 'Know when it’s done',
          message: 'We’ll tell you when a captain accepts and when the photos are ready. No spam.',
          primary: 'Turn on notifications',
          secondary: 'Not now',
          onPrimary: () {
            context.store.setNotifications(true);
            context.router.replace(const [R(N.live)]);
          },
          onSecondary: () => context.router.replace(const [R(N.live)]),
        ),
      ),
    ],
  );
}
