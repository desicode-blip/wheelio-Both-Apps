// Domain models, ported from apps/ios/Customer/Data/Models.swift. Field names mirror the backend.

import 'package:wheelio_ui/wheelio_ui.dart';

enum VehicleKind { bike, hatchback, sedan, suv }

/// Kind of wash, chosen right after the vehicle. Same price for every option.
enum WashKind {
  dryDusting,
  wetOutside,
  wetOutsideDryInside;

  String name(bool bike) => switch (this) {
    dryDusting => bike ? 'Dusting' : 'Dry wash (dusting)',
    wetOutside => bike ? 'Wet wash' : 'Wet wash, outside',
    wetOutsideDryInside => 'Wet outside + dry clean inside',
  };

  String detail(bool bike) => switch (this) {
    dryDusting => 'Dust wiped off with a dry cloth. No water.',
    wetOutside => bike ? 'Water and cloth, then wiped dry.' : 'Body, glass and wheels. Water and cloth.',
    wetOutsideDryInside => 'Wet wash outside, seats and mats dusted inside.',
  };

  String get shortName => switch (this) {
    dryDusting => 'Dusting',
    wetOutside => 'Wet wash',
    wetOutsideDryInside => 'Wet + inside',
  };
  String get wireName => switch (this) {
    dryDusting => 'dryDusting',
    wetOutside => 'wetOutside',
    wetOutsideDryInside => 'wetOutsideDryInside',
  };

  WIcon get icon => switch (this) {
    dryDusting => WIcon.wipe,
    wetOutside => WIcon.drop,
    wetOutsideDryInside => WIcon.sparkle,
  };

  /// Interior cleaning isn't offered in any society yet.
  bool get available => this != wetOutsideDryInside;

  static List<WashKind> options(VehicleKind? k) => k == VehicleKind.bike ? [dryDusting, wetOutside] : [dryDusting, wetOutside, wetOutsideDryInside];
}

class VehicleType {
  const VehicleType(this.kind, this.name, this.minutes, this.price);
  final VehicleKind kind;
  final String name;
  final int minutes;
  final int price;

  String get shortName => switch (kind) {
    VehicleKind.bike => 'Scooter',
    VehicleKind.hatchback => 'Hatchback',
    VehicleKind.sedan => 'Sedan',
    VehicleKind.suv => 'SUV',
  };
  WIcon get icon => kind == VehicleKind.bike
      ? WIcon.bike
      : kind == VehicleKind.suv
      ? WIcon.suv
      : WIcon.car;

  static List<VehicleType> all = [...demoTypes];
  static const demoTypes = [
    VehicleType(VehicleKind.bike, 'Bike or scooter', 15, 69),
    VehicleType(VehicleKind.hatchback, 'Hatchback', 20, 149),
    VehicleType(VehicleKind.sedan, 'Sedan or compact SUV', 20, 179),
    VehicleType(VehicleKind.suv, 'SUV or MUV', 25, 219),
  ];
}

class Society {
  const Society(this.id, this.name, this.area, this.city, [this.pincode = '']);
  final String id;
  final String name;
  final String area;
  final String city;
  final String pincode;
}

/// Where the vehicle is parked.
class Place {
  Place(this.society, {this.tower = '', this.floor, this.slot = ''});
  Society society;
  String tower;

  /// Mandatory before booking (B3, B2, B1, Ground, Open).
  String? floor;
  String slot;

  Place copy() => Place(society, tower: tower, floor: floor, slot: slot);
  String get title => tower.isEmpty ? society.name : '${society.name}, $tower';
  String get addressLine => '${society.area}, ${society.city}${society.pincode.isEmpty ? '' : ' ${society.pincode}'}';

  /// "B2, slot 41"
  String get parkingShort {
    final f = floor ?? '';
    if (slot.isEmpty) return f;
    return f.isEmpty ? 'slot $slot' : '$f, slot $slot';
  }

  String get key => '${society.id}|$tower|${floor ?? ''}|$slot';
}

class Vehicle {
  Vehicle(this.id, this.plate, this.type, this.place);
  final String id;
  final String plate;
  final VehicleType type;
  Place? place;
}

/// Customer's identification photos. Not wash evidence.
enum PhotoAngle {
  front('Front'),
  back('Back'),
  left('Left side'),
  right('Right side');

  const PhotoAngle(this.label);
  final String label;
}

enum UploadState { uploading, done, failed }

/// Note for the captain: text, voice or video.
class EntryNote {
  EntryNote({this.text = '', this.voiceSeconds, this.videoSeconds});
  String text;
  int? voiceSeconds;
  int? videoSeconds;

  EntryNote copy() => EntryNote(text: text, voiceSeconds: voiceSeconds, videoSeconds: videoSeconds);
  bool get isEmpty => text.trim().isEmpty && voiceSeconds == null && videoSeconds == null;
  String get summary {
    if (voiceSeconds != null) return 'Voice note · ${Fmt.clock(voiceSeconds!)}';
    if (videoSeconds != null) return 'Video · ${Fmt.clock(videoSeconds!)}';
    final t = text.trim();
    return t.isEmpty ? 'None' : t;
  }
}

/// A wash window on a given day.
class TimeSlot {
  const TimeSlot(this.date, this.startHour, this.endHour, {this.available = true});
  final DateTime date;
  final int startHour;
  final int endHour;
  final bool available;

  String get label => Fmt.window(startHour, endHour);
  String get dayLabel => Fmt.day(date);

  /// "Today, 8 – 10 AM"
  String get full => '$dayLabel, $label';
  DateTime get start => DateTime(date.year, date.month, date.day, startHour);
  DateTime get end => DateTime(date.year, date.month, date.day, endHour % 24);

  @override
  bool operator ==(Object other) => other is TimeSlot && other.date == date && other.startHour == startHour && other.endHour == endHour;
  @override
  int get hashCode => Object.hash(date, startHour, endHour);
}

class Customer {
  Customer({required this.id, required this.phone, this.name = '', this.freeWashes = 0, this.notificationsOn = false, this.refundUPI});
  final String id;
  String phone;
  String name;
  int freeWashes;
  bool notificationsOn;

  /// Saved the first time we need to send a refund (UPI only for now). Editable in Profile.
  String? refundUPI;

  String get firstName => name.split(' ').where((p) => p.isNotEmpty).firstOrNull ?? '';
  String get initials {
    final p = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }
}

class Captain {
  const Captain(this.id, this.name, this.rating, this.washes, this.initials);
  final String id;

  /// First name only is shown to customers.
  final String name;
  final double rating;
  final int washes;
  final String initials;
}

/// Order lifecycle.
enum OrderStatus {
  pendingPayment,
  paymentPending,
  searching,
  onTheWay,
  washing,
  photosReady,
  approved,
  autoApproved,
  disputed,
  disputeUpheld,
  disputeRejected,
  cancelled,
  noCaptain,

  /// Captain accepted but never turned up or updated the wash: full refund at 11:59 PM.
  captainNoShow;

  bool get isActive => const [searching, onTheWay, washing, photosReady].contains(this);
  bool get isUpcoming => isActive || this == paymentPending || this == pendingPayment;

  /// Index into the 4 customer-visible steps.
  int get stepIndex => switch (this) {
    searching => 0,
    onTheWay => 1,
    washing => 2,
    photosReady => 3,
    _ => 4,
  };
}

class PaymentMethod {
  const PaymentMethod(this.id, this.title, this.detail);
  final String id;
  final String title;
  final String detail;
}

enum PaymentOutcome { success, failed, pending }

class Refund {
  Refund({required this.amount, required this.startedAt, required this.method, required this.bankRef, this.credited = false, this.needsUPI = false, this.upi});
  final int amount;
  DateTime startedAt;
  String method;
  final String bankRef;
  bool credited;

  /// Automatic cancellations refund to a UPI ID the customer gives us.
  bool needsUPI;
  String? upi;

  /// True until the customer has told us where to send the money.
  bool get awaitingUPI => needsUPI && upi == null;
}

enum ProblemKind {
  notClean('Not clean enough', 'Spots, dust or streaks left', WIcon.drop),
  damage('Something got damaged', 'Scratch, dent or broken part', WIcon.scratch),
  wrongVehicle('Wrong vehicle washed', 'Not my car or bike', WIcon.car),
  noShow('Captain didn’t come', 'But it says done', WIcon.close);

  const ProblemKind(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final WIcon icon;
}

enum DisputeOutcome { underReview, upheld, rejected, damagePriority }

class Dispute {
  Dispute({
    required this.ref,
    required this.kind,
    required this.createdAt,
    this.note = '',
    this.outcome = DisputeOutcome.underReview,
    this.decisionNote = '',
    this.creditsAwarded = 0,
  });
  final String ref;
  final ProblemKind kind;
  final DateTime createdAt;
  String note;
  DisputeOutcome outcome;
  String decisionNote;
  int creditsAwarded;
}

class Order {
  Map<String, String> evidencePaths = {};
  Map<String, String> customerPhotoPaths = {};
  String paymentStatus = 'unpaid';
  String refundStatus = 'none';
  bool testPayment = false;
  Order({
    required this.id,
    required this.ref,
    required this.vehicle,
    required this.place,
    required this.slot,
    required this.price,
    required this.status,
    required this.createdAt,
    EntryNote? note,
    this.captain,
    this.arrivesBy,
    this.runningLateMinutes,
    this.startedAt,
    this.finishedAt,
    this.autoApproveAt,
    this.entryPassReceived = false,
    this.captainCantFind = false,
    this.rating,
    this.paidWith,
    this.refund,
    this.dispute,
    this.usedFreeWash = false,
    this.customerSkippedPhotos = false,
    this.noShowChecking = false,
    this.wash,
  }) : note = note ?? EntryNote();

  final String id;

  /// Human reference, e.g. WH-20914.
  final String ref;
  final Vehicle vehicle;
  final Place place;
  TimeSlot slot;
  final int price;
  OrderStatus status;
  final DateTime createdAt;
  EntryNote note;
  Captain? captain;
  DateTime? arrivesBy;
  int? runningLateMinutes;
  DateTime? startedAt;
  DateTime? finishedAt;
  DateTime? autoApproveAt;
  bool entryPassReceived;
  bool captainCantFind;
  int? rating;
  PaymentMethod? paidWith;
  Refund? refund;
  Dispute? dispute;
  bool usedFreeWash;

  /// The customer skipped their own photos at booking. Claims are still checked against the
  /// captain's before/after photos, but we don't promise an outcome.
  bool customerSkippedPhotos;

  /// Slot window passed and the captain hasn't updated the wash: we're checking with him.
  bool noShowChecking;

  /// Kind of wash booked (null for older bookings: treated as wet wash).
  WashKind? wash;

  String get placeKey => place.key;
  WashKind get washKind => wash ?? WashKind.wetOutside;

  /// Report allowed until this time (approval + dispute window).
  DateTime? get reportUntil => finishedAt?.add(const Duration(hours: 26));
  String get vehicleLine => '${vehicle.plate} · ${vehicle.type.shortName}';
}

/// Business values not decided yet. While null the UI shows the placeholder text from the designs.
class BusinessRules {
  static const int? cancellationFee = null;
  static const int? waitFee = null;

  /// Washes auto-approve at 12 midnight on the day they finish (the captain payout run).
  static DateTime autoApproveTime(DateTime finished) => addDays(startOfDay(finished), 1);
  static String get cancellationFeeText => cancellationFee?.toString() ?? '[CANCELLATION FEE]';
  static const refundAmountText = '[REFUND AMOUNT]';
}
