import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

// MARK: C31 Report a problem

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});
  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  ProblemKind kind = ProblemKind.notClean;
  @override
  Widget build(BuildContext context) => StepTotal(
        total: 2,
        child: WScreen(
          header: const BookingHeader(step: 1, label: 'What happened', title: 'Report a problem', fraction: 0.5),
          footer: WFooterBar(onCall: callSupport, child: WButton('Next', onTap: () => context.router.push(R(N.problemPhotos, kind: kind)))),
          children: [
            const WTitleBlock('What went wrong?', subtitle: 'Payment stays on hold while we check.'),
            // We still compare the captain's before/after photos; we just can't promise an outcome.
            if (context.store.currentOrder?.customerSkippedPhotos == true)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: WBanner(tone: Tone.wait, icon: WIcon.camera, title: 'You skipped the photos at booking.', text: 'So we can’t promise a fix, but we’ll still look into it and get back to you.'),
              ),
            for (final k in ProblemKind.values) ...[
              WSelectionTile(icon: k.icon, title: k.title, subtitle: k.subtitle, selected: kind == k, radio: true, onTap: () => setState(() => kind = k)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
}

// MARK: C32 Show us the problem

class ProblemPhotosScreen extends StatefulWidget {
  const ProblemPhotosScreen({super.key, required this.kind});
  final ProblemKind kind;
  @override
  State<ProblemPhotosScreen> createState() => _ProblemPhotosScreenState();
}

class _ProblemPhotosScreenState extends State<ProblemPhotosScreen> {
  String note = 'Water streaks on the bonnet and the left mirror wasn’t wiped.';
  int photos = 2;
  bool sending = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return StepTotal(
      total: 2,
      child: WScreen(
        header: const BookingHeader(step: 2, label: 'Show us', title: 'Report a problem', fraction: 1),
        footer: WFooterBar(
          onCall: callSupport,
          child: WButton('Send report', enabled: photos > 0, loading: sending, onTap: () async {
            final id = store.currentOrderId;
            if (id == null) return;
            setState(() => sending = true);
            try {
              await store.reportProblem(id, widget.kind, note);
            } catch (_) {}
            router.replace(const [R(N.disputeStatus)]);
          }),
        ),
        children: [
          const WTitleBlock('Show us the problem', subtitle: 'Take photos from the same angles as the captain’s. We compare all three.'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: i < photos
                    ? WPhotoSlot(label: i == 0 ? 'Front' : 'Close-up', state: PhotoState.done, height: 94, icon: i == 0 ? WIcon.car : WIcon.zoom)
                    : WPhotoSlot(label: 'Add', height: 94, onTap: () => setState(() => photos++)),
              ),
            ],
          ]),
          const SizedBox(height: 18),
          WTextArea(value: note, placeholder: 'Tell us what you see', height: 96, onChanged: (v) => note = v),
        ],
      ),
    );
  }
}

// MARK: C33 under review · C34 upheld · C35 rejected · C36 damage

class DisputeStatusScreen extends StatelessWidget {
  const DisputeStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    final d = o?.dispute;
    Widget header(String title) => Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: title, onLeading: router.popToRoot, onTrailing: () => router.go(N.help)));
    switch (d?.outcome ?? DisputeOutcome.underReview) {
      case DisputeOutcome.upheld:
        return WScreen(
          header: header('Report #${d?.ref ?? 'WH-20914'}'),
          footer: WFooterBar(
            onCall: callSupport,
            child: WButton('Book free wash', onTap: () {
              if (o != null) {
                store.startRepeat(o.vehicle);
                store.set(() => store.draft.useFreeWash = true);
              }
              router.replace(const [R(N.photos)]);
            }),
          ),
          children: [
            Column(children: [
              const SizedBox(height: 20),
              const WStateCircle(WIcon.gift, tone: Tone.ok),
              const SizedBox(height: 24),
              const WText('You’re right, sorry', WType.screen),
              const SizedBox(height: 10),
              WText(d?.decisionNote ?? '', WType.body, align: TextAlign.center),
              const SizedBox(height: 24),
            ]),
            WKeyValueCard(rows: [
              ('Refund', '${Fmt.rupees(o?.refund?.amount ?? o?.price ?? 149)} to your UPI'),
              ('Bonus', '${d?.creditsAwarded ?? 2} free washes added'),
            ]),
          ],
        );
      case DisputeOutcome.rejected:
        return WScreen(
          header: header('Report #${d?.ref ?? 'WH-20914'}'),
          footer: WStackedFooter(children: [WButton('Okay', onTap: router.popToRoot), WButton('Talk to a person', kind: ButtonKind.text, onTap: callSupport)]),
          children: [
            const WTitleBlock('The wash looks complete', subtitle: 'We compared your photos with the captain’s. The marks were there before the wash.', top: 14),
            const Row(children: [
              Expanded(child: WPhotoPlaceholder(height: 90, icon: WIcon.car, tag: 'Before')),
              SizedBox(width: 8),
              Expanded(child: WPhotoPlaceholder(height: 90, icon: WIcon.sparkle, tag: 'After', tagTone: Tone.ok)),
              SizedBox(width: 8),
              Expanded(child: WPhotoPlaceholder(height: 90, icon: WIcon.image, caption: 'Yours')),
            ]),
            const SizedBox(height: 16),
            WBanner(tone: Tone.info, icon: WIcon.info, text: d?.decisionNote ?? ''),
            const SizedBox(height: 16),
            WText('${Fmt.rupees(o?.price ?? 149)} has been released to the captain.', WType.caption),
          ],
        );
      case DisputeOutcome.damagePriority:
        return WScreen(
          header: header('Damage report'),
          footer: WFooterBar(onCall: callSupport, child: const WButton('Download evidence pack', icon: WIcon.upload, kind: ButtonKind.outline)),
          children: [
            const SizedBox(height: 14),
            Row(children: [const WBadge('Priority', tone: Tone.wait, icon: WIcon.eye), const SizedBox(width: 12), WText('Ref #${d?.ref ?? 'WH-20915'}', WType.caption)]),
            const WTitleBlock('We’ll call you within 1 hour', subtitle: 'A real person from our team will go through this with you.', top: 16),
            WCard(
              outlined: true,
              child: Column(children: [
                WListRow(icon: WIcon.shield, title: '${o?.captain?.name ?? 'Raju'} is paused from new jobs', chevron: false),
                const WDivider(),
                const WListRow(icon: WIcon.doc, title: 'Evidence pack ready', subtitle: 'Time-stamped photos, location and call log', chevron: false),
                const WDivider(),
                const WListRow(icon: WIcon.rupee, title: 'We help with the claim', subtitle: 'Small damage paid from our protection fund', chevron: false),
              ]),
            ),
          ],
        );
      case DisputeOutcome.underReview:
        return WScreen(
          header: header('Report sent'),
          footer: WFooterBar(onCall: callSupport, child: WButton('Done', onTap: router.popToRoot)),
          children: [
            const SizedBox(height: 14),
            Row(children: [const WBadge('Under review', tone: Tone.wait, icon: WIcon.eye), const SizedBox(width: 12), WText('Ref #${d?.ref ?? 'WH-20914'}', WType.caption)]),
            WTitleBlock('We’re checking the photos', subtitle: '${Fmt.rupees(o?.price ?? 149)} stays on hold. You’ll hear from us within 24 hours.', top: 16),
            WStatusSteps(spacing: 22, current: 1, steps: [
              ('Report received', Fmt.time(d?.createdAt ?? DateTime.now())),
              ('Comparing photos', 'Your photos vs the captain’s before and after'),
              ('Decision', 'By 9:00 AM tomorrow'),
            ]),
          ],
        );
    }
  }
}

// MARK: C37 Refund status

class RefundScreen extends StatelessWidget {
  const RefundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final o = store.currentOrder;
    final r = o?.refund;
    final started = r?.startedAt ?? DateTime.now();
    return WScreen(
      header: Padding(padding: const EdgeInsets.only(top: 4), child: WAppBar(title: 'Refund', onLeading: router.pop, onTrailing: () => router.go(N.help))),
      footer: WFooterBar(onCall: callSupport, child: WButton('Done', onTap: router.pop)),
      children: [
        const Padding(padding: EdgeInsets.only(top: 18), child: WText('Refund amount', WType.label)),
        WText(Fmt.rupees(r?.amount ?? 149), WType.bigMoney, mono: true),
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 22),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const ShapeDecoration(color: WColor.successTint, shape: StadiumBorder()),
          child: Row(children: [const WIconView(WIcon.rupee, size: 12, color: WColor.onSuccess), const SizedBox(width: 8), WText(r?.credited == true ? 'Refund done' : 'Refund started', WType.label, color: WColor.onSuccess)]),
        ),
        if (r?.awaitingUPI == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: WBanner(
              tone: Tone.wait,
              icon: WIcon.rupee,
              title: 'We need your UPI ID.',
              text: 'Refunds go to UPI only for now. Add yours and we’ll send it right away.',
              actionTitle: 'Add UPI ID',
              onAction: () {
                if (o != null) router.push(R(N.refundUPI, id: o.id));
              },
            ),
          ),
        WStatusSteps(spacing: 22, current: r?.credited == true ? 3 : (r?.awaitingUPI == true ? 0 : 1), steps: [
          ('Refund started', '${Fmt.date(started)} · ${Fmt.time(started)}'),
          ('With your bank', 'Usually 2 to 3 working days'),
          ('In your account', r?.method ?? 'Google Pay · ananya@okhdfc'),
        ]),
        Padding(padding: const EdgeInsets.only(top: 28), child: WText('Bank reference: ${r?.bankRef ?? 'RZP8812093'}. Not received by ${Fmt.date(addDays(DateTime.now(), 4))}? Call us.', WType.caption)),
      ],
    );
  }
}
