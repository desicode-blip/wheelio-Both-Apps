import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'model.dart';

class ReferralHomeScreen extends StatelessWidget {
  const ReferralHomeScreen({
    super.key,
    required this.repository,
    required this.onBack,
    this.language = ReferralLanguage.en,
    this.onRedeem,
  });
  final ReferralRepository repository;
  final VoidCallback onBack;
  final ReferralLanguage language;
  final void Function(ReferralReward reward)? onRedeem;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      final copy = ReferralCopy(language),
          captain = repository.identity.role == ReferralRole.captain;
      return WScreen(
        gutter: captain ? 16 : 26,
        header: WAppBar(title: copy.referrals, onLeading: onBack),
        footer: WFooterBar(
          captain: captain,
          showCall: false,
          child: WButton(
            copy.copyLink,
            icon: WIcon.gift,
            size: captain ? ButtonSize.captain : ButtonSize.regular,
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: repository.inviteUrl),
              );
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      copy.t(
                        'Demo invite link copied',
                        'डेमो लिंक कॉपी हुआ',
                        'డెమో లింక్ కాపీ అయింది',
                      ),
                    ),
                  ),
                );
            },
          ),
        ),
        children: [
          WTitleBlock(
            captain ? copy.inviteCaptain : copy.inviteCustomer,
            subtitle: captain
                ? copy.t(
                    'They wash. You both earn.',
                    'वे वॉश करें। आप दोनों कमाएँ।',
                    'వారు వాష్ చేస్తారు. ఇద్దరూ సంపాదిస్తారు.',
                  )
                : 'Free Premium washes for you.',
          ),
          ReferralCodeCard(
            code: repository.identity.code,
            label: copy.yourCode,
          ),
          const Gap(18),
          if (captain) ...[
            _MilestoneRule(
              washes: 5,
              title: copy.t('₹50 each', 'दोनों को ₹50', 'ఇద్దరికీ ₹50'),
              detail: copy.t(
                'You and your friend each earn ₹50.',
                'आपको और आपके दोस्त को ₹50 मिलेंगे।',
                'మీకు, మీ స్నేహితుడికి చెరో ₹50.',
              ),
            ),
            const Gap(10),
            _MilestoneRule(
              washes: 50,
              title: copy.t(
                '₹500 more for you',
                'आपको ₹500 और',
                'మీకు మరో ₹500',
              ),
              detail: copy.t(
                '₹550 total for each successful referral.',
                'हर सफल रेफ़रल पर कुल ₹550।',
                'ఒక్కో విజయవంతమైన రిఫరల్‌కు మొత్తం ₹550.',
              ),
            ),
          ] else ...[
            // v2 (12 Nov, Aman): the rule as three short steps, not a sentence.
            const _HowItWorks(),
          ],
          if (repository.incoming != null) ...[
            const Gap(18),
            WCard(
              outlined: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WText(
                    copy.t(
                      'Your joining reward',
                      'आपका जुड़ने का इनाम',
                      'మీ చేరిక రివార్డు',
                    ),
                    WType.title,
                  ),
                  const Gap(6),
                  WText(
                    captain
                        ? 'Complete 5 washes to earn ₹50.'
                        : 'Your referral is linked.',
                    WType.bodyStrong,
                  ),
                  const Gap(8),
                  WText(
                    '${repository.incoming!.completedWashes} / 5 ${copy.completed}',
                    WType.caption,
                  ),
                ],
              ),
            ),
          ],
          const Gap(24),
          WText(copy.progress, WType.section),
          const Gap(12),
          if (repository.outgoing.isEmpty)
            const WCard(
              outlined: true,
              child: WText(
                'Your friends appear here after they join with your code.',
                WType.body,
              ),
            ),
          for (final referral in repository.outgoing) ...[
            ReferralProgressCard(progress: referral, language: language),
            const Gap(12),
          ],
          const Gap(10),
          WText(copy.rewards, WType.section),
          const Gap(12),
          if (repository.rewards.isEmpty)
            WText(
              captain
                  ? 'Your first reward unlocks at 5 completed washes.'
                  : 'None yet',
              WType.body,
            ),
          for (final reward in repository.rewards) ...[
            WCard(
              outlined: true,
              child: Row(
                children: [
                  WIconBox(
                    reward.kind == RewardKind.cash ? WIcon.rupee : WIcon.gift,
                    tone: Tone.ok,
                    size: 44,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WText(
                          reward.kind == RewardKind.cash
                              ? '₹${reward.amountPaise ~/ 100}'
                              : 'Free Premium wash',
                          WType.title,
                        ),
                        const Gap(4),
                        WText(
                          reward.kind == RewardKind.cash
                              ? (reward.state == RewardState.paid
                                    ? copy.paid
                                    : copy.pending)
                              : reward.state == RewardState.available
                              ? 'Any supported vehicle'
                              : reward.state == RewardState.reserved
                              ? 'Reserved for your next booking'
                              : 'Used',
                          WType.caption,
                        ),
                      ],
                    ),
                  ),
                  if (reward.kind == RewardKind.premiumWash &&
                      (reward.state == RewardState.available ||
                          reward.state == RewardState.reserved) &&
                      onRedeem != null)
                    WLink('Use', onTap: () => onRedeem!(reward)),
                ],
              ),
            ),
            const Gap(10),
          ],
          const Gap(14),
          WLink(
            copy.t('What counts?', 'क्या गिना जाएगा?', 'ఏవి లెక్కిస్తారు?'),
            onTap: () => showWAlert(
              context,
              title: copy.t(
                'Completed washes only',
                'सिर्फ़ पूरे किए गए वॉश',
                'పూర్తయిన వాష్‌లు మాత్రమే',
              ),
              message: captain
                  ? 'Only completed, verified washes count. Cancelled, disputed or unfinished jobs do not count. Bonuses are separate from wash earnings; earned does not mean paid out.'
                  : 'Each referred friend must complete 5 paid washes. Cancelled, refunded or free reward washes do not count. Subscription visits count when completed, not when the plan is purchased. Each successful referral earns one Premium wash.',
            ),
          ),
        ],
      );
    },
  );
}

class ReferralCodeCard extends StatelessWidget {
  const ReferralCodeCard({super.key, required this.code, required this.label});
  final String code, label;
  @override
  Widget build(BuildContext context) => WCard(
    outlined: true,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(label, WType.caption),
              const Gap(6),
              WText(code, WType.section, mono: true),
            ],
          ),
        ),
        WLink(
          'Copy',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Code copied')));
          },
        ),
      ],
    ),
  );
}

class _MilestoneRule extends StatelessWidget {
  const _MilestoneRule({
    required this.washes,
    required this.title,
    required this.detail,
  });
  final int washes;
  final String title, detail;
  @override
  Widget build(BuildContext context) => WCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: WColor.primaryTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: WText('$washes', WType.screen, color: WColor.primary),
        ),
        const Gap(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(title, WType.title),
              const Gap(4),
              WText('After $washes completed washes', WType.caption),
              const Gap(4),
              WText(detail, WType.body),
            ],
          ),
        ),
      ],
    ),
  );
}

class ReferralProgressCard extends StatelessWidget {
  const ReferralProgressCard({
    super.key,
    required this.progress,
    this.language = ReferralLanguage.en,
  });
  final ReferralProgress progress;
  final ReferralLanguage language;
  @override
  Widget build(BuildContext context) {
    final p = progress,
        c = ReferralCopy(language),
        captain = p.role == ReferralRole.captain;
    final target = captain && p.completedWashes >= 5 ? 50 : 5;
    final remaining = (target - p.completedWashes).clamp(0, target);
    final total = captain ? 50 : 5, done = p.completedWashes >= total;
    if (!captain) {
      // v2 (12 Nov, Aman): what's left in big type, the rule in one short line.
      return WCard(
        outlined: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const WIconBox(WIcon.user, size: 40),
                const Gap(12),
                Expanded(child: WText(p.name, WType.title)),
                WText('${p.completedWashes.clamp(0, 5)}/5', WType.caption, mono: true),
              ],
            ),
            const Gap(14),
            WText(
              done ? 'Premium wash won' : '$remaining more ${remaining == 1 ? 'wash' : 'washes'}',
              WType.section,
              color: done ? WColor.onSuccess : WColor.heading,
            ),
            const Gap(2),
            WText(done ? 'Added to your rewards' : 'to win a free Premium wash', WType.caption),
            const Gap(12),
            _Segments(done: p.completedWashes.clamp(0, 5), total: 5),
          ],
        ),
      );
    }
    return WCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WIconBox(WIcon.user, size: 40),
              const Gap(12),
              Expanded(child: WText(p.name, WType.title)),
              WText(
                '${p.completedWashes} / ${captain ? 50 : 5}',
                WType.valueStrong,
                mono: true,
              ),
            ],
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (p.completedWashes / (captain ? 50 : 5)).clamp(0, 1),
              backgroundColor: WColor.track,
              color: WColor.primary,
            ),
          ),
          const Gap(10),
          WText(
            remaining == 0
                ? c.t(
                    'All rewards earned',
                    'सभी इनाम मिले',
                    'అన్ని రివార్డులు సంపాదించారు',
                  )
                : c.t(
                    '$remaining more ${remaining == 1 ? 'wash' : 'washes'} to ${captain ? (target == 5 ? 'your first ₹50' : '₹500 more') : 'a free Premium wash'}',
                    'अगले इनाम के लिए $remaining वॉश बाकी',
                    'తదుపరి రివార్డుకు ఇంకా $remaining వాష్‌లు',
                  ),
            WType.bodyStrong,
          ),
          const Gap(12),
          _ProgressMilestone(
            label: captain
                ? '5 washes · ₹50 each'
                : '5 paid washes · 1 Premium wash',
            reached: p.completedWashes >= 5,
          ),
          if (captain) ...[
            const Gap(8),
            _ProgressMilestone(
              label: '50 washes · ₹500 more for you',
              reached: p.completedWashes >= 50,
            ),
          ],
        ],
      ),
    );
  }
}

/// One block per wash: filled when done, green when all are done.
class _Segments extends StatelessWidget {
  const _Segments({required this.done, required this.total});
  final int done, total;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const Gap(6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            decoration: BoxDecoration(
              color: i < done ? (done >= total ? WColor.success : WColor.primary) : WColor.track,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
      const Gap(10),
      WIconView(WIcon.gift, size: 18, color: done >= total ? WColor.onSuccess : WColor.secondary),
    ],
  );
}

/// Customer rule in three steps: share → 5 washes → free Premium wash.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) {
    Widget step(WIcon icon, String big, String small, {bool reward = false}) => Expanded(
      child: Column(
        children: [
          WIconBox(icon, size: 44, tone: reward ? Tone.ok : Tone.info),
          const Gap(8),
          WText(big, WType.title, align: TextAlign.center),
          const Gap(2),
          WText(small, WType.caption, align: TextAlign.center),
        ],
      ),
    );
    const arrow = Padding(
      padding: EdgeInsets.only(top: 14),
      child: WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
    );
    return WCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step(WIcon.megaphone, 'Share', 'your code'),
          arrow,
          step(WIcon.sparkle, '5 washes', 'by your friend'),
          arrow,
          step(WIcon.gift, '1 free', 'Premium wash', reward: true),
        ],
      ),
    );
  }
}

class _ProgressMilestone extends StatelessWidget {
  const _ProgressMilestone({required this.label, required this.reached});
  final String label;
  final bool reached;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      WIconView(
        reached ? WIcon.check : WIcon.gift,
        size: 18,
        color: reached ? WColor.onSuccess : WColor.secondary,
      ),
      const Gap(9),
      Expanded(
        child: WText(
          label,
          WType.caption,
          color: reached ? WColor.onSuccess : WColor.secondary,
        ),
      ),
    ],
  );
}

/// Optional entry with validation supplied by the host. Does not attach a code
/// until the host has verified identity and calls its authenticated repository.
class ReferralCodeField extends StatelessWidget {
  const ReferralCodeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.error,
    this.language = ReferralLanguage.en,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final ReferralLanguage language;
  @override
  Widget build(BuildContext context) {
    final c = ReferralCopy(language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WText(c.referred, WType.title),
        const Gap(8),
        WTextField(
          label: c.codeLabel,
          value: value,
          placeholder: 'WKRAJU7X',
          caps: TextCapitalization.characters,
          error: error,
          onChanged: onChanged,
        ),
        const Gap(6),
        WText(
          c.t(
            'Skip this if nobody referred you.',
            'किसी ने रेफ़र नहीं किया तो खाली छोड़ें।',
            'ఎవరూ రిఫర్ చేయకపోతే ఖాళీగా వదలండి.',
          ),
          WType.caption,
        ),
      ],
    );
  }
}

/// Local review-only observer. Production host must authenticate the existing
/// reviewer allowlist; never mount this screen as a public admin route.
class ReferralAdminPreviewScreen extends StatelessWidget {
  const ReferralAdminPreviewScreen({
    super.key,
    required this.links,
    required this.rewards,
    required this.onBack,
  });
  final List<ReferralProgress> links;
  final List<ReferralReward> rewards;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => WScreen(
    header: WAppBar(title: 'Referral admin · preview', onLeading: onBack),
    children: [
      const WTitleBlock(
        'Attribution & rewards',
        subtitle: 'Synthetic records. The real private admin is unchanged.',
      ),
      for (final p in links) ...[
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText('${p.role.name} · ${p.name}', WType.title),
              const Gap(8),
              WText('Referrer: ${p.referrerId}', WType.caption),
              WText('Referred: ${p.referredId}', WType.caption),
              WText(
                '${p.completedWashes} qualifying completed washes',
                WType.bodyStrong,
              ),
              const Gap(10),
              for (final r in rewards.where((r) => r.referralId == p.id))
                WText(
                  '${r.milestone} washes · ${r.beneficiaryId} · ${r.kind == RewardKind.cash ? '₹${r.amountPaise ~/ 100}' : '1 Premium wash'} · ${r.state.name}',
                  WType.caption,
                ),
            ],
          ),
        ),
        const Gap(12),
      ],
    ],
  );
}
