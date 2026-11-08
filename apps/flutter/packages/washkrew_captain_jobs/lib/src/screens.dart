import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'model.dart';

class VisitTermsCard extends StatelessWidget {
  const VisitTermsCard({
    super.key,
    required this.terms,
    this.language = CaptainLanguage.en,
    this.onListen,
    this.compact = false,
  });
  final VisitTerms terms;
  final CaptainLanguage language;
  final VoidCallback? onListen;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = CaptainJobCopy(language);
    return WCard(
      outlined: true,
      padding: compact ? 14 : 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WBadge(
            c.booking(terms.kind),
            icon: terms.kind == VisitBookingKind.monthlyPlan
                ? WIcon.calendar
                : WIcon.drop,
          ),
          const Gap(12),
          WText('${terms.service} · ${terms.coverage}', WType.title, size: 17),
          const Gap(8),
          Row(
            children: [
              const WIconView(WIcon.clock, size: 20),
              const Gap(8),
              WText(
                c.t(
                  'About ${terms.estimatedMinutes} min',
                  'लगभग ${terms.estimatedMinutes} मिनट',
                  'సుమారు ${terms.estimatedMinutes} నిమిషాలు',
                ),
                WType.bodyStrong,
              ),
            ],
          ),
          if (terms.kind == VisitBookingKind.monthlyPlan &&
              terms.visitNumber != null) ...[
            const Gap(6),
            WText(
              c.t(
                'Visit ${terms.visitNumber} of ${terms.totalVisits}',
                '${terms.totalVisits} में वॉश ${terms.visitNumber}',
                '${terms.totalVisits}లో వాష్ ${terms.visitNumber}',
              ),
              WType.caption,
            ),
          ],
          const Gap(14),
          if(terms.illustrative)...[WText(c.t('Example pay · Not an approved rate','उदाहरण · तय दर नहीं','ఉదాహరణ · ఆమోదించిన ధర కాదు'),WType.caption),const Gap(6)],
          WText(c.yourPay, WType.caption),
          const Gap(4),
          Row(
            children: [
              Expanded(
                child: WText(
                  terms.payLabel,
                  compact ? WType.screen : WType.bigMoney,
                  mono: true,
                ),
              ),
              if (onListen != null)
                WIconButton(
                  WIcon.speaker,
                  size: 64,
                  style: IconButtonStyle.tint,
                  label: c.listen,
                  onTap: onListen,
                ),
            ],
          ),
          if (!terms.hasConfirmedPay) ...[
            const Gap(8),
            WText(
              c.t(
                'Pay is not confirmed. Do not accept yet.',
                'कमाई तय नहीं है। अभी स्वीकार न करें।',
                'ఆదాయం ఖరారు కాలేదు. ఇంకా అంగీకరించవద్దు.',
              ),
              WType.bodyStrong,
              color: WColor.destructive,
            ),
          ] else if (!compact) ...[
            const Gap(8),
            WText(
              c.t(
                'This is for one visit, not the full monthly plan.',
                'यह एक वॉश की कमाई है, पूरे महीने की नहीं।',
                'ఇది ఒక వాష్‌కు మాత్రమే, నెల మొత్తానికి కాదు.',
              ),
              WType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Accessible learning outside the timed offer. Payout amounts are explicitly
/// examples until an approved server payout policy is supplied.
class CaptainPayGuideScreen extends StatelessWidget {
  const CaptainPayGuideScreen({
    super.key,
    required this.oneTime,
    required this.monthly,
    required this.onBack,
    this.language = CaptainLanguage.en,
  });
  final VisitTerms oneTime, monthly;
  final VoidCallback onBack;
  final CaptainLanguage language;
  @override
  Widget build(BuildContext context) {
    final c = CaptainJobCopy(language);
    return WScreen(
      gutter: 16,
      header: WAppBar(
        title: c.t(
          'Understand your pay',
          'अपनी कमाई समझें',
          'మీ ఆదాయాన్ని తెలుసుకోండి',
        ),
        onLeading: onBack,
      ),
      children: [
        WTitleBlock(
          c.t(
            'Same clean. Clear pay.',
            'एक जैसा वॉश। साफ़ कमाई।',
            'ఒకే శుభ్రత. స్పష్టమైన ఆదాయం.',
          ),
          subtitle: c.t(
            'Check the amount before you accept each job.',
            'हर काम लेने से पहले कमाई देखें।',
            'ప్రతి పని అంగీకరించే ముందు మొత్తాన్ని చూడండి.',
          ),
        ),
        VisitTermsCard(
          terms: oneTime,
          language: language,
          onListen: () => _listen(oneTime, c),
        ),
        const Gap(14),
        VisitTermsCard(
          terms: monthly,
          language: language,
          onListen: () => _listen(monthly, c),
        ),
        const Gap(18),
        WCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText(
                c.t(
                  'What stays the same',
                  'क्या एक जैसा है',
                  'ఏవి ఒకేలా ఉంటాయి',
                ),
                WType.title,
              ),
              const Gap(8),
              WText(
                c.t(
                  'The selected cleaning checklist and expected time. A monthly visit is not a lighter clean.',
                  'चुने गए वॉश का काम और समय। महीने के प्लान में कम सफ़ाई नहीं करनी है।',
                  'ఎంచుకున్న శుభ్రత పనులు, సమయం. నెలవారీ వాష్‌లో తక్కువ శుభ్రత కాదు.',
                ),
                WType.bodyStrong,
              ),
              const Gap(12),
              WText(
                c.t('What can differ', 'क्या बदल सकता है', 'ఏవి మారవచ్చు'),
                WType.title,
              ),
              const Gap(8),
              WText(
                c.t(
                  'The pay for each visit. Read the exact amount shown on the offer. Referral rewards are separate.',
                  'हर वॉश की कमाई। ऑफर पर दिखी रकम देखें। रेफ़रल इनाम अलग हैं।',
                  'ప్రతి వాష్ ఆదాయం. ఆఫర్‌లో చూపిన మొత్తాన్ని చూడండి. రిఫరల్ రివార్డులు వేరు.',
                ),
                WType.bodyStrong,
              ),
            ],
          ),
        ),
        const Gap(16),
        const WText(
          'Illustrative pay only. Actual payout rates and any route/travel allowance are not approved yet.',
          WType.caption,
        ),
      ],
    );
  }

  void _listen(VisitTerms t, CaptainJobCopy c) {
    Device.speak(
      '${c.booking(t.kind)}. ${t.service}. ${t.coverage}. ${c.yourPay}: ${t.payLabel}. ${t.estimatedMinutes} minutes.',
      switch (language) {
        CaptainLanguage.en => 'en-IN',
        CaptainLanguage.hi => 'hi-IN',
        CaptainLanguage.te => 'te-IN',
      },
      () {},
    );
  }
}
