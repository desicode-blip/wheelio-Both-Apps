import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';

// v2 CA-JOURNEY (12 Nov 2026, Aman): after the first 3 days, My level shows a journey
// by completed washes (50 → 100 → 500 → 1000 → 2000). 50 is a badge only; 100 is a
// surprise merchandise reward; later rewards are not decided yet, so they say so.
// Milestones are configuration: the server can replace them through
// `config.captainMilestones` = [{washes, title, reward?}], without an app update.

class WashMilestone {
  const WashMilestone(this.washes, this.title, {this.reward});
  final int washes;
  final String title;

  /// Null: no reward (a badge only). Empty: reward not decided yet.
  final String? reward;
}

const defaultWashMilestones = [
  WashMilestone(50, 'Rising Captain'),
  WashMilestone(100, 'Trusted Captain', reward: 'Surprise WashKrew merchandise'),
  WashMilestone(500, 'Pro Captain', reward: ''),
  WashMilestone(1000, 'Star Captain', reward: ''),
  WashMilestone(2000, 'Legend Captain', reward: ''),
];

extension WashJourneyStore on CaptainStore {
  /// Lifetime completed washes (server field `completedWashes`).
  int get completedWashes => isLive ? (liveCaptain['completedWashes'] as num? ?? 0).toInt() : 37;

  /// Still in the first 3 days (admin hasn't moved the Captain to active work yet).
  bool get inFirstDays => isLive ? liveCaptain['workStatus'] != 'active' : levelDay <= 3;

  /// Short line for the Me tab: "Day 2 of 3" or "37 washes · next 50".
  String get levelSummary {
    if (inFirstDays) return t('Day $levelDay of 3', 'दिन $levelDay / 3', 'రోజు $levelDay / 3');
    final next = washMilestones.where((m) => m.washes > completedWashes).firstOrNull;
    return next == null
        ? t('$completedWashes washes', '$completedWashes धुलाई', '$completedWashes వాష్‌లు')
        : t(
            '$completedWashes washes · next ${next.washes}',
            '$completedWashes धुलाई · अगला ${next.washes}',
            '$completedWashes వాష్‌లు · తదుపరి ${next.washes}',
          );
  }

  List<WashMilestone> get washMilestones {
    final raw = liveConfig['captainMilestones'];
    if (raw is! List || raw.isEmpty) return defaultWashMilestones;
    final list = [
      for (final m in raw)
        if (m is Map && m['washes'] is num && m['title'] is String)
          WashMilestone((m['washes'] as num).toInt(), m['title'] as String, reward: m['reward'] as String?),
    ]..sort((a, b) => a.washes.compareTo(b.washes));
    return list.isEmpty ? defaultWashMilestones : list;
  }
}

/// The big "where am I" card: washes done, what's next and a bar to it.
class WashJourneyCard extends StatelessWidget {
  const WashJourneyCard({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, done = store.completedWashes, ms = store.washMilestones;
    final next = ms.where((m) => m.washes > done).firstOrNull;
    final prev = ms.lastWhere((m) => m.washes <= done, orElse: () => const WashMilestone(0, ''));
    final left = next == null ? 0 : next.washes - done;
    final fraction = next == null ? 1.0 : ((done - prev.washes) / (next.washes - prev.washes)).clamp(0.0, 1.0);
    return WCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WText(store.t('Your washes', 'आपकी धुलाई', 'మీ వాష్‌లు'), WType.caption),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              WText('$done', WType.bigMoney),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WText(prev.title.isEmpty ? store.t('New captain', 'नए कैप्टन', 'కొత్త కెప్టెన్') : prev.title, WType.title, color: WColor.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(minHeight: 10, value: v, backgroundColor: WColor.track, color: WColor.primary),
            ),
          ),
          const SizedBox(height: 10),
          WText(
            next == null
                ? store.t('Every milestone reached', 'सारे पड़ाव पूरे', 'అన్ని మైలురాళ్లు పూర్తి')
                : store.t('$left more to ${next.washes} washes', '${next.washes} धुलाई तक $left और', '${next.washes} వాష్‌లకు ఇంకా $left'),
            WType.valueStrong,
          ),
          if (next != null && next.reward != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const WIconView(WIcon.gift, size: 16, color: WColor.secondary),
                const SizedBox(width: 6),
                Expanded(child: WText(next.reward!.isEmpty ? store.t('Reward coming soon', 'इनाम जल्द', 'రివార్డు త్వరలో') : next.reward!, WType.caption)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Every milestone as a vertical path: reached (green tick), next (blue), later (grey).
class WashJourneyPath extends StatelessWidget {
  const WashJourneyPath({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, done = store.completedWashes, ms = store.washMilestones;
    final nextIndex = ms.indexWhere((m) => m.washes > done);
    return WCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WText(store.t('Your journey', 'आपका सफ़र', 'మీ ప్రయాణం'), WType.section, weight: FontWeight.w600),
          const SizedBox(height: 14),
          for (final (i, m) in ms.indexed)
            _Stop(
              milestone: m,
              state: m.washes <= done
                  ? _S.reached
                  : i == nextIndex
                  ? _S.next
                  : _S.later,
              last: i == ms.length - 1,
            ),
        ],
      ),
    );
  }
}

enum _S { reached, next, later }

class _Stop extends StatelessWidget {
  const _Stop({required this.milestone, required this.state, required this.last});
  final WashMilestone milestone;
  final _S state;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final store = context.store, m = milestone;
    final (bg, fg, icon) = switch (state) {
      _S.reached => (WColor.success, WColor.onSuccess, WIcon.check),
      _S.next => (WColor.primary, WColor.white, WIcon.flag),
      _S.later => (WColor.primaryTint, WColor.secondary, WIcon.lock),
    };
    final reward = m.reward == null
        ? store.t('Badge', 'बैज', 'బ్యాడ్జ్')
        : m.reward!.isEmpty
        ? store.t('Reward coming soon', 'इनाम जल्द', 'రివార్డు త్వరలో')
        : m.reward!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: WIconView(icon, size: 18, color: fg),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 4), color: state == _S.reached ? WColor.success : WColor.track),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: last ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      WText('${m.washes} ${store.t('washes', 'धुलाई', 'వాష్‌లు')}', WType.title, color: state == _S.later ? WColor.secondary : WColor.heading),
                      if (state == _S.next) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(10)),
                          child: WText(store.t('Next', 'अगला', 'తదుపరి'), WType.label, color: WColor.primary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  WText(m.title, WType.caption),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      WIconView(m.reward == null ? WIcon.starFill : WIcon.gift, size: 15, color: state == _S.reached ? WColor.onSuccess : WColor.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: WText(
                          state == _S.reached ? '${store.t('Reached', 'पूरा', 'పూర్తి')} · $reward' : reward,
                          WType.caption,
                          color: state == _S.reached ? WColor.onSuccess : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
