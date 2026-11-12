import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../screens/common.dart';
import 'vehicle_profile.dart';

// v2 CU-CARE (12 Nov 2026, Aman): photos → "Is this your vehicle?" → care routine.

/// Where the booking goes after the photos and the vehicle steps.
N routeAfterPhotos(AppStore store) {
  final d = store.draft;
  return d.isRepeat && d.place != null ? N.timeSlot : d.place == null ? N.location : N.floorSlot;
}

/// After the photos: the vehicle check when there are photos, otherwise straight on.
N routeFromPhotos(AppStore store) =>
    store.v2Features && !store.draft.addingVehicle && store.draft.photosDone > 0 ? N.vehicleCheck : routeAfterPhotos(store);

class VehicleCheckScreen extends StatefulWidget {
  const VehicleCheckScreen({super.key});
  @override
  State<VehicleCheckScreen> createState() => _VehicleCheckScreenState();
}

enum _Stage { checking, found, form }

class _VehicleCheckScreenState extends State<VehicleCheckScreen> {
  _Stage stage = _Stage.checking;
  VehicleProfile? found;
  bool saved = false; // details from an earlier booking of this plate
  late VehicleProfile edit = VehicleProfile();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  Future<void> _check() async {
    final store = context.store;
    final known = store.draft.vehicleProfile;
    VehicleProfile? p = known == null ? null : VehicleProfile.fromJson(known);
    if (p == null || p.isEmpty) {
      p = await store.savedProfileFor(store.draft.plate);
      saved = p != null && !p.isEmpty;
    } else {
      saved = true;
    }
    if (!saved) p = await store.identifyVehicle();
    if (!mounted) return;
    setState(() {
      found = p == null || p.isEmpty ? null : p;
      edit = (found ?? VehicleProfile()).copy();
      stage = found == null ? _Stage.form : _Stage.found;
    });
  }

  Future<void> _use(VehicleProfile p) async {
    final store = context.store, router = context.router;
    final kind = store.draft.type?.kind ?? VehicleKind.sedan;
    final routine = careRoutineFor(p, kind, coverage: store.draft.coverage);
    store.set(() {
      store.draft.vehicleProfile = p.toJson();
      store.draft.careRoutine = [for (final c in routine) {'title': c.title, 'detail': c.detail}];
    });
    await store.saveProfile(store.draft.plate, p);
    if (mounted) router.go(N.careRoutine);
  }

  void _skip() {
    final store = context.store;
    store.set(() {
      store.draft.vehicleProfile = null;
      store.draft.careRoutine = const [];
    });
    context.router.go(routeAfterPhotos(store));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final bike = store.draft.type?.kind == VehicleKind.bike;
    const header = BookingHeader(step: 2, label: 'Your vehicle', fraction: 0.45);
    return switch (stage) {
      _Stage.checking => WScreen(
        header: header,
        children: [
          const WTitleBlock('Checking your photos'),
          _PhotoBanner(bytes: store.draftPhotoBytes[PhotoAngle.front] ?? store.draftPhotoBytes.values.firstOrNull, bike: bike),
          const SizedBox(height: 24),
          const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: WColor.primary))),
          const SizedBox(height: 12),
          const Center(child: WText('Finding the make, colour and paint', WType.caption)),
        ],
      ),
      _Stage.found => WScreen(
        header: header,
        footer: WFooterBar(
          showCall: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WButton('Yes, that’s it', onTap: () => _use(found!..fromAi = !saved && found!.fromAi)),
              WLink('No, edit details', color: WColor.secondary, k: WType.caption, onTap: () => setState(() => stage = _Stage.form)),
            ],
          ),
        ),
        children: [
          WTitleBlock(saved ? 'Same vehicle as before?' : 'Is this your vehicle?'),
          _PhotoBanner(bytes: store.draftPhotoBytes[PhotoAngle.front] ?? store.draftPhotoBytes.values.firstOrNull, bike: bike),
          const SizedBox(height: 16),
          _ProfileSummary(profile: found!, bike: bike),
          if (!saved && found!.fromAi) ...[
            const SizedBox(height: 12),
            const Row(children: [
              WIconView(WIcon.sparkle, size: 14, color: WColor.secondary),
              SizedBox(width: 6),
              Expanded(child: WText('Found by AI from your photos', WType.caption)),
            ]),
          ],
        ],
      ),
      _Stage.form => WScreen(
        header: header,
        footer: WFooterBar(
          showCall: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WButton('Continue', enabled: !edit.isEmpty, onTap: () => _use(edit..fromAi = false)),
              WLink('Skip', color: WColor.secondary, k: WType.caption, onTap: _skip),
            ],
          ),
        ),
        children: [
          const WTitleBlock('Tell us about your vehicle', subtitle: 'Optional. The more we know, the better your Captain cares for it.'),
          WTextField(label: 'Company', value: edit.make, placeholder: bike ? 'e.g. Royal Enfield' : 'e.g. Hyundai', caps: TextCapitalization.words, onChanged: (v) => setState(() => edit.make = v)),
          const SizedBox(height: 14),
          WTextField(label: 'Model', value: edit.model, placeholder: bike ? 'e.g. Classic 350' : 'e.g. Creta', caps: TextCapitalization.words, onChanged: (v) => setState(() => edit.model = v)),
          const SizedBox(height: 14),
          WTextField(label: 'Colour', value: edit.color, placeholder: 'e.g. Pearl white', caps: TextCapitalization.sentences, onChanged: (v) => setState(() => edit.color = v)),
          const SizedBox(height: 20),
          const WText('Paint', WType.title),
          const SizedBox(height: 10),
          WFlow(children: [
            for (final f in PaintFinish.values) WChip(f.label, selected: edit.finish == f, onTap: () => setState(() => edit.finish = f)),
          ]),
          if (!bike) ...[
            const SizedBox(height: 20),
            const WText('Seats', WType.title),
            const SizedBox(height: 10),
            WFlow(children: [
              for (final s in SeatKind.values) WChip(s.label, selected: edit.seats == s, onTap: () => setState(() => edit.seats = s)),
            ]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    };
  }
}

class _PhotoBanner extends StatelessWidget {
  const _PhotoBanner({required this.bytes, required this.bike});
  final Uint8List? bytes;
  final bool bike;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: bytes != null
          ? Image.memory(bytes!, fit: BoxFit.cover)
          : ColoredBox(
              color: WColor.primaryTint,
              child: Center(child: WIconView(bike ? WIcon.bike : WIcon.carFill, size: 56, color: WColor.primary)),
            ),
    ),
  );
}

/// Name in big type, then colour and paint as two labelled values.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.bike});
  final VehicleProfile profile;
  final bool bike;
  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget fact(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [WText(label, WType.caption), const SizedBox(height: 2), WText(value.isEmpty ? '—' : value, WType.valueStrong)],
      ),
    );
    return WCard(
      radius: 16,
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WText(p.name.isEmpty ? (bike ? 'Your bike' : 'Your car') : p.name, WType.section),
          const SizedBox(height: 14),
          Row(children: [
            fact('Colour', p.color),
            fact('Paint', p.finish == PaintFinish.unknown ? '' : p.finish.label),
            if (!bike && p.seats != SeatKind.unknown) fact('Seats', p.seats.label),
          ]),
        ],
      ),
    );
  }
}

/// The 2–3 care adjustments for this vehicle.
class CareRoutineScreen extends StatelessWidget {
  const CareRoutineScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router, d = store.draft;
    final p = d.vehicleProfile == null ? VehicleProfile() : VehicleProfile.fromJson(d.vehicleProfile!);
    final bike = d.type?.kind == VehicleKind.bike;
    final steps = careRoutineFor(p, d.type?.kind ?? VehicleKind.sedan, coverage: d.coverage);
    return WScreen(
      header: const BookingHeader(step: 2, label: 'Care routine', fraction: 0.5),
      footer: WFooterBar(showCall: false, child: WButton('Next', onTap: () => router.go(routeAfterPhotos(store)))),
      children: [
        WTitleBlock('Your care routine', subtitle: 'For your ${p.name.isEmpty ? (bike ? 'bike' : 'car') : p.name}'),
        for (final (i, s) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          WCard(
            radius: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WIconBox(s.icon, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [WText(s.title, WType.title), const SizedBox(height: 4), WText(s.detail, WType.caption)],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Row(children: [
          WIconView(WIcon.user, size: 14, color: WColor.secondary),
          SizedBox(width: 6),
          Expanded(child: WText('Your Captain sees this before the wash.', WType.caption)),
        ]),
      ],
    );
  }
}
