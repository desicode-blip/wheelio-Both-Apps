import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'repository.dart';
import '../src/contracts.dart';
import '../src/policy.dart';

/// Separate review-only controls; excluded from production package entrypoint.
class RecoveryReviewHarness extends StatelessWidget {
  const RecoveryReviewHarness({
    super.key,
    required this.repository,
    required this.onBack,
    required this.onOpen,
    this.onCustomerPreview,
  });
  final DemoRecoveryRepository repository;
  final VoidCallback onBack, onOpen;
  final VoidCallback? onCustomerPreview;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (c, _) {
      final r = repository, s = r.snapshot;
      Widget control(String title, VoidCallback fn) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: WButton(
          title,
          kind: ButtonKind.outline,
          onTap: () {
            try {
              fn();
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$e')));
            }
          },
        ),
      );
      return WScreen(
        header: WAppBar(title: 'Recovery review lab', onLeading: onBack),
        footer: WFooterBar(
          showCall: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WButton('Open app flow', onTap: onOpen),
              if (onCustomerPreview != null)
                WButton(
                  'View customer response',
                  kind: ButtonKind.text,
                  onTap: onCustomerPreview,
                ),
            ],
          ),
        ),
        children: [
          const WTitleBlock(
            'Try every outcome',
            subtitle:
                'Synthetic review controls. These are not Captain or Customer permissions.',
          ),
          WText('Current state: ${s.status.name}', WType.value),
          const Gap(16),
          control('Reset this sample visit', r.reset),
          const WText('Cancellation time', WType.value),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in [48, 24, 12, 2, 1])
                SizedBox(
                  width: 140,
                  child: WButton(
                    '$h hours before',
                    kind: ButtonKind.outline,
                    onTap: () => r.setBand(h),
                  ),
                ),
              SizedBox(
                width: 180,
                child: WButton(
                  'Within 5 minutes',
                  kind: ButtonKind.outline,
                  onTap: () => r.setBand(1, grace: true),
                ),
              ),
            ],
          ),
          const Gap(10),
          WText(
            'Preview deduction: ${recoveryMoney(r.cancellationPenaltyPaise)}',
            WType.body,
          ),
          const Gap(20),
          const WText('Evidence and review', WType.value),
          const Gap(10),
          control('Fail next video upload', () {
            r.failNextUpload = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('The next upload will fail once.')),
            );
          }),
          if (s.status == RecoveryStatus.evidencePending ||
              s.status == RecoveryStatus.disputed) ...[
            control(
              'Human review: approve missing vehicle',
              () => r.reviewMissing(approve: true),
            ),
            control(
              'Human review: evidence insufficient',
              () => r.reviewMissing(approve: false),
            ),
          ],
          if (s.status == RecoveryStatus.disputed)
            control(
              'Human review: uphold customer dispute',
              r.resolveDisputeForCustomer,
            ),
          if (s.status == RecoveryStatus.replacementSearching) ...[
            control(
              'Replacement Captain accepts',
              () => r.replacement(found: true),
            ),
            control(
              'No replacement by wash window',
              () => r.replacement(found: false),
            ),
          ],
          if (s.status == RecoveryStatus.makeUpOffered)
            control('No make-up day available', r.noMakeUpAvailable),
          const Gap(16),
          const WText(
            'Open Customer and Captain in two tabs at the same localhost address. This sample visit synchronises locally. The real app needs authorized server transactions, private evidence and a server search deadline.',
            WType.caption,
          ),
        ],
      );
    },
  );
}
