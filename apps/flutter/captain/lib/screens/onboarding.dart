import 'dart:async';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/store.dart';
import '../data/spoken_answer.dart';
import 'parts.dart';

// MARK: Testing shortcut (remove before launch)

/// Testing only: the small "Skip this step (testing)" link on each onboarding stage.
/// It marks that one stage done on this phone and goes back to the steps, so testers can
/// skip stage after stage. Real data: the server still checks every document, the
/// training and the quiz when the application is sent. Turn off by setting this to false.
const onboardingSkip = true;

/// Testing only: "TEST +5 min" on Today's plan, to fast-forward the job timers.
const planClockTest = true;

class TestSkipButton extends StatelessWidget {
  const TestSkipButton({super.key, this.top = 0, this.step, this.dark = false, this.next});
  final double top;

  /// Go straight to this screen instead of skipping a KYC stage (used on "Get ready").
  final N? next;

  /// The stage this screen is for; null on the steps list = the next stage to do.
  final KycStep? step;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    if (!onboardingSkip) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Center(
        child: Pressable(
          label: 'Skip this step (testing)',
          onTap: () {
            final router = context.router;
            if (next != null) {
              router.replace([R(next!)]);
              return;
            }
            final s = step ?? store.nextStep;
            if (s == null) {
              router.go(N.rules);
              return;
            }
            store.testSkipStep(s);
            router.replace(const [R(N.steps)]);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: WText('Skip this step (testing)', WType.label, size: 14, weight: semibold, color: dark ? Colors.white70 : WColor.secondary),
          ),
        ),
      ),
    );
  }
}

// MARK: W04 4 steps (W15 one thing to fix)

enum _Stage { aadhaar, photo, bank, onboarding }

class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key, this.problem = false});
  final bool problem;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    (WIcon, String, String) info(_Stage s) => switch (s) {
          _Stage.aadhaar => (WIcon.idCard, store.t('Aadhaar', 'आधार', 'ఆధార్'), store.t('Photo of the front and back', 'आगे और पीछे की फ़ोटो', 'ముందు, వెనుక ఫోటో')),
          _Stage.photo => (WIcon.face, store.t('Your photo', 'आपकी फ़ोटो', 'మీ ఫోటో'), store.t('A quick selfie to match your Aadhaar', 'आधार से मिलाने के लिए एक सेल्फ़ी', 'ఆధార్‌తో సరిపోల్చడానికి ఒక సెల్ఫీ')),
          _Stage.bank => (WIcon.bank, store.t('Bank or UPI', 'बैंक या UPI', 'బ్యాంక్ లేదా UPI'), store.t('Where your money comes every night', 'जहाँ हर रात आपके पैसे आएंगे', 'ప్రతి రాత్రి మీ డబ్బు వచ్చే చోటు')),
          _Stage.onboarding => (WIcon.play, store.t('Onboarding', 'ऑनबोर्डिंग', 'ఆన్‌బోర్డింగ్'), store.t('Short training videos and a quiz', 'छोटे ट्रेनिंग वीडियो और एक क्विज़', 'చిన్న శిక్షణ వీడియోలు, ఒక క్విజ్')),
        };
    KycState state(_Stage s) {
      if (problem) return s == _Stage.photo ? KycState.problem : KycState.done;
      return switch (s) {
        _Stage.aadhaar => store.steps[KycStep.aadhaar] ?? KycState.todo,
        _Stage.photo => store.steps[KycStep.photo] ?? KycState.todo,
        _Stage.bank => store.steps[KycStep.bank] ?? KycState.todo,
        _Stage.onboarding => store.steps[KycStep.training] == KycState.done && store.steps[KycStep.quiz] == KycState.done ? KycState.done : KycState.todo,
      };
    }

    final list = problem ? [_Stage.aadhaar, _Stage.photo, _Stage.bank] : _Stage.values;
    final current = list.indexWhere((s) => state(s) != KycState.done);

    /// Round marker on the left: done = green tick, now = filled blue, later = soft grey.
    Widget marker(WIcon icon, KycState st, bool isCurrent) => switch (st) {
          KycState.done => Container(width: 48, height: 48, decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.check, size: 18, color: WColor.onSuccess, weight: bold)),
          KycState.problem => Container(width: 48, height: 48, decoration: const BoxDecoration(color: WColor.errorTint, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.warning, size: 18, color: WColor.destructive)),
          KycState.todo => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: isCurrent ? WColor.primary : WColor.canvas, shape: BoxShape.circle, border: isCurrent ? null : Border.all(color: WColor.border, width: 1.5)),
              alignment: Alignment.center,
              child: WIconView(icon, size: 20, color: isCurrent ? WColor.white : WColor.secondary),
            ),
        };

    void go() {
      if (store.underReview) {
        store.set(() => store.reviewNoticePending = true);
        router.home();
        return;
      }
      switch (store.nextStep) {
        case KycStep.aadhaar:
          router.push(const R(N.aadhaar));
        case KycStep.photo:
          router.go(N.selfie);
        case KycStep.bank:
          router.go(N.bank);
        case KycStep.training:
          router.go(N.training);
        case KycStep.quiz:
          router.go(N.quiz);
        case null:
          router.go(N.rules);
      }
    }

    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Quick KYC', 'छोटा KYC', 'చిన్న KYC'), back: !problem),
      footer: WFooter(
        child: problem
            ? WButton(store.t('Take photo again', 'फिर से फ़ोटो लें', 'మళ్ళీ ఫోటో తీయండి'), icon: WIcon.camera, size: ButtonSize.captain, onTap: () => router.go(N.selfie))
            : WButton(store.stepsDone == 0 ? store.t('Start', 'शुरू करें', 'ప్రారంభించండి') : store.t('Continue', 'जारी रखें', 'కొనసాగించండి'), size: ButtonSize.captain, onTap: go),
      ),
      children: [
        if (store.kycFromJob && !problem)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: WColor.waitTint, borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const WIconView(WIcon.lock, size: 17, color: WColor.waitText),
              const SizedBox(width: 12),
              Expanded(child: WText(store.t('To accept jobs, finish these steps once. Owners only let verified captains in.', 'काम लेने के लिए ये कदम एक बार पूरे करें। मालिक सिर्फ़ जाँचे गए कैप्टन को अंदर आने देते हैं।', 'పనులు తీసుకోవడానికి ఈ దశలు ఒక్కసారి పూర్తి చేయండి. యజమానులు ధృవీకరించిన కెప్టెన్లనే అనుమతిస్తారు.'), WType.caption, color: WColor.waitText, size: 14.5)),
            ]),
          ),
        if (problem) ...[
          WTitle(store.t('1 thing to fix', '1 चीज़ ठीक करें', '1 విషయం సరిచేయండి'), top: 10),
          WBody(store.t('We couldn’t match your selfie with Aadhaar.', 'आपकी सेल्फ़ी आधार से मेल नहीं खाई।', 'మీ సెల్ఫీ ఆధార్‌తో సరిపోలలేదు.'), top: 6, bottom: 26),
        ] else ...[
          WTitle(store.t('4 steps to take jobs', 'काम लेने के 4 कदम', 'పనులు తీసుకోవడానికి 4 దశలు'), top: 14),
          WBody(store.t('Here’s what comes next. We’ll take you through each one.', 'आगे यह होगा। हम हर कदम में आपकी मदद करेंगे।', 'తర్వాత ఇవి ఉంటాయి. ప్రతి దశలో మేము మీకు సహాయం చేస్తాము.'), top: 6, bottom: 26),
        ],
        for (final (i, s) in list.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                marker(info(s).$1, state(s), i == current),
                if (i < list.length - 1) Expanded(child: Container(width: 2, constraints: const BoxConstraints(minHeight: 34), color: state(s) == KycState.done ? WColor.success : WColor.border)),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    WText('${store.t('Step', 'कदम', 'దశ')} ${i + 1}', WType.label, color: WColor.secondary),
                    const SizedBox(height: 4),
                    WText(info(s).$2, WType.title, size: 19, color: i == current || state(s) == KycState.problem ? WColor.heading : WColor.secondary, weight: i == current ? semibold : medium),
                    const SizedBox(height: 4),
                    WText(info(s).$3, WType.caption, size: 14.5),
                  ]),
                ),
              ),
            ]),
          ),
        if (!problem) const TestSkipButton(top: 4),
      ],
    );
  }
}

// MARK: W05 Aadhaar (W05b photo not clear)
//
// "Upload Aadhaar photo" asks camera or gallery, shows the photo while it is checked,
// then either "Photo is clear" or W05b "Photo is not clear" with the reason.
// The check is the on-phone quality check (light, size, covered). Reading the card and
// matching it to the captain is P0 for Ajay (docs/CHANGES-2026-10-27-UI.md).

enum _AadhaarView { start, checking, clear, unclear }

class AadhaarScreen extends StatefulWidget {
  const AadhaarScreen({super.key, this.unclear = false});
  final bool unclear;
  @override
  State<AadhaarScreen> createState() => _AadhaarScreenState();
}

class _AadhaarScreenState extends State<AadhaarScreen> {
  late _AadhaarView view = widget.unclear ? _AadhaarView.unclear : _AadhaarView.start;
  Uint8List? photo;
  PhotoIssue? issue;

  /// Camera or gallery, then the check.
  void _choose() {
    final store = context.store;
    showWActions(
      context,
      title: store.t('Upload Aadhaar photo', 'आधार की फ़ोटो अपलोड करें', 'ఆధార్ ఫోటో అప్‌లోడ్ చేయండి'),
      message: store.t('Front of the card, all 4 corners inside.', 'कार्ड का आगे का हिस्सा, चारों कोने अंदर।', 'కార్డు ముందు భాగం, నాలుగు మూలలు లోపల.'),
      cancel: store.t('Cancel', 'रद्द करें', 'రద్దు చేయండి'),
      actions: [
        AlertAction(store.t('Take photo', 'फ़ोटो लें', 'ఫోటో తీయండి'), onTap: () => _pick(camera: true)),
        AlertAction(store.t('Choose from gallery', 'गैलरी से चुनें', 'గ్యాలరీ నుండి ఎంచుకోండి'), onTap: () => _pick(camera: false)),
      ],
    );
  }

  Future<void> _pick({required bool camera}) async {
    final store = context.store;
    Uint8List? bytes;
    try {
      bytes = await Device.pickImage(camera: camera);
    } catch (e) {
      store.set(() => store.toast = e is MediaAccessException ? e.message : '$e');
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() { photo = bytes; issue = null; view = _AadhaarView.checking; });
    // Let the captain see the photo being checked, even when the check is quick.
    final results = await Future.wait<Object?>([checkPhotoQuality(bytes), Future<void>.delayed(const Duration(milliseconds: 2200))]);
    if (!mounted) return;
    final found = results.first as PhotoIssue?;
    if (found != null) {
      setState(() { issue = found; view = _AadhaarView.unclear; });
      return;
    }
    if (store.isLive) {
      try {
        await store.liveUploadKyc('aadhaar', bytes);
      } catch (_) {
        if (mounted) setState(() => view = _AadhaarView.start);
        return;
      }
    }
    if (mounted) setState(() => view = _AadhaarView.clear);
  }

  /// "Open DigiLocker". DigiLocker is P0: the live app photographs the card instead.
  Future<void> _digiLocker() async {
    final store = context.store, router = context.router;
    if (store.isLive) {
      await _pick(camera: true);
      return;
    }
    store.complete(KycStep.aadhaar);
    router.replace(const [R(N.steps)]);
  }

  void _continue() {
    context.store.complete(KycStep.aadhaar);
    context.router.replace(const [R(N.steps)]);
  }

  String _issueBadge(CaptainStore store) => switch (issue) {
        PhotoIssue.tooDark => store.t('Too dark', 'बहुत अंधेरा', 'చాలా చీకటి'),
        PhotoIssue.tooSmall => store.t('Too far', 'बहुत दूर', 'చాలా దూరం'),
        PhotoIssue.obscured => store.t('Covered', 'ढका हुआ', 'కప్పబడింది'),
        PhotoIssue.unreadable => store.t('Can’t read', 'पढ़ नहीं पाए', 'చదవలేకపోయాం'),
        null => store.t('Blurry', 'धुंधली', 'అస్పష్టం'),
      };

  /// The photo (or the card placeholder) in the 178-high frame of W05b.
  Widget _frame({required Color border, Widget? badge, bool dim = false, Widget? centre}) => Container(
        height: 178,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: WColor.photo, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 2)),
        child: Stack(fit: StackFit.expand, children: [
          if (photo != null) Image.memory(photo!, fit: BoxFit.cover) else const Center(child: WIconView(WIcon.idCard, size: 40, color: WColor.secondary)),
          if (dim) const ColoredBox(color: Color(0x8022282D)),
          ?centre,
          if (badge != null) Positioned(left: 12, top: 12, child: badge),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget tip(WIcon icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [WIconView(icon, size: 17, color: WColor.primaryStrong), const SizedBox(width: 12), WText(text, WType.bodyStrong, color: WColor.heading, size: 16.5)]));
    final footer = switch (view) {
      _AadhaarView.start => WButton(store.t('Open DigiLocker', 'DigiLocker खोलें', 'DigiLocker తెరవండి'), size: ButtonSize.captain, onTap: _digiLocker),
      _AadhaarView.checking => WButton(store.t('Checking…', 'जाँच रहे हैं…', 'చూస్తున్నాం…'), size: ButtonSize.captain, loading: true, enabled: false),
      _AadhaarView.clear => WButton(store.t('Continue', 'जारी रखें', 'కొనసాగించండి'), size: ButtonSize.captain, onTap: _continue),
      _AadhaarView.unclear => WButton(store.t('Take again', 'फिर से लें', 'మళ్ళీ తీయండి'), icon: WIcon.camera, size: ButtonSize.captain, onTap: _choose),
    };
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Aadhaar', 'आधार', 'ఆధార్')),
      footer: WFooter(child: footer),
      children: [
        const Padding(padding: EdgeInsets.only(top: 6), child: WSegmentBar(filled: 1, total: 5)),
        ...switch (view) {
          _AadhaarView.start => [
              const Padding(padding: EdgeInsets.only(top: 22), child: Align(alignment: Alignment.centerLeft, child: WIconView(WIcon.idCard, size: 26, color: WColor.primaryStrong))),
              WTitle(store.t('Verify Aadhaar', 'आधार सत्यापित करें', 'ఆధార్ ధృవీకరించండి'), top: 8),
              WBody(store.t('Fastest with DigiLocker. Takes 1 minute.', 'DigiLocker से सबसे जल्दी। 1 मिनट लगेगा।', 'DigiLocker తో వేగంగా. 1 నిమిషం పడుతుంది.'), top: 4, bottom: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [const WIconView(WIcon.shield, size: 17), const SizedBox(width: 12), Expanded(child: WText(store.t('We only see your name, photo and age.', 'हम सिर्फ़ आपका नाम, फ़ोटो और उम्र देखते हैं।', 'మేము మీ పేరు, ఫోటో, వయసు మాత్రమే చూస్తాము.'), WType.caption, color: WColor.heading, size: 14.5))]),
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: WButton(store.t('Upload Aadhaar photo', 'आधार की फ़ोटो अपलोड करें', 'ఆధార్ ఫోటో అప్‌లోడ్ చేయండి'), kind: ButtonKind.text, fullWidth: false, onTap: _choose)),
            ],
          _AadhaarView.checking => [
              WTitle(store.t('Checking your photo', 'आपकी फ़ोटो जाँच रहे हैं', 'మీ ఫోటో చూస్తున్నాం'), top: 22),
              WBody(store.t('Making sure the card is clear and readable. This takes a few seconds.', 'देख रहे हैं कि कार्ड साफ़ और पढ़ने लायक है। कुछ सेकंड लगेंगे।', 'కార్డు స్పష్టంగా, చదవగలిగేలా ఉందో చూస్తున్నాం. కొన్ని సెకన్లు పడుతుంది.'), top: 6, bottom: 16),
              _frame(
                border: WColor.primary,
                dim: true,
                centre: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const WSpinner(color: WColor.white, size: 30),
                  const SizedBox(height: 12),
                  WText(store.t('Checking…', 'जाँच रहे हैं…', 'చూస్తున్నాం…'), WType.label, color: WColor.white, size: 15),
                ])),
              ),
              const SizedBox(height: 22),
              tip(WIcon.sun, store.t('Light', 'रोशनी', 'వెలుతురు')),
              tip(WIcon.idCard, store.t('All 4 corners', 'चारों कोने', 'నాలుగు మూలలు')),
              tip(WIcon.eye, store.t('Easy to read', 'पढ़ने लायक', 'చదవగలిగేలా')),
            ],
          _AadhaarView.clear => [
              WTitle(store.t('Photo is clear', 'फ़ोटो साफ़ है', 'ఫోటో స్పష్టంగా ఉంది'), top: 22),
              WBody(store.t('Your Aadhaar photo is added. Our team checks the details before you take jobs.', 'आपकी आधार फ़ोटो जुड़ गई। काम लेने से पहले हमारी टीम जानकारी जाँचेगी।', 'మీ ఆధార్ ఫోటో జత అయింది. మీరు పనులు తీసుకునే ముందు మా టీమ్ వివరాలు చూస్తుంది.'), top: 6, bottom: 16),
              _frame(border: WColor.success, badge: WBadge(store.t('Clear', 'साफ़', 'స్పష్టం'), tone: Tone.ok, icon: WIcon.check)),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: WButton(store.t('Use a different photo', 'दूसरी फ़ोटो लें', 'వేరే ఫోటో వాడండి'), kind: ButtonKind.text, fullWidth: false, onTap: _choose)),
            ],
          _AadhaarView.unclear => [
              WTitle(store.t('Photo is not clear', 'फ़ोटो साफ़ नहीं है', 'ఫోటో స్పష్టంగా లేదు'), top: 22, bottom: 16),
              _frame(border: WColor.destructive, badge: WBadge(_issueBadge(store), tone: Tone.error, icon: WIcon.close)),
              const SizedBox(height: 22),
              tip(WIcon.sun, store.t('Stand in light', 'रोशनी में खड़े हों', 'వెలుతురులో నిలబడండి')),
              tip(WIcon.idCard, store.t('All 4 corners inside', 'चारों कोने अंदर हों', 'నాలుగు మూలలు లోపల ఉండాలి')),
              tip(WIcon.close, store.t('No finger on the card', 'कार्ड पर उंगली न हो', 'కార్డుపై వేలు ఉండకూడదు')),
            ],
        },
        if (view != _AadhaarView.checking) const TestSkipButton(top: 10, step: KycStep.aadhaar),
      ],
    );
  }
}

// MARK: W06 Your photo (selfie)

class SelfieScreen extends StatelessWidget {
  const SelfieScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: WColor.camera,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(children: [
          WAppBar(title: store.t('Your photo', 'आपकी फ़ोटो', 'మీ ఫోటో'), trailing: null, dark: true, onLeading: router.pop, padding: const EdgeInsets.symmetric(horizontal: 4)),
          const Spacer(),
          SizedBox(
            width: 226,
            height: 296,
            child: CustomPaint(painter: _OvalPainter(), child: const Center(child: WIconView(WIcon.face, size: 60, color: Colors.white70))),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: WText(store.t('Face inside the oval. No cap, no mask.', 'चेहरा ओवल के अंदर। टोपी या मास्क नहीं।', 'ముఖం ఓవల్ లోపల. టోపీ, మాస్క్ వద్దు.'), WType.value, color: WColor.white, size: 16.5, align: TextAlign.center)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Pressable(
              label: 'Take photo',
              onTap: () async {
                if (store.isLive) {
                  final bytes = await Device.pickImage(camera: true, front: true).catchError((Object e) {
                    store.set(() => store.toast = e is MediaAccessException ? e.message : '$e');
                    return null;
                  });
                  if (bytes == null) return;
                  try {
                    await store.liveUploadKyc('selfie', bytes);
                  } catch (_) {
                    return;
                  }
                }
                store.complete(KycStep.photo);
                router.replace(const [R(N.steps)]);
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 5)),
                alignment: Alignment.center,
                child: Container(width: 66, height: 66, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
              ),
            ),
          ),
          const TestSkipButton(step: KycStep.photo, dark: true),
        ]),
      ),
    );
  }
}

class _OvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()..addOval(Offset.zero & s);
    final paint = Paint()
      ..color = WColor.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final m in p.computeMetrics()) {
      for (double d = 0; d < m.length; d += 13) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OvalPainter old) => false;
}

// MARK: W07 Get paid (bank or UPI)

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});
  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  int mode = 0;
  late String upi = context.store.isLive ? context.store.upi : 'raju.yadav@ybl';
  String account = '';

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Get paid', 'पैसे पाएं', 'డబ్బు పొందండి')),
      footer: WFooter(
        child: WButton(store.t('Save', 'सेव करें', 'సేవ్ చేయండి'), size: ButtonSize.captain, enabled: mode == 0 ? upi.contains('@') : account.length >= 9, onTap: () async {
          if (store.isLive) {
            try { await store.liveSavePayout(upi:upi.trim(),accountNumber:mode==0?null:account); }
            catch(_) { return; }
            if(!context.mounted)return;
          }
          store.set(() => store.upi = upi.trim());
          store.complete(KycStep.bank);
          router.replace(const [R(N.steps)]);
        }),
      ),
      children: [
        const Padding(padding: EdgeInsets.only(top: 6), child: WSegmentBar(filled: 3, total: 5)),
        const Padding(padding: EdgeInsets.only(top: 22), child: Align(alignment: Alignment.centerLeft, child: WIconView(WIcon.rupee, size: 24, color: WColor.primaryStrong))),
        WTitle(store.t('Where should we send money?', 'पैसे कहाँ भेजें?', 'డబ్బు ఎక్కడికి పంపాలి?'), top: 8, bottom: 18),
        WSegmented(options: ['UPI', store.t('Bank account', 'बैंक खाता', 'బ్యాంక్ ఖాతా')], selection: mode, onChanged: (i) => setState(() => mode = i), height: 54),
        const SizedBox(height: 22),
        if (mode == 0) ...[
          WTextField(label: 'UPI ID', value: upi, placeholder: 'name@bank', large: true, onChanged: (v) => setState(() => upi = v)),
          if (upi.contains('@') && (!store.isLive || (store.liveCaptain['payout']?['verifiedName'] != null && store.liveCaptain['payout']?['upi']==upi.trim())))
            Container(
              margin: const EdgeInsets.only(top: 20),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const WIconView(WIcon.check, size: 15, color: WColor.onSuccess),
                const SizedBox(width: 10),
                WRich([(store.t('Name matches: ', 'नाम मिलता है: ', 'పేరు సరిపోయింది: '), null), (store.isLive ? store.liveCaptain['payout']['verifiedName'] as String : 'RAJU YADAV', bold)], WType.caption, color: WColor.onSuccess, size: 14.5),
              ]),
            ),
        ] else
          WTextField(label: store.t('Account number', 'खाता नंबर', 'ఖాతా నంబర్'), value: account, placeholder: '0000 0000 0000', keyboard: TextInputType.number, large: true, onChanged: (v) => setState(() => account = v)),
        const TestSkipButton(top: 18, step: KycStep.bank),
      ],
    );
  }
}

// MARK: W08 Training videos

String _trainingDuration(CaptainStore store,int index){
  final videos=store.liveConfig['training']?['videos'] as List? ?? [];
  return videos.length>index&&videos[index]['seconds'] is num?'${((videos[index]['seconds'] as num)/60).ceil()} min':'—';
}
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final videos = [
      (store.t('Car wash: step by step', 'कार धुलाई: एक-एक कदम', 'కార్ వాష్: దశలవారీగా'), store.isLive?_trainingDuration(store,0):'4 min'),
      (store.t('Bike wash', 'बाइक धुलाई', 'బైక్ వాష్'), store.isLive?_trainingDuration(store,1):'3 min'),
      (store.t('Do’s and don’ts', 'क्या करें, क्या नहीं', 'చేయాల్సినవి, చేయకూడనివి'), store.isLive?_trainingDuration(store,2):'2 min'),
    ];
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Training', 'ट्रेनिंग', 'శిక్షణ'), subtitle: store.langName),
      footer: WFooter(
        child: store.videosWatched >= 3
            ? WButton(store.t('Start quiz', 'क्विज़ शुरू करें', 'క్విజ్ ప్రారంభించండి'), size: ButtonSize.captain, onTap: () {
                store.complete(KycStep.training);
                router.go(N.quiz);
              })
            : WButton(store.t('Watch next', 'अगला देखें', 'తదుపరి చూడండి'), icon: WIcon.play, size: ButtonSize.captain, onTap: () => router.push(R(N.video, index: store.videosWatched))),
      ),
      children: [
        const Padding(padding: EdgeInsets.only(top: 6), child: WSegmentBar(filled: 4, total: 5)),
        WTitle(store.t('Watch 3 short videos', '3 छोटे वीडियो देखें', '3 చిన్న వీడియోలు చూడండి'), top: 20),
        WBody(store.t('Then a 2-minute quiz.', 'फिर 2 मिनट का क्विज़।', 'తర్వాత 2 నిమిషాల క్విజ్.'), top: 4, bottom: 18),
        for (final (i, v) in videos.indexed) ...[
          Pressable(
            onTap: () {
              if (i <= store.videosWatched) router.push(R(N.video, index: i));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: outlinedDecoration(radius: 14),
              child: Row(children: [
                Container(width: 96, height: 64, decoration: BoxDecoration(color: WColor.inverse, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const WIconView(WIcon.play, size: 22, color: WColor.white)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [WText(v.$1, WType.title, size: 16.5), const SizedBox(height: 2), WText(v.$2, WType.caption)])),
                const SizedBox(width: 4),
                if (i < store.videosWatched)
                  Container(width: 32, height: 32, decoration: const BoxDecoration(color: WColor.success, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.check, size: 14, color: WColor.onSuccess, weight: bold))
                else if (i == store.videosWatched)
                  WBadge(store.t('Watch', 'देखें', 'చూడండి'), tone: Tone.info, icon: WIcon.check)
                else
                  Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.muted)), alignment: Alignment.center, child: const WIconView(WIcon.lock, size: 13, color: WColor.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const TestSkipButton(top: 8, step: KycStep.training),
      ],
    );
  }
}

// MARK: W09 Video player

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.index});
  final int index;
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with WidgetsBindingObserver {
  double progress = 0;
  bool playing = true, _started = false, _sending = false, _opening=false;
  VideoPlayerController? _player;
  Map<String,dynamic>? _session;
  Timer? _timer;
  @override void didChangeDependencies(){
    super.didChangeDependencies();
    if(_started)return;
    _started=true;
    WidgetsBinding.instance.addObserver(this);
    if(context.store.isLive){_open();}else{
      _timer=Timer.periodic(const Duration(milliseconds:100),(_){if(mounted&&playing&&progress<1)setState(()=>progress=(progress+1/60).clamp(0,1));});
    }
  }
  Future<void> _open() async {
    if(_opening)return;
    _opening=true;
    final store=context.store;
    try{
      final session=await store.live!.call('startCaptainTraining',{'index':widget.index});
      if(!mounted)return;
      await _player?.dispose();
      final player=VideoPlayerController.networkUrl(Uri.parse(session['url'] as String));
      _player=player;
      await player.initialize();
      if(!mounted)return;
      final seconds=(session['seconds'] as num).toDouble();
      if((player.value.duration.inMilliseconds/1000-seconds).abs()>3)throw StateError('Training duration needs an operations review.');
      _session=session;
      await player.seekTo(Duration(milliseconds:((session['watchedSeconds'] as num).toDouble()*1000).round()));
      player.addListener(_playerChanged);
      await player.play();
      _timer?.cancel();
      _timer=Timer.periodic(const Duration(seconds:10),(_){if(Device.appIsActive)_heartbeat();});
      setState((){playing=true;progress=((session['watchedSeconds'] as num)/seconds).clamp(0,.999);});
    }catch(e){if(mounted){store.set(()=>store.toast=backendError(e));setState(()=>playing=false);}}
    finally{_opening=false;}
  }
  void _playerChanged(){
    if(!mounted||_player==null)return;
    final v=_player!.value;
    if(v.hasError)return;
    if(v.duration>Duration.zero&&v.position>=v.duration&&progress<1)_heartbeat();
  }
  Future<void> _heartbeat()async{
    final player=_player,session=_session;
    if(!mounted||_sending||session==null||player==null||!Device.appIsActive)return;
    _sending=true;
    try{
      final result=await context.store.live!.call('recordTrainingProgress',{'index':widget.index,'session':session['session'],'positionSeconds':player.value.position.inMilliseconds/1000});
      if(mounted)setState(()=>progress=result['completed']==true?1:((result['watchedSeconds'] as num)/(session['seconds'] as num)).clamp(0,.999));
    }catch(e){if(mounted)context.store.set(()=>context.store.toast=backendError(e));}
    finally{_sending=false;}
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed){_player?.pause();if(mounted)setState(()=>playing=false);}}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_timer?.cancel();_player?.removeListener(_playerChanged);_player?.dispose();super.dispose();}

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final titles = [store.t('Car wash', 'कार धुलाई', 'కార్ వాష్'), store.t('Bike wash', 'बाइक धुलाई', 'బైక్ వాష్'), store.t('Do’s and don’ts', 'क्या करें, क्या नहीं', 'చేయాల్సినవి')];
    Widget point(WIcon icon, String text) => Padding(padding: const EdgeInsets.only(top: 14), child: Row(children: [WIconBox(icon, size: 40, radius: 20), const SizedBox(width: 14), Expanded(child: WText(text, WType.bodyStrong, color: WColor.heading, size: 16.5))]));
    return WScreen(
      gutter: 0,
      header: WHeader(title: titles[widget.index.clamp(0, 2)]),
      footer: WFooter(
        child: WButton(store.t('Next video', 'अगला वीडियो', 'తదుపరి వీడియో'), size: ButtonSize.captain, enabled: progress >= 1, onTap: () {
          store.set(() => store.videosWatched = store.videosWatched > widget.index + 1 ? store.videosWatched : widget.index + 1);
          router.pop();
        }),
      ),
      children: [
        Container(
          height: 202,
          color: WColor.camera,
          child: Stack(children: [
            if(_player?.value.isInitialized==true) Positioned.fill(child:Center(child:AspectRatio(aspectRatio:_player!.value.aspectRatio,child:VideoPlayer(_player!)))),
            Center(
              child: Pressable(
                label: playing ? 'Pause' : 'Play',
                onTap: () {
                  if(store.isLive){
                    final player=_player;
                    if(player==null||!player.value.isInitialized){_open();return;}
                    if(player.value.isPlaying){player.pause();_heartbeat();}else{player.play();}
                  }
                  setState(() => playing = !playing);
                },
                child: Container(width: 72, height: 72, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24), alignment: Alignment.center, child: WIconView(playing ? WIcon.pause : WIcon.play, size: 26, color: WColor.white)),
              ),
            ),
            Positioned(left: 12, right: 12, bottom: 14, child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: progress, minHeight: 4, color: WColor.primary, backgroundColor: Colors.white30))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(store.t('In this video', 'इस वीडियो में', 'ఈ వీడియోలో'), WType.section, weight: semibold),
            point(WIcon.bucket, store.t('Clean water, clean bucket', 'साफ़ पानी, साफ़ बाल्टी', 'శుభ్రమైన నీరు, శుభ్రమైన బకెట్')),
            point(WIcon.wipe, store.t('Wet cloth first, then dry', 'पहले गीला कपड़ा, फिर सूखा', 'ముందు తడి గుడ్డ, తర్వాత పొడి')),
            point(WIcon.close, store.t('Never wipe a dry, dusty bike', 'सूखी, धूल भरी बाइक कभी न पोंछें', 'పొడి, దుమ్ము బైక్‌ను ఎప్పుడూ తుడవకండి')),
            Padding(padding: const EdgeInsets.only(top: 18), child: WText(store.t('Must watch till the end. You can’t skip.', 'आख़िर तक देखना ज़रूरी है। छोड़ नहीं सकते।', 'చివరి వరకు చూడాలి. దాటవేయలేరు.'), WType.caption)),
            const TestSkipButton(top: 14, step: KycStep.training),
          ]),
        ),
      ],
    );
  }
}

// MARK: W10 Quiz

typedef _Opt = (String, String, String, WIcon);

class _Q {
  const _Q(this.text, this.a, this.b, this.right);
  final (String, String, String) text;
  final _Opt a;
  final _Opt b;
  final int right;
}

const _questions = [
  _Q(('Where do you take before photos?', 'पहले की फ़ोटो कहाँ लेते हैं?', 'ముందు ఫోటోలు ఎక్కడ తీస్తారు?'), ('At the vehicle', 'गाड़ी के पास', 'వాహనం దగ్గర', WIcon.car), ('At home', 'घर पर', 'ఇంట్లో', WIcon.home), 0),
  _Q(('The bike is dusty. What do you do first?', 'बाइक पर धूल है। पहले क्या करेंगे?', 'బైక్ దుమ్ముగా ఉంది. ముందు ఏం చేస్తారు?'), ('Pour water', 'पानी डालें', 'నీళ్ళు పోయండి', WIcon.drop), ('Wipe with dry cloth', 'सूखे कपड़े से पोंछें', 'పొడి గుడ్డతో తుడవండి', WIcon.wipe), 0),
  _Q(('Can you use soap?', 'क्या साबुन लगा सकते हैं?', 'సబ్బు వాడవచ్చా?'), ('Yes', 'हाँ', 'అవును', WIcon.check), ('No, water only', 'नहीं, सिर्फ़ पानी', 'లేదు, నీళ్ళు మాత్రమే', WIcon.bucket), 1),
  _Q(('Owner wants to pay cash. You…', 'मालिक नकद देना चाहे तो…', 'యజమాని నగదు ఇవ్వాలనుకుంటే…'), ('Say no, app only', 'मना करें, सिर्फ़ ऐप', 'వద్దు అనండి, యాప్ మాత్రమే', WIcon.ban), ('Take it', 'ले लें', 'తీసుకోండి', WIcon.rupee), 0),
  _Q(('You’ll be 10 minutes late. You…', 'आप 10 मिनट लेट होंगे तो…', 'మీరు 10 నిమిషాలు ఆలస్యం అయితే…'), ('Tell the app', 'ऐप में बताएं', 'యాప్‌లో చెప్పండి', WIcon.phone), ('Say nothing', 'कुछ न कहें', 'ఏమీ చెప్పకండి', WIcon.close), 0),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
  int q = 0;
  int? pick;
  int correct = 0;
  final List<int> _answers=[];
  bool _submitting=false;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed)_speech.cancel();}
  final _speech=SpeechToText();
  bool _listening=false,_startingSpeech=false;
  Future<void> _answerByVoice()async{
    if(_startingSpeech||pick!=null)return;
    if(_speech.isListening){await _speech.stop();return;}
    _startingSpeech=true;
    final store=context.store,question=q;
    try{
      final available=await _speech.initialize(onStatus:(status){if(mounted)setState(()=>_listening=status=='listening');},onError:(_){if(mounted){setState(()=>_listening=false);store.set(()=>store.toast='Speech is unavailable. Check microphone and speech access, or tap an answer.');}});
      if(!mounted)return;
      if(!available){store.set(()=>store.toast='Speech is unavailable on this device. Tap an answer.');return;}
      final locales=await _speech.locales(),language=store.lang.name;
      if(!mounted)return;
      final locale=locales.where((l)=>l.localeId.replaceAll('_','-').toLowerCase()=='$language-in').firstOrNull??locales.where((l)=>l.localeId.toLowerCase().startsWith(language)).firstOrNull;
      if(locale==null){store.set(()=>store.toast='Speech for this language is unavailable. Tap an answer.');return;}
      await _speech.listen(listenOptions:SpeechListenOptions(localeId:locale.localeId,listenFor:const Duration(seconds:10),pauseFor:const Duration(seconds:2),partialResults:false,cancelOnError:true),onResult:(result){
        if(!mounted||q!=question||pick!=null||!result.finalResult)return;
        final current=_questions[question],choice=spokenAnswer(result.recognizedWords,[store.t(current.a.$1,current.a.$2,current.a.$3),store.t(current.b.$1,current.b.$2,current.b.$3)]);
        if(choice==null){store.set(()=>store.toast='Say one of the two answers, or tap it.');return;}
        setState(()=>pick=choice);Device.buzz(choice!=current.right);
      });
    }catch(_){if(mounted)store.set(()=>store.toast='Speech could not start. Tap an answer or try again.');}
    finally{_startingSpeech=false;}
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_speech.cancel();super.dispose();}

  /// Once answered, the choice locks: the right option turns green (with a tick), a wrong pick
  /// turns red so the captain sees what the correct answer was.
  Widget _option(int i, _Opt o, int right) {
    final store = context.store;
    final answered = pick != null, isRight = i == right, picked = pick == i;
    final tone = !answered ? WColor.border : (isRight ? WColor.success : (picked ? WColor.destructive : WColor.border));
    final fill = !answered ? WColor.white : (isRight ? WColor.successTint : (picked ? WColor.errorTint : WColor.white));
    return Expanded(
      child: Pressable(
        enabled: !(answered && !picked && !isRight),
        onTap: () {
          if (pick != null) return;
          setState(() => pick = i);
          Device.buzz(!isRight);
        },
        child: Opacity(
          opacity: answered && !isRight && !picked ? 0.55 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 142,
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: tone, width: answered && (isRight || picked) ? 3 : 1)),
            child: Stack(children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: answered ? WColor.white : WColor.primaryTint), alignment: Alignment.center, child: WIconView(o.$4, size: 24, color: WColor.primaryStrong)),
                  const SizedBox(height: 12),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: WText(store.t(o.$1, o.$2, o.$3), WType.title, size: 16, align: TextAlign.center)),
                ]),
              ),
              if (answered && (isRight || picked))
                Positioned(
                  top: 10,
                  right: 10,
                  child: FadeIn(
                    offset: 0,
                    child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: isRight ? WColor.success : WColor.destructive), alignment: Alignment.center, child: WIconView(isRight ? WIcon.check : WIcon.close, size: 13, color: WColor.white, weight: bold)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final cur = _questions[q];
    final ok = pick == cur.right;
    final rightOpt = cur.right == 0 ? cur.a : cur.b;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Quiz', 'क्विज़', 'క్విజ్'), subtitle: store.t('Question ${q + 1} of 5', 'प्रश्न ${q + 1} / 5', 'ప్రశ్న ${q + 1} / 5')),
      footer: WFooter(
        child: WButton(store.t('Next', 'आगे', 'తదుపరి'), size: ButtonSize.captain, enabled: pick != null && !_submitting, onTap: () async {
          final c = correct + (pick == cur.right ? 1 : 0);
          if (q < 4) {
            setState(() {
              _answers.add(pick!);
              correct = c;
              q++;
              pick = null;
            });
          } else {
            var passed = c >= 4;
            if(store.isLive){
              setState(()=>_submitting=true);
              try{final result=await store.live!.call('submitTrainingQuiz',{'version':'wash-safety-1','answers':[..._answers,pick!]});passed=result['passed']==true;}
              catch(e){store.set(()=>store.toast=backendError(e));return;}
              finally{if(mounted)setState(()=>_submitting=false);}
              if(!mounted)return;
            }
            if (passed && !store.isLive) store.complete(KycStep.quiz);
            router.push(R(N.quizResult, flag: passed));
          }
        }),
      ),
      children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: WSegmentBar(filled: q + 1, total: 5)),
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WIconBox(WIcon.refresh, size: 52, radius: 26),
            const SizedBox(width: 14),
            Expanded(child: WText(store.t(cur.text.$1, cur.text.$2, cur.text.$3), WType.section, weight: semibold, size: 20)),
          ]),
        ),
        Row(children: [_option(0, cur.a, cur.right), const SizedBox(width: 12), _option(1, cur.b, cur.right)]),
        if (pick != null)
          FadeIn(
            child: Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ok ? WColor.successTint : WColor.errorTint, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WIconView(ok ? WIcon.checkCircle : WIcon.warning, size: 22, color: ok ? WColor.success : WColor.destructive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    WText(ok ? store.t('Correct!', 'सही जवाब!', 'సరైన జవాబు!') : store.t('Not quite', 'सही नहीं', 'సరైనది కాదు'), WType.title, size: 17, color: ok ? WColor.onSuccess : WColor.destructive),
                    if (!ok) ...[
                      const SizedBox(height: 3),
                      WText(store.t('The right answer is: ${rightOpt.$1}', 'सही जवाब है: ${rightOpt.$2}', 'సరైన జవాబు: ${rightOpt.$3}'), WType.body, color: WColor.heading),
                    ],
                  ]),
                ),
              ]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(children: [
              Pressable(label: _listening?'Stop listening':'Say your answer',onTap:_answerByVoice, child: Container(width: 80, height: 80, decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle), alignment: Alignment.center, child: const WIconView(WIcon.mic, size: 30, color: WColor.white))),
              const SizedBox(height: 8),
              WText(store.t('Or tap and say your answer', 'या टैप करके जवाब बोलें', 'లేదా నొక్కి జవాబు చెప్పండి'), WType.caption),
            ]),
          ),
        const TestSkipButton(top: 20, step: KycStep.quiz),
      ],
    );
  }
}

// MARK: W11 Passed (W11b failed)

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key, required this.passed});
  final bool passed;
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      footer: passed ? WFooter(child: WButton(store.t('See the rules', 'नियम देखें', 'నియమాలు చూడండి'), size: ButtonSize.captain, onTap: () => router.go(N.rules))) : null,
      children: [
        Expanded(
          child: passed
              ? WFullState(icon: WIcon.check, tone: Tone.ok, captain: true, title: store.t('Passed! 5 of 5', 'पास! 5 में से 5', 'పాస్! 5 లో 5'), message: store.t('Next: the rules. Then we verify you.', 'आगे: नियम। फिर हम आपकी जाँच करेंगे।', 'తర్వాత: నియమాలు. ఆపై మిమ్మల్ని ధృవీకరిస్తాము.'))
              : WFullState(
                  icon: WIcon.refresh,
                  tone: Tone.wait,
                  captain: true,
                  title: store.t('3 of 5. Almost!', '5 में से 3. लगभग!', '5 లో 3. దాదాపు!'),
                  message: store.t('Watch the bike video again, then try the quiz once more.', 'बाइक वाला वीडियो फिर देखें, फिर दोबारा क्विज़ दें।', 'బైక్ వీడియో మళ్ళీ చూసి, మళ్ళీ క్విజ్ ప్రయత్నించండి.'),
                  primary: store.t('Watch again', 'फिर से देखें', 'మళ్ళీ చూడండి'),
                  primaryIcon: WIcon.play,
                  onPrimary: () => router.replace(const [R(N.video, index: 1)]),
                ),
        ),
      ],
    );
  }
}

// MARK: W12 Rules

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget rule(WIcon icon, String big, Tone tone, String text) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            WIconView(icon, size: 22, color: tone == Tone.ok ? WColor.heading : tone.foreground),
            const SizedBox(width: 14),
            SizedBox(width: 70, child: WText(big, WType.section, weight: bold, color: tone == Tone.error ? WColor.destructive : (tone == Tone.info ? WColor.primaryStrong : WColor.heading))),
            Expanded(child: WText(text, WType.caption, color: WColor.heading, size: 14.5)),
          ]),
        );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Rules', 'नियम', 'నియమాలు')),
      footer: WFooter(child: WButton(store.t('I agree', 'मैं सहमत हूँ', 'నేను అంగీకరిస్తున్నాను'), icon: WIcon.check, size: ButtonSize.captain, onTap: () async {
        final router = context.router;
        // Live: agreeing sends the application for review.
        if (store.isLive) {
          // TESTING (remove with onboardingSkip): skipped stages were never sent to the server,
          // so it would refuse the application. Don't send it; move on so the flow can be tested.
          if (store.testSkipped.isNotEmpty) {
            store.set(() => store.toast = 'Testing: you skipped steps, so the application was not sent.');
          } else {
            // The server needs both photos; say so instead of its generic error.
            if (!store.kycUploaded.contains('aadhaar') || !store.kycUploaded.contains('selfie')) {
              store.set(() => store.toast = store.t('Upload your Aadhaar and selfie first.', 'पहले आधार और सेल्फ़ी अपलोड करें।', 'ముందు ఆధార్, సెల్ఫీ అప్‌లోడ్ చేయండి.'));
              router.replace(const [R(N.steps)]);
              return;
            }
            try {
              await store.liveSubmitApplication();
            } catch (_) {
              return;
            }
          }
        }
        store.startReview();
        // Documents sent and the review countdown runs: first set up the work profile.
        router.go(N.workSetup);
      })),
      children: [
        WTitle(store.t('How you earn here', 'यहाँ कमाई कैसे होती है', 'ఇక్కడ ఎలా సంపాదిస్తారు'), top: 10, bottom: 14),
        rule(WIcon.rupee, store.isLive?((store.liveConfig['vehicleTypes'] as List? ?? []).where((v)=>v['kind']=='hatchback').firstOrNull?['captainPayPaise'] is num?Fmt.rupees(((store.liveConfig['vehicleTypes'] as List).where((v)=>v['kind']=='hatchback').first['captainPayPaise'] as num).toInt()~/100):'—'):'₹116', Tone.ok, store.t('Your pay for a hatchback. Shown before you accept.', 'हैचबैक के लिए आपकी कमाई। स्वीकार करने से पहले दिखेगी।', 'హ్యాచ్‌బ్యాక్‌కు మీ సంపాదన. అంగీకరించే ముందు చూపిస్తాము.')),
        rule(WIcon.clock, store.isLive?'UPI':'12 AM', Tone.ok, store.isLive?'After owner approval, operations confirms the payout timing.':store.t('Paid to UPI the same night, after the owner approves', 'मालिक के मंज़ूर करने के बाद उसी रात UPI में', 'యజమాని ఆమోదించాక అదే రాత్రి UPI కి')),
        rule(WIcon.star, store.isLive?'★':'4★+', Tone.info, store.isLive?'Customers rate the wash after checking the photos.':store.t('Every wash must get 4 stars or more', 'हर धुलाई पर 4 या ज़्यादा स्टार चाहिए', 'ప్రతి వాష్‌కి 4 లేదా ఎక్కువ స్టార్లు రావాలి')),
        rule(WIcon.stopwatch, store.isLive?'—':'−₹1', Tone.error, store.isLive?'Any late-fee policy must be confirmed before live work.':store.t('For every minute late. Max 30% of pay.', 'हर मिनट देरी पर। ज़्यादा से ज़्यादा 30%।', 'ప్రతి నిమిషం ఆలస్యానికి. గరిష్టం 30%.')),
        rule(WIcon.ban, store.t('Out', 'बाहर', 'తొలగింపు'), Tone.error, store.t('Damage on purpose or taking customers outside the app', 'जानबूझकर नुकसान या ग्राहक को ऐप से बाहर ले जाना', 'కావాలని నష్టం లేదా కస్టమర్‌ను యాప్ బయటకు తీసుకెళ్ళడం')),
      ],
    );
  }
}

// MARK: Profile under review (pop-up on Home)
// Replaces the W13 review-call screen (removed 27 Oct). Shown on Home while the profile is
// not approved. The call option appears once the 30-minute automatic review time is over.

Future<void> showReviewNotice(BuildContext context) {
  final store = context.store;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: WColor.scrim,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => _ReviewNotice(store: store),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _ReviewNotice extends StatefulWidget {
  const _ReviewNotice({required this.store});
  final CaptainStore store;
  @override
  State<_ReviewNotice> createState() => _ReviewNoticeState();
}

class _ReviewNoticeState extends State<_ReviewNotice> {
  Timer? _tick;
  bool _closing = false;

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    widget.store.addListener(_approved);
  }

  /// Approved while the pop-up is open: close it (Home goes online by itself).
  void _approved() {
    if (widget.store.signedUp) _close();
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.store.removeListener(_approved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final left = store.callUnlocksIn;
    final mmss = '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: WSpace.gutter),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(28)),
        child: Material(
          color: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const WIconBox(WIcon.clock, size: 52, tone: Tone.wait, radius: 26),
            const SizedBox(height: 12),
            WText(store.t('Your profile is under review', 'आपकी प्रोफ़ाइल की जाँच हो रही है', 'మీ ప్రొఫైల్ పరిశీలనలో ఉంది'), WType.section, weight: semibold),
            const SizedBox(height: 12),
            WText(
              store.t(
                'We’re checking your documents. This usually takes up to 30 minutes. You’ll go online by yourself once it’s approved.',
                'हम आपके दस्तावेज़ जाँच रहे हैं। आमतौर पर 30 मिनट तक लगते हैं। मंज़ूरी मिलते ही आप अपने आप ऑनलाइन हो जाएंगे।',
                'మేము మీ పత్రాలు చూస్తున్నాం. సాధారణంగా 30 నిమిషాల వరకు పడుతుంది. ఆమోదం రాగానే మీరు ఆటోమేటిక్‌గా ఆన్‌లైన్ అవుతారు.',
              ),
              WType.body,
            ),
            const SizedBox(height: 18),
            if (left > Duration.zero)
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const WIconView(WIcon.phone, size: 17, color: WColor.secondary),
                  const SizedBox(width: 12),
                  Expanded(child: WText(store.t('Call option in', 'कॉल का विकल्प', 'కాల్ ఆప్షన్'), WType.caption, color: WColor.heading, size: 14.5)),
                  WText(mmss, WType.section, weight: semibold, mono: true),
                ]),
              )
            else
              WButton(store.t('Call our team', 'हमारी टीम को कॉल करें', 'మా టీమ్‌కి కాల్ చేయండి'), icon: WIcon.phone, size: ButtonSize.captain, onTap: () => Support.call()),
            const SizedBox(height: 12),
            WButton(store.t('OK', 'ठीक है', 'సరే'), kind: ButtonKind.text, size: ButtonSize.captain, onTap: _close),
            // TESTING ONLY (remove with onboardingSkip): skip the 30 minutes and go online.
            if (onboardingSkip)
              Center(
                child: Pressable(
                  label: 'Skip 30 min (testing)',
                  onTap: store.testSkipReview,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: WText('Skip 30 min (testing)', WType.label, size: 14, weight: semibold, color: WColor.secondary),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

