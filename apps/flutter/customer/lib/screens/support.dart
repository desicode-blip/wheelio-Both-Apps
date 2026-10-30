import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/store.dart';

// MARK: Change phone number

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key, this.verifyAccount = false});
  final bool verifyAccount;
  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

enum _Stage { number, code, done }

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  _Stage stage = _Stage.number;
  String phone = '';
  String code = '';
  bool wrong = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.verifyAccount) stage = _Stage.code;
  }

  String get current => context.store.customer?.phone ?? '';
  String get digits => Validators.digitsOnly(phone);
  bool get canSend => Validators.isValidMobile(phone) && digits != current;

  Future<void> _send() async {
    if (!canSend) return;
    setState(() => loading = true);
    final store = context.store;
    try {
      await store.requestPhoneChange(digits);
    } catch (e) {
      store.set(() => store.toast = backendError(e));
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = false;
      code = '';
      wrong = false;
      stage = _Stage.code;
    });
  }

  Future<void> _verify([String? c]) async {
    final v = c ?? code;
    if (loading || v.length != 6) return;
    setState(() => loading = true);
    var ok = false;
    try {
      if (widget.verifyAccount) {
        await context.store.live!.confirmAccountVerification(v);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      ok = await context.store.confirmPhoneChange(v);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      loading = false;
      if (ok) {
        stage = _Stage.done;
      } else {
        wrong = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = context.router;
    return WScreen(
      scrolls: stage != _Stage.done,
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Phone number', trailing: null, onLeading: widget.verifyAccount ? () => Navigator.of(context).pop(false) : router.pop)),
      footer: stage == _Stage.done
          ? null
          : WFooterBar(
              showCall: false,
              child: stage == _Stage.number
                  ? WButton('Send code', enabled: canSend, loading: loading, onTap: _send)
                  : WButton(widget.verifyAccount ? 'Verify' : 'Verify and change', enabled: code.length == 6, loading: loading, onTap: _verify),
            ),
      children: switch (stage) {
        _Stage.number => [
            WTitleBlock('Change your number', subtitle: 'Now: ${Fmt.phone(current)}. We’ll send a code to the new number to check it’s yours.', top: 14),
            WPhoneField(number: phone, onChanged: (v) => setState(() => phone = v)),
            if (digits == current && current.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: WText('That’s your current number.', WType.caption)),
          ],
        _Stage.code => [
            const Padding(padding: EdgeInsets.only(top: 14), child: WText('Enter the code', WType.screen)),
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 22), child: WText(widget.verifyAccount ? 'Sent to ${Fmt.phone(current)}. Verify before deleting your Customer account.' : 'Sent to ${Fmt.phone(digits)}. Your number changes only after this.', WType.body)),
            Align(
              alignment: Alignment.centerLeft,
              child: WOtpField(code: code, error: wrong, boxSize: 46, onChanged: (v) {
                setState(() {
                  code = v;
                  if (wrong && v.length < 6) wrong = false;
                });
                if (v.length == 6) _verify(v);
              }),
            ),
            if (wrong) const Padding(padding: EdgeInsets.only(top: 14), child: WText('That code doesn’t match. Try again.', WType.caption, color: WColor.destructive)),
            if (!context.store.isLive) const Padding(padding: EdgeInsets.only(top: 30), child: WText('Demo code: 123456', WType.caption, color: WColor.muted)),
          ],
        _Stage.done => [
            const SizedBox(height: 40),
            Expanded(child: WFullState(icon: WIcon.check, tone: Tone.ok, title: 'Number updated', message: 'We’ll use ${Fmt.phone(context.store.customer?.phone ?? digits)} from now on.', primary: 'Done', onPrimary: router.pop)),
          ],
      },
    );
  }
}

// MARK: C48 Help: pick what's going on. Everything goes to the captain first; only emergencies reach the team.

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? open;
  static const faqs = [
    ('When is my money taken?', 'Your bank holds the amount when you book. It goes to the captain only after you approve the after-photos, or automatically at midnight if you don’t respond.'),
    ('What if the captain doesn’t come?', 'If no captain accepts, or the wash doesn’t start in your window, you get a full refund to your UPI in 2 to 3 working days.'),
    ('Can I cancel?', 'Yes. Before a captain accepts, you get the full amount back. After that a small trip fee goes to the captain.'),
  ];

  @override
  Widget build(BuildContext context) {
    final router = context.router;
    final currentCancellation = context.store.isLive && context.store.liveConfig['cancellationPolicy']?['kind'] == 'refundThenCredit';
    final questions = [for (final (i, faq) in faqs.indexed) i == 2 && currentCancellation ? (faq.$1, 'Cancel within 5 minutes of booking confirmation for a full refund to your original payment method and restoration of used wallet credit. Later, 50% of the total booking value is a cancellation fee and 50% goes to your wallet for a future booking. Cancellation closes when washing starts.') : faq];
    return WScreen(
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Help', trailing: null, onLeading: router.pop)),
      children: [
        const WTitleBlock('How can we help?', subtitle: 'Pick what’s going on.', top: 14),
        for (final t in HelpTopic.values) ...[WSelectionTile(icon: t.icon, title: t.title, onTap: () => router.push(R(N.helpCaptain, topic: t))), const SizedBox(height: 10)],
        WSelectionTile(icon: WIcon.warning, title: 'Emergency', subtitle: 'Damage, an accident or a safety worry', iconTone: Tone.error, onTap: () => router.go(N.helpEmergency)),
        const WSectionLabel('Common questions', top: 26),
        for (final (i, f) in questions.indexed) ...[
          Pressable(
            feedback: false,
            onTap: () => setState(() => open = open == i ? null : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: WText(f.$1, WType.rowTitle)),
                  AnimatedRotation(turns: open == i ? 0.25 : 0, duration: const Duration(milliseconds: 200), child: const WIconView(WIcon.chevron, size: 13, color: WColor.secondary)),
                ]),
                AnimatedSize(duration: const Duration(milliseconds: 200), child: open == i ? Padding(padding: const EdgeInsets.only(top: 8), child: WText(f.$2, WType.body)) : const SizedBox(width: double.infinity)),
              ]),
            ),
          ),
          const WDivider(),
        ],
      ],
    );
  }
}

/// Sort it out with your latest captain. "Still not sorted?" only leads to us for emergencies.
class HelpCaptainScreen extends StatefulWidget {
  const HelpCaptainScreen({super.key, required this.topic});
  final HelpTopic topic;
  @override
  State<HelpCaptainScreen> createState() => _HelpCaptainScreenState();
}

class _HelpCaptainScreenState extends State<HelpCaptainScreen> {
  bool stillNotSorted = false;
  bool pinged = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.latestCaptainOrder;
    final w = o?.captain;
    return WScreen(
      canvas: true,
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Help', trailing: null, onLeading: router.pop)),
      footer: o != null && !stillNotSorted && !pinged ? WStackedFooter(children: [WButton('Still not sorted?', kind: ButtonKind.text, onTap: () => setState(() => stillNotSorted = true))]) : null,
      children: o != null && w != null
          ? [
              WTitleBlock('Let’s sort it with ${w.name}', subtitle: '${widget.topic.title}. Your captain can fix most things fastest, often the same day.', top: 14),
              WCard(
                child: Column(children: [
                  Row(children: [
                    WAvatar(w.initials, size: 50),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(w.name, WType.title, weight: semibold, size: 17), WText('${o.vehicle.plate} · ${Fmt.day(o.slot.date)}', WType.caption)])),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: WButton('Call ${w.name}', icon: WIcon.phone, onTap: () => Support.call())),
                    const SizedBox(width: 10),
                    const Expanded(child: WButton('WhatsApp', icon: WIcon.whatsapp, kind: ButtonKind.outline)),
                  ]),
                ]),
              ),
              if (pinged) Padding(padding: const EdgeInsets.only(top: 16), child: WBanner(tone: Tone.ok, icon: WIcon.check, text: 'We’ve asked ${w.name} to get back to you about this.')),
              if (stillNotSorted && !pinged)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FadeIn(
                    child: WCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const WText('Is this an emergency?', WType.title),
                        const SizedBox(height: 12),
                        const WText('Damage to your vehicle, an accident, or a safety worry.', WType.body),
                        const SizedBox(height: 12),
                        WButton('Yes, it’s an emergency', kind: ButtonKind.danger, onTap: () => router.go(N.helpEmergency)),
                        const SizedBox(height: 12),
                        WButton('No, ask ${w.name} again', kind: ButtonKind.outline, onTap: () => setState(() => pinged = true)),
                      ]),
                    ),
                  ),
                ),
            ]
          : [
              const WTitleBlock('Your captain is your first stop', subtitle: 'Once you’ve booked a wash, you can reach your captain here and sort things out directly.', top: 14),
              const SizedBox(height: 8),
              WButton('Book a wash', onTap: () {
                store.startNewBooking();
                router.replace(const [R(N.vehicleType)]);
              }),
            ],
    );
  }
}

/// Only emergencies are connected to the team.
class EmergencyHelpScreen extends StatelessWidget {
  const EmergencyHelpScreen({super.key});
  @override
  Widget build(BuildContext context) => WScreen(
        header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Emergency', trailing: null, onLeading: context.router.pop)),
        footer: WStackedFooter(children: [WButton('Call us now', icon: WIcon.phone, kind: ButtonKind.danger, onTap: () => Support.call()), const WButton('WhatsApp us', kind: ButtonKind.text)]),
        children: [
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: WStateCircle(WIcon.warning, tone: Tone.error, size: 64)),
          const SizedBox(height: 18),
          const WText('We’re here for emergencies', WType.screen),
          const SizedBox(height: 6),
          const WText('Damage to your vehicle, an accident, or a safety worry. A real person picks up.', WType.body),
          const SizedBox(height: 14),
          WText(Support.hours, WType.caption),
        ],
      );
}

// MARK: Refund UPI ID

/// Asked only when a refund needs somewhere to go (automatic cancellations).
/// Saved to the profile for next time; with no order it edits the saved ID.
class RefundUPIScreen extends StatefulWidget {
  const RefundUPIScreen({super.key, this.orderId});
  final String? orderId;
  @override
  State<RefundUPIScreen> createState() => _RefundUPIScreenState();
}

class _RefundUPIScreenState extends State<RefundUPIScreen> {
  late String upi = context.store.customer?.refundUPI ?? '';
  bool showError = false;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final id = widget.orderId == 'current' ? store.currentOrderId : widget.orderId;
    final order = id == null ? null : store.order(id);
    final valid = Validators.isValidUPI(upi);
    final amount = Fmt.rupees(order?.refund?.amount ?? order?.price ?? 0);
    Future<void> save() async {
      if (!valid) {
        setState(() => showError = true);
        return;
      }
      setState(() => saving = true);
      await sleepMs(500);
      store.saveRefundUPI(upi);
      if (!mounted) return;
      setState(() => saving = false);
      if (order != null) {
        store.set(() {
          store.currentOrderId = order.id;
          store.toast = 'Refund on its way to ${store.customer?.refundUPI ?? upi}';
        });
        router.pop();
        router.go(N.refund);
      } else {
        store.set(() => store.toast = 'UPI ID saved');
        router.pop();
      }
    }

    return WScreen(
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: order == null ? 'Refund UPI ID' : 'Your refund', trailing: null, onLeading: router.pop)),
      footer: WFooterBar(showCall: false, child: WButton(order != null ? 'Send $amount here' : 'Save', enabled: upi.isNotEmpty, loading: saving, onTap: save)),
      children: [
        order != null
            ? WTitleBlock('Where should we send your $amount?', subtitle: 'Refunds go to UPI only for now. Type the UPI ID you use in Google Pay, PhonePe or Paytm.', top: 14)
            : const WTitleBlock('Refund UPI ID', subtitle: 'If we ever need to refund you, the money goes here.', top: 14),
        WTextField(
          label: 'UPI ID',
          value: upi,
          placeholder: 'name@okhdfc',
          helper: 'Looks like name@bank or 9876543210@ybl',
          error: showError && !valid ? 'That doesn’t look like a UPI ID. Check for the @ part.' : null,
          keyboard: TextInputType.emailAddress,
          autofocus: true,
          onSubmit: save,
          onChanged: (v) => setState(() {
            upi = v;
            showError = false;
          }),
        ),
        const SizedBox(height: 18),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WIconView(WIcon.shield, size: 14, color: WColor.secondary),
          SizedBox(width: 10),
          Expanded(child: WText('We save it to your profile so you don’t have to type it again. You can change it anytime in Profile.', WType.caption)),
        ]),
      ],
    );
  }
}
