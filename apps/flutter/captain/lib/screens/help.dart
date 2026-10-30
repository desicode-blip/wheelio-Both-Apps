// Support ladder (quick check → owner → our team) and "Where I work".
// Ported from apps/ios/Captain/Screens/HelpFlowScreens.swift and WorkAreaScreen.swift.
// There is no "call us" button up front. Only safety emergencies call directly.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/store.dart';
import 'home.dart' show playWorkProfileLanding;
import 'parts.dart';

/// App problems skip the owner step.
bool _usesOwner(HelpTopic t) => t != HelpTopic.app;

class HelpFlowScreen extends StatefulWidget {
  const HelpFlowScreen({super.key, required this.topic});
  final HelpTopic topic;
  @override
  State<HelpFlowScreen> createState() => _HelpFlowScreenState();
}

class _HelpFlowScreenState extends State<HelpFlowScreen> {
  int level = 1;
  bool checking = true;
  int? jobIssue;
  String? sentMessage;
  bool callbackRequested = false;
  bool solved = false;

  @override
  void initState() {
    super.initState();
    // Step 1: the app checks first (photos, payouts, job status).
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => checking = false);
    });
  }

  Widget _label(String text) => WText(text, WType.label, color: WColor.secondary);

  Widget _result(WIcon icon, Tone tone, String title, String text) => FadeIn(
        offset: 0,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WIconView(icon, size: 20, color: tone == Tone.ok ? WColor.onSuccess : tone.bannerText),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(title, WType.title, size: 18), const SizedBox(height: 6), WText(text, WType.body, size: 15.5)])),
          ]),
        ),
      );

  Widget _photoCompare() {
    final store = context.store;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Expanded(child: WPhotoPlaceholder(height: 92, icon: WIcon.car, tag: store.t('Before', 'पहले', 'ముందు'))),
        const SizedBox(width: 8),
        Expanded(child: WPhotoPlaceholder(height: 92, icon: WIcon.sparkle, tag: store.t('After', 'बाद', 'తర్వాత'), tagTone: Tone.ok)),
      ]),
    );
  }

  // MARK: Step 1: quick check by the app

  List<Widget> _quickCheck() {
    final store = context.store;
    final out = <Widget>[_label(store.t('Step 1 · We’re checking', 'कदम 1 · हम जाँच रहे हैं', 'దశ 1 · మేము తనిఖీ చేస్తున్నాం'))];
    if (checking) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(children: [
          const WStateCircle(WIcon.sparkle, size: 92, spinning: true),
          const SizedBox(height: 14),
          WBody(store.t('Checking photos and job details…', 'फ़ोटो और काम की जानकारी देख रहे हैं…', 'ఫోటోలు, పని వివరాలు చూస్తున్నాం…'), center: true),
        ]),
      ));
      return out;
    }
    switch (widget.topic) {
      case HelpTopic.money:
        out
          ..add(_result(
              WIcon.lock,
              Tone.wait,
              store.t('₹116 is on hold', '₹116 रोके गए हैं', '₹116 నిలిపివేయబడింది'),
              store.t('Owner said the bonnet had water streaks. Your after-photos look clean, so we asked the owner to check again. Other jobs are paid as normal.',
                  'मालिक ने कहा बोनट पर पानी के निशान थे। आपकी बाद की फ़ोटो साफ़ हैं, इसलिए हमने मालिक से फिर देखने को कहा। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।',
                  'బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు. మీ తర్వాతి ఫోటోలు శుభ్రంగా ఉన్నాయి, అందుకే మళ్ళీ చూడమని యజమానిని అడిగాము. మిగతా పనుల డబ్బు మామూలుగానే వస్తుంది.')))
          ..add(_photoCompare());
      case HelpTopic.rating:
        out
          ..add(_result(
              WIcon.checkCircle,
              Tone.ok,
              store.t('Your photos look good', 'आपकी फ़ोटो ठीक हैं', 'మీ ఫోటోలు బాగున్నాయి'),
              store.t('We compared before and after photos. If they show a good wash, a low rating won’t count against you.',
                  'हमने पहले और बाद की फ़ोटो मिलाईं। अगर धुलाई अच्छी दिखी, तो कम रेटिंग आपके ख़िलाफ़ नहीं गिनी जाएगी।', 'ముందు, తర్వాతి ఫోటోలు పోల్చాము. వాష్ బాగుంటే, తక్కువ రేటింగ్ మీకు వ్యతిరేకంగా లెక్కించబడదు.')))
          ..add(_photoCompare());
      case HelpTopic.app:
        out.add(_result(
            WIcon.refresh,
            Tone.info,
            store.t('Try these', 'ये करके देखें', 'ఇవి ప్రయత్నించండి'),
            store.t('1. Turn internet off and on.  2. Close the app and open again.  3. Keep battery above 15%. Your photos are saved on the phone.',
                '1. इंटरनेट बंद करके चालू करें।  2. ऐप बंद करके फिर खोलें।  3. बैटरी 15% से ऊपर रखें। आपकी फ़ोटो फ़ोन में सेव हैं।',
                '1. ఇంటర్నెట్ ఆఫ్ చేసి ఆన్ చేయండి.  2. యాప్ మూసి మళ్ళీ తెరవండి.  3. బ్యాటరీ 15% పైన ఉంచండి. మీ ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి.')));
      case HelpTopic.job:
        final issues = <(WIcon, String, String)>[
          (
            WIcon.door,
            store.t('Can’t get in', 'अंदर नहीं जा पा रहे', 'లోపలికి వెళ్ళలేకపోతున్నాను'),
            store.t('Show the owner’s gate pass to the guard. It’s on the Go to vehicle screen.', 'गार्ड को मालिक का गेट पास दिखाएं। यह ‘गाड़ी तक जाएं’ स्क्रीन पर है।', 'గార్డ్‌కి యజమాని గేట్ పాస్ చూపించండి. ఇది ‘వాహనం దగ్గరికి వెళ్ళండి’ స్క్రీన్‌లో ఉంది.')
          ),
          (
            WIcon.search,
            store.t('Can’t find vehicle', 'गाड़ी नहीं मिल रही', 'వాహనం కనబడట్లేదు'),
            store.t('Check the owner’s vehicle photos and slot number. The plate on the vehicle must match.', 'मालिक की गाड़ी की फ़ोटो और स्लॉट नंबर देखें। गाड़ी की प्लेट मिलनी चाहिए।', 'యజమాని వాహనం ఫోటోలు, స్లాట్ నంబర్ చూడండి. ప్లేట్ సరిపోలాలి.')
          ),
          (
            WIcon.warning,
            store.t('Vehicle already damaged', 'गाड़ी पहले से खराब है', 'వాహనం ముందే దెబ్బతింది'),
            store.t('Take a clear before-photo of the damage. Our photo check marks it as old damage, so you’re safe.', 'नुकसान की साफ़ ‘पहले’ फ़ोटो लें। फ़ोटो जाँच इसे पुराना नुकसान मानेगी, आप सुरक्षित हैं।',
                'దెబ్బను స్పష్టంగా ‘ముందు’ ఫోటో తీయండి. ఫోటో తనిఖీ దాన్ని పాత దెబ్బగా గుర్తిస్తుంది.')
          ),
          (
            WIcon.drop,
            store.t('No water available', 'पानी नहीं है', 'నీళ్ళు లేవు'),
            store.t('Use the society tap near the lift or ask the guard. For a water wash, 1 bucket is enough.', 'लिफ़्ट के पास का नल इस्तेमाल करें या गार्ड से पूछें। पानी वाली धुलाई के लिए 1 बाल्टी काफ़ी है।',
                'లిఫ్ట్ దగ్గర కుళాయి వాడండి లేదా గార్డ్‌ని అడగండి. 1 బకెట్ చాలు.')
          ),
        ];
        out.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 10), child: WText(store.t('What happened?', 'क्या हुआ?', 'ఏమైంది?'), WType.section, weight: semibold)));
        for (final (i, it) in issues.indexed) {
          out.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: WSelectionTile(icon: it.$1, title: it.$2, selected: jobIssue == i, radio: true, onTap: () => setState(() => jobIssue = i))));
        }
        final i = jobIssue;
        if (i != null) out.add(_result(WIcon.sparkle, Tone.info, store.t('Try this', 'ये करें', 'ఇది చేయండి'), issues[i].$3));
    }
    return out;
  }

  // MARK: Step 2: sort it out with the owner

  List<Widget> _ownerStep() {
    final store = context.store;
    final j = store.current;
    final msgs = [
      store.t('I’m at the gate. Please allow entry.', 'मैं गेट पर हूँ। कृपया अंदर आने दें।', 'నేను గేట్ దగ్గర ఉన్నాను. లోపలికి అనుమతించండి.'),
      store.t('I can’t find the vehicle. Is it in the slot?', 'गाड़ी नहीं मिल रही। क्या स्लॉट में है?', 'వాహనం కనబడట్లేదు. స్లాట్‌లో ఉందా?'),
      store.t('Please check the photos in the app.', 'कृपया ऐप में फ़ोटो देखें।', 'దయచేసి యాప్‌లో ఫోటోలు చూడండి.'),
    ];
    return [
      _label(store.t('Step 2 · Talk to the owner', 'कदम 2 · मालिक से बात करें', 'దశ 2 · యజమానితో మాట్లాడండి')),
      const SizedBox(height: 10),
      WCard(
        child: Row(children: [
          WAvatar(j.owner.substring(0, 1), size: 52),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(j.owner, WType.title, size: 18), const SizedBox(height: 4), WText('${j.society} · ${j.plate}', WType.caption)])),
        ]),
      ),
      Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: WText(store.t('Send a quick message', 'जल्दी संदेश भेजें', 'త్వరగా సందేశం పంపండి'), WType.label)),
      for (final m in msgs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            onTap: () => setState(() => sentMessage = m),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: outlinedDecoration(radius: 14, fill: sentMessage == m ? WColor.successTint : WColor.white),
              child: Row(children: [
                WIconView(sentMessage == m ? WIcon.checkCircle : WIcon.chat, size: 16, color: sentMessage == m ? WColor.onSuccess : WColor.primaryStrong),
                const SizedBox(width: 10),
                Expanded(child: WText(m, WType.body, size: 15.5)),
              ]),
            ),
          ),
        ),
      if (sentMessage != null) WText(store.t('Sent. The owner gets it on WhatsApp.', 'भेज दिया। मालिक को WhatsApp पर मिलेगा।', 'పంపాము. యజమానికి WhatsApp లో వస్తుంది.'), WType.caption, color: WColor.onSuccess),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Pressable(
          onTap: () => Support.call(),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const WIconView(WIcon.phone, size: 16, color: WColor.primaryStrong),
              const SizedBox(width: 10),
              Expanded(child: WText(store.t('Call owner (number stays hidden)', 'मालिक को कॉल करें (नंबर छिपा रहेगा)', 'యజమానికి కాల్ (నంబర్ దాచి ఉంటుంది)'), WType.title, color: WColor.primaryStrong, size: 16)),
            ]),
          ),
        ),
      ),
    ];
  }

  // MARK: Step 3: our team (callback, not a direct line)

  List<Widget> _teamStep() {
    final store = context.store;
    return [
      _label(store.t('Step 3 · Our team', 'कदम 3 · हमारी टीम', 'దశ 3 · మా బృందం')),
      if (callbackRequested)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(children: [
            const WStateCircle(WIcon.phone, tone: Tone.ok, size: 96),
            const SizedBox(height: 12),
            WText(store.t('We’ll call you soon', 'हम जल्दी कॉल करेंगे', 'మేము త్వరలో కాల్ చేస్తాము'), WType.section, weight: semibold, size: 22, align: TextAlign.center),
            const SizedBox(height: 12),
            WBody(store.t('Within 30 minutes on ${Fmt.phone(store.phone)}. Keep your phone close.', '30 मिनट में ${Fmt.phone(store.phone)} पर। फ़ोन पास रखें।', '30 నిమిషాల్లో ${Fmt.phone(store.phone)} కి. ఫోన్ దగ్గర ఉంచుకోండి.'), center: true),
            const SizedBox(height: 12),
            WText('${store.t('Ticket', 'टिकट', 'టికెట్')} #WH-2814', WType.caption),
          ]),
        )
      else ...[
        WBody(store.t('Sorry this didn’t get fixed. Our team will look at your photos and job, then call you.', 'माफ़ करें, यह ठीक नहीं हुआ। हमारी टीम आपकी फ़ोटो और काम देखकर आपको कॉल करेगी।', 'క్షమించండి, ఇది తీరలేదు. మా బృందం మీ ఫోటోలు, పని చూసి మీకు కాల్ చేస్తుంది.'), top: 8),
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Row(children: [WIconView(WIcon.clock, size: 16, color: WColor.secondary), SizedBox(width: 10), WText('7 AM – 9 PM · Hindi, Telugu, English', WType.caption)]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: WButton(store.t('Explain by voice (optional)', 'आवाज़ में बताएं (ज़रूरी नहीं)', 'వాయిస్‌తో చెప్పండి (ఐచ్ఛికం)'), icon: WIcon.mic, kind: ButtonKind.outline, size: ButtonSize.captain, onTap: () {}),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final topic = widget.topic;
    Widget? footer;
    if (!solved) {
      if (level < 3) {
        footer = WStackedFooter(captain: true, children: [
          WButton(store.t('Solved', 'हल हो गया', 'పరిష్కారమైంది'), icon: WIcon.check, size: ButtonSize.captain, enabled: !(level == 1 && checking), onTap: () => setState(() => solved = true)),
          WButton(store.t('Still a problem', 'अभी भी समस्या है', 'ఇంకా సమస్య ఉంది'),
              kind: ButtonKind.text, enabled: !(level == 1 && checking), onTap: () => setState(() => level = (level == 1 && !_usesOwner(topic)) ? 3 : level + 1)),
        ]);
      } else if (!callbackRequested) {
        footer = WFooter(child: WButton(store.t('Ask our team to call me', 'हमारी टीम से कॉल मँगवाएं', 'మా బృందం కాల్ చేయమనండి'), icon: WIcon.phone, size: ButtonSize.captain, onTap: () => setState(() => callbackRequested = true)));
      } else {
        footer = WFooter(child: WButton(store.t('Back to home', 'होम पर वापस', 'హోమ్‌కి తిరిగి'), size: ButtonSize.captain, onTap: router.home));
      }
    }
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: helpTopicTitle(topic, store), help: false),
      footer: footer,
      children: [
        Padding(padding: const EdgeInsets.only(top: 10, bottom: 20), child: HelpLadder(current: solved ? 4 : level, skipOwner: !_usesOwner(topic))),
        if (solved)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: WStateCircle(WIcon.check, tone: Tone.ok, size: 96)),
              const SizedBox(height: 12),
              WText(store.t('Glad it’s sorted', 'अच्छा हुआ, हल हो गया', 'తీరింది, సంతోషం'), WType.section, weight: semibold, size: 22, align: TextAlign.center),
              const SizedBox(height: 12),
              WBody(store.t('You can come back to Help any time.', 'आप कभी भी मदद पर वापस आ सकते हैं।', 'ఎప్పుడైనా సహాయానికి రావచ్చు.'), center: true),
              const SizedBox(height: 22),
              WButton(store.t('Back to home', 'होम पर वापस', 'హోమ్‌కి తిరిగి'), size: ButtonSize.captain, onTap: router.home),
            ]),
          )
        else
          ...switch (level) { 1 => _quickCheck(), 2 => _ownerStep(), _ => _teamStep() },
      ],
    );
  }
}

// MARK: W57 Where I work: which jobs ring for this captain

/// Four simple choices: all jobs, chosen societies, a distance, or one place.
/// The society the phone is in right now is suggested first.
///
/// [setup]: first-time onboarding only (after "I agree", while the documents are reviewed).
/// The same two questions, one per screen: "Which jobs should ring?" then "When do you work?".
/// Done → the questionnaire shrinks into Home's "Jobs from" chip, where the answers can be
/// changed later.
class WorkAreaScreen extends StatefulWidget {
  const WorkAreaScreen({super.key, this.setup = false});
  final bool setup;
  @override
  State<WorkAreaScreen> createState() => _WorkAreaScreenState();
}

class _WorkAreaScreenState extends State<WorkAreaScreen> {
  WorkMode mode = WorkMode.all;
  int radius = 3;
  Set<String> picked = {};
  String place = 'Narsingi';
  List<WorkSlot> slots = [];
  bool loaded = false;

  /// Setup only: 0 = which jobs, 1 = when.
  int page = 0;

  /// Direction of the last page change, for the slide.
  bool forward = true;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    final store = context.store;
    mode = store.workMode;
    radius = store.radiusKm;
    picked = {...store.chosenSocieties};
    place = store.workPlace;
    // Empty means any time: the editor starts with the whole day (setup: a typical 9 to 6).
    slots = store.workSlots.isNotEmpty ? [...store.workSlots] : [widget.setup ? (9 * 60, 18 * 60) : (workDayStart, workDayEnd)];
  }

  Widget _choice(WorkMode m, WIcon icon, String title, String sub) => WSelectionTile(
        icon: icon,
        title: title,
        subtitle: sub,
        selected: mode == m,
        radio: true,
        onTap: () => setState(() {
          mode = m;
          if (m == WorkMode.societies && picked.isEmpty && context.store.hereSociety.isNotEmpty) picked = {context.store.hereSociety};
        }),
      );

  Widget _societies() {
    final store = context.store;
    final here = context.store.hereSociety;
    return FadeIn(
      offset: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WIconView(WIcon.locate, size: 18, color: WColor.primaryStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WText(store.isLive&&here.isEmpty?'Location has not been matched yet':store.t('You’re at $here now', 'आप अभी $here में हैं', 'మీరు ఇప్పుడు $here లో ఉన్నారు'), WType.title, size: 16),
                WLink(store.t('Only jobs here', 'सिर्फ़ यहाँ के काम', 'ఇక్కడి పనులు మాత్రమే'), k: WType.caption, minHeight: 32, onTap: () {if(here.isNotEmpty){setState(()=>picked={here});}else{store.set(()=>store.toast='Choose a served society below.');}}),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        WCard(
          padding: 14,
          child: Column(children: [
            for (final (i, s) in store.societyChoices.indexed) ...[
              Pressable(
                feedback: false,
                onTap: () => setState(() => picked.contains(s.name) ? picked.remove(s.name) : picked.add(s.name)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    WIconView(picked.contains(s.name) ? WIcon.squareCheck : WIcon.square, size: 24, color: picked.contains(s.name) ? WColor.primary : WColor.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        WText(s.name, WType.rowTitle, size: 16.5),
                        const SizedBox(height: 2),
                        WText(s.km == 0 ? s.area : '${s.area} · ${s.km < 1 ? '${(s.km * 1000).round()} m' : '${s.km.toStringAsFixed(1)} km'}', WType.caption),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (i < store.societyChoices.length - 1) const WDivider(inset: 36),
            ],
          ]),
        ),
      ]),
    );
  }

  List<Widget> _jobChoices(CaptainStore store) => [
        for (final w in [
          _choice(WorkMode.all, WIcon.layers, store.t('All jobs', 'सभी काम', 'అన్ని పనులు'), store.t('Any job near you', 'आपके आस-पास का कोई भी काम', 'మీ దగ్గర ఏ పనైనా')),
          _choice(WorkMode.societies, WIcon.building, store.t('My societies', 'मेरी सोसाइटी', 'నా సొసైటీలు'), store.t('Only buildings you pick', 'सिर्फ़ आपकी चुनी बिल्डिंग', 'మీరు ఎంచుకున్న భవనాలు మాత్రమే')),
          if (mode == WorkMode.societies) _societies(),
          _choice(WorkMode.radius, WIcon.locate, store.t('Distance', 'दूरी', 'దూరం'), store.t('Jobs within a few km', 'कुछ km के अंदर के काम', 'కొన్ని కి.మీ లోపు పనులు')),
          if (mode == WorkMode.radius)
            Row(children: [
              for (final (i, k) in [1, 3, 5, 10].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: WChip('$k km', selected: radius == k, height: 48, fill: true, onTap: () => setState(() => radius = k))),
              ],
            ]),
          _choice(WorkMode.place, WIcon.location, store.t('A place I choose', 'मेरी चुनी जगह', 'నేను ఎంచుకున్న ప్రదేశం'), store.t('Jobs in one area', 'एक इलाके के काम', 'ఒక ప్రాంతంలో పనులు')),
          if (mode == WorkMode.place) WFlow(spacing: 8, children: [for (final p in Society.places) WChip(p, selected: place == p, height: 44, onTap: () => setState(() => place = p))]),
        ]) ...[
          w,
          const SizedBox(height: 12),
        ],
      ];

  bool get _jobsAnswered => mode != WorkMode.societies || picked.isNotEmpty;

  /// Saves on the server (real data) and in the store. Returns false if saving failed.
  Future<bool> _save(CaptainStore store) async {
    if (store.isLive && store.registered) {
      try { await store.liveSaveWorkPreferences(mode,radius,picked,place,mergeSlots(slots)); }
      catch(e){store.set(()=>store.toast=backendError(e));return false;}
    }
    store.set(() {
      store.workMode = mode;
      store.radiusKm = radius;
      store.chosenSocieties = picked;
      store.workPlace = place;
      store.workSlots = mergeSlots(slots);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.setup) return _setup(context);
    final store = context.store, router = context.router;
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Where I work', 'मैं कहाँ काम करूँ', 'నేను ఎక్కడ పని చేస్తాను'), help: false),
      footer: WFooter(
        child: WButton(store.t('Save', 'सेव करें', 'సేవ్ చేయండి'), size: ButtonSize.captain, enabled: _jobsAnswered, onTap: () {
          // Speed (30 Oct): close at once; the server save runs in the background and a
          // failure shows a toast. (First-time setup below still waits: approval needs it.)
          final previous = (store.workMode, store.radiusKm, store.chosenSocieties, store.workPlace, store.workSlots);
          store.set(() {
            store.workMode = mode;
            store.radiusKm = radius;
            store.chosenSocieties = picked;
            store.workPlace = place;
            store.workSlots = mergeSlots(slots);
            store.toast = store.t('Saved: ${store.workSummary}', 'सेव हुआ: ${store.workSummary}', 'సేవ్ అయింది: ${store.workSummary}');
          });
          if (store.isLive && store.registered) {
            store.liveSaveWorkPreferences(mode, radius, picked, place, mergeSlots(slots)).catchError((Object e) {
              store.set(() {
                store.workMode = previous.$1;
                store.radiusKm = previous.$2;
                store.chosenSocieties = previous.$3;
                store.workPlace = previous.$4;
                store.workSlots = previous.$5;
                store.toast = backendError(e);
              });
            });
          }
          router.pop();
        }),
      ),
      children: [
        WTitle(store.t('Which jobs should ring?', 'कौन से काम बजें?', 'ఏ పనులు మోగాలి?'), top: 10),
        WBody(store.t('You can change this any time.', 'इसे कभी भी बदल सकते हैं।', 'ఎప్పుడైనా మార్చవచ్చు.'), top: 4, bottom: 16),
        ..._jobChoices(store),
        // When I work: only decides which jobs ring. Each job is still the captain's choice.
        WTitle(store.t('When do you work?', 'आप कब काम करते हैं?', 'మీరు ఎప్పుడు పని చేస్తారు?'), top: 14),
        WBody(store.t('Set when you start and finish. Taking a break? Add more time.', 'काम शुरू और ख़त्म करने का समय चुनें। बीच में ब्रेक? और समय जोड़ें।', 'మొదలు, ముగింపు సమయం ఎంచుకోండి. మధ్యలో విరామం? మరింత సమయం జోడించండి.'), top: 4, bottom: 12),
        WorkSlotsEditor(slots: slots, onChanged: (v) => setState(() => slots = v)),
        const SizedBox(height: 24),
      ],
    );
  }

  /// First-time setup: one question per screen.
  Widget _setup(BuildContext context) {
    final store = context.store, router = context.router;
    final header = WAppBar(
      title: store.t('Your work profile', 'आपकी काम की प्रोफ़ाइल', 'మీ పని ప్రొఫైల్'),
      leading: page == 1 ? WIcon.left : null,
      trailing: null,
      onLeading: () => setState(() {
        forward = false;
        page = 0;
      }),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
    );
    final footer = page == 0
        ? WButton(store.t('Next', 'आगे', 'తదుపరి'), size: ButtonSize.captain, enabled: _jobsAnswered, onTap: () => setState(() {
            forward = true;
            page = 1;
          }))
        : WButton(store.t('Done', 'हो गया', 'పూర్తయింది'), icon: WIcon.check, size: ButtonSize.captain, loading: saving, onTap: () async {
            setState(() => saving = true);
            final saved = await _save(store);
            if (!mounted) return;
            setState(() => saving = false);
            if (!saved) return;
            // "You're in" was removed (27 Oct): the questionnaire closes straight into Home.
            if (!store.isLive) store.finishKyc(); // sample app: approved at once
            if (store.signedUp) {
              store.goOnlineAfterApproval();
            } else {
              store.set(() => store.reviewNoticePending = true);
            }
            playWorkProfileLanding(this.context);
            router.home();
          });
    final pages = [
      Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Documents are with the team; this keeps the captain busy with his own profile.
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WIconView(WIcon.check, size: 17, color: WColor.onSuccess),
            const SizedBox(width: 12),
            Expanded(child: WText(store.t('Documents sent. While we check them, set up how you work.', 'दस्तावेज़ भेज दिए। जब तक हम जाँचते हैं, बताइए आप कैसे काम करेंगे।', 'పత్రాలు పంపారు. మేము చూస్తున్నంతలో, మీరు ఎలా పని చేస్తారో చెప్పండి.'), WType.caption, color: WColor.onSuccess, size: 14.5)),
          ]),
        ),
        WTitle(store.t('Which jobs should ring?', 'कौन से काम बजें?', 'ఏ పనులు మోగాలి?'), top: 18),
        WBody(store.t('You can change this any time.', 'इसे कभी भी बदल सकते हैं।', 'ఎప్పుడైనా మార్చవచ్చు.'), top: 4, bottom: 16),
        ..._jobChoices(store),
      ]),
      Column(key: const ValueKey(1), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WTitle(store.t('When do you work?', 'आप कब काम करते हैं?', 'మీరు ఎప్పుడు పని చేస్తారు?'), top: 14),
        WBody(store.t('Set when you start and finish. Taking a break? Add more time.', 'काम शुरू और ख़त्म करने का समय चुनें। बीच में ब्रेक? और समय जोड़ें।', 'మొదలు, ముగింపు సమయం ఎంచుకోండి. మధ్యలో విరామం? మరింత సమయం జోడించండి.'), top: 4, bottom: 16),
        WorkSlotsEditor(slots: slots, onChanged: (v) => setState(() => slots = v)),
      ]),
    ];
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: header,
      footer: WFooter(child: footer),
      children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: WSegmentBar(filled: page + 1, total: 2)),
        // Pages move left to right, the way the progress bar fills (right to left going back).
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
            transitionBuilder: (child, a) {
              final incoming = child.key == ValueKey(page);
              final from = incoming ? (forward ? -1.0 : 1.0) : (forward ? 1.0 : -1.0);
              return SlideTransition(position: Tween(begin: Offset(from, 0), end: Offset.zero).animate(a), child: child);
            },
            child: pages[page],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}



/// "When do you work?": one card per time range, each with a start–end slider
/// (6 AM to 9 PM, 30-minute steps), and "Add more time" for a second range after a break.
class WorkSlotsEditor extends StatelessWidget {
  const WorkSlotsEditor({super.key, required this.slots, required this.onChanged});
  final List<WorkSlot> slots;
  final ValueChanged<List<WorkSlot>> onChanged;
  static const maxSlots = 4;

  /// A new range one hour after the last one ends, up to three hours long.
  WorkSlot? get _nextFree {
    final last = slots.isEmpty ? workDayStart : slots.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
    final start = last + 60;
    if (start + 60 > workDayEnd) return null;
    return (start, start + 180 > workDayEnd ? workDayEnd : start + 180);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final sorted = [...slots]..sort((a, b) => a.$1.compareTo(b.$1));
    final overlap = [for (var i = 1; i < sorted.length; i++) sorted[i].$1 < sorted[i - 1].$2].any((x) => x);
    final free = slots.length < maxSlots ? _nextFree : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, s) in slots.indexed) ...[
        _SlotCard(
          label: store.t('Time ${i + 1}', 'समय ${i + 1}', 'సమయం ${i + 1}'),
          slot: s,
          onChanged: (v) => onChanged([...slots]..[i] = v),
          onRemove: slots.length > 1 ? () => onChanged([...slots]..removeAt(i)) : null,
        ),
        const SizedBox(height: 12),
      ],
      if (overlap)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const WIconView(WIcon.info, size: 15, color: WColor.secondary),
            const SizedBox(width: 8),
            Expanded(child: WText(store.t('Times that overlap will be joined.', 'एक-दूसरे में आने वाले समय जोड़ दिए जाएंगे।', 'ఒకదానిలో ఒకటి వచ్చే సమయాలు కలిపేస్తాం.'), WType.caption)),
          ]),
        ),
      if (free != null)
        WButton(store.t('Add more time', 'और समय जोड़ें', 'మరింత సమయం జోడించండి'), icon: WIcon.plus, kind: ButtonKind.outline, size: ButtonSize.captain, onTap: () => onChanged([...slots, free])),
    ]);
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.label, required this.slot, required this.onChanged, this.onRemove});
  final String label;
  final WorkSlot slot;
  final ValueChanged<WorkSlot> onChanged;
  final VoidCallback? onRemove;

  /// RangeSlider insets its track by the overlay radius; the sky and the labels use the same.
  static const _inset = 28.0;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final hours = (slot.$2 - slot.$1) / 60;
    final hoursText = hours == hours.roundToDouble() ? '${hours.toInt()}' : '$hours';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: outlinedDecoration(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          WText(label, WType.label, color: WColor.secondary),
          const SizedBox(width: 8),
          WText(store.t('$hoursText h', '$hoursText घंटे', '$hoursText గం.'), WType.caption),
          const Spacer(),
          if (onRemove != null)
            Pressable(
              label: store.t('Remove this time', 'यह समय हटाएं', 'ఈ సమయం తీసివేయండి'),
              onTap: onRemove,
              child: const SizedBox(width: 48, height: 40, child: Center(child: WIconView(WIcon.close, size: 18, color: WColor.secondary))),
            )
          else
            const SizedBox(height: 40),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: WText('${fmtClock(slot.$1)}  –  ${fmtClock(slot.$2)}', WType.section, weight: semibold, size: 22),
        ),
        const SizedBox(height: 8),
        // The sky: sun or moon at each end rides an arc as the handles move.
        _SkyArc(slot: slot, inset: _inset),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: WColor.primary,
            inactiveTrackColor: WColor.border,
            thumbColor: WColor.white,
            overlayColor: WColor.primary.withValues(alpha: 0.12),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 14, elevation: 2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: _inset),
            showValueIndicator: ShowValueIndicator.never,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: RangeSlider(
            min: workDayStart.toDouble(),
            max: workDayEnd.toDouble(),
            divisions: (workDayEnd - workDayStart) ~/ 30,
            values: RangeValues(slot.$1.toDouble(), slot.$2.toDouble()),
            semanticFormatterCallback: (v) => fmtClock(v.round()),
            onChanged: (v) {
              final a = v.start.round(), b = v.end.round();
              if (b - a < 60) return; // at least one hour
              if ((a, b) != slot) HapticFeedback.selectionClick();
              onChanged((a, b));
            },
          ),
        ),
        SizedBox(
          height: 18,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth - 2 * _inset;
            return Stack(clipBehavior: Clip.none, children: [
              for (final m in [4 * 60, 10 * 60, 16 * 60, 22 * 60])
                Positioned(
                  left: _inset + w * (m - workDayStart) / (workDayEnd - workDayStart) - 24,
                  width: 48,
                  child: WText(fmtClock(m), WType.small, color: WColor.secondary, align: TextAlign.center),
                ),
            ]);
          }),
        ),
      ]),
    );
  }
}

/// Sun between 6 AM and 6 PM, moon otherwise.
bool _isDay(int minutes) => minutes >= 6 * 60 && minutes < 18 * 60;

const _sunColor = Color(0xFFF59E0B), _moonColor = Color(0xFF6B5BD2);

/// Soft sky for the middle of the slot: lavender night, peach dawn/dusk, blue day.
Color _skyFor(int minutes) {
  final h = minutes / 60;
  if (h < 5.5 || h >= 19.5) return const Color(0xFFEDEBFA);
  if (h < 8 || h >= 17) return const Color(0xFFFFF1E2);
  return const Color(0xFFEAF4FF);
}

class _SkyArc extends StatelessWidget {
  const _SkyArc({required this.slot, required this.inset});
  final WorkSlot slot;
  final double inset;
  static const height = 64.0, glyph = 26.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        Offset at(int minutes) {
          final t = ((minutes - workDayStart) / (workDayEnd - workDayStart)).clamp(0.0, 1.0);
          return Offset(inset + t * (w - 2 * inset), height - 10 - math.sin(math.pi * t) * (height - 26));
        }

        Widget body(int minutes) {
          final p = at(minutes), day = _isDay(minutes);
          return Positioned(
            left: p.dx - glyph / 2,
            top: p.dy - glyph / 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
              child: Container(
                key: ValueKey(day),
                width: glyph,
                height: glyph,
                decoration: BoxDecoration(
                  color: WColor.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: (day ? _sunColor : _moonColor).withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)],
                ),
                alignment: Alignment.center,
                child: WIconView(day ? WIcon.sun : WIcon.moon, size: 16, color: day ? _sunColor : _moonColor),
              ),
            ),
          );
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: height,
          decoration: BoxDecoration(color: _skyFor((slot.$1 + slot.$2) ~/ 2), borderRadius: BorderRadius.circular(12)),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: CustomPaint(painter: _ArcPainter(at: at, slot: slot))),
            body(slot.$1),
            body(slot.$2),
          ]),
        );
      });
}

/// Dotted path for the whole day, solid colour for the chosen time.
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.at, required this.slot});
  final Offset Function(int minutes) at;
  final WorkSlot slot;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = WColor.muted.withValues(alpha: 0.5);
    for (var m = workDayStart; m <= workDayEnd; m += 20) {
      canvas.drawCircle(at(m), 1.4, dot);
    }
    final path = Path()..moveTo(at(slot.$1).dx, at(slot.$1).dy);
    for (var m = slot.$1; m <= slot.$2; m += 5) {
      final p = at(m);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [_isDay(slot.$1) ? _sunColor : _moonColor, _isDay(slot.$2) ? _sunColor : _moonColor])
            .createShader(Rect.fromPoints(at(slot.$1), at(slot.$2)).inflate(1)),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.slot != slot;
}
