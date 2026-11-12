import 'dart:convert';
import 'dart:typed_data';

import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart' show WashCoverage;

import '../data/models.dart';
import '../data/store.dart';

// v2 CU-CARE (12 Nov 2026, Aman): after the photos, AI says which vehicle it sees
// (make, model, colour, glossy or matte paint). The customer confirms it, or fixes it in
// an optional form they can skip. Then a short care routine for that vehicle.
//
// AI runs on the server (`identifyVehicle`, Ajay) once `config.vehicleAi` is true. Until
// then live builds go straight to the optional form; sample builds show a sample result.

enum PaintFinish { glossy, matte, unknown }

enum SeatKind { fabric, leather, unknown }

extension PaintFinishName on PaintFinish {
  String get label => switch (this) {
    PaintFinish.glossy => 'Glossy',
    PaintFinish.matte => 'Matte',
    PaintFinish.unknown => 'Not sure',
  };
}

extension SeatKindName on SeatKind {
  String get label => switch (this) {
    SeatKind.fabric => 'Fabric',
    SeatKind.leather => 'Leather',
    SeatKind.unknown => 'Not sure',
  };
}

class VehicleProfile {
  VehicleProfile({this.make = '', this.model = '', this.color = '', this.finish = PaintFinish.unknown, this.seats = SeatKind.unknown, this.fromAi = false});
  String make, model, color;
  PaintFinish finish;
  SeatKind seats;

  /// True while the details are exactly what the AI found (not edited).
  bool fromAi;

  String get name => [make, model].where((s) => s.trim().isNotEmpty).join(' ').trim();
  bool get isEmpty => name.isEmpty && color.trim().isEmpty && finish == PaintFinish.unknown && seats == SeatKind.unknown;

  VehicleProfile copy() => VehicleProfile(make: make, model: model, color: color, finish: finish, seats: seats, fromAi: fromAi);

  Map<String, dynamic> toJson() => {
    'make': make.trim(),
    'model': model.trim(),
    'color': color.trim(),
    'finish': finish.name,
    'seats': seats.name,
    'source': fromAi ? 'ai' : 'customer',
  };

  static VehicleProfile fromJson(Map m) => VehicleProfile(
    make: m['make'] as String? ?? '',
    model: m['model'] as String? ?? '',
    color: m['color'] as String? ?? '',
    finish: PaintFinish.values.asNameMap()[m['finish']] ?? PaintFinish.unknown,
    seats: SeatKind.values.asNameMap()[m['seats']] ?? SeatKind.unknown,
    fromAi: m['source'] == 'ai',
  );
}

/// One line of the care routine: an icon, a short title and one short detail.
class CareStep {
  const CareStep(this.icon, this.title, this.detail);
  final WIcon icon;
  final String title, detail;
}

/// 2–3 adjustments for this vehicle, most specific first. Rules, not AI, so the Captain
/// app shows exactly the same list (it is sent with the booking as `careRoutine`).
List<CareStep> careRoutineFor(VehicleProfile p, VehicleKind kind, {WashCoverage? coverage}) {
  final bike = kind == VehicleKind.bike, color = p.color.toLowerCase();
  final steps = <CareStep>[
    if (p.finish == PaintFinish.matte)
      const CareStep(WIcon.drop, 'Matte-safe wash', 'Mild shampoo, no wax or polish. Patted dry, never rubbed.')
    else if (p.finish == PaintFinish.glossy)
      const CareStep(WIcon.sparkle, 'Gloss kept bright', 'Two-bucket wash and a soft microfibre dry.'),
    if (!bike && coverage == WashCoverage.exteriorInterior && p.seats == SeatKind.leather)
      const CareStep(WIcon.seat, 'Leather seats: no water', 'Dry microfibre only. No water or wet wipes.')
    else if (!bike && coverage == WashCoverage.exteriorInterior && p.seats == SeatKind.fabric)
      const CareStep(WIcon.seat, 'Fabric seats', 'Dry brush and vacuum. No soaking.'),
    if (bike) const CareStep(WIcon.bike, 'Electrics kept dry', 'Low pressure near the chain, engine and switches.'),
    if (RegExp(r'black|dark|grey|gray|blue|maroon|red').hasMatch(color))
      const CareStep(WIcon.wipe, 'No swirl marks', 'Dark paint shows scratches: clean microfibre for every panel.')
    else if (RegExp(r'white|silver|pearl').hasMatch(color))
      const CareStep(WIcon.wipe, 'Edges and lower panels', 'Light paint shows mud: extra care on door edges.'),
    const CareStep(WIcon.drop, 'Spot-free finish', 'Final wipe so no water marks dry on the glass.'),
  ];
  return steps.take(3).toList();
}

extension VehicleProfileStore on AppStore {
  /// Server AI for vehicle photos is switched on (Ajay: `config.vehicleAi`).
  bool get vehicleAiLive => isLive && liveConfig['vehicleAi'] == true;

  String _profilesKey() => 'vehicleProfiles:${customer?.id ?? 'guest'}';

  /// Details already confirmed for this number plate on this phone, if any.
  Future<VehicleProfile?> savedProfileFor(String plate) async {
    final key = plateKey(plate);
    if (key.isEmpty) return null;
    final row = (await LocalFlags.getList(_profilesKey())).where((r) => r['plate'] == key).firstOrNull;
    return row == null ? null : VehicleProfile.fromJson(row);
  }

  Future<void> saveProfile(String plate, VehicleProfile p) async {
    final key = plateKey(plate);
    if (key.isEmpty) return;
    final rows = [for (final r in await LocalFlags.getList(_profilesKey())) if (r['plate'] != key) r];
    await LocalFlags.setList(_profilesKey(), [...rows, {'plate': key, ...p.toJson()}]);
  }

  /// What the AI sees in the customer's photos. Null when it can't tell (or is off).
  /// BACKEND (Ajay): `identifyVehicle({vehicleKind, images: [base64 JPEG ≤ 1.5 MB, up to 2]})`
  /// → `{make, model, color, finish: glossy|matte|unknown, confidence 0–1}`.
  Future<VehicleProfile?> identifyVehicle() async {
    final kind = draft.type?.kind ?? VehicleKind.sedan;
    if (!isLive) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      return kind == VehicleKind.bike
          ? VehicleProfile(make: 'Royal Enfield', model: 'Classic 350', color: 'Matte black', finish: PaintFinish.matte, fromAi: true)
          : VehicleProfile(make: 'Hyundai', model: 'Creta', color: 'White', finish: PaintFinish.glossy, fromAi: true);
    }
    if (!vehicleAiLive) return null;
    final photos = <Uint8List>[
      for (final a in [PhotoAngle.front, PhotoAngle.left, PhotoAngle.right, PhotoAngle.back])
        if (draftPhotoBytes[a] != null && draftPhotoBytes[a]!.length <= 1500000) draftPhotoBytes[a]!,
    ].take(2).toList();
    if (photos.isEmpty) return null;
    try {
      final r = await live!.call('identifyVehicle', {'vehicleKind': kind.name, 'images': [for (final b in photos) base64Encode(b)]});
      if (((r['confidence'] as num?) ?? 0) < 0.6) return null;
      final p = VehicleProfile.fromJson(r)..fromAi = true;
      return p.name.isEmpty ? null : p;
    } catch (_) {
      return null; // The optional form still works.
    }
  }
}
