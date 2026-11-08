import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import '../src/screens.dart';
import 'demo_referral_repository.dart';

class ReferralScenarioScreen extends StatefulWidget {
  const ReferralScenarioScreen({
    super.key,
    required this.repository,
    required this.onBack,
    required this.onOpen,
  });
  final DemoReferralRepository repository;
  final VoidCallback onBack, onOpen;
  @override
  State<ReferralScenarioScreen> createState() => _ReferralScenarioScreenState();
}

class _ReferralScenarioScreenState extends State<ReferralScenarioScreen> {
  int sequence = 0;
  void advance(int target) {
    final p = widget.repository.outgoing.firstOrNull;
    if (p == null) return;
    for (var i = p.completedWashes; i < target; i++) {
      widget.repository.simulateVerifiedCompletion(
        referralId: p.id,
        washId:
            'scenario_${DateTime.now().microsecondsSinceEpoch}_${sequence++}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) => WScreen(
      header: WAppBar(
        title: 'Referral scenarios · demo',
        onLeading: widget.onBack,
      ),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Open referral program', onTap: widget.onOpen),
      ),
      children: [
        const WTitleBlock(
          'Try the milestones',
          subtitle: 'Review controls only. These do not issue real rewards.',
        ),
        for (final p in widget.repository.outgoing) ...[
          ReferralProgressCard(progress: p),
          const Gap(12),
        ],
        WButton(
          'Add one completed wash',
          onTap: () {
            final p = widget.repository.outgoing.firstOrNull;
            if (p != null) advance(p.completedWashes + 1);
          },
        ),
        const Gap(12),
        WButton(
          'Preview milestone 5',
          kind: ButtonKind.outline,
          onTap: () => advance(5),
        ),
        const Gap(12),
        WButton(
          'Preview milestone 50',
          kind: ButtonKind.outline,
          onTap: () => advance(50),
        ),
        const Gap(18),
        WText(
          '${widget.repository.rewards.length} reward records · ${widget.repository.availablePremiumWashes.length} free Premium washes',
          WType.bodyStrong,
        ),
        const Gap(8),
        const WText(
          'The live app must receive verified progress and reward records from the server. No increment control belongs in the released app.',
          WType.caption,
        ),
      ],
    ),
  );
}
