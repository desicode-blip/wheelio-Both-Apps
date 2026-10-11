/// Domain models shared by the mock backend and the Supabase backend.
/// Field names mirror the database tables in backend/supabase/migrations.
library;

enum VehicleKind { bike, hatchback, sedan, suv }

/// A priced vehicle type (roadmap F03: vehicle size drives price).
class VehicleType {
  const VehicleType({required this.kind, required this.name, required this.minutes, required this.price});

  final VehicleKind kind;
  final String name;
  final int minutes;

  /// Price in whole rupees.
  final int price;

  /// Short name used in summaries ("Hatchback", "Scooter").
  String get shortName => switch (kind) {
        VehicleKind.bike => 'Scooter',
        VehicleKind.hatchback => 'Hatchback',
        VehicleKind.sedan => 'Sedan',
        VehicleKind.suv => 'SUV',
      };
}

class Society {
  const Society({required this.id, required this.name, required this.area, required this.city, this.pincode = ''});

  final String id;
  final String name;
  final String area;
  final String city;
  final String pincode;
}

/// Where the vehicle is parked (roadmap F04).
class Place {
  const Place({
    required this.society,
    this.tower = '',
    this.floor,
    this.slot = '',
    this.lat,
    this.lng,
  });

  final Society society;
  final String tower;

  /// Mandatory before booking (B3, B2, B1, Ground, Open).
  final String? floor;
  final String slot;
  final double? lat;
  final double? lng;

  String get title => tower.isEmpty ? society.name : '${society.name}, $tower';
  String get addressLine => '${society.area}, ${society.city}${society.pincode.isEmpty ? '' : ' ${society.pincode}'}';

  /// "B2, slot 41"
  String get parkingShort {
    final f = floor ?? '';
    if (slot.isEmpty) return f;
    return f.isEmpty ? 'slot $slot' : '$f, slot $slot';
  }

  Place copyWith({Society? society, String? tower, String? floor, String? slot, double? lat, double? lng}) => Place(
        society: society ?? this.society,
        tower: tower ?? this.tower,
        floor: floor ?? this.floor,
        slot: slot ?? this.slot,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}

class Vehicle {
  const Vehicle({required this.id, required this.plate, required this.type, this.place});

  final String id;
  final String plate;
  final VehicleType type;
  final Place? place;
}

/// Customer's identification photos (roadmap F02). Not wash evidence.
enum PhotoAngle { front, back, left, right }

extension PhotoAngleLabel on PhotoAngle {
  String get label => switch (this) {
        PhotoAngle.front => 'Front',
        PhotoAngle.back => 'Back',
        PhotoAngle.left => 'Left side',
        PhotoAngle.right => 'Right side',
      };
}

enum UploadState { none, uploading, done, failed }

class PhotoRef {
  const PhotoRef({required this.localPath, this.state = UploadState.uploading, this.remoteUrl, this.takenAt});

  /// Empty in mock mode (a placeholder is drawn).
  final String localPath;
  final UploadState state;
  final String? remoteUrl;
  final DateTime? takenAt;

  PhotoRef copyWith({UploadState? state, String? remoteUrl}) =>
      PhotoRef(localPath: localPath, state: state ?? this.state, remoteUrl: remoteUrl ?? this.remoteUrl, takenAt: takenAt);
}

/// Note for the washer (roadmap F05): text, voice or video.
class EntryNote {
  const EntryNote({this.text = '', this.voiceSeconds, this.videoSeconds});

  final String text;
  final int? voiceSeconds;
  final int? videoSeconds;

  bool get isEmpty => text.trim().isEmpty && voiceSeconds == null && videoSeconds == null;

  String get summary {
    if (voiceSeconds != null) return 'Voice note · ${formatClock(voiceSeconds!)}';
    if (videoSeconds != null) return 'Video · ${formatClock(videoSeconds!)}';
    if (text.trim().isNotEmpty) return text.trim();
    return 'None';
  }
}

/// A wash window on a given day (roadmap F07).
class TimeSlot {
  const TimeSlot({required this.date, required this.startHour, required this.endHour, this.available = true});

  final DateTime date;
  final int startHour;
  final int endHour;
  final bool available;

  DateTime get start => DateTime(date.year, date.month, date.day, startHour);
  DateTime get end => DateTime(date.year, date.month, date.day, endHour);

  String get id => '${date.year}-${date.month}-${date.day}-$startHour';

  /// "8 – 10 AM", "10 AM – 12 PM"
  String get windowLabel => formatWindow(startHour, endHour);

  @override
  bool operator ==(Object other) => other is TimeSlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Customer {
  const Customer({required this.id, required this.phone, this.name = '', this.freeWashes = 0, this.notificationsOn = false});

  final String id;

  /// 10-digit Indian mobile number without +91.
  final String phone;
  final String name;
  final int freeWashes;
  final bool notificationsOn;

  String get firstName => name.trim().split(' ').first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Customer copyWith({String? name, int? freeWashes, bool? notificationsOn}) => Customer(
        id: id,
        phone: phone,
        name: name ?? this.name,
        freeWashes: freeWashes ?? this.freeWashes,
        notificationsOn: notificationsOn ?? this.notificationsOn,
      );
}

class Washer {
  const Washer({required this.id, required this.name, required this.rating, required this.washes});

  final String id;

  /// First name only is shown to customers.
  final String name;
  final double rating;
  final int washes;

  String get initials => name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
}

/// Order lifecycle (roadmap F11: searching, accepted, on the way, washing, done).
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
  noWasher,
}

extension OrderStatusInfo on OrderStatus {
  bool get isActive => switch (this) {
        OrderStatus.searching || OrderStatus.onTheWay || OrderStatus.washing || OrderStatus.photosReady => true,
        _ => false,
      };

  bool get isUpcoming => isActive || this == OrderStatus.paymentPending;

  /// Index into the 4 customer-visible steps.
  int get stepIndex => switch (this) {
        OrderStatus.searching => 0,
        OrderStatus.onTheWay => 1,
        OrderStatus.washing => 2,
        OrderStatus.photosReady => 3,
        _ => 4,
      };
}

class PaymentMethod {
  const PaymentMethod({required this.id, required this.title, required this.detail, required this.kind});

  final String id;
  final String title;
  final String detail;

  /// upi | upi_app | upi_id | card
  final String kind;
}

enum PaymentOutcome { success, failed, pending }

class Refund {
  const Refund({required this.amount, required this.startedAt, required this.method, required this.bankRef, this.credited = false});

  final int amount;
  final DateTime startedAt;
  final String method;
  final String bankRef;
  final bool credited;
}

enum ProblemKind { notClean, damage, wrongVehicle, noShow }

extension ProblemKindText on ProblemKind {
  String get title => switch (this) {
        ProblemKind.notClean => 'Not clean enough',
        ProblemKind.damage => 'Something got damaged',
        ProblemKind.wrongVehicle => 'Wrong vehicle washed',
        ProblemKind.noShow => 'Washer didn’t come',
      };

  String get subtitle => switch (this) {
        ProblemKind.notClean => 'Spots, dust or streaks left',
        ProblemKind.damage => 'Scratch, dent or broken part',
        ProblemKind.wrongVehicle => 'Not my car or bike',
        ProblemKind.noShow => 'But it says done',
      };
}

enum DisputeOutcome { underReview, upheld, rejected, damagePriority }

class Dispute {
  const Dispute({
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
  final String note;
  final DisputeOutcome outcome;
  final String decisionNote;
  final int creditsAwarded;
}

class Order {
  const Order({
    required this.id,
    required this.ref,
    required this.vehicle,
    required this.place,
    required this.slot,
    required this.price,
    required this.status,
    required this.createdAt,
    this.note = const EntryNote(),
    this.washer,
    this.arrivesBy,
    this.runningLateBy,
    this.startedAt,
    this.finishedAt,
    this.autoApproveAt,
    this.entryPassReceived = false,
    this.washerCantFind = false,
    this.beforePhotos = 0,
    this.afterPhotos = 0,
    this.rating,
    this.paidWith,
    this.refund,
    this.dispute,
    this.usedFreeWash = false,
  });

  final String id;

  /// Human reference, e.g. WH-20914.
  final String ref;
  final Vehicle vehicle;
  final Place place;
  final TimeSlot slot;
  final int price;
  final OrderStatus status;
  final DateTime createdAt;
  final EntryNote note;
  final Washer? washer;
  final DateTime? arrivesBy;
  final Duration? runningLateBy;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? autoApproveAt;
  final bool entryPassReceived;
  final bool washerCantFind;
  final int beforePhotos;
  final int afterPhotos;
  final int? rating;
  final PaymentMethod? paidWith;
  final Refund? refund;
  final Dispute? dispute;
  final bool usedFreeWash;

  /// Report allowed until this time (approval + dispute window).
  DateTime? get reportUntil => finishedAt?.add(const Duration(hours: 26));

  Order copyWith({
    OrderStatus? status,
    Washer? washer,
    DateTime? arrivesBy,
    Duration? runningLateBy,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? autoApproveAt,
    bool? entryPassReceived,
    bool? washerCantFind,
    int? beforePhotos,
    int? afterPhotos,
    int? rating,
    PaymentMethod? paidWith,
    Refund? refund,
    Dispute? dispute,
    TimeSlot? slot,
  }) =>
      Order(
        id: id,
        ref: ref,
        vehicle: vehicle,
        place: place,
        slot: slot ?? this.slot,
        price: price,
        status: status ?? this.status,
        createdAt: createdAt,
        note: note,
        washer: washer ?? this.washer,
        arrivesBy: arrivesBy ?? this.arrivesBy,
        runningLateBy: runningLateBy ?? this.runningLateBy,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        autoApproveAt: autoApproveAt ?? this.autoApproveAt,
        entryPassReceived: entryPassReceived ?? this.entryPassReceived,
        washerCantFind: washerCantFind ?? this.washerCantFind,
        beforePhotos: beforePhotos ?? this.beforePhotos,
        afterPhotos: afterPhotos ?? this.afterPhotos,
        rating: rating ?? this.rating,
        paidWith: paidWith ?? this.paidWith,
        refund: refund ?? this.refund,
        dispute: dispute ?? this.dispute,
        usedFreeWash: usedFreeWash,
      );
}

// ---------------------------------------------------------------------------
// Formatting helpers (Indian English, tabular money).

String rupees(int amount) => '₹$amount';

String formatClock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _hour(int h) {
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12';
}

String _ampm(int h) => h < 12 ? 'AM' : 'PM';

/// "8 – 10 AM" when both ends share AM/PM, otherwise "10 AM – 12 PM".
String formatWindow(int startHour, int endHour) {
  if (_ampm(startHour) == _ampm(endHour % 24)) {
    return '${_hour(startHour)} – ${_hour(endHour)} ${_ampm(endHour % 24)}';
  }
  return '${_hour(startHour)} ${_ampm(startHour)} – ${_hour(endHour)} ${_ampm(endHour % 24)}';
}

/// "8:40 AM"
String formatTime(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:${t.minute.toString().padLeft(2, '0')} ${_ampm(t.hour)}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today", "Tomorrow" or "Mon, 12 Oct".
String formatDay(DateTime d, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final day = _dateOnly(d);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return formatDate(d);
}

/// "Mon, 12 Oct"
String formatDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "+91 98480 11223"
String formatPhone(String tenDigits) =>
    tenDigits.length == 10 ? '+91 ${tenDigits.substring(0, 5)} ${tenDigits.substring(5)}' : '+91 $tenDigits';
