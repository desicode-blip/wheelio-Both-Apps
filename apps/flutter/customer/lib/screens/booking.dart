import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../app/design_flags.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

// MARK: C05 Vehicle type (C52: 200% text)

class VehicleTypeScreen extends StatelessWidget {
  const VehicleTypeScreen({super.key, this.large = false, this.asRoot = false});
  final bool large;

  /// Shown in place of the hidden first-time Home (no back button there).
  final bool asRoot;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final next = WButton('Next', enabled: store.draft.type != null, onTap: () => router.go(N.washType));
    return OnAppear(
      onAppear: () {
        if (store.draft.type == null && !large) store.set(() => store.draft.type = VehicleType.all[1]);
      },
      child: TextScale(
        scale: large ? 1.6 : 1,
        child: WScreen(
          header: BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2, showBack: !asRoot, showProgress: DesignFlags.firstStepProgress),
          footer: large
              ? Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: WColor.divider)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter, vertical: 12),
                  child: next,
                )
              : WFooterBar(showCall: false, child: next),
          children: [
            WTitleBlock('What are we washing?', subtitle: large ? null : 'Pick your vehicle. You choose the wash next.'),
            for (final t in large ? VehicleType.all.take(2) : VehicleType.all) ...[
              if (large)
                // C52: at 200% text the tile stacks so nothing is cut off.
                Pressable(
                  onTap: () => store.set(() => store.draft.type = t),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: outlinedDecoration(
                      radius: 16,
                      fill: store.draft.type == t ? WColor.primaryTint : WColor.white,
                      stroke: store.draft.type == t ? WColor.primary : WColor.border,
                      width: store.draft.type == t ? 2 : 1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WText(t.name, WType.section, weight: semibold),
                        WText('About ${t.minutes} min', WType.body),
                        WText(Fmt.rupees(t.price), WType.section, weight: bold),
                      ],
                    ),
                  ),
                )
              else
                WSelectionTile(
                  icon: t.icon,
                  title: t.name,
                  subtitle: 'About ${t.minutes} min',
                  trailing: Fmt.rupees(t.price),
                  selected: store.draft.type == t,
                  onTap: () => store.set(() => store.draft.type = t),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// MARK: Wash type (after C05)

class WashTypeScreen extends StatelessWidget {
  const WashTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final isBike = store.draft.type?.kind == VehicleKind.bike;
    final options = WashKind.options(store.draft.type?.kind);
    return OnAppear(
      onAppear: () {
        final w = store.draft.wash;
        if (w != null && options.contains(w) && w.available) return;
        store.set(() => store.draft.wash = WashKind.wetOutside);
      },
      child: WScreen(
        header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
        footer: WFooterBar(
          showCall: false,
          child: WButton('Next', enabled: store.draft.wash != null, onTap: () => router.go(N.vehicleNumber)),
        ),
        children: [
          WTitleBlock(
            'What kind of wash?',
            subtitle: 'Same price for every option${store.draft.type != null ? ': ${Fmt.rupees(store.draft.type!.price)}' : ''}.',
          ),
          for (final w in options) ...[
            Opacity(
              opacity: w.available ? 1 : 0.7,
              child: Pressable(
                onTap: () {
                  if (w.available) {
                    store.set(() => store.draft.wash = w);
                  } else {
                    showWAlert(
                      context,
                      title: 'Not available in your society yet',
                      message: 'Inside cleaning isn’t offered in your society right now. We’ll let you know when it is.',
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: outlinedDecoration(
                    radius: 16,
                    fill: store.draft.wash == w ? WColor.primaryTint : WColor.white,
                    stroke: store.draft.wash == w ? WColor.primary : WColor.border,
                    width: store.draft.wash == w ? 2 : 1,
                  ),
                  child: Row(
                    children: [
                      WIconBox(w.icon, size: 48, tone: w.available ? Tone.info : Tone.mute),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WText(w.name(isBike), WType.title),
                            const SizedBox(height: 2),
                            WText(w.detail(isBike), WType.caption),
                            if (!w.available)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: WText('Not in your society yet', WType.label, color: WColor.secondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Pressable(
                        label: 'See what ${w.name(isBike)} means',
                        onTap: () => showWAlert(
                          context,
                          title: 'Video coming soon',
                          message: 'We’re making a short video that shows this wash. For now, pick the one you like and carry on.',
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: store.draft.wash == w ? Colors.transparent : WColor.primaryTint),
                          alignment: Alignment.center,
                          child: const WIconView(WIcon.eye, size: 18, color: WColor.primaryStrong),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// MARK: C06 Vehicle number. Any number is accepted as typed, so customers never hit an error here.

class VehicleNumberScreen extends StatefulWidget {
  const VehicleNumberScreen({super.key});
  @override
  State<VehicleNumberScreen> createState() => _VehicleNumberScreenState();
}

class _VehicleNumberScreenState extends State<VehicleNumberScreen> {
  late String plate = context.store.draft.plate;

  void _next() {
    final t = plate.trim();
    if (t.isEmpty) return;
    context.store.set(() => context.store.draft.plate = Fmt.plate(t));
    context.router.go(N.photos);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.store.draft.type;
    return WScreen(
      header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Next', enabled: plate.trim().isNotEmpty, onTap: _next),
      ),
      children: [
        const WTitleBlock('What’s the number plate?', subtitle: 'So the captain finds the right vehicle.'),
        WTextField(
          label: 'Vehicle number',
          value: plate,
          placeholder: 'TS 09 EA 4521',
          caps: TextCapitalization.characters,
          autofocus: true,
          onSubmit: _next,
          onChanged: (v) => setState(() => plate = v),
        ),
        const Padding(padding: EdgeInsets.only(top: 18), child: _PlateHint()),
        if (t != null)
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Pressable(
              onTap: context.router.pop,
              child: Row(
                children: [
                  WIconBox(t.icon, size: 38, radius: 10),
                  const SizedBox(width: 10),
                  WText('${t.shortName} · ${Fmt.rupees(t.price)} · ', WType.caption),
                  const WText('Change', WType.caption, color: WColor.primaryStrong, decoration: TextDecoration.underline),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A small, friendly picture of an Indian number plate, so people know what to type.
/// Only a reference: the letters are an example, never checked against what is typed.
class _PlateHint extends StatelessWidget {
  const _PlateHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        // The plate, tilted a little so it reads as a sketch, not a rule.
        Transform.rotate(
          angle: -0.045,
          child: Container(
            decoration: BoxDecoration(
              color: WColor.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: WColor.heading, width: 1.5),
              boxShadow: const [BoxShadow(color: WColor.shadowCard, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue "IND" strip, like on the new high-security plates.
                  Container(
                    width: 18,
                    decoration: const BoxDecoration(
                      color: WColor.primary,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('IND', style: wStyle(WType.small, weight: bold, size: 6.5, color: WColor.white).copyWith(letterSpacing: 0.4)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text('TS 07 HB 2024', style: wStyle(WType.title, weight: bold, size: 15).copyWith(letterSpacing: 1.4, height: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WText('Looks like this', WType.caption, color: WColor.heading),
              SizedBox(height: 2),
              WText('Spaces or no spaces, both are fine.', WType.small, color: WColor.secondary),
            ],
          ),
        ),
      ],
    ),
  );
}

// MARK: C07 Photos (C07b partial, C07c done)

PhotoState slotState(UploadState? s) => switch (s) {
  null => PhotoState.empty,
  UploadState.uploading => PhotoState.uploading,
  UploadState.done => PhotoState.done,
  UploadState.failed => PhotoState.failed,
};

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final d = store.draft;
    void goNext() => router.go(store.draft.place == null ? N.location : N.floorSlot);
    final title = d.photosComplete
        ? WTitleBlock('Looking good', subtitle: '4 photos${d.videoSeconds != null ? ' and a video' : ''}. Tap any photo to retake.')
        : d.photos.isEmpty
        ? const WTitleBlock('Take 4 quick photos', subtitle: 'They help the captain find your vehicle. The captain takes the official before photos.')
        : WTitleBlock('Take 4 quick photos', subtitle: '${d.photosDone} of 4 done');
    return WScreen(
      header: const BookingHeader(step: 2, label: 'Photos', fraction: 0.4),
      footer: WFooterBar(
        showCall: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WButton('Next', enabled: d.photosComplete, onTap: goNext),
            // Photos are optional for the customer: the captain takes the official before photos.
            if (!d.photosComplete)
              WLink(
                'Skip for now',
                color: WColor.secondary,
                k: WType.caption,
                onTap: () => showWAlert(
                  context,
                  title: 'Skip the photos?',
                  message: store.isLive
                      ? 'Your captain will still take official before and after photos. Your own photos provide an extra record of the vehicle’s condition.'
                      : 'Without your photos from before the wash, we won’t be able to take up any claim if something goes wrong later.',
                  actions: [
                    const AlertAction('Take photos', cancel: true),
                    AlertAction('Skip anyway', onTap: goNext),
                  ],
                ),
              ),
          ],
        ),
      ),
      children: [
        title,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 154 / ((d.photos.isEmpty ? 126 : 98) + (d.photos.isEmpty ? 0 : 24)),
          children: [
            for (final a in PhotoAngle.values)
              WPhotoSlot(
                label: a.label,
                state: slotState(d.photos[a]),
                height: d.photos.isEmpty ? 126 : 98,
                onTap: () => d.photos[a] == UploadState.failed ? store.uploadPhoto(a) : router.push(R(N.camera, angle: a)),
              ),
          ],
        ),
        if (d.hasFailedPhoto)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: WBanner(
              tone: Tone.error,
              icon: WIcon.wifiOff,
              text: 'Back photo didn’t upload. It’s saved on your phone.',
              actionTitle: 'Retry',
              onAction: () {
                final a = PhotoAngle.values.where((x) => d.photos[x] == UploadState.failed).firstOrNull;
                if (a != null) store.uploadPhoto(a);
              },
            ),
          ),
        if (!store.isLive && d.videoSeconds != null && d.photosComplete)
          Container(
            margin: const EdgeInsets.only(top: 20),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const ShapeDecoration(color: WColor.canvas, shape: StadiumBorder()),
            child: Row(
              children: [
                const WIconView(WIcon.video, size: 17, color: WColor.primaryStrong),
                const SizedBox(width: 12),
                Expanded(child: WText('Walk-around video · ${Fmt.clock(d.videoSeconds!)}', WType.bodyStrong, color: WColor.heading)),
                const WIconView(WIcon.check, size: 15),
              ],
            ),
          )
        else if (!store.isLive && !d.hasFailedPhoto)
          // Optional extra: same look as the photo slots, plus an "Optional" tab on its edge.
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Pressable(
              label: 'Optional: walk-around video, 15 seconds',
              onTap: () => store.set(() => store.draft.videoSeconds = 14),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const DashedBorder(
                    child: SizedBox(
                      height: 62,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          WIconView(WIcon.video, size: 17, color: WColor.primaryStrong),
                          SizedBox(width: 10),
                          WText('Walk-around video (15 sec)', WType.bodyStrong, color: WColor.primaryStrong, weight: medium),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const ShapeDecoration(
                        color: WColor.canvas,
                        shape: StadiumBorder(side: BorderSide(color: WColor.border)),
                      ),
                      child: WText('OPTIONAL', WType.small, weight: semibold, size: 10.5, color: WColor.secondary, letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// MARK: C08 Camera (C08b access needed)

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.angle, this.forceDenied = false});
  final PhotoAngle angle;
  final bool forceDenied;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool denied = false;
  late PhotoAngle current = widget.angle;

  Future<void> _shoot() async {
    final store = context.store;
    final a = current;
    await store.uploadPhoto(a);
    if (!mounted || store.draft.photos[a] == null) return;
    final next = PhotoAngle.values.where((x) => store.draft.photos[x] == null && x != a).firstOrNull;
    if (next != null) {
      setState(() => current = next);
    } else {
      context.router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    if (store.isLive) {
      return WScreen(
        header: const PlainHeader(),
        children: [
          WTitleBlock('${current.label} photo', subtitle: 'Choose a clear photo of your vehicle. It will be shared only with your assigned captain.'),
          WButton('Take or choose photo', icon: WIcon.camera, onTap: _shoot),
          if (store.draftPhotoBytes[current] != null) Padding(padding: const EdgeInsets.only(top: 20), child: Image.memory(store.draftPhotoBytes[current]!)),
        ],
      );
    }
    if (denied || widget.forceDenied) {
      return WScreen(
        scrolls: false,
        header: WAppBar(onLeading: router.pop, onTrailing: () => router.go(N.help)),
        children: [
          Expanded(
            child: WFullState(
              icon: WIcon.camera,
              tone: Tone.wait,
              title: 'Camera access needed',
              message: 'Photos help the captain find your vehicle. Allow camera to continue.',
              primary: 'Allow camera',
              secondary: 'Skip photos for now',
              onPrimary: () => setState(() => denied = false),
              onSecondary: () {
                store.set(() {
                  for (final a in PhotoAngle.values) {
                    store.draft.photos[a] = UploadState.done;
                  }
                });
                router.pop();
              },
            ),
          ),
        ],
      );
    }
    final pad = MediaQuery.paddingOf(context);
    final index = PhotoAngle.values.indexOf(current);
    return Material(
      color: WColor.camera,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(
          children: [
            WAppBar(title: '${current.label} · ${index + 1} of 4', leading: WIcon.close, trailing: null, dark: true, onLeading: router.pop),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                decoration: BoxDecoration(color: WColor.cameraPanel, borderRadius: BorderRadius.circular(20)),
                child: Stack(
                  children: [
                    const Center(
                      child: CustomPaint(size: Size(250, 160), painter: CarOutlinePainter()),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 22,
                      child: WText(
                        'Fit the ${current.label.toLowerCase()} of the vehicle in the outline',
                        WType.body,
                        color: Colors.white.withValues(alpha: 0.9),
                        align: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  const SizedBox(width: 60),
                  const Spacer(),
                  ShutterButton(onTap: _shoot),
                  const Spacer(),
                  SizedBox(
                    width: 60,
                    child: Center(child: WIconView(WIcon.flash, size: 20, color: Colors.white.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onTap, this.size = 78});
  final VoidCallback onTap;
  final double size;
  @override
  Widget build(BuildContext context) => Pressable(
    label: 'Take photo',
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: WColor.white, width: 5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.8,
        height: size * 0.8,
        decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle),
      ),
    ),
  );
}

/// Dashed car outline for the guided camera.
class CarOutlinePainter extends CustomPainter {
  const CarOutlinePainter();
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.28, w, h * 0.52), const Radius.circular(22)))
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, 0, w * 0.56, h * 0.3), const Radius.circular(10)))
      ..addOval(Rect.fromLTWH(w * 0.12, h * 0.66, h * 0.3, h * 0.3))
      ..addOval(Rect.fromLTWH(w - w * 0.12 - h * 0.3, h * 0.66, h * 0.3, h * 0.3));
    drawDashed(
      canvas,
      p,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
      9,
      7,
    );
  }

  @override
  bool shouldRepaint(CarOutlinePainter old) => false;
}

void drawDashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
  for (final m in path.computeMetrics()) {
    for (double d = 0; d < m.length; d += dash + gap) {
      canvas.drawPath(m.extractPath(d, d + dash), paint);
    }
  }
}

// MARK: C09 Location (C09b off)

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, this.forceOff = false});
  final bool forceOff;
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool off = false;
  final place = AppStore.homePlace();

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    if (store.isLive) return const AddressSearchScreen();
    if (off || widget.forceOff) {
      return WScreen(
        scrolls: false,
        header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
        children: [
          Expanded(
            child: WFullState(
              icon: WIcon.location,
              tone: Tone.wait,
              title: 'Location is off',
              message: 'We use it only to find captains in your society. You can also type your address.',
              primary: 'Turn on location',
              secondary: 'Type address',
              onPrimary: () => setState(() => off = false),
              onSecondary: () => router.go(N.addressSearch),
            ),
          ),
        ],
      );
    }
    return WScreen(
      gutter: 0,
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Yes, it’s here',
          onTap: () {
            store.set(() => store.draft.place = Place(place.society, tower: place.tower));
            router.go(N.floorSlot);
          },
        ),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: WSpace.gutter),
          child: WTitleBlock('Is your vehicle here?', subtitle: 'Drag the map to move the pin.'),
        ),
        const SizedBox(height: 330, child: MapPlaceholder()),
        Padding(
          padding: const EdgeInsets.fromLTRB(WSpace.gutter, 18, WSpace.gutter, 0),
          child: WCard(
            outlined: true,
            child: Row(
              children: [
                const WIconBox(WIcon.home, size: 44, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [WText('${place.society.name}, ${place.tower}', WType.title), WText(place.addressLine, WType.caption)],
                  ),
                ),
                WLink('Change', onTap: () => router.go(N.addressSearch)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple drawn map (blocks, roads and a pin) until Google Maps is connected. Drag to move it.
class MapPlaceholder extends StatefulWidget {
  const MapPlaceholder({super.key});
  @override
  State<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<MapPlaceholder> {
  Offset off = Offset.zero;
  bool dragging = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, box) {
      final w = box.maxWidth, h = box.maxHeight;
      return MouseRegion(
        cursor: dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: GestureDetector(
          onPanStart: (_) => setState(() => dragging = true),
          onPanUpdate: (d) => setState(() => off += d.delta),
          onPanEnd: (_) => setState(() => dragging = false),
          child: ClipRect(
            child: ColoredBox(
              color: WColor.map,
              child: Stack(
                children: [
                  for (var i = 0; i < 25; i++)
                    Positioned(
                      left: -w * 0.4 + (i % 5) * w * 0.36 + off.dx,
                      top: -h * 0.4 + (i ~/ 5) * h * 0.36 + off.dy,
                      width: w * 0.28,
                      height: h * 0.25,
                      child: Container(
                        decoration: BoxDecoration(color: i % 7 == 1 || i % 7 == 5 ? WColor.mapGreen : WColor.mapBlock, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  Positioned(
                    left: w * 0.51 - 15,
                    top: h * 0.43 - 20,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(0, dragging ? -0.25 : 0),
                      child: Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 16,
                            height: 6,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 26,
                    bottom: 16,
                    child: WIconButton(WIcon.locate, label: 'My location', onTap: () => setState(() => off = Offset.zero)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// MARK: C09c Address search

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});
  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  String query = 'my home av';
  bool picked = false;

  /// Bold the part of the name after the search match.
  Widget _highlighted(String name) {
    final q = query.trim();
    final i = q.isEmpty ? -1 : name.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0) return WText(name, WType.rowTitle);
    final end = i + q.length;
    return WRich([(name.substring(0, end), null), (name.substring(end), bold)], WType.rowTitle);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    return WScreen(
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Next', enabled: picked, onTap: () => router.go(N.floorSlot)),
      ),
      children: [
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 18), child: WText('Where is your vehicle?', WType.screen)),
        WTextField(label: 'Society or building', value: query, leadingIcon: WIcon.search, autofocus: true, onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 14),
        for (final s in store.searchSocieties(query)) ...[
          Pressable(
            feedback: false,
            onTap: () {
              setState(() => picked = true);
              store.set(() => store.draft.place = Place(s, tower: store.isLive ? '' : 'Tower 3'));
              router.go(N.floorSlot);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const WIconBox(WIcon.location, size: 40, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_highlighted(s.name), WText('${s.area}, ${s.city}', WType.caption)]),
                  ),
                ],
              ),
            ),
          ),
          const WDivider(),
        ],
        const SizedBox(height: 14),
        if (!store.isLive)
          Row(
            children: [
              const WText('Can’t find it?', WType.caption),
              const SizedBox(width: 4),
              WLink(
                'Enter address by hand',
                k: WType.caption,
                onTap: () {
                  // Carry what they already typed into the society name.
                  ManualAddressScreen.prefill = query.trim();
                  router.go(N.manualAddress);
                },
              ),
            ],
          )
        else
          const WText('Service is available only in the societies listed above.', WType.caption),
      ],
    );
  }
}

// MARK: C09d Address by hand (society not in the list)
//
// Flow: Search (C09c) → "Enter address by hand" → this screen → Floor and slot (C10, with a
// Tower field) → the rest of the booking as usual. The typed text from the search becomes the
// society name. BACKEND: save the address for review and check the area is served
// before payment (see docs/BACKEND-HOOKUP.md).

class ManualAddressScreen extends StatefulWidget {
  const ManualAddressScreen({super.key});

  /// What the person typed in the search box, used to start the name field.
  static String prefill = '';
  static const idPrefix = 'manual-';

  @override
  State<ManualAddressScreen> createState() => _ManualAddressScreenState();
}

class _ManualAddressScreenState extends State<ManualAddressScreen> {
  late String name = _titleCase(ManualAddressScreen.prefill);
  String area = '';
  String pincode = '';
  String city = 'Hyderabad';
  int focusArea = 0, focusPin = 0, focusCity = 0;

  static String _titleCase(String s) =>
      s.split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  bool get _pinOk => RegExp(r'^[1-9]\d{5}$').hasMatch(pincode);
  bool get _ready => name.trim().isNotEmpty && area.trim().isNotEmpty && _pinOk && city.trim().isNotEmpty;

  void _next() {
    if (!_ready) return;
    final store = context.store;
    final society = Society(
      '${ManualAddressScreen.idPrefix}${DateTime.now().millisecondsSinceEpoch}',
      name.trim(),
      area.trim(),
      city.trim(),
      pincode,
    );
    store.set(() => store.draft.place = Place(society));
    context.router.go(N.floorSlot);
  }

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Next', enabled: _ready, onTap: _next),
      ),
      children: [
        const WTitleBlock('Type your address', subtitle: 'Just the basics. The captain gets the rest from your parking details next.'),
        WTextField(
          label: 'Society or building name',
          value: name,
          placeholder: 'Society or building name',
          leadingIcon: WIcon.home,
          caps: TextCapitalization.words,
          autofocus: true,
          action: TextInputAction.next,
          onSubmit: () => setState(() => focusArea++),
          onChanged: (v) => setState(() => name = v),
        ),
        const Gap(14),
        WTextField(
          label: 'Area or locality',
          value: area,
          placeholder: 'Area or locality',
          leadingIcon: WIcon.location,
          caps: TextCapitalization.words,
          focusTrigger: focusArea,
          action: TextInputAction.next,
          onSubmit: () => setState(() => focusPin++),
          onChanged: (v) => setState(() => area = v),
        ),
        const Gap(14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: WTextField(
                label: 'Pincode',
                value: pincode,
                placeholder: 'Pincode',
                keyboard: TextInputType.number,
                focusTrigger: focusPin,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                error: pincode.length == 6 && !_pinOk ? 'Check the pincode' : null,
                action: TextInputAction.next,
                onSubmit: () => setState(() => focusCity++),
                onChanged: (v) => setState(() => pincode = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WTextField(
                label: 'City',
                value: city,
                placeholder: 'City',
                caps: TextCapitalization.words,
                focusTrigger: focusCity,
                onSubmit: _next,
                onChanged: (v) => setState(() => city = v),
              ),
            ),
          ],
        ),
        const Gap(20),
        const WBanner(
          tone: Tone.info,
          icon: WIcon.info,
          text: 'New place for us? If captains don’t reach it yet, we’ll tell you before you pay.',
        ),
      ],
    );
  }
}

// MARK: C10 Floor and slot

class FloorSlotScreen extends StatefulWidget {
  const FloorSlotScreen({super.key});
  @override
  State<FloorSlotScreen> createState() => _FloorSlotScreenState();
}

class _FloorSlotScreenState extends State<FloorSlotScreen> {
  static const floors = ['B3', 'B2', 'B1', 'Ground', 'Open'];
  /// Typed by hand (C09d): start empty, like the live app, instead of the demo's B2 / 41.
  late final bool _manual = context.store.draft.place?.society.id.startsWith(ManualAddressScreen.idPrefix) ?? false;
  late String? floor = context.store.draft.place?.floor ?? (context.store.isLive || _manual ? null : 'B2');
  late String slot = (context.store.draft.place?.slot.isNotEmpty ?? false)
      ? context.store.draft.place!.slot
      : context.store.isLive || _manual
      ? ''
      : '41';
  late String tower = context.store.draft.place?.tower ?? '';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Next',
          enabled: floor != null,
          onTap: () {
            store.set(() {
              store.draft.place?.floor = floor;
              store.draft.place?.slot = slot.trim();
              store.draft.place?.tower = tower.trim();
            });
            context.router.go(N.entryNotes);
          },
        ),
      ),
      children: [
        WTitleBlock('Where is it parked?', subtitle: store.draft.place?.title ?? ''),
        if (store.isLive || _manual) ...[
          WTextField(label: 'Tower or building', value: tower, placeholder: 'Tower or building', onChanged: (v) => tower = v),
          const Gap(16),
        ],
        const WSectionLabel('Parking floor'),
        WFlow(
          children: [for (final f in floors) WChip(f, selected: floor == f, onTap: () => setState(() => floor = f))],
        ),
        const SizedBox(height: 26),
        WTextField(
          label: 'Slot number',
          value: slot,
          placeholder: 'Slot number',
          helper: 'Optional, but it saves the captain time',
          leadingIcon: WIcon.parking,
          caps: TextCapitalization.characters,
          onChanged: (v) => setState(() => slot = v),
        ),
      ],
    );
  }
}

// MARK: C11 Notes for the captain

/// Video or voice note (one of the two, same priority), and a text message that can go
/// along with either. Nothing is recorded by default.
class EntryNotesScreen extends StatefulWidget {
  const EntryNotesScreen({super.key});
  @override
  State<EntryNotesScreen> createState() => _EntryNotesScreenState();
}

class _EntryNotesScreenState extends State<EntryNotesScreen> {
  late String text = context.store.draft.note.text;
  late int? voice = context.store.draft.note.voiceSeconds;
  late int? video = context.store.draft.note.videoSeconds;
  bool playing = false;
  String? recording;

  bool get hasRecording => voice != null || video != null;

  /// Demo: a short "recording" then the clip appears. BACKEND: real camera / mic capture.
  void _record(String kind) {
    if (recording != null) return;
    setState(() => recording = kind);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        if (kind == 'video') {
          video = 15;
          voice = null;
        } else {
          voice = 12;
          video = null;
        }
        recording = null;
      });
    });
  }

  Widget _recordTile(WIcon icon, String title, String kind) {
    final busy = recording == kind;
    return Expanded(
      child: Pressable(
        enabled: recording == null || busy,
        onTap: () => _record(kind),
        child: Container(
          height: 132,
          decoration: outlinedDecoration(radius: 16, stroke: busy ? WColor.destructive : WColor.border, width: busy ? 2 : 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: busy ? WColor.destructive : WColor.primaryTint, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: busy
                    ? Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: WColor.white, borderRadius: BorderRadius.circular(4)),
                      )
                    : WIconView(icon, size: 22, color: WColor.primaryStrong),
              ),
              const SizedBox(height: 12),
              WText(
                busy ? 'Recording…' : title,
                WType.bodyStrong,
                color: busy ? WColor.destructive : WColor.primaryStrong,
                weight: medium,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(VoidCallback action) => Pressable(
    label: 'Delete recording',
    onTap: () => setState(() {
      action();
      playing = false;
    }),
    child: const SizedBox(
      width: 44,
      height: 44,
      child: Center(child: WIconView(WIcon.trash, size: 17, color: WColor.destructive)),
    ),
  );

  Widget _recordedVideo(int secs) => FadeIn(
    offset: 0,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Pressable(
            label: playing ? 'Pause video' : 'Play video',
            onTap: () => setState(() => playing = !playing),
            child: Container(
              width: 96,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF2A3445), Color(0xFF4A5568)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const WIconView(WIcon.carFill, size: 26, color: Colors.white38),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: WIconView(playing ? WIcon.pause : WIcon.play, size: 18, color: WColor.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    WIconView(WIcon.video, size: 14, color: WColor.primaryStrong),
                    SizedBox(width: 6),
                    WText('Video message', WType.bodyStrong),
                  ],
                ),
                const SizedBox(height: 4),
                WText(Fmt.clock(secs), WType.caption, mono: true),
              ],
            ),
          ),
          _deleteButton(() => video = null),
        ],
      ),
    ),
  );

  Widget _recordedVoice(int secs) => FadeIn(
    offset: 0,
    child: Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Pressable(
            label: playing ? 'Pause voice note' : 'Play voice note',
            onTap: () => setState(() => playing = !playing),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: WIconView(playing ? WIcon.pause : WIcon.play, size: 15, color: WColor.primaryStrong),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WText('Voice note', WType.small, color: WColor.secondary),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: playing
                      ? const LinearProgressIndicator(minHeight: 3, color: WColor.primary, backgroundColor: WColor.border)
                      : Container(height: 3, color: WColor.border),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          WText(Fmt.clock(secs), WType.caption, mono: true),
          _deleteButton(() => voice = null),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.8),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Next',
          onTap: () {
            store.set(() {
              store.draft.note.text = text;
              store.draft.note.voiceSeconds = voice;
              store.draft.note.videoSeconds = video;
            });
            context.router.go(N.timeSlot);
          },
        ),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  WText('Additional message', WType.screen),
                  WText('(Optional)*', WType.body, color: WColor.secondary, size: 15),
                ],
              ),
              SizedBox(height: 6),
              WText('Like gate, lift, landmark or parking spot.', WType.body, maxLines: 1),
            ],
          ),
        ),
        if (!store.isLive && video != null)
          _recordedVideo(video!)
        else if (!store.isLive && voice != null)
          _recordedVoice(voice!)
        else if (!store.isLive)
          // 1 · Video  2 · Voice note: same weight, pick one.
          Row(children: [_recordTile(WIcon.video, 'Record video', 'video'), const SizedBox(width: 12), _recordTile(WIcon.mic, 'Record voice note', 'voice')]),
        if (hasRecording)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: WText('One recording per booking. Delete it to record again.', WType.small, color: WColor.muted),
          ),
        // 3 · Text: goes along with either recording.
        Padding(padding: const EdgeInsets.only(top: 26, bottom: 8), child: WText(hasRecording ? 'Add a text message too' : 'Or write a message', WType.label)),
        WTextArea(value: text, height: 96, placeholder: 'Example: use the B2 ramp near the gym, white car next to the pillar', onChanged: (v) => text = v),
      ],
    );
  }
}

// MARK: C12 Time slot (C12b no captains today)

class TimeSlotScreen extends StatefulWidget {
  const TimeSlotScreen({super.key});
  @override
  State<TimeSlotScreen> createState() => _TimeSlotScreenState();
}

class _TimeSlotScreenState extends State<TimeSlotScreen> {
  final days = [for (var i = 0; i < 3; i++) addDays(startOfDay(DateTime.now()), i)];
  int dayIndex = 0;

  /// Start hours of the picked windows. The sample app allows several (or the whole day);
  /// the live app keeps one until the backend accepts more (docs/BACKEND-HOOKUP.md).
  Set<int> picked = {};
  String requested = '';
  Set<int> available = {};
  bool fetching = false;
  String? slotError;

  bool get _multi => !context.store.isLive;

  void _loadAvailability() {
    final store = context.store;
    if (!store.isLive || store.draft.place == null) return;
    final d = days[dayIndex];
    final day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final key = '${store.draft.place!.society.id}:$day';
    if (requested == key) return;
    requested = key;
    fetching = true;
    slotError = null;
    available = {};
    picked = {};
    store.live!
        .call('getAvailability', {'societyId': store.draft.place!.society.id, 'day': day})
        .then((result) {
          if (!mounted || requested != key) return;
          setState(() {
            fetching = false;
            available = {
              for (final s in result['slots'] as List)
                if (s['available'] == true) (s['startHour'] as num).toInt(),
            };
            final first = store.timeSlots(d).where((s) => s.available && available.contains(s.startHour)).firstOrNull;
            picked = {?first?.startHour};
          });
        })
        .catchError((Object e) {
          if (mounted && requested == key) {
            setState(() {
              fetching = false;
              slotError = 'Availability could not be loaded. ${backendError(e)}';
            });
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAvailability();
    if (context.store.isLive) return;
    if (picked.isNotEmpty) return;
    final s = context.store.draft.slot;
    if (s != null && s.available) {
      final i = days.indexWhere((d) => d == startOfDay(s.date));
      if (i >= 0) dayIndex = i;
      final open = {for (final x in context.store.timeSlots(days[dayIndex])) if (x.available) x.startHour};
      picked = (s.windows.isEmpty ? {s.startHour} : {for (final w in s.windows) w.$1}).intersection(open);
      if (picked.isNotEmpty) return;
    }
    final first = context.store.timeSlots(days[dayIndex]).where((x) => x.available).firstOrNull;
    picked = {?first?.startHour};
  }

  void _changeDay(int i) => setState(() {
    dayIndex = i;
    final first = context.store.timeSlots(days[i]).where((x) => x.available).firstOrNull;
    picked = {?first?.startHour};
    _loadAvailability();
  });

  void _toggle(TimeSlot s) => setState(() {
    if (!_multi) {
      picked = {s.startHour};
    } else if (!picked.remove(s.startHour)) {
      picked.add(s.startHour);
    }
  });

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final slots = [
      for (final s in store.timeSlots(days[dayIndex]))
        TimeSlot(s.date, s.startHour, s.endHour, available: s.available && (!store.isLive || available.contains(s.startHour))),
    ];
    final open = slots.where((s) => s.available).toList();
    final noneFree = open.isEmpty;
    final chosen = [for (final s in open) if (picked.contains(s.startHour)) s];
    final wholeDay = _multi && open.length > 1 && chosen.length == open.length;
    return WScreen(
      header: const BookingHeader(step: 4, label: 'Time', fraction: 0.8),
      footer: WFooterBar(
        showCall: false,
        child: WButton(
          'Next',
          enabled: chosen.isNotEmpty && !fetching && !noneFree,
          onTap: () {
            final windows = [for (final s in chosen) (s.startHour, s.endHour)];
            store.set(
              () => store.draft.slot = TimeSlot(
                days[dayIndex],
                chosen.first.startHour,
                chosen.last.endHour,
                windows: windows.length > 1 ? windows : const [],
                anyTime: wholeDay,
              ),
            );
            context.router.go(N.review);
          },
        ),
      ),
      children: [
        WTitleBlock(
          'When should we come?',
          subtitle: noneFree ? null : (_multi ? 'Pick one or more windows. The captain arrives any time in them.' : 'The captain arrives any time in this window.'),
        ),
        WSegmented(options: [for (final d in days) Fmt.day(d)], selection: dayIndex, onChanged: _changeDay),
        const SizedBox(height: 20),
        if (fetching)
          const WText('Checking captain capacity…', WType.body)
        else if (noneFree)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: WBanner(
              tone: slotError != null ? Tone.error : Tone.wait,
              icon: slotError != null ? WIcon.warning : WIcon.search,
              text: store.isLive
                  ? slotError ?? 'No captains are available in this society for this date. Choose another date or come back later.'
                  : 'No captains free today in your society. Tomorrow has slots from 6 AM.',
              actionTitle: slotError != null || dayIndex == days.length - 1 ? 'Retry' : 'Next date',
              onAction: () {
                if (slotError == null && dayIndex < days.length - 1) {
                  _changeDay(dayIndex + 1);
                } else {
                  setState(() {
                    requested = '';
                    _loadAvailability();
                  });
                }
              },
            ),
          ),
        // "Any time of the day": one tap picks every open window; tap again to clear.
        if (_multi && !fetching && open.length > 1) ...[
          Pressable(
            onTap: () => setState(() => picked = wholeDay ? {} : {for (final s in open) s.startHour}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: outlinedDecoration(
                radius: WRadius.chip,
                fill: wholeDay ? WColor.primaryTint : WColor.white,
                stroke: wholeDay ? WColor.primary : WColor.border,
                width: wholeDay ? 2 : 1,
              ),
              child: Row(
                children: [
                  WIconView(wholeDay ? WIcon.checkCircle : WIcon.sun, size: 20, color: WColor.primaryStrong),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WText('Any time of the day', WType.bodyStrong, color: wholeDay ? WColor.primaryStrong : WColor.heading, weight: semibold),
                        WText('No time preference. The captain picks when to come.', WType.small, color: WColor.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!fetching && slotError == null)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 159 / 54,
            children: [
              for (final s in slots)
                WChip(
                  s.label,
                  selected: picked.contains(s.startHour) && s.available,
                  enabled: s.available,
                  strike: !s.available,
                  height: 54,
                  fill: true,
                  onTap: () => _toggle(s),
                ),
            ],
          ),
        if (!fetching && !noneFree && slotError == null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: WText(
              chosen.length > 1 && !wholeDay
                  ? 'You picked ${chosen.length} windows: ${TimeSlot(days[dayIndex], 0, 0, windows: [for (final s in chosen) (s.startHour, s.endHour)]).label}. No need to be home.'
                  : 'No need to be home. A captain comes in your slot and cleans your vehicle just the way you asked.',
              WType.caption,
            ),
          ),
      ],
    );
  }
}

// MARK: C13 Check and pay (+ C17 pay sheet)

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _sheetOpen = false;

  bool _freeDefaulted = false;
  bool _useCredit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Someone with a free wash uses it by default; they can switch it off.
    if (_freeDefaulted) return;
    _freeDefaulted = true;
    final store = context.store;
    if ((store.customer?.freeWashes ?? 0) > 0 && !store.isLive) store.draft.useFreeWash = true;
  }

  void _syncSheet() {
    final router = context.router;
    if (router.showPaySheet && !_sheetOpen && isTopScreen(context)) {
      _sheetOpen = true;
      showWSheet<void>(
        context,
        height: 520,
        builder: (_) => AppScope(store: context.store, router: router, child: const PayMethodSheet()),
      ).whenComplete(() {
        _sheetOpen = false;
        if (router.showPaySheet) router.openPaySheet(false);
      });
    } else if (!router.showPaySheet && _sheetOpen) {
      _sheetOpen = false;
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSheet();
    });
    final d = store.draft;
    final free = store.customer?.freeWashes ?? 0;
    // Credit from a late cancellation comes off automatically (not with a free wash).
    final credit = store.isLive ? 0 : (store.customer?.credit ?? 0);
    d.creditApplied = d.useFreeWash || !_useCredit ? 0 : credit.clamp(0, d.basePrice);
    return WScreen(
      header: const BookingHeader(step: 5, label: 'Pay', fraction: 1),
      footer: WFooterBar(
        showCall: false,
        child: d.price == 0
            // Free wash: nothing to pay, so skip the payment sheet.
            ? WButton(d.useFreeWash ? 'Book with free wash' : 'Book with credit', kind: ButtonKind.success, onTap: () => store.isLoggedIn ? router.push(const R(N.paying, pay: PayView.processing)) : router.go(N.login))
            : WButton('Continue to pay', onTap: () => store.isLoggedIn ? router.openPaySheet(true) : router.go(N.login)),
      ),
      children: [
        const WTitleBlock('Check and pay'),
        WCard(
          radius: 16,
          onTap: router.pop,
          child: Row(
            children: [
              WIconBox(d.type?.icon ?? WIcon.car, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WPlate(d.plate.isEmpty ? 'TS 09 EA 4521' : d.plate),
                    const SizedBox(height: 6),
                    WText(
                      '${d.type?.shortName ?? ''}${d.wash != null ? ' · ${d.wash!.shortName}' : ''} · ${d.place?.tower ?? ''} · ${d.place?.parkingShort ?? ''}',
                      WType.caption,
                    ),
                  ],
                ),
              ),
              const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
            ],
          ),
        ),
        const SizedBox(height: 18),
        WKeyValueCard(
          boldLast: true,
          rows: [('When', d.slot?.full ?? ''), ('Wash', d.wash == WashKind.dryDusting ? 'Exterior · dry dusting' : 'Exterior · water and cloth'), ('Notes', d.note.summary), ('Total', Fmt.rupees(d.price))],
        ),
        // Only when they have one: a short note that a free wash can pay for this booking.
        if (free > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const WIconView(WIcon.gift, size: 22, color: WColor.onSuccess),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WText(free == 1 ? 'You have 1 free wash' : 'You have $free free washes', WType.bodyStrong, color: WColor.onSuccess),
                      WText(d.useFreeWash ? 'Used for this booking. You pay ₹0.' : 'Use it for this booking and pay nothing.', WType.caption, color: WColor.onSuccess),
                    ],
                  ),
                ),
                WToggle(on: d.useFreeWash, tint: WColor.success, onChanged: (v) => store.set(() => store.draft.useFreeWash = v)),
              ],
            ),
          ),
        ],
        if (credit > 0 && !d.useFreeWash) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            decoration: BoxDecoration(color: WColor.successTint, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const WIconView(WIcon.rupee, size: 22, color: WColor.onSuccess),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WText('${Fmt.rupees(credit)} credit', WType.bodyStrong, color: WColor.onSuccess),
                      WText(
                        _useCredit ? '${Fmt.rupees(d.creditApplied)} off. You pay ${Fmt.rupees(d.price)}.' : 'From a cancelled booking. Use it here?',
                        WType.caption,
                        color: WColor.onSuccess,
                      ),
                    ],
                  ),
                ),
                WToggle(on: _useCredit, tint: WColor.success, onChanged: (v) => setState(() => _useCredit = v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (d.price > 0) HeldSafelyBanner(amount: d.price),
      ],
    );
  }
}

// MARK: C17 Payment method sheet

class PayMethodSheet extends StatelessWidget {
  const PayMethodSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final price = store.draft.price;
    // Scrolls if the phone is short, so the Pay button is never cut off.
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            WText('Pay ${Fmt.rupees(price)}', WType.section, weight: semibold, mono: true),
            const Spacer(),
            const WBadge('Held until you approve', tone: Tone.mute, icon: WIcon.shield),
          ],
        ),
        const SizedBox(height: 14),
        for (final m in store.paymentMethods) ...[
          WSelectionTile(
            icon: WIcon.receipt,
            title: m.title,
            subtitle: m.detail,
            selected: store.payMethodId == m.id,
            radio: true,
            iconTone: Tone.mute,
            onTap: () => store.set(() => store.payMethodId = m.id),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        WButton(
          'Pay ${Fmt.rupees(price)}',
          kind: ButtonKind.success,
          onTap: () {
            router.openPaySheet(false);
            router.push(const R(N.paying, pay: PayView.processing));
          },
        ),
        const SizedBox(height: 10),
        const WText('Secured by Razorpay. Full refund if no captain comes.', WType.caption, align: TextAlign.center),
      ],
    ),
    );
  }
}
