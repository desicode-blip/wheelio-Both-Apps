// Money, level and account tabs. Ported from apps/ios/Captain/Screens/MoneyScreens.swift.

import 'package:washkrew_service_recovery/washkrew_service_recovery.dart' show RecoveryCaseCard;
import '../features/preview_features.dart' show ReferralEarningsCard;
import '../features/wash_journey.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/store.dart';
import 'parts.dart';
import 'welcome.dart';

// MARK: W40 Money

class MoneyTab extends StatefulWidget {
  const MoneyTab({super.key});
  @override
  State<MoneyTab> createState() => _MoneyTabState();
}

class _MoneyTabState extends State<MoneyTab> {
  int range = 0;

  Widget _tile(WIcon icon, Tone tone, String big, String small) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WIconView(icon, size: 21, color: tone == Tone.ok ? WColor.heading : tone.foreground),
            const SizedBox(height: 6),
            WText(big, WType.section, weight: semibold, mono: true),
            const SizedBox(height: 6),
            WText(small, WType.caption, color: WColor.heading),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final paid = store.t('Paid', 'भेजा', 'చెల్లించారు');
    return ColoredBox(
      color: WColor.canvas,
      child: ListView(padding: EdgeInsets.fromLTRB(WSpace.gutterCaptain, MediaQuery.paddingOf(context).top, WSpace.gutterCaptain, 20), children: [
        WTitle(store.t('Money', 'पैसे', 'డబ్బు'), top: 22, bottom: 14),
        if (!store.signedUp && !store.isLive) ...[
          GuestNotice(store.t('Example earnings. Your money shows here after your first job, and comes to your UPI every night.', 'उदाहरण कमाई। पहले काम के बाद आपके पैसे यहाँ दिखेंगे और हर रात UPI पर आएंगे।',
              'ఉదాహరణ సంపాదన. మొదటి పని తర్వాత మీ డబ్బు ఇక్కడ కనిపిస్తుంది, ప్రతి రాత్రి UPI కి వస్తుంది.')),
          const SizedBox(height: 14),
        ],
        // v2 (handoff, preview): a "vehicle not found" receipt and referral bonuses,
        // kept apart from wash earnings.
        if (store.v2Features) ...[
          if (store.recoveryStarted) RecoveryCaseCard(repository: store.recovery, captain: true, onOpen: () => router.go(N.recoveryEarnings)),
          // 13 Nov: no sample referral earnings on a live build.
          if (store.referralsLive) ReferralEarningsCard(repository: store.referrals, onOpen: () => router.go(N.referrals)),
          const SizedBox(height: 14),
        ],
        WSegmented(options: [store.t('Today', 'आज', 'ఈరోజు'), store.t('This week', 'इस हफ़्ते', 'ఈ వారం')], selection: range, onChanged: (i) => setState(() => range = i), height: 50),
        const SizedBox(height: 14),
        WCard(
          padding: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(range == 0 ? store.isLive ? store.t('Today’s earnings · payouts confirmed separately', 'आज की कमाई · भुगतान की पुष्टि अलग से होगी', 'ఈరోజు ఆదాయం · చెల్లింపు వేరుగా నిర్ధారిస్తారు') : store.t('Comes to UPI tonight before 12', 'आज रात 12 से पहले UPI में आएगा', 'ఈ రాత్రి 12 లోపు UPI కి వస్తుంది') : store.t('This week so far', 'इस हफ़्ते अब तक', 'ఈ వారం ఇప్పటి వరకు'), WType.caption),
            const SizedBox(height: 10),
            WText(Fmt.rupees(range == 0 ? store.earnedToday : store.isLive ? store.weekMoney.$1 : 4562), WType.bigMoney, mono: true),
            const SizedBox(height: 10),
            Row(children: [
              _tile(WIcon.check, Tone.ok, Fmt.rupees(range == 0 ? store.approvedToday : store.isLive ? store.weekMoney.$2 : 4342), store.t('Approved', 'मंज़ूर', 'ఆమోదించబడింది')),
              const SizedBox(width: 10),
              _tile(WIcon.clock, Tone.wait, Fmt.rupees(range == 0 ? store.waitingToday : store.isLive ? store.weekMoney.$3 : 220), store.t('Waiting', 'इंतज़ार में', 'వేచి ఉంది')),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // Live: payouts are sent by operations (payout history is P0); held money is real.
        if (store.isLive && store.heldEarnings.isNotEmpty)
          WCard(
            padding: 14,
            child: Column(children: [
              for (final (i, e) in store.heldEarnings.indexed) ...[
                if (i > 0) const WDivider(inset: 54),
                WListRow(icon: WIcon.lock, tone: Tone.wait, title: '${store.t('On hold', 'रोका गया', 'నిలిపివేయబడింది')} · ${Fmt.rupees((e['amount'] as num? ?? 0) / 100)}', subtitle: store.t('Owner reported a problem', 'मालिक ने शिकायत की', 'యజమాని సమస్య చెప్పారు'), onTap: () {store.selectedHeldOrderId=e['orderId'];router.go(N.payoutHeld);} ),
              ],
            ]),
          ),
        if(store.isLive&&store.payouts.isNotEmpty)WCard(padding:14,child:Column(children:[for(final (i,p) in store.payouts.indexed)...[if(i>0)const WDivider(inset:54),WListRow(icon:WIcon.receipt,title:'${Fmt.date(p['paidAt'].toDate())} · ${Fmt.rupees((p['amount'] as num) / 100)}',subtitle:'$paid ${Fmt.time(p['paidAt'].toDate())} · ${p['destination']}',onTap:(){store.selectedPayoutId=p['id'];router.go(N.payoutDetail);})]])),
        if (!store.isLive) WCard(
          padding: 14,
          child: Column(children: [
            WListRow(icon: WIcon.receipt, title: '${store.t('Yesterday', 'कल', 'నిన్న')} · ₹1,262', subtitle: '$paid 11:48 PM · ${store.upi}', onTap: () => router.go(N.payoutDetail)),
            const WDivider(inset: 54),
            WListRow(icon: WIcon.receipt, title: '${store.t('Thu', 'गुरु', 'గురు')} · ₹980', subtitle: '$paid 11:52 PM', onTap: () => router.go(N.payoutDetail)),
            const WDivider(inset: 54),
            if (store.noShowCancelled) ...[
              WListRow(
                icon: WIcon.ban,
                tone: Tone.error,
                title: '${store.t('Penalty', 'जुर्माना', 'జరిమానా')} · −₹[NO-SHOW PENALTY]',
                subtitle: '${store.t('Didn’t reach', 'नहीं पहुँचे', 'చేరుకోలేదు')} ${store.noShowPlate} · ${store.t('cut from next payout', 'अगले पेमेंट से कटेगा', 'తదుపరి చెల్లింపు నుండి')}',
                onTap: () => router.go(N.noShowCancelled),
              ),
              const WDivider(inset: 54),
            ],
            WListRow(icon: WIcon.lock, tone: Tone.wait, title: '${store.t('On hold', 'रोका गया', 'నిలిపివేయబడింది')} · ₹116', subtitle: store.t('Owner reported a problem', 'मालिक ने शिकायत की', 'యజమాని సమస్య చెప్పారు'), onTap: () => router.go(N.payoutHeld)),
          ]),
        ),
      ]),
    );
  }
}

// MARK: W41 Payout detail

class PayoutDetailScreen extends StatelessWidget {
  const PayoutDetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final payout=store.selectedPayout;
    if(store.isLive&&payout==null)return const MoneyTab();
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title:store.isLive?Fmt.date(payout!['paidAt'].toDate()):store.t('Fri, 9 Oct', 'शुक्र, 9 अक्टू', 'శుక్ర, 9 అక్టో'), subtitle:store.isLive?'${store.t('Paid','भेज दिया','చెల్లించారు')} ${Fmt.time(payout!['paidAt'].toDate())}':store.t('Paid 11:48 PM', '11:48 PM पर भेजा', '11:48 PM కి చెల్లించారు')),
      children: [
        const SizedBox(height: 14),
        WText('${store.t('Sent to', 'भेजा गया', 'పంపబడింది')} ${store.isLive?payout!['destination']:store.upi}', WType.caption),
        const SizedBox(height: 4),
        WText(store.isLive?Fmt.rupees((payout!['amount'] as num) / 100):'₹1,262', WType.bigMoney, mono: true),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 18),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const ShapeDecoration(color: WColor.successTint, shape: StadiumBorder()),
            child: Row(children: [const WIconView(WIcon.check, size: 12, color: WColor.onSuccess), const SizedBox(width: 8), WText(store.t('Paid', 'भेज दिया', 'చెల్లించారు'), WType.label, color: WColor.onSuccess)]),
          ),
        ),
        WKeyValueCard(rows: [
          (store.isLive?'${(payout!['earningIds'] as List).length} ${store.t('jobs','काम','పనులు')}':store.t('9 jobs', '9 काम', '9 పనులు'), store.isLive?Fmt.rupees((payout!['amount'] as num) / 100):'₹1,290'),
          (store.isLive?store.t('Late (0 jobs)','देरी (0 काम)','ఆలస్యం (0 పనులు)'):store.t('Late (2 jobs)', 'देरी (2 काम)', 'ఆలస్యం (2 పనులు)'), store.isLive?'₹0':'−₹28'),
          (store.t('Total', 'कुल', 'మొత్తం'),store.isLive?Fmt.rupees((payout!['amount'] as num) / 100): '₹1,262'),
        ], boldLast: true),
        const SizedBox(height: 18),
        WText(store.isLive?'${payout!['reference']}':'UPI ref 4410 2219 8830', WType.caption),
      ],
    );
  }
}

// MARK: W42 Money held

class PayoutHeldScreen extends StatelessWidget {
  const PayoutHeldScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final order=store.selectedHeldOrder;
    if(store.isLive&&order==null)return const MoneyTab();
    final amount=store.isLive?Fmt.rupees((order!['captainPayPaise'] as num? ?? 0) / 100):'₹116';
    final reason=(order?['dispute'] as Map?)?['note'] as String? ?? '';
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Money held', 'पैसे रोके गए', 'డబ్బు నిలిపివేయబడింది')),
      footer: WFooter(child: WButton(store.t('Explain by voice', 'आवाज़ में बताएं', 'వాయిస్‌తో వివరించండి'), icon: WIcon.mic, kind: ButtonKind.outline, size: ButtonSize.captain, onTap: ()=>store.explainHeld(context))),
      children: [
        WTitle(store.t('$amount is on hold', '$amount रोके गए हैं', '$amount నిలిపివేయబడింది'), top: 10),
        WBody(store.isLive ? reason : store.t('Owner said the bonnet had water streaks.', 'मालिक ने कहा बोनट पर पानी के निशान थे।', 'బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు.'), top: 6, bottom: 18),
        Row(children: [
          Expanded(child: DesignPhoto(path:order?['evidence']?['before_0']?['path'],height: 96, icon: WIcon.car, tag: store.t('Before', 'पहले', 'ముందు'))),
          const SizedBox(width: 8),
          Expanded(child: DesignPhoto(path:order?['evidence']?['after_0']?['path'],height: 96, icon: WIcon.sparkle, tag: store.t('After', 'बाद', 'తర్వాత'), tagTone: Tone.ok)),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(children: [
              DesignPhoto(path:(order?['dispute']?['photos'] as List?)?.firstOrNull,height: 96, icon: WIcon.image),
              Positioned(left: 0, right: 0, bottom: 14, child: WText(store.t('Owner', 'मालिक', 'యజమాని'), WType.small, align: TextAlign.center)),
            ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: WBanner(tone: Tone.info, icon: WIcon.clock, text: store.t('We decide within 24 hours. Your other jobs are paid as normal.', 'हम 24 घंटे में फ़ैसला करेंगे। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।', '24 గంటల్లో నిర్ణయిస్తాము. మీ ఇతర పనుల డబ్బు మామూలుగానే వస్తుంది.')),
        ),
      ],
    );
  }
}

// MARK: W43 My level

class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget day(int d, String sub) {
      final state = d < store.levelDay ? 0 : (d == store.levelDay ? 1 : 2);
      return Expanded(
        child: Column(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle, color: state == 0 ? WColor.success : state == 1 ? WColor.primary : WColor.primaryTint),
            alignment: Alignment.center,
            child: WIconView(state == 0 ? WIcon.check : WIcon.calendar, size: 22, color: state == 0 ? WColor.onSuccess : state == 1 ? WColor.white : WColor.heading),
          ),
          const SizedBox(height: 6),
          WText(store.t('Day $d', 'दिन $d', 'రోజు $d'), WType.title),
          const SizedBox(height: 6),
          WText(sub, WType.caption),
        ]),
      );
    }

    final jobs = store.t('jobs', 'काम', 'పనులు');
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('My level', 'मेरा लेवल', 'నా స్థాయి')),
      children: [
        const SizedBox(height: 10),
        // v2 CA-JOURNEY: where they are by washes, then the first 3 days (only while
        // they last), the rating and the whole milestone path.
        const WashJourneyCard(),
        const SizedBox(height: 14),
        if (store.inFirstDays) ...[
        WCard(
          padding: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(store.t('New captain: day ${store.levelDay} of 3', 'नए कैप्टन: दिन ${store.levelDay} / 3', 'కొత్త కెప్టెన్: రోజు ${store.levelDay} / 3'), WType.section, weight: semibold),
            const SizedBox(height: 16),
            Row(children: [day(1,store.isLive?(store.levelDay==1&&store.jobLimit>0?'${store.jobLimit} $jobs':'—'):'2 $jobs'),day(2,store.isLive?(store.levelDay==2&&store.jobLimit>0?'${store.jobLimit} $jobs':'—'):'4 $jobs'),day(3,store.isLive?(store.levelDay==3&&store.jobLimit>0?'${store.jobLimit} $jobs':'—'):'6–8')]),
          ]),
        ),
        const SizedBox(height: 14),
        ],
        WCard(
          padding: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(store.t('Your rating', 'आपकी रेटिंग', 'మీ రేటింగ్'), WType.caption),
            const SizedBox(height: 8),
            Row(children: [
              WText(store.rating.toStringAsFixed(1), WType.bigMoney),
              const SizedBox(width: 10),
              for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(right: 4), child: WIconView(i < store.rating.round() ? WIcon.starFill : WIcon.star, size: 20, color: i < store.rating.round() ? WColor.star : WColor.track)),
            ]),
            const SizedBox(height: 8),
            WText(store.isLive?'From ${store.liveCaptain['ratingCount']??0} rated washes':store.t('From 6 washes · keep every wash at 4★ or more', '6 धुलाई से · हर धुलाई 4★ या ज़्यादा रखें', '6 వాష్‌ల నుండి · ప్రతి వాష్ 4★ లేదా ఎక్కువ ఉంచండి'), WType.caption),
          ]),
        ),
        const SizedBox(height: 14),
        const WashJourneyPath(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// MARK: W44 Probation extended

class ProbationScreen extends StatelessWidget {
  const ProbationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget dot(WIcon icon, Color bg, Color fg, String title, String sub) => Expanded(
          child: Column(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), alignment: Alignment.center, child: WIconView(icon, size: 18, color: fg)),
            const SizedBox(height: 6),
            WText(title, WType.label, color: WColor.heading),
            const SizedBox(height: 6),
            WText(sub, WType.caption),
          ]),
        );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      footer: store.trainingEnabled ? WFooter(child: WButton(store.t('Watch 30-sec tip', '30 सेकंड की टिप देखें', '30 సెకన్ల చిట్కా చూడండి'), icon: WIcon.play, kind: ButtonKind.outline, size: ButtonSize.captain, onTap: () => context.router.go(N.refresher))) : null,
      children: [
        const Spacer(),
        const Center(child: WStateCircle(WIcon.calendar, tone: Tone.wait, size: 112)),
        const SizedBox(height: 14),
        WText(store.isLive?(store.jobLimit>0?'Daily limit: ${store.jobLimit} jobs':'Work limits awaiting review'):store.t('1 more day at 4 jobs', '4 काम पर 1 दिन और', '4 పనులతో ఇంకో 1 రోజు'), WType.section, weight: semibold, size: 23, align: TextAlign.center),
        const SizedBox(height: 14),
        WBody(
            store.t('One owner gave 3★: “Mirror was dusty.” Get 4★ or more on all jobs tomorrow to move up.', 'एक मालिक ने 3★ दिए: “शीशे पर धूल थी।” कल सभी कामों पर 4★ या ज़्यादा लें तो आगे बढ़ेंगे।',
                'ఒక యజమాని 3★ ఇచ్చారు: “అద్దం దుమ్ముగా ఉంది.” రేపు అన్ని పనులకు 4★ పైన వస్తే ముందుకు వెళ్తారు.'),
            center: true),
        const SizedBox(height: 22),
        Row(children: [
          dot(WIcon.check, WColor.success, WColor.onSuccess, store.t('Day 1', 'दिन 1', 'రోజు 1'), '2'),
          dot(WIcon.close, WColor.destructive, WColor.white, store.t('Day 2', 'दिन 2', 'రోజు 2'), '4'),
          dot(WIcon.calendar, WColor.primary, WColor.white, store.t('Day 2', 'दिन 2', 'రోజు 2'), '4'),
          dot(WIcon.calendar, WColor.primaryTint, WColor.heading, store.t('Day 3', 'दिन 3', 'రోజు 3'), '6–8'),
        ]),
        const Spacer(),
      ],
    );
  }
}

// MARK: W45 Refresher video

class RefresherScreen extends StatelessWidget {
  const RefresherScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: 0,
      header: WHeader(title: store.t('New tip', 'नई टिप', 'కొత్త చిట్కా'), back: false, help: false),
      footer: WFooter(child: WButton(store.t('Play', 'चलाएं', 'ప్లే చేయండి'), icon: WIcon.play, size: ButtonSize.captain, onTap: () => context.router.replace(const [R(N.video, index: 2)]))),
      children: [
        Container(
          height: 202,
          color: WColor.camera,
          alignment: Alignment.center,
          child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.play, size: 26, color: WColor.white)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WTitle(store.t('Mirrors and number plate', 'शीशे और नंबर प्लेट', 'అద్దాలు, నంబర్ ప్లేట్')),
            WBody(store.t('30 seconds. Watch it fully to get jobs again.', '30 सेकंड। पूरा देखें, फिर काम मिलेंगे।', '30 సెకన్లు. పూర్తిగా చూస్తే మళ్ళీ పనులు వస్తాయి.'), top: 8),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: WColor.waitTint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const WIconView(WIcon.lock, size: 15, color: WColor.waitText),
                const SizedBox(width: 10),
                Expanded(child: WText(store.t('New jobs are paused until you watch.', 'देखने तक नए काम रुके हैं।', 'చూసే వరకు కొత్త పనులు ఆగాయి.'), WType.caption, color: WColor.waitText, size: 14.5)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

// MARK: W46 Blocked

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(gutter: WSpace.gutterCaptain, scrolls: false, children: [
      const Spacer(),
      const Center(child: WStateCircle(WIcon.ban, tone: Tone.error, size: 112)),
      const SizedBox(height: 14),
      WText(store.t('You can’t take jobs now', 'अभी आप काम नहीं ले सकते', 'ఇప్పుడు మీరు పనులు తీసుకోలేరు'), WType.section, weight: semibold, size: 23, align: TextAlign.center),
      const SizedBox(height: 14),
      WBody(
          store.isLive?store.liveCaptain['workStatusReason'] as String? ?? 'New jobs are paused pending review.':store.t('Too many low ratings in the last 2 weeks. If you think this is wrong, ask us to check again.', 'पिछले 2 हफ़्तों में बहुत कम रेटिंग। अगर यह गलत है, तो हमसे फिर जाँचने को कहें।',
              'గత 2 వారాల్లో చాలా తక్కువ రేటింగ్‌లు. ఇది తప్పు అనుకుంటే మళ్ళీ తనిఖీ చేయమని అడగండి.'),
          center: true),
      const SizedBox(height: 20),
      WButton(store.t('Ask to check again', 'फिर से जाँच का अनुरोध', 'మళ్ళీ తనిఖీ చేయమని అడగండి'), icon: WIcon.mic, kind: ButtonKind.outline, size: ButtonSize.captain, onTap: () async {if(!store.isLive)return;try{final result=await store.live!.call('createSupportRequest',{'role':'captain','requestId':'work-review-${DateTime.now().millisecondsSinceEpoch}','kind':'other','note':'Captain requests a review of their work restriction.'});store.set(()=>store.toast='Review request saved. Reference: ${result['reference'] ?? result['requestId']}');}catch(e){store.set(()=>store.toast=backendError(e));}}),
      const SizedBox(height: 14),
      WText(store.isLive?'Pending earnings: ${Fmt.rupees(store.weekMoney.$2+store.weekMoney.$3)}. Operations can confirm the payout.':store.t('Your pending money (₹464) will still be paid.', 'आपके बाकी पैसे (₹464) फिर भी मिलेंगे।', 'మీ బాకీ డబ్బు (₹464) చెల్లిస్తాము.'), WType.caption, align: TextAlign.center),
      const Spacer(),
    ]);
  }
}

// MARK: W47 Me

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final header = store.registered
        ? Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Row(children: [
              const WProfilePhoto(size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WText(store.name, WType.section, weight: semibold, size: 22),
                  const SizedBox(height: 2),
                  WText(store.signedUp ? '${Fmt.phoneShort(store.phone)} · ★ ${store.rating.toStringAsFixed(1)}' : Fmt.phoneShort(store.phone), WType.caption),
                ]),
              ),
            ]),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 22),
            child: WCard(
              padding: 18,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(width: 60, height: 60, decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.user, size: 24, color: WColor.secondary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      WText(store.t('You’re looking around', 'आप ऐप देख रहे हैं', 'మీరు యాప్ చూస్తున్నారు'), WType.section, weight: semibold, size: 20),
                      const SizedBox(height: 2),
                      WText(store.t('Sign up with your name and number', 'नाम और नंबर से साइन अप करें', 'పేరు, నంబర్‌తో సైన్ అప్'), WType.caption),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                WButton(store.t('Sign up', 'साइन अप करें', 'సైన్ అప్'), size: ButtonSize.captain, onTap: () => router.push(const R(N.signUp))),
                const SizedBox(height: 12),
                Center(child: WLink(store.t('Already a captain? Log in', 'पहले से कैप्टन हैं? लॉग इन करें', 'ఇప్పటికే కెప్టెన్‌నా? లాగిన్'), onTap: () => router.push(const R(N.signUp, flag: true)))),
              ]),
            ),
          );

    final notifSubtitle = !store.notificationsOn ? store.t('Off', 'बंद', 'ఆఫ్') : (store.notifPrefs.isMuted ? store.t('Muted', 'म्यूट', 'మ్యూట్') : store.t('On', 'चालू', 'ఆన్'));
    return ColoredBox(
      color: WColor.canvas,
      child: ListView(padding: EdgeInsets.fromLTRB(WSpace.gutterCaptain, MediaQuery.paddingOf(context).top, WSpace.gutterCaptain, 20), children: [
        header,
        if (store.registered && !store.signedUp) ...[
          const SizedBox(height: 14),
          WCard(
            padding: 14,
            onTap: () {
              store.set(() => store.kycFromJob = false);
              router.push(const R(N.steps));
            },
            child: Row(children: [
              const WIconBox(WIcon.idCard, size: 44, tone: Tone.wait),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WText(store.t('Finish KYC', 'KYC पूरा करें', 'KYC పూర్తి చేయండి'), WType.title, size: 17),
                  const SizedBox(height: 2),
                  WText('${store.kycStagesDone}/4 · ${store.t('Needed to take jobs', 'काम लेने के लिए ज़रूरी', 'పనులు తీసుకోవడానికి అవసరం')}', WType.caption),
                ]),
              ),
              const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        WCard(
          padding: 14,
          child: Column(children: [
            WListRow(icon: WIcon.location, title: store.t('Where I work', 'मैं कहाँ काम करूँ', 'నేను ఎక్కడ పని చేస్తాను'), subtitle: store.workSummary, onTap: () => router.go(N.workArea)),
            const WDivider(inset: 54),
            WListRow(icon: WIcon.languages, title: store.t('Language', 'भाषा', 'భాష'), subtitle: store.langName, onTap: () => showWSheet<void>(context, height: 380, gutter: WSpace.gutterCaptain, builder: (_) => const LanguageSheet())),
            if (store.registered) ...[
              const WDivider(inset: 54),
              WListRow(icon: WIcon.phone, title: store.t('Phone number', 'फ़ोन नंबर', 'ఫోన్ నంబర్'), subtitle: Fmt.phone(store.phone), onTap: () => router.go(N.changePhone)),
              const WDivider(inset: 54),
              WListRow(icon: store.notificationsOn ? WIcon.bell : WIcon.bellSlash, title: store.t('Notifications', 'सूचनाएं', 'నోటిఫికేషన్లు'), subtitle: notifSubtitle, onTap: () => router.go(N.notificationSettings)),
            ],
            if (store.signedUp) ...[
              const WDivider(inset: 54),
              WListRow(icon: WIcon.rupee, title: store.t('Payout UPI', 'पेमेंट UPI', 'చెల్లింపు UPI'), subtitle: store.upi, onTap: () => router.go(N.editUPI)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.star, title: store.t('My level', 'मेरा लेवल', 'నా స్థాయి'), subtitle: store.levelSummary, onTap: () => router.go(N.level)),
            ],
            if(store.trainingEnabled) ...[
              const WDivider(inset: 54),
              WListRow(icon: WIcon.play, title: store.t('Training videos', 'ट्रेनिंग वीडियो', 'శిక్షణ వీడియోలు'), onTap: () => router.go(N.training)),
            ],
            const WDivider(inset: 54),
            WListRow(icon: WIcon.sparkle, title: store.t('Why wash with ${Brand.name}', '${Brand.name} के साथ क्यों', '${Brand.name} తో ఎందుకు'), onTap: () => router.go(N.welcome)),
          ]),
        ),
        const SizedBox(height: 14),
        WCard(
          padding: 14,
          child: Column(children: [
            WListRow(icon: WIcon.help, title: store.t('Help', 'मदद', 'సహాయం'), onTap: () => router.go(N.help)),
            if (store.registered) ...[
              const WDivider(inset: 54),
              WListRow(
                icon: WIcon.logout,
                title: store.t('Log out', 'लॉग आउट', 'లాగ్ అవుట్'),
                // 13 Nov (Aman): confirm, loader, first screen, "Logged out" toast.
                onTap: () => confirmLogOut(
                  context,
                  logOut: store.logOut,
                  then: router.home,
                  title: store.t('Log out?', 'लॉग आउट करें?', 'లాగ్ అవుట్ చేయాలా?'),
                  message: store.t('You’ll go offline and this session ends on this phone.', 'आप ऑफ़लाइन हो जाएंगे और इस फ़ोन पर सेशन खत्म होगा।', 'మీరు ఆఫ్‌లైన్ అవుతారు, ఈ ఫోన్‌లో సెషన్ ముగుస్తుంది.'),
                  confirm: store.t('Log out', 'लॉग आउट', 'లాగ్ అవుట్'),
                  cancel: store.t('Cancel', 'रद्द करें', 'రద్దు'),
                  busy: store.t('Logging out…', 'लॉग आउट हो रहा है…', 'లాగ్ అవుట్ అవుతోంది…'),
                  done: store.t('Logged out', 'लॉग आउट हो गया', 'లాగ్ అవుట్ అయింది'),
                ),
              ),
              const WDivider(inset: 54),
              WListRow(
                icon: WIcon.trash,
                tone: Tone.error,
                title: store.t('Delete account', 'अकाउंट हटाएं', 'ఖాతాను తొలగించండి'),
                onTap: () async {
                  final gone = await showDeleteAccountDialog(
                    context,
                    size: ButtonSize.captain,
                    text: DeleteAccountText(
                      title: store.t('Delete your account?', 'अपना अकाउंट हटाएं?', 'మీ ఖాతాను తొలగించాలా?'),
                      message: store.t(
                        'Your profile, KYC documents and job history go with it. You can’t do this while you have a job in progress.',
                        'आपकी प्रोफ़ाइल, KYC दस्तावेज़ और काम का इतिहास भी हट जाएगा। कोई काम चल रहा हो तो आप ऐसा नहीं कर सकते।',
                        'మీ ప్రొఫైల్, KYC పత్రాలు, పనుల చరిత్ర కూడా తొలగిపోతాయి. ఏదైనా పని జరుగుతుంటే మీరు ఇది చేయలేరు.',
                      ),
                      delete: store.isLive ? store.t('Yes, continue', 'हाँ, आगे बढ़ें', 'అవును, కొనసాగించు') : store.t('Delete account', 'अकाउंट हटाएं', 'ఖాతాను తొలగించండి'),
                      keep: store.t('Keep my account', 'अकाउंट रखें', 'ఖాతాను ఉంచండి'),
                    ),
                    finalConfirmation: store.isLive ? DeleteAccountText(
                      title: store.t('Are you absolutely sure?', 'क्या आप बिल्कुल पक्का हैं?', 'మీరు ఖచ్చితంగా నిర్ణయించుకున్నారా?'),
                      message: store.t(
                        'Your Captain profile, KYC documents and saved work settings will be removed. This cannot be undone. Payment records are kept separately. Your Customer account stays.',
                        'आपकी कैप्टन प्रोफ़ाइल, KYC दस्तावेज़ और काम की सेटिंग हट जाएंगी। यह वापस नहीं हो सकता। पेमेंट रिकॉर्ड अलग से रखे जाते हैं। आपका Customer अकाउंट रहेगा।',
                        'మీ Captain ప్రొఫైల్, KYC పత్రాలు, పని సెట్టింగ్‌లు తొలగిపోతాయి. దీన్ని రద్దు చేయలేరు. చెల్లింపు రికార్డులు వేరుగా ఉంచబడతాయి. మీ Customer ఖాతా ఉంటుంది.',
                      ),
                      delete: store.t('Delete account', 'अकाउंट हटाएं', 'ఖాతాను తొలగించండి'),
                      keep: store.t('Keep my account', 'अकाउंट रखें', 'ఖాతాను ఉంచండి'),
                    ) : null,
                    delete: store.deleteAccount,
                  );
                  if (gone) router.home();
                },
              ),
            ],
          ]),
        ),
        // v2 (12 Nov): standard features. Sample data until the server parts are live.
        if (store.v2Features) ...[
          const SizedBox(height: 14),
          WCard(
            padding: 14,
            child: Column(children: [
              ComingSoonGate(
                available: store.referralsLive,
                feature: store.t('Referrals', 'रेफ़रल', 'రెఫరల్స్'),
                child: WListRow(icon: WIcon.gift, title: store.t('Refer a Captain', 'कैप्टन को बुलाएँ', 'కెప్టెన్‌ను ఆహ్వానించండి'), subtitle: store.referralsLive ? '${store.t('Your code', 'आपका कोड', 'మీ కోడ్')}: ${store.referrals.identity.code}' : store.t('Coming soon', 'जल्द आ रहा है', 'త్వరలో'), onTap: () => router.go(N.referrals)),
              ),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.rupee, title: store.t('Understand your pay', 'अपनी कमाई समझें', 'మీ ఆదాయాన్ని తెలుసుకోండి'), onTap: () => router.go(N.payGuide)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.calendar, title: store.t('Recurring assignments', 'नियमित काम', 'క్రమమైన పనులు'), subtitle: store.recurringAccepted ? store.t('${store.myAssignments.length} active', '${store.myAssignments.length} चालू', '${store.myAssignments.length} చురుకుగా') : store.t('Your monthly jobs', 'आपके मासिक काम', 'మీ నెలవారీ పనులు'), onTap: () => router.go(N.recurringList)),
            ]),
          ),
        ],
        // Review tools only (7 taps on the name below): sample outcomes for checking screens.
        if (store.previewFeatures) ...[
          const SizedBox(height: 14),
          const WText('Review tools', WType.caption),
          const SizedBox(height: 8),
          WCard(
            padding: 14,
            child: Column(children: [
              WListRow(icon: WIcon.check, title: 'Job offer pay', subtitle: 'One-time and monthly-plan visit', onTap: () => router.go(N.offerTermsPreview)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.car, title: 'Vehicle not found', subtitle: 'Check, contact, record, send proof', onTap: () => router.go(N.recovery)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.close, title: 'Cancel a wash', subtitle: 'Reason and exact deduction before confirming', onTap: () => router.push(const R(N.recovery, flag: true))),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.sparkle, title: 'Review outcomes', subtitle: 'Approve, ask for proof, dispute, replacement', onTap: () => router.go(N.recoveryScenarios)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.star, title: 'Referral progress', subtitle: 'Try milestones', onTap: () => router.go(N.referralScenarios)),
              const WDivider(inset: 54),
              WListRow(icon: WIcon.shield, title: 'Admin referral view', subtitle: 'Read-only, sample data', onTap: () => router.go(N.referralAdmin)),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        const _PreviewSwitch(),
      ]),
    );
  }
}

/// v2: tap "WashKrew Captain" 7 times to try the handoff features on this phone.
class _PreviewSwitch extends StatefulWidget {
  const _PreviewSwitch();
  @override
  State<_PreviewSwitch> createState() => _PreviewSwitchState();
}

class _PreviewSwitchState extends State<_PreviewSwitch> {
  int taps = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (++taps < 7) return;
          taps = 0;
          final on = !store.previewFeatures;
          store.setPreviewFeatures(on);
          store.set(() => store.toast = on ? 'Review tools: on' : 'Review tools: off');
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: WText(store.previewFeatures ? '${Brand.captainApp} · review tools on' : Brand.captainApp, WType.caption),
        ),
      ),
    );
  }
}

// MARK: W48 Help

class WHelpScreen extends StatelessWidget {
  const WHelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    Widget row(WIcon icon, String title, VoidCallback onTap, {bool emergency = false}) => Pressable(
          onTap: onTap,
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: outlinedDecoration(radius: 16, fill: emergency ? WColor.errorTint : WColor.white, stroke: emergency ? WColor.destructive.withValues(alpha: 0.4) : WColor.border),
            child: Row(children: [
              WIconBox(icon, size: 52, tone: emergency ? Tone.error : Tone.info),
              const SizedBox(width: 16),
              Expanded(child: WText(title, WType.value, color: emergency ? WColor.destructive : WColor.heading, size: 18)),
              WIconView(emergency ? WIcon.phone : WIcon.chevron, size: emergency ? 18 : 13, color: emergency ? WColor.destructive : WColor.secondary),
            ]),
          ),
        );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Help', 'मदद', 'సహాయం'), help: false),
      children: [
        WTitle(store.t('What’s the problem?', 'क्या समस्या है?', 'సమస్య ఏమిటి?'), top: 10),
        WBody(store.t('Most problems get fixed in a minute.', 'ज़्यादातर समस्याएं एक मिनट में ठीक होती हैं।', 'చాలా సమస్యలు ఒక్క నిమిషంలో తీరుతాయి.'), top: 4, bottom: 14),
        const Padding(padding: EdgeInsets.only(bottom: 18), child: HelpLadder(current: 0)),
        for (final t in HelpTopic.values) ...[
          row(helpTopicIcon(t), helpTopicTitle(t, store), () => router.push(R(N.helpFlow, topic: t))),
          const SizedBox(height: 12),
        ],
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: WText(store.t('Emergency', 'इमरजेंसी', 'అత్యవసరం'), WType.label)),
        row(WIcon.warning, store.t('Accident, injury or safety', 'दुर्घटना, चोट या सुरक्षा', 'ప్రమాదం, గాయం లేదా భద్రత'), () => Support.call(), emergency: true),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: WText(store.t('Only for emergencies. Works 24 hours.', 'सिर्फ़ इमरजेंसी के लिए। 24 घंटे चालू।', 'అత్యవసరాలకు మాత్రమే. 24 గంటలు.'), WType.caption),
        ),
      ],
    );
  }
}

// MARK: Language picker (Me → Language)

/// All languages at once; tap one to choose it.
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    void close() => Future.delayed(const Duration(milliseconds: 250), () {
          if (context.mounted) Navigator.of(context).pop();
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(top: 10, bottom: 16), child: WText(store.t('Choose your language', 'भाषा चुनें', 'భాష ఎంచుకోండి'), WType.section, weight: semibold, size: 21)),
      LangTile(lang: Lang.en, glyph: 'A', title: 'English', height: 72, onPick: close),
      const SizedBox(height: 12),
      LangTile(lang: Lang.hi, glyph: 'अ', title: 'हिन्दी · Hindi', height: 72, onPick: close),
      const SizedBox(height: 12),
      LangTile(lang: Lang.te, glyph: 'అ', title: 'తెలుగు · Telugu', height: 72, onPick: close),
    ]);
  }
}
