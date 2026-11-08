import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'contracts.dart';
import 'policy.dart';

/// Shared recovery presentation. Supply an authenticated repository and private
/// evidence player/capture widget in production. No demo controls in this widget.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.repository,
    required this.role,
    required this.onBack,
    this.evidence,
    this.capture,
    this.onDone,
    this.onEarnings,
    this.onResumeWash,
    this.previewLabel,
    this.doneLabel,
    this.onScenarios,
    this.startCancelling = false,
  });
  /// v2: open on the Captain's "Cancel wash" quote (the handoff used a URL parameter).
  final bool startCancelling;
  final RecoveryRepository repository;
  final RecoveryRole role;
  final VoidCallback onBack;
  final Widget? evidence, capture;
  final VoidCallback? onDone, onEarnings, onResumeWash;
  final String? previewLabel, doneLabel;
  final VoidCallback? onScenarios;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  int language = 0;
  String t(String en, String hi, String te) => [en, hi, te][language];
  late bool cancelling = widget.startCancelling || Uri.base.queryParameters['intent'] == 'cancel';
  bool
      busy = false;
  String? error;
  String reason = 'Change of plans';
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  WButton action(
    String text,
    Future<void> Function() fn, {
    ButtonKind kind = ButtonKind.primary,
  }) => WButton(
    text,
    kind: kind,
    size: widget.role == RecoveryRole.captain
        ? ButtonSize.captain
        : ButtonSize.regular,
    loading: busy,
    onTap: () => run(fn),
  );
  Widget card(String title, String detail, {WIcon icon = WIcon.clock}) => WCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WIconBox(icon, size: 44),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(title, WType.value),
              const Gap(6),
              WText(detail, WType.caption),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final r = widget.repository,
          s = r.snapshot,
          captain = widget.role == RecoveryRole.captain;
      final children = <Widget>[];
      Widget? primary;
      if (widget.previewLabel != null)
        children.addAll([WBadge(widget.previewLabel!), const Gap(12)]);

      if (captain) {
        children.addAll([
          DropdownButtonFormField<int>(
            initialValue: language,
            decoration: const InputDecoration(
              labelText: 'Language / भाषा / భాష',
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('English')),
              DropdownMenuItem(value: 1, child: Text('हिन्दी')),
              DropdownMenuItem(value: 2, child: Text('తెలుగు')),
            ],
            onChanged: (v) => setState(() => language = v!),
          ),
          const Gap(10),
          WButton(
            t('Listen to the steps', 'निर्देश सुनें', 'సూచనలు వినండి'),
            icon: WIcon.speaker,
            kind: ButtonKind.text,
            size: ButtonSize.captain,
            onTap: () => Device.speak(
              t(
                'Check the parking spot, call the owner, then record a video. Send it for review. Only approved cases earn half of your quoted earnings.',
                'पार्किंग की जगह जाँचें, मालिक को कॉल करें, फिर वीडियो बनाएं। समीक्षा के लिए भेजें। मंजूरी मिलने पर इस वॉश की तय कमाई का आधा मिलेगा।',
                'పార్కింగ్ స్థలాన్ని తనిఖీ చేసి యజమానికి కాల్ చేయండి. తర్వాత వీడియో తీసి సమీక్షకు పంపండి. ఆమోదం పొందితే ఈ వాష్‌కు చెప్పిన ఆదాయంలో సగం లభిస్తుంది.',
              ),
              ['en-IN', 'hi-IN', 'te-IN'][language],
              () {},
            ),
          ),
          const Gap(12),
        ]);
      }

      if (s.status == RecoveryStatus.assigned) {
        if (!captain) {
          children.addAll([
            const WTitleBlock(
              'Your wash is on track',
              subtitle: 'Basic · Exterior only',
            ),
            card('Raju is your Captain', 'Tower 3 · B2 · Slot 41'),
            const Gap(18),
            const WText(
              'We’ll keep your Captain details up to date here.',
              WType.body,
            ),
          ]);
        } else if (cancelling) {
          children.addAll([
            WTitleBlock(
              t(
                'Can’t do this wash?',
                'यह वॉश नहीं कर सकते?',
                'ఈ వాష్ చేయలేరా?',
              ),
              subtitle:
                  'We’ll look for another Captain. Check the deduction before you cancel.',
            ),
            card(
              'Cancellation deduction',
              recoveryMoney(r.cancellationPenaltyPaise),
              icon: WIcon.rupee,
            ),
            const Gap(16),
            const WText(
              'Based on this visit’s paid booking value, not the full monthly plan.',
              WType.caption,
            ),
            const Gap(16),
            DropdownButtonFormField<String>(
              initialValue: reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: [
                'Change of plans',
                'Vehicle breakdown',
                'Emergency',
                'Unsafe location',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => reason = v!),
            ),
            const Gap(12),
            const WText(
              'For an emergency or unsafe situation, contact support for human review. Selecting a reason does not automatically waive the deduction.',
              WType.caption,
            ),
            const Gap(18),
            action(
              t('Cancel this wash', 'यह वॉश रद्द करें', 'ఈ వాష్ రద్దు చేయండి'),
              () => r.cancelCaptain(reason: reason),
              kind: ButtonKind.danger,
            ),
            const Gap(8),
            WButton(
              'Keep this wash',
              kind: ButtonKind.text,
              onTap: () => setState(() => cancelling = false),
            ),
            const Gap(18),
            const WText(
              'Within 5 minutes of accepting: ₹0. After that: 24+ hours ahead, 10%; 2–24 hours, 50%; under 2 hours, 100%.',
              WType.caption,
            ),
          ]);
        } else if (s.step == EvidenceStep.ready) {
          children.addAll([
            const WTitleBlock(
              'Review your report',
              subtitle:
                  'Check the video before sharing it with the owner and support.',
            ),
            card('TS 09 EA 4521', 'Tower 3 · B2 · Slot 41', icon: WIcon.car),
            const Gap(14),
            if (widget.evidence != null) widget.evidence!,
            const Gap(14),
            const WText(
              'Place checked · Owner contact attempted',
              WType.bodyStrong,
            ),
            const Gap(10),
            WText(
              'If approved: ${recoveryMoney(RecoveryPolicy.missingVehiclePay(r.visit.captainQuotePaise))} visit compensation. This is not earned until review is complete.',
              WType.caption,
            ),
            const Gap(14),
            WButton(
              'Record again',
              kind: ButtonKind.outline,
              onTap: () => run(r.retakeVideo),
            ),
          ]);
          primary = action(
            t(
              'Send proof for review',
              'समीक्षा के लिए भेजें',
              'సమీక్షకు పంపండి',
            ),
            r.submitEvidence,
          );
        } else {
          final step = s.step;
          children.addAll([
            WTitleBlock(
              s.status == RecoveryStatus.missingRejected
                  ? 'Let’s check again'
                  : t(
                      'Vehicle not here?',
                      'गाड़ी यहाँ नहीं है?',
                      'వాహనం ఇక్కడ లేదా?',
                    ),
              subtitle:
                  'Check the parking spot and try the owner before sending proof.',
            ),
            card('TS 09 EA 4521', 'Tower 3 · B2 · Slot 41', icon: WIcon.car),
            const Gap(18),
            card(
              t(
                '1 · Confirm the place',
                '1 · जगह की जाँच करें',
                '1 · స్థలాన్ని నిర్ధారించండి',
              ),
              step == EvidenceStep.location
                  ? 'Check the building, floor and parking number.'
                  : 'Place checked',
              icon: WIcon.check,
            ),
            const Gap(10),
            card(
              t(
                '2 · Contact the owner',
                '2 · मालिक से संपर्क करें',
                '2 · యజమానిని సంప్రదించండి',
              ),
              step.index < EvidenceStep.record.index
                  ? 'Give the owner a chance to help you find the vehicle.'
                  : 'Contact attempt recorded',
              icon: WIcon.phone,
            ),
            const Gap(10),
            card(
              t(
                '3 · Record the empty spot',
                '3 · खाली जगह का वीडियो बनाएं',
                '3 · ఖాళీ స్థలాన్ని వీడియో తీయండి',
              ),
              'Show the parking number and surroundings. Avoid faces and documents. This video is shared with the owner and support.',
              icon: WIcon.image,
            ),
            const Gap(18),
          ]);
          if (step == EvidenceStep.location)
            primary = action(
              r.isDemo ? 'Confirm demo location' : 'Confirm my location',
              r.verifyArrival,
            );
          if (step == EvidenceStep.contact)
            primary = action(
              r.isDemo ? 'Simulate unanswered call' : 'Call owner',
              r.contactOwner,
            );
          if (step == EvidenceStep.record || step == EvidenceStep.failed) {
            if (widget.capture != null) children.add(widget.capture!);
            primary = action(
              step == EvidenceStep.failed
                  ? 'Retry video upload'
                  : t(
                      'Use this video',
                      'यह वीडियो इस्तेमाल करें',
                      'ఈ వీడియో వాడండి',
                    ),
              r.prepareVideo,
            );
          }
          children.addAll([
            const Gap(16),
            WText(
              'If approved, you earn ${recoveryMoney(RecoveryPolicy.missingVehiclePay(r.visit.captainQuotePaise))} — 50% of your quoted ${recoveryMoney(r.visit.captainQuotePaise)} earnings for this visit. Sending proof is not approval.',
              WType.caption,
            ),
            const Gap(12),
            WButton(
              t(
                'I need to cancel instead',
                'मुझे वॉश रद्द करना है',
                'నేను వాష్ రద్దు చేయాలి',
              ),
              kind: ButtonKind.text,
              onTap: () => setState(() => cancelling = true),
            ),
          ]);
        }
      } else if ([
        RecoveryStatus.evidencePending,
        RecoveryStatus.missingApproved,
        RecoveryStatus.missingRejected,
        RecoveryStatus.disputed,
      ].contains(s.status)) {
        final rejected = s.status == RecoveryStatus.missingRejected;
        final approved = s.status == RecoveryStatus.missingApproved,
            disputed = s.status == RecoveryStatus.disputed;
        children.addAll([
          WTitleBlock(
            rejected
                ? (captain
                      ? 'More information needed'
                      : 'Your report is still with support')
                : disputed
                ? 'Support is reviewing'
                : approved
                ? (captain
                      ? 'Visit compensation approved'
                      : 'Vehicle wasn’t available')
                : (captain
                      ? 'Proof sent for review'
                      : 'Your Captain couldn’t find the vehicle'),
            subtitle: rejected
                ? 'The evidence did not establish vehicle unavailability. No compensation was approved.'
                : disputed
                ? 'We’ll review the evidence and both accounts before resolving this case.'
                : approved
                ? 'The wash was not completed.'
                : 'No decision has been made yet.',
          ),
          card(
            captain
                ? 'This visit’s earnings'
                : approved
                ? 'No refund for this visit'
                : 'Decision pending',
            captain
                ? (approved
                      ? '${recoveryMoney(s.compensationPaise)} · 50% of your quoted earnings'
                      : 'Compensation is pending review.')
                : approved
                ? 'The submitted proof was approved. You can ask support to review this.'
                : 'Review the video. If the vehicle was there, tell us.',
          ),
          const Gap(18),
        ]);
        children.addAll([
          card(
            'Report WK-NF-001',
            approved
                ? 'Review complete · Visit not performed'
                : disputed
                ? 'Dispute received · Evidence retained'
                : 'Submitted · Owner and support can review',
            icon: WIcon.receipt,
          ),
          const Gap(14),
        ]);
        if (!approved && !disputed)
          children.addAll([
            const WText('What happens next', WType.section),
            const Gap(8),
            const WText(
              'The owner can provide the vehicle location or ask for a review. Support checks the report before deciding any compensation. You can leave this screen and return from your jobs.',
              WType.body,
            ),
            const Gap(16),
          ]);
        if (approved && captain)
          children.addAll([
            const WText(
              'Approved · Payout not yet confirmed',
              WType.bodyStrong,
            ),
            const Gap(10),
            const WText(
              'This visit closes without a completed wash. The compensation appears separately from wash earnings.',
              WType.caption,
            ),
            const Gap(14),
          ]);
        if (widget.evidence != null) children.add(widget.evidence!);
        children.addAll([
          const Gap(12),
          WText(s.note, WType.body),
          const Gap(16),
        ]);
        if (!captain && !approved && !disputed && !rejected)
          children.add(
            action('My vehicle is here', () => _ownerLocation(context)),
          );
        if (captain && rejected)
          primary = action('Record clearer proof', r.retakeVideo);
        if (!captain && !disputed) {
          children.add(const Gap(10));
          children.add(
            WButton(
              'Ask support to review',
              kind: ButtonKind.outline,
              onTap: () => _dispute(context),
            ),
          );
        }
        if (!captain)
          children.addAll([
            const Gap(16),
            const WText(
              'Plans changed? Please let us know before your next wash so your Captain doesn’t travel to an unavailable vehicle.',
              WType.caption,
            ),
          ]);
      } else if (s.status == RecoveryStatus.vehicleLocated) {
        children.addAll([
          WTitleBlock(
            captain
                ? 'The owner shared the location'
                : 'Location sent to your Captain',
            subtitle: captain
                ? 'Check the updated parking details with the owner.'
                : 'We’ve kept your response with this report.',
          ),
          card('Parking update', s.note, icon: WIcon.location),
          const Gap(16),
          const WText(
            'No missing-vehicle compensation or refund has been issued. A wash only counts when it is actually completed.',
            WType.body,
          ),
        ]);
        if (captain && widget.onResumeWash != null)
          primary = WButton(
            'Return to wash',
            size: ButtonSize.captain,
            onTap: widget.onResumeWash,
          );
      } else if (s.status == RecoveryStatus.replacementSearching) {
        children.addAll([
          WTitleBlock(
            captain ? 'Your wash is cancelled' : 'Finding another Captain',
            subtitle: captain
                ? 'This job is no longer yours. Please don’t start the wash.'
                : 'Your wash details and price stay the same.',
          ),
          card(
            captain ? 'Deduction recorded' : 'Captain update',
            captain
                ? recoveryMoney(s.penaltyPaise)
                : 'We’re checking for an available Captain nearby.',
          ),
          const Gap(18),
          WText(
            captain
                ? 'If you think this is incorrect, contact support for a human review.'
                : r.visit.monthly
                ? 'If no replacement fits, we’ll offer a make-up day before returning this visit’s value.'
                : 'We’ll keep checking available Captains and escalate if needed. If the visit cannot be fulfilled, its full paid value returns to your wallet.',
            WType.body,
          ),
        ]);
      } else if (s.status == RecoveryStatus.makeUpOffered ||
          s.status == RecoveryStatus.makeUpScheduled) {
        final scheduled = s.status == RecoveryStatus.makeUpScheduled;
        children.addAll([
          WTitleBlock(
            scheduled
                ? 'Make-up wash scheduled'
                : captain
                ? 'A make-up day is being arranged'
                : 'Let’s make up this wash',
            subtitle: scheduled
                ? 'Your remaining plan visits stay as they are.'
                : 'We couldn’t arrange a replacement for the original window.',
          ),
          card(
            'Alternate visit',
            s.makeUpAt == null
                ? 'Support is checking another day'
                : '${Fmt.date(s.makeUpAt!)} · ${Fmt.window(s.makeUpAt!.hour, s.makeUpAt!.hour + 2)}',
            icon: WIcon.calendar,
          ),
          const Gap(14),
          const WText(
            'Same service · No extra charge · Replaces this missed visit',
            WType.bodyStrong,
          ),
          const Gap(12),
          WText(
            captain
                ? 'This does not restore your assignment. Follow only jobs currently assigned in your calendar.'
                : 'If a make-up day cannot be arranged, we’ll return only this visit’s paid value to your wallet.',
            WType.caption,
          ),
        ]);
        if (!captain && !scheduled) {
          primary = action('Confirm make-up day', r.acceptMakeUp);
          children.addAll([
            const Gap(14),
            WButton(
              'This day doesn’t work',
              kind: ButtonKind.outline,
              onTap: () => run(r.declineMakeUp),
            ),
          ]);
        }
      } else if (s.status == RecoveryStatus.reassigned) {
        children.addAll([
          WTitleBlock(
            captain ? 'Replacement arranged' : 'Your wash is on track',
            subtitle: captain
                ? 'Another Captain has taken over.'
                : 'Basic · Exterior only',
          ),
          card(
            captain ? 'Maya has this job now' : 'Maya is your Captain',
            captain
                ? 'Your cancellation deduction: ${recoveryMoney(s.penaltyPaise)}'
                : 'Captain updated · Same service, time window and price',
          ),
          const Gap(14),
          WText(
            captain
                ? 'You can no longer start this wash or submit photos.'
                : 'There’s nothing you need to do.',
            WType.caption,
          ),
        ]);
      } else {
        children.addAll([
          WTitleBlock(
            captain ? 'Visit closed' : 'Full value returned',
            subtitle: s.note,
          ),
          card(
            captain
                ? 'Customer wallet credited'
                : 'Added to your WashKrew wallet',
            recoveryMoney(s.creditPaise),
            icon: WIcon.rupee,
          ),
          const Gap(14),
          WText(
            captain
                ? 'Cancellation deduction: ${recoveryMoney(s.penaltyPaise)}. This is separate from customer wallet credit.'
                : 'Use this credit towards your next wash. It has not been refunded to your bank.',
            WType.body,
          ),
          if (r.visit.monthly) ...[
            const Gap(12),
            const WText(
              'Only this monthly-plan visit is affected. Your other visits remain scheduled.',
              WType.caption,
            ),
          ],
        ]);
      }
      if (primary == null && widget.onDone != null) {
        primary = WButton(
          captain &&
                  s.status == RecoveryStatus.missingApproved &&
                  widget.onEarnings != null
              ? 'View earnings'
              : widget.doneLabel ??
                    (captain ? 'Back to jobs' : 'Back to bookings'),
          size: captain ? ButtonSize.captain : ButtonSize.regular,
          onTap:
              captain &&
                  s.status == RecoveryStatus.missingApproved &&
                  widget.onEarnings != null
              ? widget.onEarnings
              : widget.onDone,
        );
      }
      if (error != null && primary == null)
        children.addAll([
          const Gap(16),
          Semantics(
            liveRegion: true,
            child: WText(error!, WType.body, color: WColor.destructive),
          ),
        ]);
      if (r.isDemo)
        children.addAll([
          const Gap(24),
          const WText(
            'Local review prototype · Sample visit, evidence and ledger only. No real payment, phone call, location verification or award.',
            WType.caption,
          ),
        ]);
      return WScreen(
        gutter: captain ? 16 : 26,
        header: WAppBar(
          title: captain ? 'Wash help' : 'Your wash',
          onLeading: widget.onBack,
        ),
        footer: primary == null
            ? null
            : WFooterBar(
                showCall: false,
                captain: captain,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      WText(error!, WType.caption, color: WColor.destructive),
                      const Gap(8),
                    ],
                    primary,
                    if (widget.onScenarios != null &&
                        [
                          RecoveryStatus.evidencePending,
                          RecoveryStatus.missingApproved,
                          RecoveryStatus.disputed,
                          RecoveryStatus.missingRejected,
                          RecoveryStatus.walletCredited,
                          RecoveryStatus.replacementSearching,
                        ].contains(s.status))
                      WButton(
                        'Continue demo review',
                        kind: ButtonKind.text,
                        onTap: widget.onScenarios,
                      ),
                  ],
                ),
              ),
        children: children,
      );
    },
  );
  Future<void> _ownerLocation(BuildContext context) async {
    final input = TextEditingController();
    final location = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Where is your vehicle?'),
          content: TextField(
            controller: input,
            maxLength: 300,
            onChanged: (_) => set(() {}),
            decoration: const InputDecoration(
              hintText: 'Building, floor and parking slot',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: input.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(c, input.text.trim()),
              child: const Text('Send location'),
            ),
          ],
        ),
      ),
    );
    if (location != null)
      await widget.repository.ownerLocatedVehicle(location: location);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  Future<void> _dispute(BuildContext context) async {
    final input = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tell us what happened'),
        content: TextField(
          controller: input,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'For example, my vehicle was in the correct slot.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => input.text.trim().isEmpty
                ? null
                : Navigator.pop(c, input.text.trim()),
            child: const Text('Send for review'),
          ),
        ],
      ),
    );
    if (reason != null) await run(() => widget.repository.dispute(reason));
    // Controller disposal deferred until the dialog exit animation is complete.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }
}
