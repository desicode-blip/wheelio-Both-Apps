import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';
import 'package:washkrew_referrals/washkrew_referrals.dart';
import 'package:washkrew_referrals/demo_tools.dart';
import 'package:washkrew_service_recovery/washkrew_service_recovery.dart';
import 'package:washkrew_service_recovery/demo_tools.dart';

import '../data/store.dart';

// v2 CU-WASHCHOICE phases 3–4 (ChatGPT handoff, 8 Nov): referrals and "vehicle not
// found" for the Customer. Opened only with Preview new features; the repositories are
// the handoff's in-memory previews until Ajay's server versions replace them.

/// Referral progress, code and the free Premium wash.
class CustomerReferralsScreen extends StatelessWidget {
  const CustomerReferralsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return ReferralHomeScreen(
      repository: store.referrals,
      onBack: router.pop,
      onRedeem: (reward) async {
        store.startNewBooking();
        try {
          final id = await store.referrals.reservePremiumWash(reward.id);
          store.set(() {
            store.purchase.premiumRewardId = id;
            store.purchase.mode = PurchaseMode.once;
            store.purchase.level = ServiceLevel.premium;
            store.purchase.coverage = WashCoverage.exterior;
          });
          router.go(N.vehicleType);
        } catch (e) {
          store.set(() => store.toast = e.toString().replaceFirst('Bad state: ', ''));
        }
      },
    );
  }
}

/// Preview controls for referral progress (handoff review tool).
class CustomerReferralScenariosScreen extends StatelessWidget {
  const CustomerReferralScenariosScreen({super.key});
  @override
  Widget build(BuildContext context) => ReferralScenarioScreen(
    repository: context.store.referrals,
    onBack: context.router.pop,
    onOpen: () => context.router.go(N.referrals),
  );
}

/// "Were you referred?" — optional code.
class CustomerReferralJoinScreen extends StatefulWidget {
  const CustomerReferralJoinScreen({super.key});
  @override
  State<CustomerReferralJoinScreen> createState() => _CustomerReferralJoinScreenState();
}

class _CustomerReferralJoinScreenState extends State<CustomerReferralJoinScreen> {
  String code = '';
  String? error;
  @override
  Widget build(BuildContext context) => WScreen(
    header: WAppBar(title: 'Referral code', onLeading: context.router.pop),
    footer: WFooterBar(
      showCall: false,
      child: WButton(
        'Continue',
        onTap: () async {
          final s = context.store;
          final e = s.referrals.validateCode(code);
          if (e != null) {
            setState(() => error = e);
            return;
          }
          await s.referrals.attachCode(code);
          if (context.mounted) context.router.pop();
        },
      ),
    ),
    children: [
      const WTitleBlock('Were you referred?', subtitle: 'Optional. Your code is linked after account verification.'),
      ReferralCodeField(
        value: code,
        error: error,
        onChanged: (v) => setState(() {
          code = v;
          error = null;
        }),
      ),
      const Gap(14),
      const WText('Preview on this phone. The real link is made by the server after sign-in.', WType.caption),
    ],
  );
}

/// Vehicle not found: owner response, dispute, replacement and make-up.
class CustomerRecoveryScreen extends StatelessWidget {
  const CustomerRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return RecoveryScreen(
      repository: store.recovery,
      role: RecoveryRole.customer,
      onBack: router.pop,
      evidence: const PhoneEvidence(capture: false),
      onDone: () {
        router.popToRoot();
        router.tab = 1;
      },
      onScenarios: () => router.go(N.recoveryScenarios),
    );
  }
}

/// Preview controls for review outcomes (handoff review tool).
class CustomerRecoveryScenariosScreen extends StatelessWidget {
  const CustomerRecoveryScenariosScreen({super.key});
  @override
  Widget build(BuildContext context) => RecoveryReviewHarness(
    repository: context.store.recovery,
    onBack: context.router.pop,
    onOpen: () => context.router.go(N.recovery),
  );
}
