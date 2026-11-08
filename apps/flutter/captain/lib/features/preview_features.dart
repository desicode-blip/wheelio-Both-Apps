import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_referrals/washkrew_referrals.dart';
import 'package:washkrew_referrals/demo_tools.dart';
import 'package:washkrew_captain_jobs/washkrew_captain_jobs.dart';
import 'package:washkrew_service_recovery/washkrew_service_recovery.dart';
import 'package:washkrew_service_recovery/demo_tools.dart';

import '../data/store.dart';

// v2 (ChatGPT handoff, 8 Nov 2026): Captain referrals, per-visit pay, recurring work and
// "vehicle not found". Preview only — opened from Me → Preview. The pay figures are the
// handoff's illustrative examples (not approved rates) and never touch real jobs.

CaptainLanguage _lang(CaptainStore s) => CaptainLanguage.values[s.lang.index];

const exampleOnce = VisitTerms(
  quoteId: 'preview-once',
  policyVersion: 'illustrative-not-approved',
  kind: VisitBookingKind.oneTime,
  service: 'Basic',
  coverage: 'Exterior only',
  estimatedMinutes: 20,
  netPayPaise: 12000,
  illustrative: true,
);

const exampleMonthly = VisitTerms(
  quoteId: 'preview-monthly',
  policyVersion: 'illustrative-not-approved',
  kind: VisitBookingKind.monthlyPlan,
  service: 'Basic',
  coverage: 'Exterior only',
  estimatedMinutes: 20,
  netPayPaise: 3500,
  visitNumber: 3,
  totalVisits: 13,
  illustrative: true,
);

/// Reads a visit's terms aloud in the Captain's language.
void speakTerms(CaptainStore store, VisitTerms t) => Device.speak(
  '${CaptainJobCopy(_lang(store)).booking(t.kind)}. ${t.service}. ${t.coverage}. ${t.payLabel}. ${t.estimatedMinutes} minutes.',
  store.lang == Lang.hi ? 'hi-IN' : store.lang == Lang.te ? 'te-IN' : 'en-IN',
  () {},
);

class CaptainReferralsScreen extends StatelessWidget {
  const CaptainReferralsScreen({super.key});
  @override
  Widget build(BuildContext context) => ReferralHomeScreen(
    repository: context.store.referrals,
    onBack: context.router.pop,
    language: ReferralLanguage.values[context.store.lang.index],
  );
}

class CaptainReferralScenariosScreen extends StatelessWidget {
  const CaptainReferralScenariosScreen({super.key});
  @override
  Widget build(BuildContext context) => ReferralScenarioScreen(
    repository: context.store.referrals,
    onBack: context.router.pop,
    onOpen: () => context.router.go(N.referrals),
  );
}

/// What the private admin would show for referrals (synthetic, read-only).
class ReferralAdminPreview extends StatelessWidget {
  const ReferralAdminPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.store;
    return ReferralAdminPreviewScreen(
      links: [...s.referrals.adminLinks, ...s.customerReferralPreview.adminLinks],
      rewards: [...s.referrals.adminRewards, ...s.customerReferralPreview.adminRewards],
      onBack: context.router.pop,
    );
  }
}

class PayGuidePreview extends StatelessWidget {
  const PayGuidePreview({super.key});
  @override
  Widget build(BuildContext context) => CaptainPayGuideScreen(
    oneTime: exampleOnce,
    monthly: exampleMonthly,
    onBack: context.router.pop,
    language: _lang(context.store),
  );
}

/// The offer card's pay terms for a one-time wash and a monthly-plan visit (CA-01/CA-02).
class OfferTermsPreview extends StatelessWidget {
  const OfferTermsPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      header: WAppBar(title: store.t('Job offer pay', 'काम की कमाई', 'పని ఆదాయం'), onLeading: context.router.pop),
      gutter: WSpace.gutterCaptain,
      children: [
        VisitTermsCard(terms: exampleOnce, language: _lang(store), onListen: () => speakTerms(store, exampleOnce)),
        const Gap(16),
        VisitTermsCard(terms: exampleMonthly, language: _lang(store), onListen: () => speakTerms(store, exampleMonthly)),
        const Gap(16),
        const WText('Example rates for design review, not approved pay. Real offers show the server’s quote.', WType.caption),
      ],
    );
  }
}

RecurringAssignment sampleRecurringAssignment() {
  final now = DateTime.now(), start = DateTime(now.year, now.month, now.day);
  final last = DateTime(now.year, now.month + 2, 0).day;
  final end = DateTime(now.year, now.month + 1, now.day.clamp(1, last));
  final dates = <DateTime>[];
  for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
    if ([1, 3, 5].contains(d.weekday)) dates.add(d);
  }
  return RecurringAssignment(
    id: 'preview-recurring',
    terms: VisitTerms(
      quoteId: 'preview-recurring',
      policyVersion: 'illustrative-not-approved',
      kind: VisitBookingKind.monthlyPlan,
      service: 'Basic',
      coverage: 'Exterior only',
      estimatedMinutes: 20,
      netPayPaise: 3500,
      visitNumber: 1,
      totalVisits: dates.length,
      illustrative: true,
    ),
    dates: dates,
    vehicle: 'TS 09 EA 4521 · Hatchback',
    place: 'My Home Avatar · Tower 3 · B2 · Slot 41',
  );
}

class RecurringAssignmentPreview extends StatelessWidget {
  const RecurringAssignmentPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return RecurringAssignmentScreen(
      assignment: sampleRecurringAssignment(),
      accepted: store.recurringAccepted,
      onBack: router.pop,
      onAccept: () => store.set(() => store.recurringAccepted = true),
      onCalendar: () {
        router.popToRoot();
        router.tab = 1;
      },
    );
  }
}

/// Captain side of "vehicle not found": check parking, contact, record, review, send.
class CaptainRecoveryScreen extends StatelessWidget {
  const CaptainRecoveryScreen({super.key, this.cancel = false});
  /// Opens on "Cancel wash" with the deduction quote.
  final bool cancel;
  @override
  Widget build(BuildContext context) {
    final router = context.router;
    return RecoveryScreen(
      repository: context.store.recovery,
      role: RecoveryRole.captain,
      startCancelling: cancel,
      onBack: router.pop,
      evidence: const PhoneEvidence(capture: false),
      capture: const PhoneEvidence(capture: true),
      onDone: () {
        router.popToRoot();
        router.tab = 1;
      },
      onEarnings: () => router.go(N.recoveryEarnings),
      onResumeWash: router.pop,
      onScenarios: () => router.go(N.recoveryScenarios),
    );
  }
}

/// Preview controls for review outcomes (handoff review tool), incl. the owner's view.
class CaptainRecoveryScenariosScreen extends StatelessWidget {
  const CaptainRecoveryScenariosScreen({super.key});
  @override
  Widget build(BuildContext context) => RecoveryReviewHarness(
    repository: context.store.recovery,
    onBack: context.router.pop,
    onOpen: () => context.router.go(N.recovery),
    onCustomerPreview: () => context.router.go(N.recoveryOwnerPreview),
  );
}

class RecoveryOwnerPreview extends StatelessWidget {
  const RecoveryOwnerPreview({super.key});
  @override
  Widget build(BuildContext context) => RecoveryScreen(
    repository: context.store.recovery,
    role: RecoveryRole.customer,
    onBack: context.router.pop,
    onDone: context.router.pop,
    doneLabel: 'Back to review controls',
    previewLabel: 'Preview · Customer view',
    evidence: const PhoneEvidence(capture: false),
    onScenarios: () => context.router.go(N.recoveryScenarios),
  );
}

class RecoveryEarningsPreview extends StatelessWidget {
  const RecoveryEarningsPreview({super.key});
  @override
  Widget build(BuildContext context) => RecoveryEarningsScreen(
    repository: context.store.recovery,
    onBack: context.router.pop,
    onDone: () {
      context.router.popToRoot();
      context.router.tab = 2;
    },
  );
}

/// Referral bonuses on Money, kept apart from wash earnings.
class ReferralEarningsCard extends StatelessWidget {
  const ReferralEarningsCard({super.key, required this.repository, required this.onOpen});
  final ReferralRepository repository;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) => WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WIconBox(WIcon.gift, tone: Tone.ok, size: 44),
              const Gap(12),
              const Expanded(child: WText('Referral bonuses', WType.title)),
              WLink('View', onTap: onOpen),
            ],
          ),
          const Gap(10),
          WText('₹${repository.pendingCashPaise ~/ 100}', WType.section, mono: true),
          const Gap(4),
          const WText('Earned · payout pending. Separate from wash earnings.', WType.caption),
        ],
      ),
    ),
  );
}
