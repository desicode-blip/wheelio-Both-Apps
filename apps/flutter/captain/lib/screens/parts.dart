// Captain chrome and pieces used on several screens: header, footer, booking visuals,
// vehicle photos, the owner's note player, profile photo, bell, work-area chip, help ladder.

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../data/store.dart';

/// Captain header: back, title (+ subtitle), help.
class WHeader extends StatelessWidget {
  const WHeader({super.key, this.title = '', this.subtitle, this.back = true, this.help = true, this.onBack});
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final bool back;
  final bool help;
  @override
  Widget build(BuildContext context) => WAppBar(
        title: title,
        subtitle: subtitle,
        leading: back ? WIcon.left : null,
        trailing: help ? WIcon.help : null,
        onLeading: onBack ?? context.router.pop,
        onTrailing: () => context.router.go(N.help),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      );
}

/// Captain footer: one big action, full width. Support lives in Help.
class WFooter extends StatelessWidget {
  const WFooter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => WFooterBar(showCall: false, captain: true, child: child);
}

/// Bigger, plainer type for the captain app (low cognitive load).
class WTitle extends StatelessWidget {
  const WTitle(this.text, {super.key, this.top = 0, this.bottom = 0});
  final String text;
  final double top;
  final double bottom;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: top, bottom: bottom), child: WText(text, WType.screen, weight: bold, size: 27));
}

class WBody extends StatelessWidget {
  const WBody(this.text, {super.key, this.top = 0, this.bottom = 0, this.center = false});
  final String text;
  final double top;
  final double bottom;
  final bool center;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: top, bottom: bottom), child: WText(text, WType.body, size: 17, align: center ? TextAlign.center : null));
}

String sideName(CaptainStore s, int i) => [s.t('Front', 'आगे', 'ముందు భాగం'), s.t('Back', 'पीछे', 'వెనుక భాగం'), s.t('Left', 'बायाँ', 'ఎడమ'), s.t('Right', 'दायाँ', 'కుడి')][i];

String washName(WashType w, CaptainStore s) => switch (w) {
      WashType.dryDusting => s.t('Dry dusting', 'सूखी सफ़ाई', 'పొడి దుమ్ము తుడుపు'),
      WashType.wetOutside => s.t('Water wash', 'पानी से धुलाई', 'నీటి వాష్'),
      WashType.wetOutsideDryInside => s.t('Water wash + inside', 'पानी से धुलाई + अंदर', 'నీటి వాష్ + లోపల'),
    };

WIcon _washIcon(WashType w) => w.water ? WIcon.dropFill : WIcon.wind;

/// Big picture card: the vehicle, then Outside / Water / Inside with ✓ or ✗.
class BookingVisual extends StatelessWidget {
  const BookingVisual({super.key, required this.job});
  final Job job;

  Widget _tile(WIcon icon, String label, bool yes) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: yes ? WColor.successTint.withValues(alpha: 0.5) : WColor.canvas, borderRadius: BorderRadius.circular(16)),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: yes ? WColor.primaryTint : WColor.canvas),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(alignment: Alignment.center, children: [
                    WIconView(icon, size: 26, color: yes ? WColor.primaryStrong : WColor.muted),
                    if (!yes) Transform.rotate(angle: -0.7, child: Container(width: 64, height: 3, color: WColor.destructive.withValues(alpha: 0.7))),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              WText(label, WType.title, size: 15.5, color: yes ? WColor.heading : WColor.secondary),
            ]),
            Positioned(
              top: -6,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: yes ? WColor.success : WColor.destructive),
                alignment: Alignment.center,
                child: WIconView(yes ? WIcon.check : WIcon.close, size: 11, color: WColor.white, weight: bold),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: outlinedDecoration(),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 92,
            height: 76,
            child: Stack(children: [
              Container(width: 84, height: 68, decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: WIconView(job.isBike ? WIcon.bike : WIcon.carFill, size: 40, color: WColor.primaryStrong)),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: job.wash.water ? WColor.primary : WColor.secondary, border: Border.all(color: WColor.white, width: 2)),
                  alignment: Alignment.center,
                  child: WIconView(_washIcon(job.wash), size: 14, color: WColor.white, weight: bold),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WText(store.t('Owner booked', 'मालिक ने बुक किया', 'యజమాని బుక్ చేశారు'), WType.small),
              const SizedBox(height: 4),
              WText(washName(job.wash, store), WType.section, weight: semibold),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _tile(job.isBike ? WIcon.bike : WIcon.car, store.t('Outside', 'बाहर', 'బయట'), true),
          const SizedBox(width: 10),
          _tile(WIcon.dropFill, store.t('Water', 'पानी', 'నీళ్ళు'), job.wash.water),
          if (!job.isBike) ...[const SizedBox(width: 10), _tile(WIcon.seat, store.t('Inside', 'अंदर', 'లోపల'), job.wash.inside)],
        ]),
      ]),
    );
  }
}

/// One-line version: vehicle + wash picture + name (job alert and Go to vehicle).
class BookingChip extends StatelessWidget {
  const BookingChip({super.key, required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const ShapeDecoration(color: WColor.primaryTint, shape: StadiumBorder()),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: job.wash.water ? WColor.primary : WColor.secondary),
            alignment: Alignment.center,
            child: WIconView(_washIcon(job.wash), size: 15, color: WColor.white, weight: semibold),
          ),
          const SizedBox(width: 10),
          WText(washName(job.wash, context.store), WType.title, size: 16),
          if (job.wash.inside) ...[const SizedBox(width: 10), const WIconView(WIcon.seat, size: 15, color: WColor.primaryStrong)],
        ]),
      );
}

// MARK: Car outlines (guided camera and owner's photos): 0 front, 1 back, 2 left, 3 right

class CarShapePainter extends CustomPainter {
  const CarShapePainter(this.side, {this.fill, this.dashed = false});
  final int side;
  final Color? fill;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Offset pt(double x, double y) => Offset(w * x, h * y);
    Rect rc(double x0, double y0, double x1, double y1) => Rect.fromLTRB(w * x0, h * y0, w * x1, h * y1);
    final p = Path()..fillType = PathFillType.evenOdd;
    if (side >= 2) {
      p
        ..moveTo(0, h * 0.75)
        ..lineTo(w * 0.04, h * 0.45)
        ..lineTo(w * 0.28, h * 0.38)
        ..quadraticBezierTo(w * 0.45, -h * 0.1, w * 0.68, h * 0.35)
        ..lineTo(w * 0.98, h * 0.55)
        ..lineTo(w, h * 0.75)
        ..close()
        ..addOval(Rect.fromLTWH(w * 0.15, h * 0.58, h * 0.42, h * 0.42))
        ..addOval(Rect.fromLTWH(w - w * 0.15 - h * 0.42, h * 0.58, h * 0.42, h * 0.42));
    } else {
      final front = side == 0;
      p
        ..moveTo(pt(0.24, front ? 0.06 : 0.08).dx, pt(0, front ? 0.06 : 0.08).dy)
        ..lineTo(w * 0.76, h * (front ? 0.06 : 0.08))
        ..lineTo(w * 0.88, h * 0.42)
        ..lineTo(w * 0.12, h * 0.42)
        ..close()
        ..moveTo(w * (front ? 0.28 : 0.29), h * (front ? 0.13 : 0.15))
        ..lineTo(w * (front ? 0.72 : 0.71), h * (front ? 0.13 : 0.15))
        ..lineTo(w * (front ? 0.80 : 0.78), h * (front ? 0.37 : 0.36))
        ..lineTo(w * (front ? 0.20 : 0.22), h * (front ? 0.37 : 0.36))
        ..close()
        ..addRRect(RRect.fromRectAndRadius(rc(0.04, 0.42, 0.96, 0.82), Radius.circular(w * 0.06)))
        ..addRRect(RRect.fromRectAndRadius(rc(0.10, 0.82, 0.25, 0.97), const Radius.circular(4)))
        ..addRRect(RRect.fromRectAndRadius(rc(0.75, 0.82, 0.90, 0.97), const Radius.circular(4)));
      if (fill == null) {
        if (front) {
          p
            ..addRRect(RRect.fromRectAndRadius(rc(0.0, 0.33, 0.09, 0.42), const Radius.circular(4)))
            ..addRRect(RRect.fromRectAndRadius(rc(0.91, 0.33, 1.0, 0.42), const Radius.circular(4)))
            ..addOval(rc(0.09, 0.50, 0.30, 0.62))
            ..addOval(rc(0.70, 0.50, 0.91, 0.62))
            ..addRRect(RRect.fromRectAndRadius(rc(0.36, 0.52, 0.64, 0.64), const Radius.circular(4)))
            ..moveTo(w * 0.04, h * 0.72)
            ..lineTo(w * 0.96, h * 0.72);
        } else {
          p
            ..addRRect(RRect.fromRectAndRadius(rc(0.06, 0.48, 0.24, 0.60), const Radius.circular(4)))
            ..addRRect(RRect.fromRectAndRadius(rc(0.76, 0.48, 0.94, 0.60), const Radius.circular(4)))
            ..addRect(rc(0.35, 0.58, 0.65, 0.69))
            ..moveTo(w * 0.04, h * 0.74)
            ..lineTo(w * 0.96, h * 0.74);
        }
      }
    }
    if (side == 3) {
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (fill != null) {
      canvas.drawPath(p, Paint()..color = fill!);
    } else {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      for (final m in p.computeMetrics()) {
        for (double d = 0; d < m.length; d += dashed ? 14 : m.length) {
          canvas.drawPath(m.extractPath(d, dashed ? d + 8 : m.length), paint);
        }
      }
    }
    if (side == 3) canvas.restore();
  }

  @override
  bool shouldRepaint(CarShapePainter old) => old.side != side || old.fill != fill;
}

/// Placeholder for the owner's photo of one side. BACKEND: show the owner's real photo for that side.
class VehiclePhotoView extends StatelessWidget {
  const VehiclePhotoView({super.key, required this.side, this.isBike = false, this.compact = false});
  final int side;
  final bool isBike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store=context.store;
    if(store.isLive){
      final photos=store.liveOrder(store.current.id)?['customerPhotos'] as Map? ?? {};
      final path=photos[['front','back','left','right'][side.clamp(0,3)]] as String?;
      return LayoutBuilder(builder:(c,constraints)=>DesignPhoto(path:path,height:constraints.hasBoundedHeight?constraints.maxHeight:240,radius:0,icon:isBike?WIcon.bike:WIcon.car,caption:path==null?'No owner photo for this side':null));
    }
    const shape = Color(0xD93B4A5E);
    final size = side >= 2 ? (compact ? const Size(96, 36) : const Size(300, 112)) : (compact ? const Size(82, 62) : const Size(250, 186));
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFDDE6F3), Color(0xFFB9C6D8)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Stack(children: [
        Positioned(left: 0, right: 0, bottom: 0, height: compact ? 26 : 120, child: const ColoredBox(color: Color(0x598D9AAD))),
        Center(
          child: Transform.translate(
            offset: Offset(0, compact ? 4 : 30),
            child: isBike ? WIconView(WIcon.bike, size: compact ? 54 : 160, color: const Color(0xFF3B4A5E)) : CustomPaint(size: size, painter: CarShapePainter(side, fill: shape)),
          ),
        ),
      ]),
    );
  }
}

/// Full-screen viewer: Front, Back, Left, Right. Phones swipe; the web uses arrows.
class VehiclePhotosViewer extends StatefulWidget {
  const VehiclePhotosViewer({super.key, required this.isBike, required this.plate});
  final bool isBike;
  final String plate;
  @override
  State<VehiclePhotosViewer> createState() => _VehiclePhotosViewerState();
}

class _VehiclePhotosViewerState extends State<VehiclePhotosViewer> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final pad = MediaQuery.paddingOf(context);
    return Material(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WText(store.t('Vehicle photos', 'गाड़ी की फ़ोटो', 'వాహనం ఫోటోలు'), WType.title, color: WColor.white, size: 17),
                  WText('${sideName(store, index)} · ${index + 1}/4 · ${widget.plate}', WType.caption, color: Colors.white70),
                ]),
              ),
              Pressable(
                label: 'Close',
                onTap: () => Navigator.of(context).pop(),
                child: Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24), alignment: Alignment.center, child: const WIconView(WIcon.close, size: 16, color: WColor.white, weight: bold)),
              ),
            ]),
          ),
          Expanded(
            child: WPager(
              count: 4,
              index: index,
              onIndex: (i) => setState(() => index = i),
              builder: (c, i) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AspectRatio(aspectRatio: 3 / 4, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: VehiclePhotoView(side: i, isBike: widget.isBike))),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(bottom: 16), child: PageDots(count: 4, index: index, onTap: (i) => setState(() => index = i))),
        ]),
      ),
    );
  }
}

// MARK: Owner's voice note player

/// Plays the owner's note. Demo: read out by the device voice in the captain's language.
/// BACKEND: replace with the owner's recorded audio file.
class NotePlayer extends ChangeNotifier {
  static final shared = NotePlayer();
  bool playing = false;
  double progress = 0;
  bool finishedOnce = false;
  ClipPlayback? real;
  String? _realAccount;
  String? realJob;
  Future<void> loadReal(MediaClip clip,String account,String jobId)async{
    stop();real?.dispose();real=ClipPlayback();_realAccount=account;
    realJob=jobId;
    finishedOnce=false;progress=0;
    real!.addListener((){playing=real!.playing;progress=real!.progress;finishedOnce=real!.finishedOnce;notifyListeners();});
    await real!.load(clip);
  }
  void Function()? _stop;
  DateTime _started = DateTime.now();
  static const seconds = 12;

  static String text(Lang l) => switch (l) {
        Lang.en => 'Hello. My car is in slot 41, basement B2. Please clean the wheels well, and don’t move the wipers. Thank you.',
        Lang.hi => 'नमस्ते। मेरी गाड़ी B2 में, स्लॉट 41 पर है। पहिये अच्छे से साफ़ करना, और वाइपर मत हिलाना। धन्यवाद।',
        Lang.te => 'నమస్తే. నా కారు B2 లో, స్లాట్ 41 లో ఉంది. చక్రాలు బాగా శుభ్రం చేయండి, వైపర్లు కదపకండి. ధన్యవాదాలు.',
      };

  void play(Lang l) {
    if(WashKrewRuntime.backend!=null){
      if(real==null||_realAccount!=WashKrewRuntime.backend!.uid)return;
      real!.toggle().catchError((Object _){});return;
    }
    stop();
    playing = true;
    progress = 0;
    _started = DateTime.now();
    notifyListeners();
    var ended = false;
    _stop = Device.speak(text(l), l == Lang.en ? 'en-IN' : l == Lang.hi ? 'hi-IN' : 'te-IN', () {
      ended = true;
      playing = false;
      progress = 1;
      finishedOnce = true;
      notifyListeners();
    });
    () async {
      while (!ended && playing) {
        progress = (DateTime.now().difference(_started).inMilliseconds / (seconds * 1000)).clamp(0, 0.97);
        notifyListeners();
        await sleepMs(100);
      }
    }();
  }

  void stop() {
    real?.pause().catchError((Object _){});
    _stop?.call();
    _stop = null;
    if (playing) {
      playing = false;
      notifyListeners();
    }
  }

  void reset() {
    finishedOnce = false;
    progress = 0;
    notifyListeners();
  }
}

/// Replay button beside the screen title after the note was heard. Never auto-plays.
class OwnerNoteButton extends StatelessWidget {
  const OwnerNoteButton({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    if (!store.ownerNoteHeard) return const SizedBox.shrink();
    final p = NotePlayer.shared;
    return ListenableBuilder(
      listenable: p,
      builder: (c, _) => Pressable(
        label: 'Play owner’s note again',
        onTap: () async { if(store.isLive){try{await loadOwnerRecording(store,p);}catch(e){store.set(()=>store.toast=backendError(e));return;}} p.playing ? p.stop() : p.play(store.lang); },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(color: WColor.canvas, shape: const StadiumBorder(side: BorderSide(color: WColor.border))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            WIconView(p.playing ? WIcon.stop : WIcon.speaker, size: 12, color: WColor.secondary, weight: semibold),
            const SizedBox(width: 6),
            WText(p.playing ? store.t('Playing', 'चल रहा', 'ప్లే అవుతోంది') : store.t('Owner’s note', 'मालिक का संदेश', 'యజమాని నోట్'), WType.small, size: 12.5, weight: medium, color: WColor.secondary),
          ]),
        ),
      ),
    );
  }
}

Future<void> loadOwnerRecording(CaptainStore store,NotePlayer player)async{
  final jobId=store.current.id,account=store.liveUid;
  if(player.realJob==jobId&&player.real?.ready==true)return;
  final media=store.liveOrder(jobId)?['customerMedia'] as Map?;
  final recording=media?['note_audio']??media?['note_video'];
  if(recording is! Map)throw StateError('This booking has no recorded owner note.');
  final bytes=await store.live!.media(recording['path']);
  if(store.liveUid!=account||store.current.id!=jobId||bytes==null)throw StateError('Reopen this job to load the owner note.');
  await player.loadReal(MediaClip(bytes:bytes,contentType:recording['contentType'],seconds:(recording['seconds'] as num).toInt()),account,jobId);
}

// MARK: Profile photo, bell, work area, help ladder

/// Tap to pick a photo, long-press (or right-click) to remove. Separate from the KYC selfie.
class WProfilePhoto extends StatelessWidget {
  const WProfilePhoto({super.key, this.size = 60, this.badge = true});
  final double size;
  final bool badge;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final initials = store.name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    return Pressable(
      label: store.t('Profile photo', 'प्रोफ़ाइल फ़ोटो', 'ప్రొఫైల్ ఫోటో'),
      onTap: () async {
        final d = await Device.pickImage();
        if (d != null) await store.setProfilePhoto(d);
      },
      onLongPress: store.profilePhoto == null
          ? null
          : () => showWActions(context, actions: [AlertAction(store.t('Remove photo', 'फ़ोटो हटाएं', 'ఫోటో తీసివేయండి'), destructive: true, onTap: () => store.setProfilePhoto(null))]),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          WAvatar(initials, size: size, photo: store.profilePhoto),
          if (badge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: WColor.primary, shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 2)),
                alignment: Alignment.center,
                child: const WIconView(WIcon.camera, size: 11, color: WColor.white),
              ),
            ),
        ]),
      ),
    );
  }
}

class WNotificationBell extends StatelessWidget {
  const WNotificationBell({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final n = store.unreadCount;
    return Pressable(
      label: store.t('Notifications', 'सूचनाएं', 'నోటిఫికేషన్లు'),
      onTap: () => context.router.go(N.notifications),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(children: [
          Center(child: WIconView(store.notificationsOn ? WIcon.bell : WIcon.bellSlash, size: 22)),
          if (n > 0)
            Positioned(
              top: 6,
              right: 4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: WColor.destructive, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(n > 9 ? '9+' : '$n', style: wStyle(WType.small, weight: bold, size: 11, color: WColor.white)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// "📍 Jobs from: … · Change" — shown on Home and under the job alert.
class WorkAreaChip extends StatelessWidget {
  const WorkAreaChip({super.key, this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final fg = onDark ? WColor.white : WColor.primaryStrong;
    return Pressable(
      onTap: () => context.router.go(N.workArea),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: ShapeDecoration(color: onDark ? Colors.white.withValues(alpha: 0.16) : WColor.white, shape: StadiumBorder(side: onDark ? BorderSide.none : const BorderSide(color: WColor.border))),
        child: Row(children: [
          WIconView(WIcon.location, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(child: WRich([(store.t('Jobs from: ', 'काम: ', 'పనులు: '), null), (store.workSummary, bold)], WType.caption, size: 14.5, color: onDark ? WColor.white : WColor.heading)),
          const SizedBox(width: 6),
          WText(store.t('Change', 'बदलें', 'మార్చండి'), WType.label, color: fg),
          const SizedBox(width: 6),
          WIconView(WIcon.chevron, size: 11, color: fg),
        ]),
      ),
    );
  }
}

/// Support ladder shown on Help and inside each problem: 1) quick check by the app →
/// 2) sort it out with the owner → 3) team. 0 = just showing the steps; 1…3 = current step.
class HelpLadder extends StatelessWidget {
  const HelpLadder({super.key, required this.current, this.skipOwner = false});
  final int current;
  final bool skipOwner;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    Widget step(int n, WIcon icon, String label, {bool skipped = false}) {
      final done = current > n, now = current == n;
      return Expanded(
        child: Column(children: [
          Opacity(
            opacity: skipped ? 0.4 : 1,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: done ? WColor.success : now ? WColor.primary : WColor.primaryTint),
              alignment: Alignment.center,
              child: WIconView(done ? WIcon.check : icon, size: 15, color: done ? WColor.onSuccess : now ? WColor.white : WColor.primaryStrong),
            ),
          ),
          const SizedBox(height: 6),
          WText(label, WType.small, color: now ? WColor.heading : WColor.secondary, weight: now ? semibold : FontWeight.w400, maxLines: 1),
        ]),
      );
    }

    Widget line(int after) => Container(width: 30, height: 2, margin: const EdgeInsets.only(bottom: 18), color: current > after ? WColor.success : WColor.border);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        step(1, WIcon.sparkle, store.t('Quick check', 'जल्दी जाँच', 'త్వరిత తనిఖీ')),
        line(1),
        step(2, WIcon.user, store.t('Owner', 'मालिक', 'యజమాని'), skipped: skipOwner),
        line(2),
        step(3, WIcon.chat, store.t('Our team', 'हमारी टीम', 'మా బృందం')),
      ]),
    );
  }
}

/// Guest notice used on Jobs and Money.
class GuestNotice extends StatelessWidget {
  const GuestNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: WColor.primaryTint, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WIconView(WIcon.eye, size: 17, color: WColor.primaryStrong),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WText(text, WType.caption, color: WColor.inverse, size: 14.5),
            if (!store.registered) ...[
              const SizedBox(height: 8),
              WLink(store.t('Sign up to start', 'शुरू करने के लिए साइन अप करें', 'మొదలుపెట్టడానికి సైన్ అప్'), k: WType.caption, minHeight: 24, onTap: () => context.router.push(const R(N.signUp))),
            ],
          ]),
        ),
      ]),
    );
  }
}

String helpTopicTitle(HelpTopic t, CaptainStore s) => switch (t) {
      HelpTopic.money => s.t('Money or payout', 'पैसे या पेमेंट', 'డబ్బు లేదా చెల్లింపు'),
      HelpTopic.job => s.t('Problem at a job', 'काम पर समस्या', 'పనిలో సమస్య'),
      HelpTopic.rating => s.t('Rating or photo check', 'रेटिंग या फ़ोटो जाँच', 'రేటింగ్ లేదా ఫోటో తనిఖీ'),
      HelpTopic.app => s.t('App not working', 'ऐप नहीं चल रहा', 'యాప్ పనిచేయట్లేదు'),
    };

WIcon helpTopicIcon(HelpTopic t) => switch (t) { HelpTopic.money => WIcon.rupee, HelpTopic.job => WIcon.car, HelpTopic.rating => WIcon.star, HelpTopic.app => WIcon.phone };
