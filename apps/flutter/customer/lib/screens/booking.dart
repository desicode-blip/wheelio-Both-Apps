import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

// MARK: C05 Vehicle type (C52: 200% text)

class VehicleTypeScreen extends StatelessWidget {
  const VehicleTypeScreen({super.key, this.large = false});
  final bool large;

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
          header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
          footer: large
              ? Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: WColor.divider))), padding: const EdgeInsets.symmetric(horizontal: WSpace.gutter, vertical: 12), child: next)
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
                    decoration: outlinedDecoration(radius: 16, fill: store.draft.type == t ? WColor.primaryTint : WColor.white, stroke: store.draft.type == t ? WColor.primary : WColor.border, width: store.draft.type == t ? 2 : 1),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      WText(t.name, WType.section, weight: semibold),
                      WText('About ${t.minutes} min', WType.body),
                      WText(Fmt.rupees(t.price), WType.section, weight: bold),
                    ]),
                  ),
                )
              else
                WSelectionTile(icon: t.icon, title: t.name, subtitle: 'About ${t.minutes} min', trailing: Fmt.rupees(t.price), selected: store.draft.type == t, onTap: () => store.set(() => store.draft.type = t)),
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
        footer: WFooterBar(showCall: false, child: WButton('Next', enabled: store.draft.wash != null, onTap: () => router.go(N.vehicleNumber))),
        children: [
          WTitleBlock('What kind of wash?', subtitle: 'Same price for every option${store.draft.type != null ? ': ${Fmt.rupees(store.draft.type!.price)}' : ''}.'),
          for (final w in options) ...[
            Opacity(
              opacity: w.available ? 1 : 0.7,
              child: Pressable(
                onTap: () {
                  if (w.available) {
                    store.set(() => store.draft.wash = w);
                  } else {
                    showWAlert(context, title: 'Not available in your society yet', message: 'Inside cleaning isn’t offered in your society right now. We’ll let you know when it is.');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: outlinedDecoration(radius: 16, fill: store.draft.wash == w ? WColor.primaryTint : WColor.white, stroke: store.draft.wash == w ? WColor.primary : WColor.border, width: store.draft.wash == w ? 2 : 1),
                  child: Row(children: [
                    WIconBox(w.icon, size: 48, tone: w.available ? Tone.info : Tone.mute),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        WText(w.name(isBike), WType.title),
                        const SizedBox(height: 2),
                        WText(w.detail(isBike), WType.caption),
                        if (!w.available) const Padding(padding: EdgeInsets.only(top: 2), child: WText('Not in your society yet', WType.label, color: WColor.secondary)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      label: 'See what ${w.name(isBike)} means',
                      onTap: () => showWAlert(context, title: 'Video coming soon', message: 'We’re making a short video that shows this wash. For now, pick the one you like and carry on.'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: store.draft.wash == w ? Colors.transparent : WColor.primaryTint),
                        alignment: Alignment.center,
                        child: const WIconView(WIcon.eye, size: 18, color: WColor.primaryStrong),
                      ),
                    ),
                  ]),
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
    context.store.set(() => context.store.draft.plate = t.toUpperCase());
    context.router.go(N.photos);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.store.draft.type;
    return WScreen(
      header: const BookingHeader(step: 1, label: 'Vehicle', fraction: 0.2),
      footer: WFooterBar(showCall: false, child: WButton('Next', enabled: plate.trim().isNotEmpty, onTap: _next)),
      children: [
        const WTitleBlock('What’s the number plate?', subtitle: 'So the captain finds the right vehicle.'),
        WTextField(label: 'Vehicle number', value: plate, placeholder: 'TS 09 EA 4521', helper: 'Use the number on your plate', caps: TextCapitalization.characters, autofocus: true, onSubmit: _next, onChanged: (v) => setState(() => plate = v)),
        if (t != null)
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Pressable(
              onTap: context.router.pop,
              child: Row(children: [
                WIconBox(t.icon, size: 38, radius: 10),
                const SizedBox(width: 10),
                WText('${t.shortName} · ${Fmt.rupees(t.price)} · ', WType.caption),
                const WText('Change', WType.caption, color: WColor.primaryStrong, decoration: TextDecoration.underline),
              ]),
            ),
          ),
      ],
    );
  }
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          WButton('Next', enabled: d.photosComplete, onTap: goNext),
          // Photos are optional for the customer: the captain takes the official before photos.
          if (!d.photosComplete)
            WLink('Skip for now', color: WColor.secondary, k: WType.caption, onTap: () => showWAlert(
                  context,
                  title: 'Skip the photos?',
                  message: 'Without your photos from before the wash, we won’t be able to take up any claim if something goes wrong later.',
                  actions: [const AlertAction('Take photos', cancel: true), AlertAction('Skip anyway', onTap: goNext)],
                )),
        ]),
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
        if (d.videoSeconds != null && d.photosComplete)
          Container(
            margin: const EdgeInsets.only(top: 20),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const ShapeDecoration(color: WColor.canvas, shape: StadiumBorder()),
            child: Row(children: [
              const WIconView(WIcon.video, size: 17, color: WColor.primaryStrong),
              const SizedBox(width: 12),
              Expanded(child: WText('Walk-around video · ${Fmt.clock(d.videoSeconds!)}', WType.bodyStrong, color: WColor.heading)),
              const WIconView(WIcon.check, size: 15),
            ]),
          )
        else if (!d.hasFailedPhoto)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Pressable(
              onTap: () => store.set(() => store.draft.videoSeconds = 14),
              child: const DashedBorder(
                child: SizedBox(
                  height: 62,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    WIconView(WIcon.video, size: 17, color: WColor.primaryStrong),
                    SizedBox(width: 10),
                    WText('Walk-around video · optional, 15 sec', WType.bodyStrong, color: WColor.primaryStrong, weight: medium),
                  ]),
                ),
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

  void _shoot() {
    final store = context.store;
    final a = current;
    store.uploadPhoto(a);
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
        child: Column(children: [
          WAppBar(title: '${current.label} · ${index + 1} of 4', leading: WIcon.close, trailing: null, dark: true, onLeading: router.pop),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(color: WColor.cameraPanel, borderRadius: BorderRadius.circular(20)),
              child: Stack(children: [
                const Center(child: CustomPaint(size: Size(250, 160), painter: CarOutlinePainter())),
                Positioned(left: 16, right: 16, bottom: 22, child: WText('Fit the ${current.label.toLowerCase()} of the vehicle in the outline', WType.body, color: Colors.white.withValues(alpha: 0.9), align: TextAlign.center)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(children: [
              const SizedBox(width: 60),
              const Spacer(),
              ShutterButton(onTap: _shoot),
              const Spacer(),
              SizedBox(width: 60, child: Center(child: WIconView(WIcon.flash, size: 20, color: Colors.white.withValues(alpha: 0.5)))),
            ]),
          ),
        ]),
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
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: WColor.white, width: 5)),
          alignment: Alignment.center,
          child: Container(width: size * 0.8, height: size * 0.8, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
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
    drawDashed(canvas, p, Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5, 9, 7);
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
        child: WButton('Yes, it’s here', onTap: () {
          store.set(() => store.draft.place = Place(place.society, tower: place.tower));
          router.go(N.floorSlot);
        }),
      ),
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: WSpace.gutter), child: WTitleBlock('Is your vehicle here?', subtitle: 'Drag the map to move the pin.')),
        const SizedBox(height: 330, child: MapPlaceholder()),
        Padding(
          padding: const EdgeInsets.fromLTRB(WSpace.gutter, 18, WSpace.gutter, 0),
          child: WCard(
            outlined: true,
            child: Row(children: [
              const WIconBox(WIcon.home, size: 44, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WText('${place.society.name}, ${place.tower}', WType.title),
                  WText(place.addressLine, WType.caption),
                ]),
              ),
              WLink('Change', onTap: () => router.go(N.addressSearch)),
            ]),
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
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
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
                child: Stack(children: [
                  for (var i = 0; i < 25; i++)
                    Positioned(
                      left: -w * 0.4 + (i % 5) * w * 0.36 + off.dx,
                      top: -h * 0.4 + (i ~/ 5) * h * 0.36 + off.dy,
                      width: w * 0.28,
                      height: h * 0.25,
                      child: Container(decoration: BoxDecoration(color: i % 7 == 1 || i % 7 == 5 ? WColor.mapGreen : WColor.mapBlock, borderRadius: BorderRadius.circular(6))),
                    ),
                  Positioned(
                    left: w * 0.51 - 15,
                    top: h * 0.43 - 20,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(0, dragging ? -0.25 : 0),
                      child: Column(children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(color: WColor.primary, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Container(width: 11, height: 11, decoration: const BoxDecoration(color: WColor.white, shape: BoxShape.circle)),
                        ),
                        const SizedBox(height: 2),
                        Container(width: 16, height: 6, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8))),
                      ]),
                    ),
                  ),
                  Positioned(right: 26, bottom: 16, child: WIconButton(WIcon.locate, label: 'My location', onTap: () => setState(() => off = Offset.zero))),
                ]),
              ),
            ),
          ),
        );
      });
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
      footer: WFooterBar(showCall: false, child: WButton('Next', enabled: picked, onTap: () => router.go(N.floorSlot))),
      children: [
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 18), child: WText('Where is your vehicle?', WType.screen)),
        WTextField(label: 'Society or building', value: query, leadingIcon: WIcon.search, autofocus: true, onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 14),
        for (final s in store.searchSocieties(query)) ...[
          Pressable(
            feedback: false,
            onTap: () {
              setState(() => picked = true);
              store.set(() => store.draft.place = Place(s, tower: 'Tower 3'));
              router.go(N.floorSlot);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const WIconBox(WIcon.location, size: 40, radius: 10),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_highlighted(s.name), WText('${s.area}, ${s.city}', WType.caption)])),
              ]),
            ),
          ),
          const WDivider(),
        ],
        const SizedBox(height: 14),
        const Row(children: [WText('Can’t find it?', WType.caption), SizedBox(width: 4), WLink('Enter address by hand', k: WType.caption)]),
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
  late String? floor = context.store.draft.place?.floor ?? 'B2';
  late String slot = (context.store.draft.place?.slot.isNotEmpty ?? false) ? context.store.draft.place!.slot : '41';

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return WScreen(
      header: const BookingHeader(step: 3, label: 'Place', fraction: 0.6),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Next', enabled: floor != null, onTap: () {
          store.set(() {
            store.draft.place?.floor = floor;
            store.draft.place?.slot = slot.trim();
          });
          context.router.go(N.entryNotes);
        }),
      ),
      children: [
        WTitleBlock('Where is it parked?', subtitle: store.draft.place?.title ?? ''),
        const WSectionLabel('Parking floor'),
        WFlow(children: [for (final f in floors) WChip(f, selected: floor == f, onTap: () => setState(() => floor = f))]),
        const SizedBox(height: 26),
        WTextField(label: 'Slot number', value: slot, placeholder: 'Slot number', helper: 'Optional, but it saves the captain time', leadingIcon: WIcon.parking, caps: TextCapitalization.characters, onChanged: (v) => setState(() => slot = v)),
      ],
    );
  }
}

// MARK: C11 Notes for the captain

class EntryNotesScreen extends StatefulWidget {
  const EntryNotesScreen({super.key});
  @override
  State<EntryNotesScreen> createState() => _EntryNotesScreenState();
}

class _EntryNotesScreenState extends State<EntryNotesScreen> {
  late String text = context.store.draft.note.text;
  late int? voice = context.store.draft.note.voiceSeconds ?? 12;
  bool playing = false;

  Widget _record(WIcon icon, String title, VoidCallback onTap) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: outlinedDecoration(radius: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [WIconView(icon, size: 16), const SizedBox(width: 8), WText(title, WType.bodyStrong, color: WColor.heading, weight: medium)]),
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
        child: WButton('Next', onTap: () {
          store.set(() {
            store.draft.note.text = text;
            store.draft.note.voiceSeconds = voice;
          });
          context.router.go(N.timeSlot);
        }),
      ),
      children: [
        const WTitleBlock('Anything the captain should know?', subtitle: 'Optional. Gate, lift, landmarks.'),
        WTextArea(value: text, placeholder: 'Example: use the B2 ramp near the gym, white car next to the pillar', onChanged: (v) => text = v),
        const WSectionLabel('Or record it', top: 22),
        Row(children: [
          _record(WIcon.mic, 'Voice note', () => setState(() => voice = 12)),
          const SizedBox(width: 12),
          _record(WIcon.video, 'Video', () => store.set(() => store.draft.note.videoSeconds = 10)),
        ]),
        if (voice != null)
          Container(
            margin: const EdgeInsets.only(top: 20),
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: WColor.canvas, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Pressable(
                label: playing ? 'Pause' : 'Play',
                onTap: () => setState(() => playing = !playing),
                child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: WColor.primaryTint, shape: BoxShape.circle), alignment: Alignment.center, child: WIconView(playing ? WIcon.pause : WIcon.play, size: 15, color: WColor.primaryStrong)),
              ),
              const SizedBox(width: 12),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: playing ? const LinearProgressIndicator(minHeight: 3, color: WColor.primary, backgroundColor: WColor.border) : Container(height: 3, color: WColor.border))),
              const SizedBox(width: 12),
              WText(Fmt.clock(voice!), WType.caption, mono: true),
              const SizedBox(width: 12),
              Pressable(label: 'Delete voice note', onTap: () => setState(() => voice = null), child: const WIconView(WIcon.trash, size: 17, color: WColor.destructive)),
            ]),
          ),
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
  TimeSlot? picked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (picked != null) return;
    final s = context.store.draft.slot;
    picked = s != null && s.available ? s : context.store.timeSlots(days[0]).where((x) => x.available).firstOrNull;
  }

  void _changeDay(int i) => setState(() {
        dayIndex = i;
        picked = context.store.timeSlots(days[i]).where((x) => x.available).firstOrNull;
      });

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final slots = store.timeSlots(days[dayIndex]);
    final noneFree = !slots.any((s) => s.available);
    return WScreen(
      header: const BookingHeader(step: 4, label: 'Time', fraction: 0.8),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Next', enabled: picked != null && !noneFree, onTap: () {
          store.set(() => store.draft.slot = picked);
          context.router.go(N.review);
        }),
      ),
      children: [
        WTitleBlock('When should we come?', subtitle: noneFree ? null : 'The captain arrives any time in this window.'),
        WSegmented(options: [for (final d in days) Fmt.day(d)], selection: dayIndex, onChanged: _changeDay),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 159 / 54,
          children: [for (final s in slots) WChip(s.label, selected: picked == s, enabled: s.available, strike: !s.available, height: 54, fill: true, onTap: () => setState(() => picked = s))],
        ),
        if (noneFree)
          Padding(padding: const EdgeInsets.only(top: 20), child: WBanner(tone: Tone.wait, icon: WIcon.search, text: 'No captains free today in your society. Tomorrow has slots from 6 AM.', actionTitle: 'See tomorrow', onAction: () => _changeDay(1)))
        else
          const Padding(padding: EdgeInsets.only(top: 18), child: WText('No need to be home. A captain comes in your slot and cleans your vehicle just the way you asked.', WType.caption)),
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

  void _syncSheet() {
    final router = context.router;
    if (router.showPaySheet && !_sheetOpen && isTopScreen(context)) {
      _sheetOpen = true;
      showWSheet<void>(context, height: 520, builder: (_) => AppScope(store: context.store, router: router, child: const PayMethodSheet())).whenComplete(() {
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
    return WScreen(
      header: const BookingHeader(step: 5, label: 'Pay', fraction: 1),
      footer: WFooterBar(
        showCall: false,
        child: WButton('Continue to pay', onTap: () => store.isLoggedIn ? router.openPaySheet(true) : router.go(N.login)),
      ),
      children: [
        const WTitleBlock('Check and pay'),
        WCard(
          radius: 16,
          onTap: router.pop,
          child: Row(children: [
            WIconBox(d.type?.icon ?? WIcon.car, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                WPlate(d.plate.isEmpty ? 'TS 09 EA 4521' : d.plate),
                const SizedBox(height: 6),
                WText('${d.type?.shortName ?? ''}${d.wash != null ? ' · ${d.wash!.shortName}' : ''} · ${d.place?.tower ?? ''} · ${d.place?.parkingShort ?? ''}', WType.caption),
              ]),
            ),
            const WIconView(WIcon.chevron, size: 13, color: WColor.secondary),
          ]),
        ),
        const SizedBox(height: 18),
        WKeyValueCard(boldLast: true, rows: [
          ('When', d.slot?.full ?? ''),
          ('Wash', 'Exterior · water and cloth'),
          ('Notes', d.note.summary),
          ('Total', Fmt.rupees(d.price)),
        ]),
        if (free > 0)
          WToggleRow(
            padding: const EdgeInsets.only(top: 14),
            on: d.useFreeWash,
            tint: WColor.success,
            onChanged: (v) => store.set(() => store.draft.useFreeWash = v),
            child: WText('Use a free wash ($free left)', WType.bodyStrong),
          ),
        const SizedBox(height: 18),
        HeldSafelyBanner(amount: d.price),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        WText('Pay ${Fmt.rupees(price)}', WType.section, weight: semibold, mono: true),
        const Spacer(),
        const WBadge('Held until you approve', tone: Tone.mute, icon: WIcon.shield),
      ]),
      const SizedBox(height: 14),
      for (final m in store.paymentMethods) ...[
        WSelectionTile(icon: WIcon.receipt, title: m.title, subtitle: m.detail, selected: store.payMethodId == m.id, radio: true, iconTone: Tone.mute, onTap: () => store.set(() => store.payMethodId = m.id)),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 6),
      WButton('Pay ${Fmt.rupees(price)}', kind: ButtonKind.success, onTap: () {
        router.openPaySheet(false);
        router.push(const R(N.paying, pay: PayView.processing));
      }),
      const SizedBox(height: 10),
      const WText('Secured by Razorpay. Full refund if no captain comes.', WType.caption, align: TextAlign.center),
    ]);
  }
}
