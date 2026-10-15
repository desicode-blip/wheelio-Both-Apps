import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/store.dart';
import 'parts.dart';

// MARK: W01 Choose your language

class LangTile extends StatelessWidget {
  const LangTile({super.key, required this.lang, required this.glyph, required this.title, this.height = 78, this.onPick});
  final Lang lang;
  final String glyph;
  final String title;
  final double height;
  final VoidCallback? onPick;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final on = store.lang == lang;
    return Pressable(
      onTap: () {
        store.set(() => store.lang = lang);
        onPick?.call();
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: outlinedDecoration(radius: 16, fill: on ? WColor.primaryTint : WColor.white, stroke: on ? WColor.primary : WColor.border, width: on ? 2 : 1),
        child: Row(children: [
          SizedBox(width: 40, child: WText(glyph, WType.screen, size: 24, align: TextAlign.center)),
          const SizedBox(width: 18),
          Expanded(child: WText(title, WType.value, size: 18)),
          WRadio(on: on),
        ]),
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      footer: WFooter(child: WButton(store.t('Next', 'आगे', 'తదుపరి'), size: ButtonSize.captain, onTap: () => context.router.go(N.welcome))),
      children: [
        const SizedBox(height: 24),
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: WColor.primary, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 3)),
              alignment: Alignment.center,
              child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
            ),
          ),
          const SizedBox(width: 10),
          const WText(Brand.name, WType.screen, size: 25),
        ]),
        const SizedBox(height: 26),
        const Align(alignment: Alignment.centerLeft, child: WIconView(WIcon.translate, size: 24, color: WColor.primaryStrong)),
        const WTitle('Choose your language', top: 8),
        const Padding(padding: EdgeInsets.only(top: 2, bottom: 20), child: WText('भाषा चुनें · భాష ఎంచుకోండి', WType.caption)),
        const LangTile(lang: Lang.en, glyph: 'A', title: 'English'),
        const SizedBox(height: 12),
        const LangTile(lang: Lang.hi, glyph: 'अ', title: 'हिन्दी · Hindi'),
        const SizedBox(height: 12),
        const LangTile(lang: Lang.te, glyph: 'అ', title: 'తెలుగు · Telugu'),
      ],
    );
  }
}

// MARK: W00 Welcome: three slides, one idea each

enum WelcomeArtKind { freedom, nearHome, evening }

/// Big picture, two short lines, a quiet "Next". The dots double as the timer.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const slideMs = 3500;
  int index = 0;
  double progress = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _tick?.cancel();
    progress = 0;
    final started = DateTime.now();
    _tick = Timer.periodic(const Duration(milliseconds: 60), (t) {
      final p = (DateTime.now().difference(started).inMilliseconds / slideMs).clamp(0.0, 1.0);
      setState(() => progress = p);
      if (p >= 1) {
        t.cancel();
        if (index < 2) _go(index + 1);
      }
    });
  }

  void _go(int i) {
    setState(() => index = i.clamp(0, 2));
    _start();
  }

  void _enterApp() {
    context.store.set(() => context.store.exploring = true);
    context.router.home();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final slides = [
      (WelcomeArtKind.freedom, store.t('Work when you want', 'जब चाहें, काम करें', 'మీకు నచ్చినప్పుడు పని'), store.t('Morning, evening or both. You decide.', 'सुबह, शाम या दोनों। आप तय करें।', 'ఉదయం, సాయంత్రం లేదా రెండూ. మీ ఇష్టం.')),
      (WelcomeArtKind.nearHome, store.t('Jobs near your home', 'घर के पास काम', 'ఇంటి దగ్గరే పని'), store.t('Cars parked in buildings close to you.', 'आपके पास की बिल्डिंग में खड़ी गाड़ियाँ।', 'మీ దగ్గరి భవనాల్లో పార్క్ చేసిన కార్లు.')),
      (WelcomeArtKind.evening, store.t('Paid every night', 'हर रात पैसे', 'ప్రతి రాత్రి డబ్బు'), store.t('Straight to your UPI. No waiting.', 'सीधे आपके UPI में। कोई इंतज़ार नहीं।', 'నేరుగా మీ UPI కి. ఎదురుచూపు లేదు.')),
    ];
    final s = slides[index];
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: WColor.white,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom + 12),
        child: Column(children: [
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WSpace.gutterCaptain),
              child: Row(children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: index > 0 ? 1 : 0,
                  child: Pressable(
                    enabled: index > 0,
                    onTap: () => _go(index - 1),
                    child: SizedBox(height: 44, child: Row(children: [const WIconView(WIcon.left, size: 15, weight: semibold), const SizedBox(width: 4), WText(store.t('Back', 'पीछे', 'వెనక్కి'), WType.body, color: WColor.heading)])),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 8, WSpace.gutterCaptain, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(a), child: child)),
                child: WelcomeArt(key: ValueKey(index), kind: s.$1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 28, WSpace.gutterCaptain, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Column(key: ValueKey('t$index'), children: [
                WText(s.$2, WType.screen, size: 26, align: TextAlign.center),
                const SizedBox(height: 10),
                WText(s.$3, WType.body, size: 17, color: WColor.secondary, align: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          TimerDots(count: 3, index: index, progress: progress),
          Padding(
            padding: const EdgeInsets.fromLTRB(WSpace.gutterCaptain, 26, WSpace.gutterCaptain, 0),
            child: Row(children: [
              Pressable(onTap: _enterApp, child: SizedBox(height: 48, child: Center(child: WText(store.t('Skip', 'छोड़ें', 'దాటవేయి'), WType.body, color: WColor.secondary)))),
              const Spacer(),
              Pressable(
                onTap: () => index < 2 ? _go(index + 1) : _enterApp(),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  decoration: const ShapeDecoration(color: WColor.primaryTint, shape: StadiumBorder()),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    WText(store.t('Next', 'आगे', 'తదుపరి'), WType.title, color: WColor.primaryStrong, size: 17),
                    const SizedBox(width: 8),
                    const WIconView(WIcon.arrowRight, size: 15, color: WColor.primaryStrong, weight: semibold),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Slide pictures (drawn, gently animated; no money shown).
class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key, required this.kind});
  final WelcomeArtKind kind;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      WelcomeArtKind.freedom => const [Color(0xFFDCEBFF), Color(0xFFFFF3D6)],
      WelcomeArtKind.nearHome => const [Color(0xFFE3F6EE), Color(0xFFF4FBF7)],
      WelcomeArtKind.evening => const [Color(0xFF2B2F6B), Color(0xFF5A4E9A)],
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bg, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: LayoutBuilder(builder: (c, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Widget at(double x, double y, Widget child) => Positioned(left: w * x, top: h * y, child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child));
          Widget hill(double left, double width, double bottom, double height, Color color) =>
              Positioned(left: w * left, width: w * width, bottom: -h * bottom, height: h * height, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.all(Radius.elliptical(w * width / 2, h * height / 2)))));
          return Pulse(
            duration: const Duration(milliseconds: 2400),
            builder: (c, on) => Stack(children: switch (kind) {
              // A man with open arms on a hill at sunrise, birds drifting.
              WelcomeArtKind.freedom => [
                  at(0.72, 0.28, Transform.scale(scale: 0.94 + 0.14 * on, child: Container(width: w * 0.54, height: w * 0.54, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD27A).withValues(alpha: 0.35))))),
                  at(0.72, 0.28, Transform.scale(scale: 0.96 + 0.1 * on, child: Container(width: w * 0.36, height: w * 0.36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD27A))))),
                  at(0.24 + 0.06 * on, 0.22 - 0.04 * on, const WIconView(WIcon.bird, size: 22, color: Color(0xFF5E7087))),
                  at(0.38 + 0.06 * on, 0.15 - 0.03 * on, WIconView(WIcon.bird, size: 15, color: const Color(0xFF5E7087).withValues(alpha: 0.7))),
                  hill(-0.25, 1.5, 0.23, 0.5, const Color(0xFF8FD3A7)),
                  hill(-0.4, 1.1, 0.22, 0.36, const Color(0xFF6CC28F)),
                  at(0.48, 0.62, Transform.translate(offset: Offset(0, 4 - 8 * on), child: WIconView(WIcon.figure, size: h * 0.36, color: WColor.primaryStrong))),
                ],
              // A man walking a short path from home to the building next door.
              WelcomeArtKind.nearHome => [
                  at(0.76, 0.50, WIconView(WIcon.building, size: h * 0.34, color: const Color(0xFF9CC9B5))),
                  at(0.20, 0.58, WIconView(WIcon.homeFill, size: h * 0.20, color: const Color(0xFF6FB596))),
                  Positioned(left: 0, right: 0, bottom: 0, height: h * 0.25, child: const ColoredBox(color: Color(0xFFCBE9DA))),
                  Positioned.fill(child: CustomPaint(painter: _PathPainter())),
                  at(0.76, 0.20 - 0.03 * on, const WIconView(WIcon.location, size: 30, color: WColor.primary, weight: bold)),
                  at(0.42 + 0.14 * on, 0.64, WIconView(WIcon.walk, size: h * 0.26, color: WColor.primaryStrong)),
                ],
              // Home at night with family; the day's work is done.
              WelcomeArtKind.evening => [
                  at(0.78, 0.18, Transform.rotate(angle: -0.35, child: WIconView(WIcon.moon, size: h * 0.12, color: const Color(0xFFFFE6A8)))),
                  for (final (i, p) in const [(0.14, 0.14), (0.32, 0.26), (0.52, 0.10), (0.62, 0.30), (0.22, 0.38), (0.90, 0.40)].indexed)
                    at(p.$1, p.$2, Opacity(opacity: (i.isEven ? on : 1 - on) * 0.6 + 0.35, child: WIconView(WIcon.sparkleFill, size: i.isEven ? 14 : 10, color: WColor.white))),
                  hill(-0.2, 1.4, 0.21, 0.42, const Color(0xFF3D3A7E)),
                  at(0.46, 0.64, Transform.translate(offset: Offset(0, 2 - 4 * on), child: WIconView(WIcon.family, size: h * 0.34, color: WColor.white))),
                  // A soft "done" notification: the day's money has arrived (no amount shown).
                  at(0.24, 0.24, Transform.scale(
                    scale: 0.94 + 0.06 * on,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const ShapeDecoration(color: WColor.white, shape: StadiumBorder(), shadows: [BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, 4))]),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [WIconView(WIcon.checkCircle, size: 16, color: WColor.success), SizedBox(width: 8), WText('UPI', WType.label, size: 13, color: WColor.heading)]),
                    ),
                  )),
                ],
            }),
          );
        }),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width * 0.24, s.height * 0.76)
      ..quadraticBezierTo(s.width * 0.5, s.height * 0.84, s.width * 0.76, s.height * 0.76);
    final paint = Paint()
      ..color = const Color(0xFF6FB596)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final m in p.computeMetrics()) {
      for (double d = 0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, d + 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => false;
}

// MARK: Light sign-up: name, number (W02) → code (W03)

/// Shown when a guest wants to go online, or from the nudge / Me tab.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.login = false});
  final bool login;
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String name = '';
  String number = '';
  int focusNumber = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final login = widget.login;
    final valid = Validators.isValidMobile(number) && (login || Validators.isValidName(name));
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: login ? store.t('Log in', 'लॉग इन', 'లాగిన్') : store.t('Sign up', 'साइन अप', 'సైన్ అప్')),
      footer: WFooter(
        child: WButton(store.t('Get code', 'कोड भेजें', 'కోడ్ పొందండి'), size: ButtonSize.captain, enabled: valid, onTap: () {
          store.set(() {
            if (!login) store.name = name.trim();
            store.phone = Validators.digitsOnly(number);
          });
          context.router.push(R(N.otp, flag: login));
        }),
      ),
      children: [
        WTitle(login ? store.t('Welcome back', 'फिर से स्वागत है', 'మళ్ళీ స్వాగతం') : store.t('Save your spot', 'अपनी जगह पक्की करें', 'మీ స్థానం ఖాయం చేసుకోండి'), top: 10),
        WBody(
          login
              ? store.t('Enter your number. We send a code by SMS.', 'अपना नंबर डालें। हम SMS से कोड भेजेंगे।', 'మీ నంబర్ ఇవ్వండి. SMS ద్వారా కోడ్ పంపుతాము.')
              : store.t('Just your name and number for now. Documents come later, only when you take your first job.', 'अभी सिर्फ़ नाम और नंबर। कागज़ बाद में, जब आप पहला काम लेंगे।',
                  'ఇప్పుడు పేరు, నంబర్ మాత్రమే. పత్రాలు తర్వాత, మొదటి పని తీసుకున్నప్పుడు.'),
          top: 6,
          bottom: 22,
        ),
        if (!login) ...[
          // Name first (keyboard opens here), then Next moves to the number.
          WTextField(
            label: store.t('Your name', 'आपका नाम', 'మీ పేరు'),
            value: name,
            placeholder: 'Raju Yadav',
            caps: TextCapitalization.words,
            large: true,
            autofocus: true,
            action: TextInputAction.next,
            onSubmit: () => setState(() => focusNumber++),
            onChanged: (v) => setState(() => name = v),
          ),
          const SizedBox(height: 16),
        ],
        WPhoneField(number: number, large: true, autofocus: login, focusTrigger: focusNumber, onChanged: (v) => setState(() => number = v)),
        Padding(padding: const EdgeInsets.only(top: 12), child: WText(store.t('We send a code by SMS.', 'हम SMS से कोड भेजेंगे।', 'మేము SMS ద్వారా కోడ్ పంపుతాము.'), WType.caption)),
      ],
    );
  }
}

// MARK: W03 Enter the code

class WOtpScreen extends StatefulWidget {
  const WOtpScreen({super.key, this.login = false});
  final bool login;
  @override
  State<WOtpScreen> createState() => _WOtpScreenState();
}

class _WOtpScreenState extends State<WOtpScreen> {
  String code = '';
  bool reading = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // Demo: auto-read the SMS code like Android's SMS Retriever.
    var i = 0;
    _t = Timer.periodic(const Duration(milliseconds: 450), (t) {
      i++;
      setState(() => code = '381624'.substring(0, i));
      if (i >= 6) {
        t.cancel();
        setState(() => reading = false);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: widget.login ? store.t('Log in', 'लॉग इन', 'లాగిన్') : store.t('Sign up', 'साइन अप', 'సైన్ అప్')),
      footer: WFooter(
        child: WButton(store.t('Next', 'आगे', 'తదుపరి'), size: ButtonSize.captain, enabled: code.length == 6, onTap: () {
          // Demo: a returning captain has already done KYC.
          if (widget.login) store.signedUp = true;
          store.finishRegistration();
          context.router.home();
        }),
      ),
      children: [
        const Padding(padding: EdgeInsets.only(top: 14), child: Align(alignment: Alignment.centerLeft, child: WIconView(WIcon.chat, size: 24, color: WColor.primaryStrong))),
        WTitle(store.t('Enter the code', 'कोड डालें', 'కోడ్ నమోదు చేయండి'), top: 8),
        WBody('${store.t('Sent to', 'भेजा गया', 'పంపబడింది')} ${Fmt.phoneShort(store.phone)}', top: 4, bottom: 20),
        Align(alignment: Alignment.centerLeft, child: WOtpField(code: code, onChanged: (v) => setState(() => code = v), boxSize: 46, autofocus: false)),
        if (reading)
          Container(
            margin: const EdgeInsets.only(top: 20),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const WIconView(WIcon.check, size: 15),
              const SizedBox(width: 10),
              WText(store.t('Reading the code from SMS…', 'SMS से कोड पढ़ रहे हैं…', 'SMS నుండి కోడ్ చదువుతోంది…'), WType.caption, color: WColor.heading),
            ]),
          ),
      ],
    );
  }
}

// MARK: Nudge after looking around for a while

class SignUpNudge extends StatelessWidget {
  const SignUpNudge({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Column(children: [
      const SizedBox(height: 12),
      const WStateCircle(WIcon.sparkle, tone: Tone.ok, size: 84),
      const SizedBox(height: 14),
      WText(store.t('Like what you see?', 'पसंद आया?', 'నచ్చిందా?'), WType.section, weight: semibold, size: 22),
      const SizedBox(height: 14),
      WBody(store.t('Add your name and number to save your spot. It takes 30 seconds.', 'अपनी जगह पक्की करने के लिए नाम और नंबर डालें। 30 सेकंड लगेंगे।', 'మీ స్థానం ఖాయం చేసుకోవడానికి పేరు, నంబర్ ఇవ్వండి. 30 సెకన్లు చాలు.'), center: true),
      const Spacer(),
      WButton(store.t('Sign up', 'साइन अप करें', 'సైన్ అప్'), size: ButtonSize.captain, onTap: () {
        Navigator.of(context).pop();
        context.router.push(const R(N.signUp));
      }),
      WButton(store.t('Later', 'बाद में', 'తర్వాత'), kind: ButtonKind.text, onTap: () => Navigator.of(context).pop()),
    ]);
  }
}
