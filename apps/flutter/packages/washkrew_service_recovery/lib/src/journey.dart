import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'contracts.dart';
import 'policy.dart';

/// Persistent entry into a case. No client clock or grant operation.
class RecoveryCaseCard extends StatelessWidget {
  const RecoveryCaseCard({
    super.key,
    required this.repository,
    required this.onOpen,
    this.captain = false,
  });
  final RecoveryRepository repository;
  final VoidCallback onOpen;
  final bool captain;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (c, _) {
      final s = repository.snapshot;
      if (s.revision == 0 ||
          (s.status == RecoveryStatus.assigned &&
              s.step == EvidenceStep.location &&
              s.note.isEmpty))
        return const SizedBox.shrink();
      final title = switch (s.status) {
        RecoveryStatus.assigned => 'Finish your report',
        RecoveryStatus.evidencePending => 'Vehicle report · In review',
        RecoveryStatus.missingApproved => 'Vehicle report · Approved',
        RecoveryStatus.missingRejected =>
          'Vehicle report · More information needed',
        RecoveryStatus.disputed => 'Vehicle report · Dispute in review',
        RecoveryStatus.vehicleLocated => 'Vehicle location updated',
        RecoveryStatus.replacementSearching => 'Finding another Captain',
        RecoveryStatus.makeUpOffered => 'Make-up day offered',
        RecoveryStatus.makeUpScheduled => 'Make-up wash scheduled',
        RecoveryStatus.reassigned => 'Replacement arranged',
        RecoveryStatus.walletCredited => 'Visit closed · Wallet credited',
      };
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: WCard(
          onTap: onOpen,
          outlined: true,
          child: Row(
            children: [
              const WIconBox(WIcon.receipt, size: 44),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WText(title, WType.value),
                    const Gap(5),
                    WText(
                      s.status == RecoveryStatus.missingApproved && captain
                          ? '${recoveryMoney(s.compensationPaise)} approved · Payout pending'
                          : 'TS 09 EA 4521 · View details',
                      WType.caption,
                    ),
                  ],
                ),
              ),
              const WIconView(WIcon.chevron, size: 20),
            ],
          ),
        ),
      );
    },
  );
}

class RecoveryEarningsScreen extends StatelessWidget {
  const RecoveryEarningsScreen({
    super.key,
    required this.repository,
    required this.onBack,
    required this.onDone,
  });
  final RecoveryRepository repository;
  final VoidCallback onBack, onDone;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (c, _) {
      final s = repository.snapshot,
          visit = repository.visit,
          approved = s.status == RecoveryStatus.missingApproved;
      Widget line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: WText(label, WType.body)),
            WText(value, WType.valueStrong),
          ],
        ),
      );
      return WScreen(
        gutter: 16,
        header: WAppBar(title: 'Visit earnings', onLeading: onBack),
        footer: WFooterBar(
          captain: true,
          showCall: false,
          child: WButton(
            'Back to Money',
            size: ButtonSize.captain,
            onTap: onDone,
          ),
        ),
        children: [
          WTitleBlock(
            approved
                ? '${recoveryMoney(s.compensationPaise)} approved'
                : 'Settlement details',
            subtitle: 'TS 09 EA 4521 · Report WK-NF-001',
          ),
          WCard(
            outlined: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line(
                  'Original visit quote',
                  recoveryMoney(visit.captainQuotePaise),
                ),
                line('Completed wash earnings', '₹0'),
                line(
                  'Vehicle-not-found compensation',
                  approved
                      ? recoveryMoney(s.compensationPaise)
                      : s.status == RecoveryStatus.disputed
                      ? 'On hold'
                      : 'Not approved',
                ),
                if (s.penaltyPaise > 0)
                  line(
                    'Cancellation deduction',
                    '−${recoveryMoney(s.penaltyPaise)}',
                  ),
                const Divider(),
                WText(
                  approved
                      ? 'Approved · Awaiting payout confirmation'
                      : 'Review status: ${s.status.name}',
                  WType.bodyStrong,
                ),
              ],
            ),
          ),
          const Gap(18),
          const WText(
            'An approved amount is not a completed bank transfer. Payout confirmation will appear only when operations actually send it.',
            WType.body,
          ),
          const Gap(12),
          const WText(
            'No completed wash or referral progress is added for this unperformed visit.',
            WType.caption,
          ),
          if (repository.isDemo) ...[
            const Gap(18),
            const WText(
              'Sample receipt only. No real financial ledger was changed.',
              WType.caption,
            ),
          ],
        ],
      );
    },
  );
}
