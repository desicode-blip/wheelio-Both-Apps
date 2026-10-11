import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/backend.dart';
import '../data/models.dart';
import '../data/validators.dart';
import '../routes.dart';
import '../state/app_state.dart';
import 'common.dart';

IconData vehicleIcon(VehicleKind k) => switch (k) {
      VehicleKind.bike => Icons.two_wheeler_rounded,
      VehicleKind.hatchback => Icons.directions_car_outlined,
      VehicleKind.sedan => Icons.directions_car_filled_outlined,
      VehicleKind.suv => Icons.airport_shuttle_outlined,
    };

// ---------------------------------------------------------------------------
// C05-VehicleType (and C52 at 200% text)

class VehicleTypeScreen extends StatefulWidget {
  const VehicleTypeScreen({super.key});

  @override
  State<VehicleTypeScreen> createState() => _VehicleTypeScreenState();
}

class _VehicleTypeScreenState extends State<VehicleTypeScreen> {
  late final Future<List<VehicleType>> _types = AppScope.read(context).backend.vehicleTypes();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selected = app.draft.type;
    return WScreen(
      header: const BookingHeader(step: 1, label: 'Vehicle'),
      children: [
        const WTitleBlock(title: 'What are we washing?', subtitle: 'Exterior water wash. Bucket and cloth, no soap.'),
        FutureBuilder<List<VehicleType>>(
          future: _types,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const WGap(children: [WSkeleton(height: 82, radius: 20), WSkeleton(height: 82, radius: 20)]);
            }
            return WGap(
              children: [
                for (final t in snap.data!)
                  WSelectionTile(
                    icon: vehicleIcon(t.kind),
                    title: t.name,
                    subtitle: 'About ${t.minutes} min',
                    trailingText: rupees(t.price),
                    selected: selected?.kind == t.kind,
                    onTap: () {
                      app.draft.type = t;
                      app.changed();
                    },
                  ),
              ],
            );
          },
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(label: 'Next', onPressed: selected == null ? null : () => context.push(R.vehicleNumber)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C06-VehicleNumber, C06b (invalid)

class VehicleNumberScreen extends StatefulWidget {
  const VehicleNumberScreen({super.key, this.showError = false});

  final bool showError;

  @override
  State<VehicleNumberScreen> createState() => _VehicleNumberScreenState();
}

class _VehicleNumberScreenState extends State<VehicleNumberScreen> {
  late final TextEditingController _plate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = AppScope.read(context).draft;
    _plate = TextEditingController(text: widget.showError ? 'TS 09' : draft.plate);
    if (widget.showError) _error = 'Enter the full number, like TS 09 EA 4521';
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  void _next() {
    if (!Validators.isValidPlate(_plate.text)) {
      setState(() => _error = 'Enter the full number, like TS 09 EA 4521');
      return;
    }
    final app = AppScope.read(context);
    app.draft.plate = Validators.formatPlate(_plate.text);
    context.push(R.photos);
  }

  @override
  Widget build(BuildContext context) {
    final type = AppScope.of(context).draft.type;
    return WScreen(
      header: const BookingHeader(step: 1, label: 'Vehicle'),
      children: [
        const WTitleBlock(title: 'What’s the number plate?', subtitle: 'So the washer finds the right vehicle.'),
        WTextField(
          label: 'Vehicle number',
          controller: _plate,
          hint: 'TS 09 EA 4521',
          helper: 'Use the number on your plate',
          error: _error,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _next(),
        ),
        if (type != null)
          Row(
            children: [
              Icon(vehicleIcon(type.kind), size: 20, color: WColors.secondary),
              const SizedBox(width: 8),
              Text('${type.name} · ${rupees(type.price)} · ', style: WText.body),
              WLinkButton(label: 'Change', onTap: () => goBack(context, R.vehicleType)),
            ],
          ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Next', onPressed: _next)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C07-Photos, C07b (partial, one failed), C07c (all done)

Future<void> uploadDraftPhoto(AppState app, PhotoAngle angle, String path) async {
  app.draft.photos[angle] = PhotoRef(localPath: path, takenAt: DateTime.now());
  app.changed();
  try {
    final url = await app.backend.uploadPhoto(angle, path);
    app.draft.photos[angle] = app.draft.photos[angle]!.copyWith(state: UploadState.done, remoteUrl: url);
  } on BackendException {
    // The photo stays on the phone; the customer can retry.
    app.draft.photos[angle] = app.draft.photos[angle]!.copyWith(state: UploadState.failed);
  }
  app.changed();
}

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.draft;
    final complete = d.photosComplete;
    final failed = PhotoAngle.values.where((a) => d.photos[a]?.state == UploadState.failed).toList();

    WPhotoState stateOf(PhotoAngle a) => switch (d.photos[a]?.state) {
          null || UploadState.none => WPhotoState.empty,
          UploadState.uploading => WPhotoState.uploading,
          UploadState.done => WPhotoState.filled,
          UploadState.failed => WPhotoState.failed,
        };

    void onSlot(PhotoAngle a) {
      final p = d.photos[a];
      if (p?.state == UploadState.failed) {
        uploadDraftPhoto(app, a, p!.localPath);
      } else {
        context.push('${R.camera}?angle=${a.name}');
      }
    }

    final String title;
    final String subtitle;
    if (complete) {
      title = 'Looking good';
      subtitle = d.videoSeconds == null
          ? '4 photos. Tap any photo to retake.'
          : '4 photos and a video. Tap any photo to retake.';
    } else {
      title = 'Take 4 quick photos';
      subtitle = d.photos.isEmpty
          ? 'They help the washer find your vehicle. The washer takes the official before photos.'
          : '${d.photosDone} of 4 done';
    }

    return WScreen(
      header: BookingHeader(step: 2, label: 'Photos', onBack: () => goBack(context, R.vehicleNumber)),
      children: [
        WTitleBlock(title: title, subtitle: subtitle),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 4 / 3,
          children: [
            for (final a in PhotoAngle.values) WPhotoSlot(label: a.label, state: stateOf(a), onTap: () => onSlot(a)),
          ],
        ),
        WCard(
          onTap: () {
            d.videoSeconds = 14;
            app.changed();
          },
          child: Row(
            children: [
              WIconTile(icon: d.videoSeconds == null ? Icons.videocam_outlined : Icons.check_rounded,
                  tone: d.videoSeconds == null ? WTone.info : WTone.ok),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  d.videoSeconds == null
                      ? 'Walk-around video · optional, 15 sec'
                      : 'Walk-around video · ${formatClock(d.videoSeconds!)}',
                  style: WText.title,
                ),
              ),
            ],
          ),
        ),
        if (failed.isNotEmpty)
          WBanner(
            tone: WTone.error,
            text: '${failed.first.label} photo didn’t upload. It’s saved on your phone.',
            action: WLinkButton(
              label: 'Retry',
              onTap: () {
                for (final a in failed) {
                  uploadDraftPhoto(app, a, d.photos[a]!.localPath);
                }
              },
            ),
          ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Next', onPressed: complete ? () => context.push(R.location) : null)],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C08-Camera, C08b (permission needed)

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.angle, this.forceDenied = false});

  final PhotoAngle angle;
  final bool forceDenied;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool? _allowed;
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      Future.microtask(_check);
    }
  }

  Future<void> _check() async {
    final ok = widget.forceDenied ? false : await AppScope.read(context).device.ensureCamera();
    if (mounted) setState(() => _allowed = ok);
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    final path = await app.device.takePhoto();
    if (!mounted) return;
    if (path == null) {
      setState(() => _busy = false);
      return;
    }
    uploadDraftPhoto(app, widget.angle, path);
    // Go straight to the next missing angle, or back to the photo grid.
    final next = PhotoAngle.values.where((a) => a != widget.angle && app.draft.photos[a] == null).firstOrNull;
    if (next != null) {
      context.pushReplacement('${R.camera}?angle=${next.name}');
    } else {
      goBack(context, R.photos);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) {
      return const Scaffold(backgroundColor: WColors.camera, body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed == false) {
      return WScreen(
        header: SimpleHeader(fallback: R.photos),
        body: WStateView(
          icon: Icons.no_photography_outlined,
          tone: WTone.wait,
          title: 'Camera access needed',
          body: 'Photos help the washer find your vehicle. Allow camera to continue.',
        ),
        footer: WFooterBar(
          vertical: true,
          children: [
            WButton(
              label: 'Allow camera',
              onPressed: () {
                final device = AppScope.read(context).device;
                // On a real phone this opens Settings when access was refused before.
                device.ensureCamera().then((ok) {
                  // In the gallery's forced-denied state, tapping Allow shows the camera.
                  if (mounted) setState(() => _allowed = ok || widget.forceDenied);
                });
              },
            ),
            WButton.text(label: 'Skip photos for now', onPressed: () => context.go(R.location)),
          ],
        ),
      );
    }
    final index = PhotoAngle.values.indexOf(widget.angle) + 1;
    return Scaffold(
      backgroundColor: WColors.camera,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close camera',
                    onPressed: () => goBack(context, R.photos),
                    icon: const Icon(Icons.close_rounded, color: WColors.white),
                  ),
                  Expanded(
                    child: Text('${widget.angle.label} · $index of 4',
                        textAlign: TextAlign.center, style: WText.appBarTitle.copyWith(color: WColors.white)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: WColors.white.withValues(alpha: 0.85), width: 2),
                        ),
                        child: Icon(Icons.directions_car_outlined, size: 96, color: WColors.white.withValues(alpha: 0.35)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Fit the ${widget.angle.label.toLowerCase()} of the vehicle in the outline',
                        textAlign: TextAlign.center, style: WText.body.copyWith(color: WColors.white)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Semantics(
                button: true,
                label: 'Take photo',
                child: GestureDetector(
                  onTap: _busy ? null : _capture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: WColors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _busy ? WColors.muted : WColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C09-Location, C09b (location off)

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, this.forceOff = false});

  final bool forceOff;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _loading = true;
  bool _started = false;
  Place? _place;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      Future.microtask(() => _locate(first: true));
    }
  }

  Future<void> _locate({bool first = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final app = AppScope.read(context);
    if (first && app.draft.place != null && !widget.forceOff) {
      setState(() {
        _place = app.draft.place;
        _loading = false;
      });
      return;
    }
    final pos = (widget.forceOff && first) ? null : await app.device.currentLocation();
    Place? place;
    if (pos != null) place = await app.backend.placeFromLocation(pos.lat, pos.lng);
    if (!mounted) return;
    setState(() {
      _place = place;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = BookingHeader(step: 3, label: 'Place', onBack: () => goBack(context, R.photos));
    if (_loading) {
      return WScreen(header: header, body: const Center(child: CircularProgressIndicator()));
    }
    final place = _place;
    if (place == null) {
      return WScreen(
        header: header,
        body: const WStateView(
          icon: Icons.location_off_outlined,
          tone: WTone.wait,
          title: 'Location is off',
          body: 'We use it only to find washers in your society. You can also type your address.',
        ),
        footer: WFooterBar(
          vertical: true,
          children: [
            WButton(label: 'Turn on location', onPressed: () => _locate()),
            WButton.text(label: 'Type address', onPressed: () => context.push(R.addressSearch)),
          ],
        ),
      );
    }
    return WScreen(
      header: header,
      children: [
        const WTitleBlock(title: 'Is your vehicle here?', subtitle: 'Drag the map to move the pin.'),
        const WMapPlaceholder(),
        WCard(
          child: Row(
            children: [
              const WIconTile(icon: Icons.apartment_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(place.title, style: WText.title), Text(place.addressLine, style: WText.caption)],
                ),
              ),
              WLinkButton(label: 'Change', onTap: () => context.push(R.addressSearch)),
            ],
          ),
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Yes, it’s here',
            onPressed: () {
              final app = AppScope.read(context);
              app.draft.place = place;
              context.push(R.floorSlot);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C09c-AddressSearch

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _query = TextEditingController(text: 'My Home Av');
  late Future<List<Society>> _results = AppScope.read(context).backend.searchSocieties(_query.text);
  Society? _picked;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _choose(Society s) {
    final app = AppScope.read(context);
    app.draft.place = Place(society: s);
    context.push(R.floorSlot);
  }

  Future<void> _manual() async {
    final name = TextEditingController();
    final area = TextEditingController();
    final ok = await showWSheet<bool>(
      context,
      builder: (context) => WGap(
        gap: 16,
        children: [
          Text('Enter your address', style: WText.section),
          WTextField(label: 'Society or building', controller: name, autofocus: true),
          WTextField(label: 'Area and city', controller: area, hint: 'Narsingi, Hyderabad'),
          WButton(label: 'Use this address', onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && mounted) {
      _choose(Society(id: 'manual', name: name.text.trim(), area: area.text.trim(), city: ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: BookingHeader(step: 3, label: 'Place', onBack: () => goBack(context, R.location)),
      children: [
        const WTitleBlock(title: 'Where is your vehicle?'),
        WTextField(
          label: 'Society or building',
          controller: _query,
          autofocus: true,
          suffix: const Icon(Icons.search_rounded, color: WColors.secondary),
          onChanged: (v) => setState(() => _results = AppScope.read(context).backend.searchSocieties(v)),
        ),
        FutureBuilder<List<Society>>(
          future: _results,
          builder: (context, snap) {
            final list = snap.data ?? const <Society>[];
            return WRowGroup(children: [
              for (final s in list)
                WListRow(
                  leading: const Icon(Icons.location_on_outlined, color: WColors.secondary),
                  title: s.name,
                  subtitle: '${s.area}, ${s.city}',
                  trailing: _picked?.id == s.id ? const Icon(Icons.check_rounded, color: WColors.primary) : null,
                  showChevron: false,
                  onTap: () => setState(() => _picked = s),
                ),
            ]);
          },
        ),
        Row(
          children: [
            Text('Can’t find it? ', style: WText.body),
            WLinkButton(label: 'Enter address by hand', onTap: _manual),
          ],
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [WButton(label: 'Next', onPressed: _picked == null ? null : () => _choose(_picked!))],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C10-FloorSlot

class FloorSlotScreen extends StatefulWidget {
  const FloorSlotScreen({super.key});

  @override
  State<FloorSlotScreen> createState() => _FloorSlotScreenState();
}

class _FloorSlotScreenState extends State<FloorSlotScreen> {
  static const floors = ['B3', 'B2', 'B1', 'Ground', 'Open'];
  late final TextEditingController _slot;
  late final TextEditingController _tower;
  String? _floor;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).draft.place;
    _floor = p?.floor;
    _slot = TextEditingController(text: p?.slot ?? '');
    _tower = TextEditingController(text: p?.tower ?? '');
  }

  @override
  void dispose() {
    _slot.dispose();
    _tower.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final place = app.draft.place;
    return WScreen(
      header: BookingHeader(step: 3, label: 'Place', onBack: () => goBack(context, R.location)),
      children: [
        WTitleBlock(title: 'Where is it parked?', subtitle: place?.title),
        if (place != null && place.tower.isEmpty)
          WTextField(label: 'Tower or block', controller: _tower, hint: 'Tower 3'),
        WGap(
          gap: 10,
          children: [
            Text('Parking floor', style: WText.label),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in floors)
                  WChoiceChip(label: f, selected: _floor == f, onTap: () => setState(() => _floor = f)),
              ],
            ),
          ],
        ),
        WTextField(
          label: 'Slot number',
          controller: _slot,
          hint: '41',
          helper: 'Optional, but it saves the washer time',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Next',
            onPressed: _floor == null || place == null
                ? null
                : () {
                    app.draft.place = place.copyWith(
                      floor: _floor,
                      slot: _slot.text.trim(),
                      tower: place.tower.isEmpty ? _tower.text.trim() : null,
                    );
                    context.push(R.entryNotes);
                  },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C11-EntryNotes

class EntryNotesScreen extends StatefulWidget {
  const EntryNotesScreen({super.key});

  @override
  State<EntryNotesScreen> createState() => _EntryNotesScreenState();
}

class _EntryNotesScreenState extends State<EntryNotesScreen> {
  late final TextEditingController _text;
  int? _voice;
  int? _video;

  @override
  void initState() {
    super.initState();
    final n = AppScope.read(context).draft.note;
    _text = TextEditingController(text: n.text);
    _voice = n.voiceSeconds;
    _video = n.videoSeconds;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WScreen(
      header: BookingHeader(step: 3, label: 'Place', onBack: () => goBack(context, R.floorSlot)),
      children: [
        const WTitleBlock(title: 'Anything the washer should know?', subtitle: 'Optional. Gate, lift, landmarks.'),
        WTextField(
          label: 'Note for the washer',
          controller: _text,
          hint: 'Example: use the B2 ramp near the gym, white car next to the pillar',
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        WGap(
          gap: 10,
          children: [
            Text('Or record it', style: WText.label),
            Row(
              children: [
                WChoiceChip(
                  icon: Icons.mic_none_rounded,
                  label: _voice == null ? 'Voice note' : 'Voice note · ${formatClock(_voice!)}',
                  selected: _voice != null,
                  onTap: () => setState(() {
                    _voice = _voice == null ? 12 : null;
                    _video = null;
                  }),
                ),
                const SizedBox(width: 10),
                WChoiceChip(
                  icon: Icons.videocam_outlined,
                  label: _video == null ? 'Video' : 'Video · ${formatClock(_video!)}',
                  selected: _video != null,
                  onTap: () => setState(() {
                    _video = _video == null ? 12 : null;
                    _voice = null;
                  }),
                ),
              ],
            ),
          ],
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Next',
            onPressed: () {
              AppScope.read(context).draft.note = EntryNote(text: _text.text, voiceSeconds: _voice, videoSeconds: _video);
              context.push(R.timeSlot);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C12-TimeSlot, C12b (no washers free today)

class TimeSlotScreen extends StatefulWidget {
  const TimeSlotScreen({super.key});

  @override
  State<TimeSlotScreen> createState() => _TimeSlotScreenState();
}

class _TimeSlotScreenState extends State<TimeSlotScreen> {
  int _day = 0;
  Future<List<TimeSlot>>? _slots;
  TimeSlot? _picked;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slots ??= _load();
    _picked ??= AppScope.read(context).draft.slot;
  }

  Future<List<TimeSlot>> _load() {
    final app = AppScope.read(context);
    final place = app.draft.place ?? Place(society: const Society(id: '', name: '', area: '', city: ''));
    return app.backend.timeSlots(place, _today.add(Duration(days: _day)));
  }

  void _setDay(int d) => setState(() {
        _day = d;
        _slots = _load();
      });

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 3; i++) _today.add(Duration(days: i))];
    return WScreen(
      header: BookingHeader(step: 4, label: 'Time', onBack: () => goBack(context, R.entryNotes)),
      children: [
        const WTitleBlock(title: 'When should we come?', subtitle: 'The washer arrives any time in this window.'),
        WSegmented(labels: [for (final d in days) formatDay(d)], index: _day, onTap: _setDay),
        FutureBuilder<List<TimeSlot>>(
          future: _slots,
          builder: (context, snap) {
            if (!snap.hasData) return const WSkeleton(height: 180, radius: 14);
            final slots = snap.data!;
            final noneFree = slots.every((s) => !s.available);
            return WGap(
              gap: 16,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.2,
                  children: [
                    for (final s in slots)
                      WChoiceChip(
                        label: s.windowLabel,
                        selected: _picked == s,
                        disabled: !s.available,
                        onTap: () => setState(() => _picked = s),
                      ),
                  ],
                ),
                if (noneFree && _day == 0)
                  WBanner(
                    tone: WTone.wait,
                    text: 'No washers free today in your society. Tomorrow has slots from 6 AM.',
                    action: WLinkButton(label: 'See tomorrow', onTap: () => _setDay(1)),
                  )
                else
                  Text('Full slots are crossed out. You don’t need to be there.', style: WText.caption),
              ],
            );
          },
        ),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: 'Next',
            onPressed: _picked == null
                ? null
                : () {
                    AppScope.read(context).draft.slot = _picked;
                    context.push(R.review);
                  },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C13-Review

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final d = app.draft;
    final type = d.type;
    final place = d.place;
    final slot = d.slot;
    if (type == null || place == null || slot == null) {
      return WScreen(
        header: const BookingHeader(step: 5, label: 'Pay'),
        body: WStateView(
          icon: Icons.edit_note_rounded,
          title: 'A few details are missing',
          body: 'Start again from the vehicle type.',
          children: [WButton(label: 'Start again', onPressed: () => context.go(R.vehicleType))],
        ),
      );
    }
    final credits = app.customer?.freeWashes ?? 0;
    return WScreen(
      header: BookingHeader(step: 5, label: 'Pay', onBack: () => goBack(context, R.timeSlot)),
      children: [
        const WTitleBlock(title: 'Check and pay'),
        WCard(
          onTap: () => context.go(R.vehicleType),
          child: Row(
            children: [
              WIconTile(icon: vehicleIcon(type.kind)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WPlate(number: d.plate),
                    const SizedBox(height: 6),
                    Text('${type.shortName} · ${place.tower.isEmpty ? place.society.name : place.tower} · ${place.parkingShort}',
                        style: WText.caption),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, color: WColors.secondary, semanticLabel: 'Edit'),
            ],
          ),
        ),
        WRowGroup(children: [
          WKeyValue(label: 'When', value: '${formatDay(slot.date)}, ${slot.windowLabel}'),
          const WKeyValue(label: 'Wash', value: 'Exterior · water and cloth'),
          WKeyValue(label: 'Notes', value: d.note.summary),
          WKeyValue(label: 'Total', value: d.useFreeWash ? 'Free wash' : rupees(type.price), strong: true),
        ]),
        if (credits > 0)
          WCard(
            style: WCardStyle.fill,
            onTap: () {
              d.useFreeWash = !d.useFreeWash;
              app.changed();
            },
            child: Row(
              children: [
                Icon(d.useFreeWash ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: WColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text('Use 1 of your $credits free washes', style: WText.title)),
              ],
            ),
          ),
        if (!d.useFreeWash) HeldSafelyBanner(amount: type.price),
      ],
      footer: WFooterBar(
        leading: supportButton(context),
        children: [
          WButton(
            label: d.useFreeWash ? 'Book free wash' : 'Continue to pay',
            onPressed: () {
              if (app.isLoggedIn) {
                context.push(R.payMethod);
              } else {
                app.afterLogin = R.payMethod;
                context.push(R.login);
              }
            },
          ),
        ],
      ),
    );
  }
}
