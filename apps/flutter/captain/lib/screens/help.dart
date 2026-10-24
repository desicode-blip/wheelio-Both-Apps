// Support ladder (quick check → owner → our team) and "Where I work".
// Ported from apps/ios/Captain/Screens/HelpFlowScreens.swift and WorkAreaScreen.swift.
// There is no "call us" button up front. Only safety emergencies call directly.

import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/store.dart';
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
class WorkAreaScreen extends StatefulWidget {
  const WorkAreaScreen({super.key});
  @override
  State<WorkAreaScreen> createState() => _WorkAreaScreenState();
}

class _WorkAreaScreenState extends State<WorkAreaScreen> {
  WorkMode mode = WorkMode.all;
  int radius = 3;
  Set<String> picked = {};
  String place = 'Narsingi';
  Set<WorkTime> times = {};
  bool loaded = false;

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
    times = {...store.workTimes};
  }

  Widget _choice(WorkMode m, WIcon icon, String title, String sub) => WSelectionTile(
        icon: icon,
        title: title,
        subtitle: sub,
        selected: mode == m,
        radio: true,
        onTap: () => setState(() {
          mode = m;
          if (m == WorkMode.societies && picked.isEmpty) picked = {Society.current.name};
        }),
      );

  Widget _societies() {
    final store = context.store;
    final here = Society.current.name;
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
                WText(store.t('You’re at $here now', 'आप अभी $here में हैं', 'మీరు ఇప్పుడు $here లో ఉన్నారు'), WType.title, size: 16),
                WLink(store.t('Only jobs here', 'सिर्फ़ यहाँ के काम', 'ఇక్కడి పనులు మాత్రమే'), k: WType.caption, minHeight: 32, onTap: () => setState(() => picked = {here})),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        WCard(
          padding: 14,
          child: Column(children: [
            for (final (i, s) in Society.all.indexed) ...[
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
                        WText('${s.area} · ${s.km < 1 ? '${(s.km * 1000).round()} m' : '${s.km.toStringAsFixed(1)} km'}', WType.caption),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (i < Society.all.length - 1) const WDivider(inset: 36),
            ],
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      canvas: true,
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Where I work', 'मैं कहाँ काम करूँ', 'నేను ఎక్కడ పని చేస్తాను'), help: false),
      footer: WFooter(
        child: WButton(store.t('Save', 'सेव करें', 'సేవ్ చేయండి'), size: ButtonSize.captain, enabled: mode != WorkMode.societies || picked.isNotEmpty, onTap: () {
          store.set(() {
            store.workMode = mode;
            store.radiusKm = radius;
            store.chosenSocieties = picked;
            store.workPlace = place;
            store.workTimes = times;
          });
          store.set(() => store.toast = store.t('Saved: ${store.workSummary}', 'सेव हुआ: ${store.workSummary}', 'సేవ్ అయింది: ${store.workSummary}'));
          router.pop();
        }),
      ),
      children: [
        WTitle(store.t('Which jobs should ring?', 'कौन से काम बजें?', 'ఏ పనులు మోగాలి?'), top: 10),
        WBody(store.t('You can change this any time.', 'इसे कभी भी बदल सकते हैं।', 'ఎప్పుడైనా మార్చవచ్చు.'), top: 4, bottom: 16),
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
        // When I work: only decides which jobs ring. Each job is still the captain's choice.
        WTitle(store.t('When do you work?', 'आप कब काम करते हैं?', 'మీరు ఎప్పుడు పని చేస్తారు?'), top: 14),
        WBody(store.t('Pick one or more. Leave all off for any time.', 'एक या ज़्यादा चुनें। कभी भी के लिए कुछ न चुनें।', 'ఒకటి లేదా ఎక్కువ ఎంచుకోండి. ఎప్పుడైనా అంటే ఏదీ ఎంచుకోకండి.'), top: 4, bottom: 12),
        Row(children: [
          for (final (i, t) in WorkTime.values.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: WChip(
                switch (t) {
                  WorkTime.morning => store.t('6–10 AM', 'सुबह 6–10', 'ఉ. 6–10'),
                  WorkTime.midday => store.t('10 AM–2 PM', 'दिन 10–2', 'ఉ. 10–మ. 2'),
                  WorkTime.afternoon => store.t('2–6 PM', 'दोपहर 2–6', 'మ. 2–6'),
                },
                selected: times.contains(t),
                height: 48,
                fill: true,
                onTap: () => setState(() => times.contains(t) ? times.remove(t) : times.add(t)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 24),
      ],
    );
  }
}
