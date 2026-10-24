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
  Place(this.society, {this.tower = '', this.floor, this.slot = '',this.addressKey});
  Society society;
  String? addressKey;
  String tower;

  /// Mandatory before booking (B3, B2, B1, Ground, Open).
  String? floor;
  String slot;

  Place copy() => Place(society, tower: tower, floor: floor, slot: slot,addressKey:addressKey);
  String get title => tower.isEmpty ? society.name : '${society.name}, $tower';
  String get addressLine => '${society.area}, ${society.city}${society.pincode.isEmpty ? '' : ' ${society.pincode}'}';

  /// "B2, slot 41"
  String get parkingShort {
    final f = floor ?? '';
    if (slot.isEmpty) return f;
    return f.isEmpty ? 'slot $slot' : '$f, slot $slot';
  }

  String get key => '${society.id}|${addressKey ?? ''}|$tower|${floor ?? ''}|$slot';
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
  const TimeSlot(this.date, this.startHour, this.endHour, {this.available = true, this.windows = const [], this.anyTime = false});
  final DateTime date;

  /// Earliest start and latest end. With several windows these span all of them.
  final int startHour;
  final int endHour;
  final bool available;

  /// Windows the customer picked when they chose more than one, e.g. [(10, 12), (16, 18)].
  final List<(int, int)> windows;

  /// "Any time of the day": every open window was picked; the captain chooses when to come.
  final bool anyTime;

  /// "8 – 10 AM", "10 AM – 2 PM, 4 – 6 PM" or "Any time (6 AM – 6 PM)".
  String get label {
    if (anyTime) return 'Any time (${Fmt.window(startHour, endHour)})';
    if (windows.length < 2) return Fmt.window(startHour, endHour);
    // Join windows that touch, so 10–12 and 12–2 read as 10 AM – 2 PM.
    final merged = <(int, int)>[];
    for (final w in [...windows]..sort((a, b) => a.$1.compareTo(b.$1))) {
      if (merged.isNotEmpty && merged.last.$2 == w.$1) {
        merged[merged.length - 1] = (merged.last.$1, w.$2);
      } else {
        merged.add(w);
      }
    }
    return merged.map((w) => Fmt.window(w.$1, w.$2)).join(', ');
  }

  String get dayLabel => Fmt.day(date);

  /// "Today, 8 – 10 AM"
  String get full => '$dayLabel, $label';
  DateTime get start => DateTime(date.year, date.month, date.day, startHour);
  DateTime get end => DateTime(date.year, date.month, date.day, endHour % 24);

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.date == date && other.startHour == startHour && other.endHour == endHour && other.anyTime == anyTime && other.windows.join() == windows.join();
  @override
  int get hashCode => Object.hash(date, startHour, endHour, anyTime, windows.join());
}

class Customer {
  Customer({required this.id, required this.phone, this.name = '', this.freeWashes = 0, this.notificationsOn = false, this.refundUPI});
  final String id;
  String phone;
  String name;
  int freeWashes;

  /// Rupees from bookings cancelled after the first 15 minutes (50% of the price).
  /// Comes off the next booking.
  int credit = 0;
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
  DateTime? serverSlotStart;
  Map<String, dynamic>? liveCancelPolicy;
  String get cancellationTerms {
    final p = liveCancelPolicy;
    if (paymentStatus != 'captured') return 'No payment has been confirmed. Any reserved free wash or credit will be restored.';
    if (price == 0) return 'Your reserved free wash or credit will be restored. No cash payment was taken.';
    if (p?['kind'] != 'wallet') return 'Eligible payment is refunded to the original payment method, less any configured cancellation fee. Reserved credit is restored.';
    final minutes = (p?['freeWashMinutes'] as num).toInt();
    if (DateTime.now().difference(createdAt).inSeconds <= minutes * 60) return 'You get 1 free wash for your next booking. No cash refund.';
    final credit = (price * (p?['lateCreditBps'] as num).toInt() / 10000).round();
    return 'You get ${Fmt.rupees(credit)} credit for your next booking. No cash refund.';
  }
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

  /// Cancelled by the customer within 15 minutes: no refund, 1 free wash added to their account.
  bool freeWashGiven = false;

  /// Cancelled after 15 minutes: rupees credited for the next booking (50%).
  int creditGiven = 0;

  /// Credit from an earlier cancellation used to pay for this booking.
  int creditUsed = 0;

  /// What the booking was worth: the price paid plus any credit, or the full wash price for a free wash.
  int get value => usedFreeWash ? vehicle.type.price : price + creditUsed;

  /// Still before the slot starts (nothing to wash or photograph yet).
  bool get slotAhead => (serverSlotStart ?? slot.start).isAfter(DateTime.now());

  /// Cancellable until the wash starts.
  bool canCancel([DateTime? now]) => const [OrderStatus.searching, OrderStatus.onTheWay].contains(status);

  /// Still in the first 15 minutes: cancelling gives a free wash.
  bool inFreeCancelWindow([DateTime? now]) => (now ?? DateTime.now()).difference(createdAt) < BusinessRules.cancelWindow;

  /// Whole minutes left in the free-wash window (at least 1 while it is open).
  int cancelMinutesLeft([DateTime? now]) {
    final left = BusinessRules.cancelWindow - (now ?? DateTime.now()).difference(createdAt);
    return left.isNegative ? 0 : (left.inSeconds / 60).ceil().clamp(1, BusinessRules.cancelWindow.inMinutes);
  }

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
  /// Cancelling within this long after booking: no refund, 1 free wash instead.
  static const cancelWindow = Duration(minutes: 15);

  /// Cancelling later (until the wash starts): this share of the price becomes credit
  /// for the next booking. No cash refund either way.
  static const lateCancelCreditPercent = 50;
  static int lateCancelCredit(int price) => (price * lateCancelCreditPercent / 100).round();
  static const int? cancellationFee = null;
  static const int? waitFee = null;

  /// Washes auto-approve at 12 midnight on the day they finish (the captain payout run).
  static DateTime autoApproveTime(DateTime finished) => addDays(startOfDay(finished), 1);
  static String get cancellationFeeText => cancellationFee?.toString() ?? '[CANCELLATION FEE]';
  static const refundAmountText = '[REFUND AMOUNT]';
}
