// The wash itself: owner's note, face check, before photos, camera, washing, after photos,
// photo check, sending and done. Ported from apps/ios/Captain/Screens/WashScreens.swift
// and OwnerNoteScreens.swift.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';
import 'parts.dart';

/// Before · Wash · After progress for a job.
class WashStageBar extends StatelessWidget {
  const WashStageBar({super.key, required this.stage});

  /// 0 before, 1 wash, 2 after
  final int stage;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WSegmentBar(
      filled: stage + 1,
      total: 3,
      labels: [store.t('Before', 'पहले', 'ముందు'), store.t('Wash', 'धुलाई', 'వాష్'), store.t('After', 'बाद में', 'తర్వాత')],
      greenUpTo: stage,
    );
  }
}

// MARK: W26n Owner's note (must listen once, right after "I'm at the vehicle")

class OwnerNoteScreen extends StatefulWidget {
  const OwnerNoteScreen({super.key});
  @override
  State<OwnerNoteScreen> createState() => _OwnerNoteScreenState();
}

class _OwnerNoteScreenState extends State<OwnerNoteScreen> {
  final player = NotePlayer.shared;

  @override
  void initState() {
    super.initState();
    // Auto-play only the first time, and only while this screen is really on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.store;
      if (store.ownerNoteHeard) return;
      player.reset();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || !context.router.isAt(N.ownerNote) || store.ownerNoteHeard || player.playing) return;
        player.play(store.lang);
      });
    });
  }

  @override
  void dispose() {
    if (player.playing) player.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    const bars = [10.0, 18, 28, 14, 22, 34, 16, 26, 12, 30, 20, 24];
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => WScreen(
        gutter: WSpace.gutterCaptain,
        scrolls: false,
        header: WHeader(title: store.t('Owner’s note', 'मालिक का संदेश', 'యజమాని నోట్')),
        footer: WFooter(
          child: WButton(store.t('Continue', 'आगे बढ़ें', 'కొనసాగించండి'), size: ButtonSize.captain, enabled: player.finishedOnce, onTap: () {
            player.stop();
            store.set(() => store.ownerNoteHeard = true);
            router.go(N.faceCheck);
          }),
        ),
        children: [
          const Spacer(),
          WText(store.t('Listen before you start', 'शुरू करने से पहले सुनें', 'మొదలుపెట్టే ముందు వినండి'), WType.section, weight: semibold, size: 22, align: TextAlign.center),
          const SizedBox(height: 18),
          WText('${store.current.owner} · ${store.current.society}', WType.body, align: TextAlign.center),
          const SizedBox(height: 18),
          // Big play / pause with a moving sound wave.
          Pulse(
            active: player.playing,
            duration: const Duration(milliseconds: 500),
            builder: (c, t) => Column(children: [
              Pressable(
                label: player.playing ? 'Pause' : 'Play owner’s note',
                onTap: () => player.playing ? player.stop() : player.play(store.lang),
                child: SizedBox(
                  width: 206,
                  height: 206,
                  child: Stack(alignment: Alignment.center, children: [
                    Transform.scale(scale: player.playing ? 1 + 0.08 * t : 1, child: Container(width: 190, height: 190, decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle))),
                    Container(width: 124, height: 124, decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle)),
                    WIconView(player.playing ? WIcon.pause : (player.finishedOnce ? WIcon.replay : WIcon.play), size: 44, color: WColor.white),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 36,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 24; i++)
                    Container(
                      width: 5,
                      height: player.playing ? bars[i % 12] * (0.6 + 0.4 * t) : bars[i % 12] * 0.6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: ShapeDecoration(color: i / 24 < player.progress ? WColor.primary : WColor.border, shape: const StadiumBorder()),
                    ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          WText(
            player.finishedOnce
                ? store.t('Done. You can play it again anytime from the side button.', 'हो गया। साइड बटन से कभी भी फिर सुन सकते हैं।', 'అయింది. పక్క బటన్ నుండి ఎప్పుడైనా మళ్ళీ వినవచ్చు.')
                : store.t('Listen till the end to continue.', 'आगे बढ़ने के लिए पूरा सुनें।', 'కొనసాగడానికి పూర్తిగా వినండి.'),
            WType.caption,
            align: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// MARK: W30 Quick face check

class FaceCheckScreen extends StatefulWidget {
  const FaceCheckScreen({super.key});
  @override
  State<FaceCheckScreen> createState() => _FaceCheckScreenState();
}

class _FaceCheckScreenState extends State<FaceCheckScreen> {
  bool checking = false;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      scrolls: false,
      header: WHeader(title: store.t('Quick check', 'जल्दी जाँच', 'త్వరిత తనిఖీ')),
      footer: WFooter(
        child: WButton(store.t('Open camera', 'कैमरा खोलें', 'కెమెరా తెరవండి'), icon: WIcon.camera, size: ButtonSize.captain, loading: checking, onTap: () async {
          setState(() => checking = true);
          await sleepMs(1200);
          if (!mounted) return;
          setState(() => checking = false);
          router.replace(const [R(N.goToVehicle), R(N.beforePhotos)]);
        }),
      ),
      children: [
        Expanded(
          child: WFullState(
            icon: WIcon.face,
            captain: true,
            spinning: checking,
            title: store.t('Show your face', 'अपना चेहरा दिखाएं', 'మీ ముఖం చూపించండి'),
            message: store.t('Only to check it’s you. Takes 2 seconds.', 'सिर्फ़ यह जाँचने के लिए कि आप ही हैं। 2 सेकंड लगेंगे।', 'అది మీరేనని చూడటానికి మాత్రమే. 2 సెకన్లు.'),
          ),
        ),
      ],
    );
  }
}

// MARK: W31 Before photos · W35 After photos

class JobPhotosScreen extends StatelessWidget {
  const JobPhotosScreen({super.key, this.after = false});
  final bool after;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final done = after ? store.afterDone : store.beforeDone;
    Widget slot(int i) => done.contains(i)
        ? WPhotoSlot(label: sideName(store, i), state: PhotoState.done, tag: after ? store.t('After', 'बाद', 'తర్వాత') : store.t('Before', 'पहले', 'ముందు'), tagTone: after ? Tone.ok : Tone.mute, height: 112)
        : Pressable(
            onTap: () => router.push(R(N.camera, flag: after, index: i)),
            child: DashedBorder(
              child: SizedBox(
                height: 136,
                width: double.infinity,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const WIconView(WIcon.camera, size: 24, color: WColor.primaryStrong),
                  const SizedBox(height: 8),
                  WText(sideName(store, i), WType.title, color: WColor.primaryStrong, size: 17),
                ]),
              ),
            ),
          );
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.current.plate),
      footer: WFooter(
        child: after
            ? WButton(store.t('Check photos', 'फ़ोटो जाँचें', 'ఫోటోలు తనిఖీ చేయండి'), size: ButtonSize.captain, enabled: done.length == 4, onTap: () => router.go(store.aiFlag ? N.aiCheck : N.uploading))
            : WButton(store.t('Next', 'आगे', 'తదుపరి'), size: ButtonSize.captain, enabled: done.length == 4, onTap: () => router.go(N.washing)),
      ),
      children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: WashStageBar(stage: after ? 2 : 0)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: WTitle(after ? store.t('After photos', 'बाद की फ़ोटो', 'తర్వాతి ఫోటోలు') : store.t('Before photos', 'पहले की फ़ोटो', 'ముందు ఫోటోలు'))),
          const SizedBox(width: 6),
          const OwnerNoteButton(),
        ]),
        WBody(after ? store.t('Same 4 sides as before.', 'पहले जैसी ही 4 तरफ़।', 'ముందు లాగే 4 వైపులు.') : store.t('4 sides. Same as the outline.', '4 तरफ़। आउटलाइन जैसा।', '4 వైపులు. అవుట్‌లైన్ లాగే.'), top: 4, bottom: 16),
        for (final row in [
          [0, 1],
          [2, 3],
        ]) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: slot(row[0])), const SizedBox(width: 14), Expanded(child: slot(row[1]))]),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// MARK: W32 Camera (in-app, time and location stamped)

class JobCameraScreen extends StatelessWidget {
  const JobCameraScreen({super.key, required this.after, required this.side});
  final bool after;
  final int side;

  void _shoot(BuildContext context) {
    final store = context.store, router = context.router;
    if (store.darkPhoto && side == 2 && !after) {
      store.set(() => store.darkPhoto = false);
      router.swapTop(const R(N.photoDark));
      return;
    }
    store.set(() => (after ? store.afterDone : store.beforeDone).add(side));
    final done = after ? store.afterDone : store.beforeDone;
    final next = [0, 1, 2, 3].where((i) => !done.contains(i)).firstOrNull;
    if (next != null) {
      router.swapTop(R(N.camera, flag: after, index: next));
    } else {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final pad = MediaQuery.paddingOf(context);
    final sideView = side >= 2;
    return Material(
      color: WColor.camera,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Pressable(label: store.t('Close', 'बंद करें', 'మూసివేయండి'), onTap: router.pop, child: const SizedBox(width: 48, height: 48, child: Center(child: WIconView(WIcon.close, size: 18, color: Colors.white54)))),
              Expanded(child: WText(sideName(store, side) + (sideView ? store.t(' side', '', '') : ''), WType.section, color: WColor.white, weight: semibold, align: TextAlign.center)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const ShapeDecoration(color: WColor.primaryTint, shape: StadiumBorder()),
                child: WText('${side + 1} ${store.t('of', '/', '/')} 4', WType.label, color: WColor.primaryStrong),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Container(
                decoration: BoxDecoration(color: WColor.cameraPanel, borderRadius: BorderRadius.circular(16)),
                child: Stack(children: [
                  // Dotted guide matches the side: front and back views, or the side profile.
                  Center(child: CustomPaint(size: sideView ? const Size(270, 100) : const Size(240, 180), painter: CarShapePainter(side, dashed: true))),
                  Positioned(top: 12, left: 12, child: WBadge(store.t('At the vehicle', 'गाड़ी के पास', 'వాహనం దగ్గర'), tone: Tone.ok, icon: WIcon.location)),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Row(children: [
              const SizedBox(width: 60, child: Center(child: WIconView(WIcon.flash, size: 20, color: Colors.white38))),
              const Spacer(),
              Pressable(
                label: 'Take photo',
                onTap: () => _shoot(context),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 5)),
                  alignment: Alignment.center,
                  child: Container(width: 66, height: 66, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 60),
            ]),
          ),
        ]),
      ),
    );
  }
}

// MARK: W33 Photo too dark

class PhotoDarkScreen extends StatelessWidget {
  const PhotoDarkScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: sideName(store, 2) + store.t(' side', '', '')),
      footer: WFooter(child: WButton(store.t('Take again', 'फिर से लें', 'మళ్ళీ తీయండి'), icon: WIcon.camera, size: ButtonSize.captain, onTap: () => router.swapTop(const R(N.camera, index: 2)))),
      children: [
        const SizedBox(height: 8),
        Container(
          height: 216,
          decoration: BoxDecoration(color: const Color(0xFF2A3646), borderRadius: BorderRadius.circular(14), border: Border.all(color: WColor.destructive, width: 3)),
          child: Stack(children: [
            const Center(child: WIconView(WIcon.car, size: 44, color: Colors.white38)),
            Positioned(top: 12, left: 12, child: WBadge(store.t('Too dark', 'बहुत अंधेरा', 'చాలా చీకటి'), tone: Tone.error, icon: WIcon.sun)),
          ]),
        ),
        WTitle(store.t('Photo is too dark', 'फ़ोटो बहुत अंधेरी है', 'ఫోటో చాలా చీకటిగా ఉంది'), top: 22),
        WBody(store.t('Turn on flash or move your phone light closer.', 'फ़्लैश चालू करें या फ़ोन की लाइट पास लाएं।', 'ఫ్లాష్ ఆన్ చేయండి లేదా ఫోన్ లైట్ దగ్గరగా తీసుకురండి.'), top: 6),
      ],
    );
  }
}

// MARK: W34 Washing (W34b late)

class WashingScreen extends StatefulWidget {
  const WashingScreen({super.key});
  @override
  State<WashingScreen> createState() => _WashingScreenState();
}

class _WashingScreenState extends State<WashingScreen> {
  int seconds = 14 * 60 + 32;
  final done = <int>{};
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds > 0 && !context.store.lateWash) setState(() => seconds--);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _step(int i, WIcon icon, String title) {
    final on = done.contains(i);
    return Expanded(
      child: Pressable(
        onTap: () => setState(() => on ? done.remove(i) : done.add(i)),
        child: Container(
          height: 112,
          decoration: BoxDecoration(color: on ? WColor.successTint : WColor.canvas, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: on ? WColor.success : WColor.primaryTint, shape: BoxShape.circle), alignment: Alignment.center, child: WIconView(on ? WIcon.check : icon, size: 22, color: on ? WColor.onSuccess : WColor.primaryStrong)),
            const SizedBox(height: 10),
            WText(title, WType.title, size: 16.5),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final late = store.lateWash;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.current.plate),
      footer: WFooter(child: WButton(store.t('Done washing', 'धुलाई पूरी', 'వాష్ పూర్తైంది'), size: ButtonSize.captain, onTap: () => router.go(N.afterPhotos))),
      children: [
        const Padding(padding: EdgeInsets.only(top: 4), child: WashStageBar(stage: 1)),
        const Padding(padding: EdgeInsets.only(top: 12), child: Align(alignment: Alignment.centerRight, child: OwnerNoteButton())),
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 22),
          child: Column(children: [
            WText(late ? store.t('Should have finished 8:55 AM', '8:55 AM तक ख़त्म होना था', '8:55 AM కి పూర్తవ్వాలి') : store.t('Finish by 8:55 AM', '8:55 AM तक ख़त्म करें', '8:55 AM లోపు పూర్తి చేయండి'), WType.body, size: 16),
            const SizedBox(height: 8),
            WText(late ? '+6:10' : Fmt.clock(seconds), WType.hugeMoney, weight: bold, size: 64, mono: true, color: late ? WColor.destructive : WColor.heading),
            const SizedBox(height: 8),
            late ? WBadge(store.t('−₹6 so far', 'अब तक −₹6', 'ఇప్పటి వరకు −₹6'), tone: Tone.error, icon: WIcon.clock) : WBadge(store.t('On time', 'समय पर', 'సమయానికి'), tone: Tone.ok, icon: WIcon.check),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 22), child: BookingVisual(job: store.current)),
        if (late)
          WBanner(tone: Tone.wait, icon: WIcon.info, text: store.t('−₹1 for each late minute. Max ₹35 on this job.', 'हर लेट मिनट पर −₹1। इस काम पर ज़्यादा से ज़्यादा ₹35।', 'ప్రతి ఆలస్య నిమిషానికి −₹1. ఈ పనికి గరిష్టం ₹35.'))
        else ...[
          Padding(padding: const EdgeInsets.only(bottom: 8), child: WText(store.t('Steps', 'कदम', 'దశలు'), WType.label)),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(children: [
              store.current.wash.water ? _step(0, WIcon.bucket, store.t('Water', 'पानी', 'నీళ్ళు')) : _step(0, WIcon.wipe, store.t('Dust', 'धूल झाड़ें', 'దుమ్ము దులపండి')),
              const SizedBox(width: 10),
              _step(1, WIcon.wipe, store.t('Wipe', 'पोंछें', 'తుడవండి')),
              const SizedBox(width: 10),
              _step(2, WIcon.sparkle, store.t('Dry', 'सुखाएं', 'ఆరబెట్టండి')),
            ]),
          ),
        ],
      ],
    );
  }
}

// MARK: W36 AI photo check

class AiCheckScreen extends StatelessWidget {
  const AiCheckScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Photo check', 'फ़ोटो जाँच', 'ఫోటో తనిఖీ')),
      footer: Container(
        color: WColor.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          WFooter(
            child: WButton(store.t('Wipe and retake', 'पोंछें और फिर लें', 'తుడిచి మళ్ళీ తీయండి'), icon: WIcon.camera, size: ButtonSize.captain, onTap: () {
              store.set(() {
                store.aiFlag = false;
                store.afterDone.remove(2);
              });
              router.swapTop(const R(N.camera, flag: true, index: 2));
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WLink(store.t('It’s clean, send anyway', 'साफ़ है, फिर भी भेजें', 'శుభ్రంగా ఉంది, అయినా పంపండి'), onTap: () => router.swapTop(const R(N.uploading))),
          ),
        ]),
      ),
      children: [
        const SizedBox(height: 8),
        Container(
          height: 198,
          decoration: BoxDecoration(color: const Color(0xFF33445C), borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const WIconView(WIcon.car, size: 46, color: Colors.white54),
                Transform.translate(offset: const Offset(-6, 0), child: Container(width: 62, height: 62, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.star, width: 3)))),
              ]),
            ),
            Positioned(top: 12, left: 12, child: WBadge(store.t('Left mirror', 'बायाँ शीशा', 'ఎడమ అద్దం'), tone: Tone.wait, icon: WIcon.eye)),
          ]),
        ),
        WTitle(store.t('Left mirror looks dusty', 'बायाँ शीशा धूल भरा लग रहा है', 'ఎడమ అద్దం దుమ్ముగా ఉంది'), top: 22),
        WBody(store.t('Wipe it once more and take the left photo again.', 'एक बार और पोंछें और बाईं फ़ोटो फिर से लें।', 'మళ్ళీ ఒకసారి తుడిచి ఎడమ ఫోటో మళ్ళీ తీయండి.'), top: 6),
      ],
    );
  }
}

// MARK: W37 Sending photos

class UploadingScreen extends StatefulWidget {
  const UploadingScreen({super.key});
  @override
  State<UploadingScreen> createState() => _UploadingScreenState();
}

class _UploadingScreenState extends State<UploadingScreen> {
  var progress = [1.0, 1.0, 0.5, 0.55];

  @override
  void initState() {
    super.initState();
    () async {
      for (var i = 0; i < 20; i++) {
        await sleepMs(250);
        if (!mounted) return;
        setState(() => progress = [for (final p in progress) (p + 0.05).clamp(0, 1).toDouble()]);
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    Widget slot(int i) => WPhotoSlot(label: sideName(store, i), state: progress[i] >= 1 ? PhotoState.done : PhotoState.uploading, tag: store.t('After', 'बाद', 'తర్వాత'), tagTone: Tone.ok, height: 112);
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WHeader(title: store.t('Sending photos', 'फ़ोटो भेज रहे हैं', 'ఫోటోలు పంపుతోంది'), back: false),
      footer: WFooter(child: WButton(store.t('Next job', 'अगला काम', 'తదుపరి పని'), size: ButtonSize.captain, onTap: () => router.replace([R(N.jobDone, flag: store.lateWash)]))),
      children: [
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: slot(0)), const SizedBox(width: 14), Expanded(child: slot(1))]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: slot(2)), const SizedBox(width: 14), Expanded(child: slot(3))]),
        if (store.lowSignal || progress.any((p) => p < 1))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: WBanner(
              tone: Tone.wait,
              icon: WIcon.wifiOff,
              title: store.t('Weak signal.', 'कमज़ोर सिग्नल।', 'బలహీన సిగ్నల్.'),
              text: store.t('Photos are saved on your phone and will send by themselves. You can start the next job.', 'फ़ोटो फ़ोन में सेव हैं और अपने आप चली जाएंगी। आप अगला काम शुरू कर सकते हैं।', 'ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి, అవే పంపబడతాయి. మీరు తదుపరి పని మొదలుపెట్టవచ్చు.'),
            ),
          ),
      ],
    );
  }
}

// MARK: W38 Shine done (W38b late)

class JobDoneScreen extends StatelessWidget {
  const JobDoneScreen({super.key, this.late = false});
  final bool late;
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final pay = store.current.pay;
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: const SizedBox(height: 40),
      footer: WFooter(
        child: WButton(store.t('Next job', 'अगला काम', 'తదుపరి పని'), size: ButtonSize.captain, onTap: () {
          store.finishJob();
          store.set(() => store.lateWash = false);
          router.home();
          router.tab = 1;
        }),
      ),
      children: [
        const SizedBox(height: 50),
        Center(child: WStateCircle(late ? WIcon.clock : WIcon.sparkle, tone: late ? Tone.wait : Tone.ok, size: 112)),
        const SizedBox(height: 12),
        WText(late ? store.t('Done, 12 min late', 'हो गया, 12 मिनट लेट', 'పూర్తైంది, 12 నిమిషాలు ఆలస్యం') : store.t('Shine done!', 'चमक गई!', 'మెరిసింది!'), WType.section, weight: semibold, size: 24, align: TextAlign.center),
        const SizedBox(height: 12),
        WBody(
          late ? store.t('Try to start earlier next time.', 'अगली बार जल्दी शुरू करें।', 'తదుపరిసారి ముందుగా మొదలుపెట్టండి.') : store.t('Owner checks the photos. Money comes tonight before 12.', 'मालिक फ़ोटो देखेंगे। पैसे आज रात 12 बजे से पहले आएंगे।', 'యజమాని ఫోటోలు చూస్తారు. డబ్బు ఈ రాత్రి 12 లోపు వస్తుంది.'),
          center: true,
        ),
        const SizedBox(height: 26),
        if (late)
          WKeyValueCard(rows: [
            (store.t('Pay', 'कमाई', 'చెల్లింపు'), Fmt.rupees(pay)),
            (store.t('Late 12 min', '12 मिनट लेट', '12 నిమిషాల ఆలస్యం'), '−₹12'),
            (store.t('You get', 'आपको मिलेंगे', 'మీకు వచ్చేది'), Fmt.rupees(pay - 12)),
          ], boldLast: true)
        else
          WCard(
            padding: 20,
            child: Column(children: [
              WText(store.t('This job', 'यह काम', 'ఈ పని'), WType.caption),
              const SizedBox(height: 6),
              WText(Fmt.rupees(pay), WType.bigMoney, mono: true),
              const SizedBox(height: 6),
              WBadge(store.t('Waiting for owner', 'मालिक का इंतज़ार', 'యజమాని కోసం వేచి ఉంది'), tone: Tone.wait, icon: WIcon.clock),
            ]),
          ),
      ],
    );
  }
}
