// App state plus an in-memory backend with the sample people and places from the designs
// (Ananya, Raju, My Home Avatar Tower 3, TS 09 EA 4521). Ported from AppStore.swift and
// Notifications.swift. Demo login: any valid mobile number, code 123456. Code 000000 = expired.
// BACKEND: when the real services are connected, the marked methods call the server
// (backend/API-CONTRACT.md); screens don't change.

import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import '../app/design_flags.dart';
import 'models.dart';
import 'availability_cache.dart';

// MARK: Routes

/// One route per screen ID (design read-me).
enum N {
  welcome,
  vehicleType,
  washType,
  vehicleNumber,
  photos,
  camera,
  location,
  addressSearch,
  manualAddress,
  floorSlot,
  entryNotes,
  timeSlot,
  review,
  login,
  otp,
  name,
  paying,
  booked,
  whatsApp,
  notifyAsk,
  live,
  photoCompare,
  rate,
  reportProblem,
  problemPhotos,
  disputeStatus,
  refund,
  bookingDetail,
  repeatBooking,
  help,
  helpCaptain,
  helpEmergency,
  changePhone,
  notifications,
  refundUPI,
  notificationSettings,
  offline,
  serverError,
  sessionExpired,
  gallery,
}

enum OtpStart { entering, wrong, expired }

enum PayView { processing, failed, pending }

enum HelpTopic {
  notClean('Wash wasn’t done well', WIcon.sparkle),
  late('Captain is late or didn’t come', WIcon.clock),
  booking('Change or cancel a booking', WIcon.calendar),
  payment('Payment or refund', WIcon.rupee),
  other('Something else', WIcon.chat);

  const HelpTopic(this.title, this.icon);
  final String title;
  final WIcon icon;
}

class R {
  const R(
    this.n, {
    this.large = false,
    this.savedOnly = false,
    this.angle,
    this.denied = false,
    this.off = false,
    this.error = false,
    this.otp = OtpStart.entering,
    this.pay = PayView.processing,
    this.kind,
    this.id,
    this.topic,
  });
  final N n;
  final bool large;
  final bool savedOnly;
  final PhotoAngle? angle;
  final bool denied;
  final bool off;
  final bool error;
  final OtpStart otp;
  final PayView pay;
  final ProblemKind? kind;
  final String? id;
  final HelpTopic? topic;
}

class AppRouter extends WRouter<R> {
  bool showSplash = true;

  /// Pay sheet (C17) shown over Review.
  bool showPaySheet = false;

  bool isAt(N n) => last?.n == n;
  void go(N n) => push(R(n));

  void setSplash(bool v) {
    showSplash = v;
    notifyListeners();
  }

  void openPaySheet(bool v) {
    showPaySheet = v;
    notifyListeners();
  }

  /// After login: back to Check and pay with the pay sheet open, or home.
  void finishLogin() {
    final address = path.indexWhere((e) => e.route.n == N.manualAddress);
    if (address >= 0) { keep(address + 1); return; }
    final i = path.indexWhere((e) => e.route.n == N.review);
    if (i >= 0) {
      keep(i + 1);
      Future.delayed(const Duration(milliseconds: 450), () => openPaySheet(true));
    } else {
      path = [];
      tab = 0;
    }
  }
}

// MARK: Notifications model

/// What a notification is about. Each kind belongs to a category the customer can switch off
/// (except account and security messages, which always come through).
enum NotificationCategory {
  bookings('Booking updates', 'Captain accepted, on the way, photos ready', 'Bookings'),
  payments('Payments and refunds', 'Refunds and payment problems', 'Payments'),
  offers('Offers and tips', 'Free washes and discounts', 'Offers'),
  account('Account and security', 'Sign-ins and number changes. Always on.', 'Account');

  const NotificationCategory(this.title, this.detail, this.filterTitle);
  final String title;
  final String detail;
  final String filterTitle;
}

enum NotificationKind {
  bookingConfirmed,
  gatePassNeeded,
  captainAssigned,
  captainRunningLate,
  captainCantFind,
  washStarted,
  photosReady,
  approveReminder,
  autoApproved,
  noCaptain,
  bookingCancelled,
  washStatusCheck,
  noShowRefund,
  disputeDecision,
  refundCredited,
  paymentPending,
  freeWash,
  offer,
  phoneChanged,
  welcome;

  NotificationCategory get category => switch (this) {
    refundCredited || paymentPending => NotificationCategory.payments,
    freeWash || offer => NotificationCategory.offers,
    phoneChanged || welcome => NotificationCategory.account,
    _ => NotificationCategory.bookings,
  };

  WIcon get icon => switch (this) {
    bookingConfirmed => WIcon.check,
    gatePassNeeded => WIcon.door,
    captainAssigned => WIcon.location,
    captainRunningLate || approveReminder => WIcon.clock,
    captainCantFind || paymentPending => WIcon.warning,
    washStarted => WIcon.drop,
    photosReady => WIcon.camera,
    autoApproved => WIcon.sparkle,
    noCaptain || bookingCancelled => WIcon.close,
    washStatusCheck => WIcon.search,
    noShowRefund || refundCredited => WIcon.rupee,
    disputeDecision => WIcon.flag,
    freeWash => WIcon.gift,
    offer => WIcon.megaphone,
    phoneChanged => WIcon.lock,
    welcome => WIcon.bell,
  };

  Tone get tone => switch (this) {
    captainCantFind || paymentPending || phoneChanged => Tone.error,
    captainRunningLate || approveReminder || gatePassNeeded || washStatusCheck => Tone.wait,
    noShowRefund || photosReady || autoApproved || refundCredited || freeWash || bookingConfirmed => Tone.ok,
    _ => Tone.info,
  };

  /// Order states this notification still makes sense in. When the order has moved on,
  /// opening it shows the latest state instead, with a short note.
  List<OrderStatus>? get liveStatuses => switch (this) {
    bookingConfirmed => [OrderStatus.searching],
    captainAssigned || captainRunningLate || captainCantFind || washStatusCheck => [OrderStatus.onTheWay],
    washStarted => [OrderStatus.washing],
    photosReady || approveReminder => [OrderStatus.photosReady],
    _ => null,
  };
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.date,
    this.orderId,
    this.expiresAt,
    this.read = false,
  });
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime date;
  final String? orderId;

  /// Offers only: after this the offer can't be used.
  final DateTime? expiresAt;
  bool read;
}

enum AlertStyle {
  soundAndBanner('Sound and banner'),
  bannerOnly('Banner only, no sound');

  const AlertStyle(this.title);
  final String title;
}

class NotificationPrefs {
  AlertStyle style = AlertStyle.soundAndBanner;

  /// Temporary mute: no banners or sounds until this time. Updates still land in the list.
  DateTime? mutedUntil;
  Set<NotificationCategory> categories = {...NotificationCategory.values};

  /// 10 PM – 7 AM: banners arrive silently.
  bool quietHours = false;

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
  static bool get inQuietHours {
    final h = DateTime.now().hour;
    return h >= 22 || h < 7;
  }
}

// MARK: Store

/// Switches that force edge cases so every designed state can be reached without a backend.
class DemoScenario {
  PaymentOutcome payment = PaymentOutcome.success;
  bool noCaptainFound = false;
  bool captainRunsLate = false;

  /// Captain accepts but never turns up: late → checking → full refund at 11:59 PM.
  bool captainNoShow = false;
  bool captainCantFind = false;
  bool entryPassNeverArrives = false;
  bool noCaptainsToday = false;
  bool failBackPhotoOnce = false;
  bool disputeRejected = false;
  bool offline = false;
  bool emptyHistory = false;

  /// Seconds between live order steps. Short so a demo takes under a minute.
  double stepSeconds = 5;
}

/// The booking being built, one small decision per screen.
class BookingDraft {
  BookingDraft({
    this.type,
    this.wash,
    this.plate = '',
    Map<PhotoAngle, UploadState>? photos,
    this.videoSeconds,
    this.place,
    EntryNote? note,
    this.slot,
    this.useFreeWash = false,
    this.creditApplied = 0,
    this.isRepeat = false,
  }) : photos = photos ?? {},
       note = note ?? EntryNote();
  VehicleType? type;
  WashKind? wash;
  String plate;
  Map<PhotoAngle, UploadState> photos;
  int? videoSeconds;
  Place? place;
  EntryNote note;
  TimeSlot? slot;
  bool useFreeWash;

  /// Rupees of the customer's credit taken off this booking (set on Check and pay).
  int creditApplied;
  bool isRepeat;

  int get photosDone => photos.values.where((s) => s == UploadState.done).length;
  bool get photosComplete => PhotoAngle.values.every((a) => photos[a] == UploadState.done);
  bool get hasFailedPhoto => photos.values.contains(UploadState.failed);
  int get basePrice => type?.price ?? 0;
  int get price => useFreeWash ? 0 : (basePrice - creditApplied).clamp(0, basePrice);
}

class OtpResult {
  const OtpResult(this.kind, {this.isNew = false, this.triesLeft = 0});
  final String kind; // ok, wrong, expired, tooManyTries
  final bool isNew;
  final int triesLeft;
}

class AppError implements Exception {
  const AppError(this.kind);
  final String kind;
}

class AppStore extends ChangeNotifier {
  final LiveBackend? live;
  bool get isLive => live != null;
  bool backendReady = false;
  bool bookingsEnabled = false;
  bool testPayments = false;
  final _availability = BookingAvailabilityCache();
  int _availabilityRevision = 0;
  String _availabilityPolicy = '';
  (String, String, DateTime)? _prefetchedAvailability;
  String get availabilityContext => '${live?.uid ?? _liveUid}:${testPayments ? 'test' : 'live'}:$_availabilityRevision';
  String? backendMessage;
  List<Society> liveSocieties = [];
  List<(int, int)> liveWindows = [];
  final List<StreamSubscription<dynamic>> _liveSubscriptions = [];
  final List<StreamSubscription<dynamic>> _accountSubscriptions = [];
  String _liveUid = '';
  String draftRequestId = newId('draft');
  String? draftBookingId;
  StreamSubscription<dynamic>? _walletSubscription;
  String _walletIdentity = '';
  int _walletFree = 0, _walletCredit = 0;
  final Map<PhotoAngle, Uint8List> draftPhotoBytes = {};
  final Map<String, MediaClip> draftMedia = {};
  static const demoOtp = '123456';
  static const expiredOtp = '000000';
  static const samplePhone = '9848011223';

  static const societies = [
    Society('soc_avatar', 'My Home Avatar', 'Narsingi', 'Hyderabad', '500089'),
    Society('soc_avali', 'My Home Avali', 'Gachibowli', 'Hyderabad', '500032'),
    Society('soc_avishkaar', 'My Home Avishkaar', 'Kokapet', 'Hyderabad', '500075'),
  ];
  static const raju = Captain('wsh_raju', 'Raju', 4.8, 212, 'RY');
  static Place homePlace() => Place(societies[0], tower: 'Tower 3', floor: 'B2', slot: '41');
  static Vehicle car() => Vehicle('veh_car', 'TS 09 EA 4521', VehicleType.all[1], homePlace());
  static Vehicle scooter() => Vehicle('veh_scooter', 'TS 09 HB 0731', VehicleType.all[0], Place(societies[0], tower: 'Tower 3', floor: 'B1'));
  static const gpay = PaymentMethod('gpay', 'Google Pay', 'ananya@okhdfc');

  DemoScenario demo = DemoScenario();
  Customer? customer;
  List<Vehicle> vehicles = [];
  List<Order> orders = [];

  List<AppNotification> notifications = [];
  NotificationPrefs notificationPrefs = NotificationPrefs();
  Permission systemPermission = Permission.unknown;

  /// Banner currently shown at the top of the app.
  AppNotification? liveBanner;

  /// Short note shown at the bottom (e.g. "Things have moved on").
  String? toast;

  /// Order whose live screen is open (no banner needed for it).
  String? viewingOrderId;
  BookingDraft draft = BookingDraft();
  String? currentOrderId;
  String pendingPhone = '';

  /// Chosen on the login screen: "I've booked before" (phone + code only) or "I'm new here" (+ name).
  bool returningCustomer = false;
  String payMethodId = 'gpay';
  bool hasSeenWelcome = false;

  /// Hidden design switch (DesignFlags.firstWashHome); the Screens gallery can turn it on.
  bool showFirstWashHome = DesignFlags.firstWashHome;

  /// Profile photo picked from the library (kept on the device for now).
  Uint8List? profilePhoto;
  String? _profilePhotoPath;
  List<Place> savedPlaces = [];
  Timer? _preferenceSave;
  bool _disposed=false,_inboxLoaded=false;
  Future<void> _preferenceQueue = Future.value();
  String pendingNewPhone = '';

  int _otpTries = 0;
  int _refCounter = 20914;
  bool _backPhotoFailed = false;
  final Map<String, WTask> _tasks = {};
  final _rand = Random();

  AppStore({this.live}) {
    if (live == null) {
      _seedPastOrders();
    } else {
      VehicleType.all = [for (final t in VehicleType.demoTypes) VehicleType(t.kind, t.name, t.minutes, 0)];
      _liveSubscriptions.add(
        live!.catalog.listen(
          (snapshot) {
            final config = snapshot.data() ?? {};
            liveConfig = config;
            Support.configure(config);
            bookingsEnabled = config['bookingsEnabled'] == true;
            testPayments = config['paymentMode'] == 'test';
            _bindWallet();
            final types = (config['vehicleTypes'] as List? ?? []).where((v) => v['active'] == true && v['pricePaise'] is num).toList();
            if (types.isNotEmpty) {
              VehicleType.all = [
                for (final v in types)
                  VehicleType(VehicleKind.values.byName(v['kind']), v['name'], (v['minutes'] as num).toInt(), (v['pricePaise'] as num).toInt() ~/ 100),
              ];
              if (draft.type != null) draft.type = VehicleType.all.where((t) => t.kind == draft.type!.kind).firstOrNull;
            }
            liveSocieties = [
              for (final s in config['societies'] as List? ?? [])
                if (s['active'] == true) Society(s['id'], s['name'], s['area'], s['city'] ?? 'Hyderabad', s['pincode'] ?? ''),
            ];
            liveWindows = [for (final w in config['slotWindows'] as List? ?? []) ((w['startHour'] as num).toInt(), (w['endHour'] as num).toInt())];
            final policy = jsonEncode({for (final key in ['paymentMode', 'bookingsEnabled', 'capacityPerSlot', 'slotWindows', 'societies']) key: config[key]});
            if (policy != _availabilityPolicy) {
              _availabilityPolicy = policy;
              _invalidateAvailability();
            }
            backendReady = types.isNotEmpty;
            backendMessage = backendReady ? null : 'The booking catalog is unavailable. Check your connection and reopen ${Brand.name}.';
            _prefetchKnownAvailability();
            changed();
          },
          onError: (Object e) {
            backendMessage = backendError(e);
            changed();
          },
        ),
      );
      _liveSubscriptions.add(
        live!.sessions.listen((user) {
          final uid = user?.phoneNumber != null ? user!.uid : '';
          if (uid != _liveUid) _bindLiveAccount(uid);
        }),
      );
    }
  }

  void _bindWallet() {
    final identity = _liveUid.isEmpty ? '' : '${_liveUid}_${testPayments ? 'test' : 'live'}';
    if (_walletIdentity == identity) return;
    _walletIdentity = identity;
    _walletSubscription?.cancel();
    _walletFree = 0; _walletCredit = 0;
    customer?.freeWashes = 0; customer?.credit = 0;
    if (identity.isEmpty) return;
    _walletSubscription = live!.wallet(_liveUid, testPayments ? 'test' : 'live').listen((s) {
      if (identity != _walletIdentity) return;
      final d = s.data() ?? {};
      _walletFree = (d['freeWashes'] as num? ?? 0).toInt();
      _walletCredit = (d['creditPaise'] as num? ?? 0).toInt() ~/ 100;
      customer?.freeWashes = _walletFree; customer?.credit = _walletCredit;
      changed();
    }, onError: (Object e) { backendMessage = backendError(e); changed(); });
  }

  void _bindLiveAccount(String uid) {
    _liveUid = uid;
    _invalidateAvailability();
    for (final s in _accountSubscriptions) {
      s.cancel();
    }
    _accountSubscriptions.clear();
    customer = null;
    _inboxLoaded=false;
    profilePhoto = null;
    _profilePhotoPath = null;
    savedPlaces = [];
    _preferenceSave?.cancel();
    _readIds.clear(); _unreadIds.clear(); _deletedIds.clear();
    _bindWallet();
    orders = [];
    vehicles = [];
    notifications = [];
    _inbox = [];
    currentOrderId = null;
    if (uid.isEmpty) {
      changed();
      return;
    }
    live!.registerPush('customer').catchError((Object _) {});
    _accountSubscriptions.add(live!.inbox(uid).listen((s){
      if(_liveUid!=uid)return;
      final oldIds=_inbox.map((e)=>e.$1).toSet();
      _inbox=[for(final doc in s.docs) if(doc.data()['role']=='customer') (doc.id, doc.data())];
      _mapInbox();
      if(_inboxLoaded){for(final n in notifications.where((n)=>!oldIds.contains(n.id))) { _present(n); }}
      _inboxLoaded=true;
      changed();
    },onError:(Object e){backendMessage=backendError(e);changed();}));
    _accountSubscriptions.add(
      live!
          .profile(uid)
          .listen(
            (snapshot) {
              if (_liveUid != uid) return;
              final data = snapshot.data();
              if (data == null) return;
              customer = Customer(id: uid, phone: (data['phone'] as String? ?? '').replaceFirst('+91', ''), name: data['name'] as String? ?? '', freeWashes: _walletFree, notificationsOn: data['customerPushEnabled'] == true)..credit = _walletCredit;
              _restorePreferences(data);
              final photoPath = data['customerPhotoPath'] as String?;
              if (photoPath != _profilePhotoPath) {
                _profilePhotoPath = photoPath;
                if (photoPath == null) {
                  profilePhoto = null;
                } else {
                  live!.photo(photoPath).then((bytes) { if (_liveUid == uid && photoPath == _profilePhotoPath) { profilePhoto = bytes; changed(); } }).catchError((Object e) { if (_liveUid == uid) set(() => toast = backendError(e)); });
                }
              }
              savedPlaces = [for (final p in data['savedPlaces'] as List? ?? []) Place(Society(p['societyId'],p['societyName'],p['area']??'',p['city']??'',p['pincode']??''),tower:p['tower']??'',floor:p['floor'],slot:p['parking']??'',latitude:(p['vehiclePosition']?['latitude'] as num?)?.toDouble(),longitude:(p['vehiclePosition']?['longitude'] as num?)?.toDouble())];
              _prefetchKnownAvailability();
              changed();
            },
            onError: (Object e) {
              backendMessage = backendError(e);
              changed();
            },
          ),
    );
    _accountSubscriptions.add(
      live!
          .orders(uid)
          .listen(
            (snapshot) {
              if (_liveUid != uid) return;
              orders = [for (final doc in snapshot.docs) _liveOrder(doc.id, doc.data())];
              vehicles = [];
              for (final o in orders) {
                if (!vehicles.any((v) => v.plate == o.vehicle.plate)) vehicles.add(o.vehicle);
              }
              if (currentOrderId == null || !orders.any((o) => o.id == currentOrderId)) currentOrderId = activeOrder?.id;
              _mapInbox();
              changed();
            },
            onError: (Object e) {
              backendMessage = backendError(e);
              changed();
            },
          ),
    );
    changed();
  }

  List<(String, Map<String, dynamic>)> _inbox = [];
  void _mapInbox() => notifications = [for (final (id, d) in _inbox) if (d['deletedAt'] == null) _liveNotice(id, d)];

  /// A server inbox item in the designed wording, using the booking it belongs to.
  AppNotification _liveNotice(String id, Map<String, dynamic> d) {
    final o = order(d['orderId'] as String? ?? '');
    final name = o?.captain?.name ?? 'Your captain';
    final price = Fmt.rupees(o?.price ?? 0);
    final (kind, title, body) = switch (d['kind']) {
      'searching' => (NotificationKind.bookingConfirmed, 'Booking confirmed', o == null ? 'We’re finding a captain.' : '${o.vehicle.plate} · ${o.slot.full}. We’re finding a captain.'),
      'onTheWay' => (NotificationKind.captainAssigned, '$name is on the way', o == null ? 'Your captain is on the way.' : o.etaFresh?'Arriving by ${Fmt.time(o.arrivesBy!)} for ${o.vehicle.plate}.':'Your captain is on the way for ${o.vehicle.plate}.'),
      'washing' => (NotificationKind.washStarted, 'Washing has started', '$name started at ${Fmt.time(o?.startedAt ?? DateTime.now())}. Photos when he’s done.'),
      'photosReady' => (NotificationKind.photosReady, 'Check the wash', 'Photos are ready. Approve your $price wash payment, or tell us if something’s wrong.'),
      'approved' => (NotificationKind.autoApproved, 'Wash approved', 'Your $price wash payment is approved.'),
      'autoApproved' => (NotificationKind.autoApproved, 'Wash approved at midnight', 'Your $price wash payment is approved.'),
      'vehicleHelp' => (NotificationKind.captainCantFind, '$name cannot find your vehicle', 'Open your booking to reply.'),
      'washStatusCheck' => (NotificationKind.washStatusCheck, 'We’re checking your wash', 'Your slot ended. Open your booking for the latest status.'),
      'disputeDecision' => (NotificationKind.disputeDecision, 'Your report has an update', o?.dispute?.decisionNote ?? 'Open your report to see the review decision.'),
      'phoneChanged' => (NotificationKind.phoneChanged, 'Mobile number updated', 'Your verified mobile number was updated.'),
      'cancelled' => (NotificationKind.bookingCancelled, 'Booking cancelled', o?.freeWashGiven == true
          ? '1 free wash is added to your account. Use it on your next booking.'
          : (o?.creditGiven ?? 0) > 0
          ? '${Fmt.rupees(o!.creditGiven)} credit is added. It comes off your next booking.'
          : 'Your refund of ${Fmt.rupees(o?.refund?.amount ?? o?.price ?? 0)} has started.'),
      'disputed' => (NotificationKind.disputeDecision, 'We’ve got your report', o == null ? 'We’re checking the photos.' : 'We’re checking the photos for ${o.vehicle.plate}.'),
      'refund' => (NotificationKind.refundCredited, 'Refund update', 'Your refund of ${Fmt.rupees(o?.refund?.amount ?? o?.price ?? 0)} has an update.'),
      _ => (NotificationKind.bookingConfirmed, (d['title'] as String? ?? '').replaceFirst('Test · ', ''), d['body'] as String? ?? ''),
    };
    return AppNotification(id: id, kind: kind, title: title, body: body, date: d['createdAt']?.toDate() as DateTime? ?? DateTime.now(), orderId: d['orderId'], read: d['read'] == true);
  }

  Order _liveOrder(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic value) => value == null ? null : (value.toDate() as DateTime).toLocal();
    final kind = VehicleKind.values.byName(data['vehicleKind']);
    final type =
        VehicleType.all.where((t) => t.kind == kind).firstOrNull ?? VehicleType(kind, data['vehicleName'], 20, (data['pricePaise'] as num).toInt() ~/ 100);
    final society = Society(data['societyId'], data['societyName'], data['area'], data['city'] ?? 'Hyderabad');
    final place = Place(society, tower: data['tower'] ?? '', floor: data['floor'], slot: data['parking'] ?? '',addressKey:data['addressKey'],latitude:(data['vehiclePosition']?['latitude'] as num?)?.toDouble(),longitude:(data['vehiclePosition']?['longitude'] as num?)?.toDouble());
    final captain = data['captain'] as Map?;
    final order = Order(
      id: id,
      ref: data['ref'],
      vehicle: Vehicle('veh_${data['plate']}', Fmt.plate(data['plate']), type, place),
      place: place,
      slot: TimeSlot(DateTime.parse(data['day']), (data['startHour'] as num).toInt(), (data['endHour'] as num).toInt(),
        windows: [for(final w in data['requestedWindows'] as List? ?? []) ((w['startHour'] as num).toInt(), (w['endHour'] as num).toInt())], anyTime: data['anyTime']==true),
      price: (data['pricePaise'] as num).toInt() ~/ 100,
      status: data['dispute']?['outcome']=='rejected'?OrderStatus.disputeRejected:data['status'] == 'approved' && data['approvalSource'] == 'automatic' ? OrderStatus.autoApproved : data['status'] == 'cancelled' && data['cancellationReason'] == 'slotExpired' ? data['captainId'] == null ? OrderStatus.noCaptain : OrderStatus.captainNoShow : OrderStatus.values.byName(data['status']),
      createdAt: date(data['createdAt']) ?? DateTime.now(),
      captain: captain == null
          ? null
          : Captain(
              captain['id'],
              captain['name'],
              (captain['rating'] as num? ?? 0).toDouble(),
              (captain['washes'] as num? ?? 0).toInt(),
              (captain['name'] as String).substring(0, 1).toUpperCase(),
            ),
      startedAt: date(data['startedAt']),
      finishedAt: date(data['finishedAt']),
      autoApproveAt: date(data['autoApproveAt']),
      entryPassReceived: data['entryPass']?['status'] == 'received',
      captainCantFind: data['vehicleHelp']?['status'] == 'waiting',
      runningLateMinutes:(data['runningLateMinutes'] as num?)?.toInt(),
      noShowChecking:data['noShowChecking']==true,
      arrivesBy:date(data['arrivalEstimateAt']),
      note: EntryNote(text: data['note'] ?? ''),
      rating: data['rating'] as int?,
      wash: WashKind.values.byName(data['washKind']),
      paidWith: data['paymentStatus'] == 'captured' ? const PaymentMethod('razorpay', 'Razorpay', 'Prepaid') : null,
    );
    order.liveCancelPolicy = Map<String, dynamic>.from(data['cancellationPolicy'] as Map? ?? {'kind': 'refund'});
    order.usedFreeWash = data['freeWashUsed'] == true;
    order.creditUsed = (data['creditUsedPaise'] as num? ?? 0).toInt() ~/ 100;
    order.freeWashGiven = data['cancellationBenefit']?['kind'] == 'freeWash';
    order.creditGiven = (data['cancellationBenefit']?['creditPaise'] as num? ?? 0).toInt() ~/ 100;
    order.arrivalUpdatedAt=date(data['arrivalUpdatedAt']);
    order.serverSlotStart = date(data['slotStart']);
    order.paymentStatus = data['paymentStatus'] ?? 'unpaid';
    order.refundStatus = data['refundStatus'] ?? 'none';
    order.cancellationReason = data['cancellationReason'] as String?;
    order.testPayment = data['paymentMode'] == 'test';
    order.evidencePaths = {for (final entry in (data['evidence'] as Map? ?? {}).entries) entry.key as String: entry.value['path'] as String};
    order.customerPhotoPaths = {for (final entry in (data['customerPhotos'] as Map? ?? {}).entries) entry.key as String: entry.value as String};
    order.customerSkippedPhotos = order.customerPhotoPaths.length < 4;
    if (data['dispute'] is Map) {
      final d = data['dispute'] as Map;
      order.dispute = Dispute(
        ref: data['ref'],
        kind: ProblemKind.values.byName(d['kind']),
        createdAt: date(d['createdAt']) ?? DateTime.now(),
        note: d['note'] ?? '',
        outcome: DisputeOutcome.values.where((v) => v.name == d['outcome']).firstOrNull ?? DisputeOutcome.underReview,
        decisionNote: d['decisionNote'] ?? '',
        creditsAwarded: (d['creditsAwarded'] as num? ?? 0).toInt(),
      );
    }
    if (order.refundStatus != 'none') {
      order.refund = Refund(
        amount: (data['refundAmountPaise'] as num? ?? data['pricePaise']).toInt() ~/ 100,
        startedAt: date(data['cancelledAt']) ?? date(data['dispute']?['resolvedAt']) ?? date(data['dispute']?['createdAt']) ?? DateTime.now(),
        method: 'Original payment method',
        bankRef: data['providerRefundId'] ?? 'Pending',
        credited: order.refundStatus == 'processed',
      );
    }
    return order;
  }

  @override
  void dispose() {
    _disposed=true;_liveUid='';
    _invalidateAvailability();
    _preferenceSave?.cancel();
    _walletSubscription?.cancel();
    for (final s in [..._liveSubscriptions, ..._accountSubscriptions]) {
      s.cancel();
    }
    for (final task in _tasks.values) {
      task.cancel();
    }
    super.dispose();
  }

  /// Change state from a screen and redraw.
  void set(VoidCallback f) {
    if(_disposed)return;
    final before = isLive ? jsonEncode(_preferences()) : '';
    f();
    _prefetchKnownAvailability();
    notifyListeners();
    if (isLive && before != jsonEncode(_preferences())) _savePreferences();
  }

  Map<String, dynamic> _preferences() => {'role':'customer','enabled':notificationsOn,'soundOn':notificationPrefs.style == AlertStyle.soundAndBanner,'quietHours':notificationPrefs.quietHours,'mutedUntil':notificationPrefs.mutedUntil?.millisecondsSinceEpoch,'offCategories':[for(final c in NotificationCategory.values) if(c != NotificationCategory.account && !notificationPrefs.categories.contains(c)) c.name]};
  void _restorePreferences(Map<String,dynamic> data) {
    final p=data['notificationPreferences']?['customer'];
    if(p is! Map) return;
    notificationPrefs.style=p['soundOn']==false?AlertStyle.bannerOnly:AlertStyle.soundAndBanner;
    notificationPrefs.quietHours=p['quietHours']==true;
    notificationPrefs.mutedUntil=p['mutedUntil'] is num?DateTime.fromMillisecondsSinceEpoch((p['mutedUntil'] as num).toInt()):null;
    notificationPrefs.categories={for(final c in NotificationCategory.values) if(c==NotificationCategory.account || !(p['offCategories'] as List? ?? []).contains(c.name)) c};
  }
  void _savePreferences() {
    if (!isLive || _liveUid.isEmpty) return;
    final account=_liveUid, value=_preferences();
    _preferenceSave?.cancel();
    _preferenceSave=Timer(const Duration(milliseconds:300),(){
      _preferenceQueue=_preferenceQueue.then((_) async { if(_liveUid==account) await live!.call('saveNotificationPreferences',value); }).catchError((Object e){if(_liveUid==account) {toast=backendError(e);changed();}});
    });
  }
  Future<void> setProfilePhoto(Uint8List? bytes) async {
    if (!isLive) { set(()=>profilePhoto=bytes); return; }
    final before = profilePhoto;
    set(() => profilePhoto = bytes); // show it at once; the upload follows
    try { await live!.saveProfilePhoto('customer',bytes); }
    catch(e) { set(() { profilePhoto = before; toast = backendError(e); }); }
  }
  // MARK: Speed (30 Oct): don't make screens wait for saves the next step doesn't need.

  /// Saves the parking place without holding the screen; a failure shows a toast.
  void saveDraftPlaceInBackground() {
    saveDraftPlace().catchError((Object e) => set(() => toast = backendError(e)));
  }

  void _invalidateAvailability() {
    _availabilityRevision++;
    _availability.clear();
    _prefetchedAvailability = null;
  }

  /// Account/catalog identity is also part of the screen's request-order guard.
  Future<Set<int>> availabilityFor(String societyId, DateTime day, {bool fresh = false}) {
    final d = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    _availability.setContext(availabilityContext);
    return _availability.load('$societyId:$d', () async {
      final r = await live!.call('getAvailability', {'societyId': societyId, 'day': d});
      return {for (final s in r['slots'] as List) if (s['available'] == true) (s['startHour'] as num).toInt()};
    }, fresh: fresh);
  }

  Place? get _availabilityPlace => draft.place ?? savedPlaces.where((p) => liveSocieties.any((s) => s.id == p.society.id)).firstOrNull;

  void _prefetchKnownAvailability() {
    if (!isLive || !backendReady || _disposed) return;
    final p = _availabilityPlace;
    if (p == null) return;
    final context = (availabilityContext, p.society.id, startOfDay(DateTime.now()));
    if (_prefetchedAvailability == context) return;
    _prefetchedAvailability = context;
    prefetchAvailability();
  }

  /// Preload only one known society; errors remain retryable on the slot screen.
  void prefetchAvailability() {
    final p = _availabilityPlace;
    if (!isLive || !backendReady || _disposed || p == null) return;
    final today = startOfDay(DateTime.now());
    for (var i = 0; i < 3; i++) {
      unawaited(availabilityFor(p.society.id, addDays(today, i)).then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    }
  }

  Future<void> saveDraftPlace() async {
    final p=draft.place;
    if(!isLive||!isLoggedIn||p==null)return;
    await live!.call('saveCustomerPlace',{'societyId':p.society.id,'tower':p.tower,'floor':p.floor??'','parking':p.slot,if(p.latitude!=null&&p.longitude!=null)'vehiclePosition':{'latitude':p.latitude,'longitude':p.longitude}});
  }
  Map<String,dynamic> liveConfig = {};
  (double,double) mapCenter(Place place){
    final society=(liveConfig['societies'] as List? ?? []).where((s)=>s['id']==place.society.id).firstOrNull;
    return (place.latitude??(society?['location']?['latitude'] as num?)?.toDouble()??17.385,place.longitude??(society?['location']?['longitude'] as num?)?.toDouble()??78.4867);
  }
  Future<Place?> locatePlace()async{
    final position=await live!.currentPosition();
    final result=await live!.call('matchServiceLocation',{'latitude':position.latitude,'longitude':position.longitude,'suggest':true});
    final society=searchSocieties('').where((s)=>s.id==result['societyId']).firstOrNull;
    return society==null?null:Place(society,latitude:position.latitude,longitude:position.longitude);
  }
  Future<void> downloadBookingDocument(String orderId,String kind)async{
    if(!isLive)return;
    try{await Device.downloadDocument(live!.call('createBookingDocument',{'orderId':orderId,'kind':kind}).then((r)=>r['url'] as String));}
    catch(e){set(()=>toast=backendError(e));}
  }
  Future<void> _notificationAction(List<String> ids,String action) async {
    try { await live!.notificationAction(ids,action); }
    catch(e) { set(()=>toast=backendError(e)); }
  }

  void changed() {if(!_disposed)notifyListeners();}

  bool get isLoggedIn => customer != null;
  Order? get currentOrder => orders.where((o) => o.id == currentOrderId).firstOrNull;
  Order? get activeOrder {
    final active = orders.where((o) => o.status.isActive).toList()
      ..sort((a, b) => a.slotAhead == b.slotAhead ? a.slot.start.compareTo(b.slot.start) : (a.slotAhead ? 1 : -1));
    return active.firstOrNull;
  }
  List<Order> get upcomingOrders =>
      demo.emptyHistory ? [] : (orders.where((o) => o.status.isUpcoming).toList()..sort((a, b) => a.slot.start.compareTo(b.slot.start)));
  List<Order> get pastOrders => demo.emptyHistory
      ? []
      : (orders.where((o) => !o.status.isUpcoming && o.status != OrderStatus.pendingPayment).toList()..sort((a, b) => b.slot.start.compareTo(a.slot.start)));
  List<Vehicle> get myVehicles => demo.emptyHistory ? [] : vehicles;
  Order? order(String id) => orders.where((o) => o.id == id).firstOrNull;

  void _update(String id, void Function(Order o) change) {
    final o = order(id);
    if (o == null) return;
    final old = (status: o.status, late: o.runningLateMinutes, checking: o.noShowChecking, cantFind: o.captainCantFind, credited: o.refund?.credited ?? false);
    change(o);
    _notifyChanges(old, o);
    notifyListeners();
  }

  String _nextRef() => 'WH-${_refCounter++}';

  Future<void> _latency([int ms = 450]) async {
    await sleepMs(ms);
    if (demo.offline) throw const AppError('offline');
  }

  void _seedPastOrders() {
    final today = startOfDay(DateTime.now());
    Order past(String id, int daysAgo, Vehicle v, OrderStatus status, {Refund? refund, int? rating, Place? place, WashKind wash = WashKind.wetOutside}) {
      final day = addDays(today, -daysAgo);
      return Order(
        id: id,
        ref: 'WH-${20871 - daysAgo}',
        vehicle: v,
        place: place ?? v.place ?? homePlace(),
        slot: TimeSlot(day, 8, 10),
        price: v.type.price,
        status: status,
        createdAt: day,
        captain: status == OrderStatus.cancelled ? null : raju,
        startedAt: day.add(const Duration(hours: 8, minutes: 32)),
        finishedAt: day.add(const Duration(hours: 8, minutes: 54)),
        entryPassReceived: true,
        rating: rating,
        paidWith: gpay,
        refund: refund,
        wash: wash,
      );
    }

    final d2 = addDays(today, -10);
    orders = [
      past('ord_past1', 7, car(), OrderStatus.approved, rating: 4),
      past(
        'ord_past2',
        10,
        car(),
        OrderStatus.noCaptain,
        refund: Refund(amount: 149, startedAt: d2, method: 'Google Pay · ananya@okhdfc', bankRef: 'RZP8812001', credited: true),
      ),
      past('ord_past3', 13, scooter(), OrderStatus.cancelled),
      // Same car, booked at another society (parents' place): its own entry, place highlighted.
      past(
        'ord_past4',
        16,
        car(),
        OrderStatus.approved,
        rating: 5,
        place: Place(societies[1], tower: 'Tower 1', floor: 'B1', slot: '12'),
      ),
      // Same car and place, but a dry wash: its own entry, wash highlighted.
      past('ord_past5', 21, car(), OrderStatus.approved, rating: 4, wash: WashKind.dryDusting),
    ];
  }

  // MARK: Auth (BACKEND: auth.signInWithOtp / verifyOtp)

  Future<void> requestOtp(String phone) async {
    if (isLive) {
      await live!.requestOtp(phone);
      pendingPhone = phone;
      changed();
      return;
    }
    await _latency(700);
    pendingPhone = phone;
    _otpTries = 0;
    notifyListeners();
  }

  Future<OtpResult> verifyOtp(String code) async {
    if (isLive) {
      await live!.verifyOtp(code, role: 'customer');
      final uid = live!.uid!;
      if (_liveUid != uid) _bindLiveAccount(uid);
      final data = (await live!.db.doc('users/$uid').get()).data()!;
      customer = Customer(id: uid, phone: pendingPhone, name: data['name'] ?? '');
      changed();
      return OtpResult('ok', isNew: customer!.name.isEmpty);
    }
    await _latency(600);
    if (code == expiredOtp) return const OtpResult('expired');
    if (code != demoOtp) {
      _otpTries += 1;
      final left = 3 - _otpTries;
      return left <= 0 ? const OtpResult('tooManyTries') : OtpResult('wrong', triesLeft: left);
    }
    // Demo: anyone who says they've booked before is found as the sample customer.
    final known = pendingPhone == samplePhone || returningCustomer;
    customer = Customer(id: 'cus_$pendingPhone', phone: pendingPhone, name: known ? 'Ananya Rao' : '', notificationsOn: known);
    if (known && vehicles.isEmpty) vehicles = [car(), scooter()];
    if (known) {
      seedSampleNotifications();
    } else {
      notifications = [];
      notify(NotificationKind.welcome, 'Welcome to ${Brand.name}', 'Book a wash, see the photos, then pay. That’s it.', deliver: false);
    }
    notifyListeners();
    return OtpResult('ok', isNew: !known);
  }

  /// Gallery shortcut: log in as the sample customer.
  void signInAsSample([int freeWashes = 0]) {
    if (isLive) return;
    customer = Customer(id: 'cus_ananya', phone: samplePhone, name: 'Ananya Rao', freeWashes: freeWashes, notificationsOn: true);
    if (vehicles.isEmpty) vehicles = [car(), scooter()];
    if (notifications.isEmpty) seedSampleNotifications();
    notifyListeners();
  }

  void signOut() {
    if (isLive) {
      live!.signOut().catchError((Object e) {
        toast = backendError(e);
        changed();
      });
    }
    customer = null;
    vehicles = [];
    notifications = [];
    liveBanner = null;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    if (isLive) {
      await live!.saveName(name);
      customer?.name = name.trim();
      changed();
      return;
    }
    await _latency();
    customer?.name = name.trim();
    notifyListeners();
  }

  /// Designed actions the live backend can't do yet (P0 list: docs/P0-BACKEND-FOR-DESIGN.md).
  /// The screen stays exactly as designed; tapping explains it instead of pretending.
  static const notYet = 'This isn’t available yet. Call us and we’ll do it for you.';
  bool blockLive([String message = notYet]) {
    if (!isLive) return false;
    toast = message;
    changed();
    return true;
  }

  /// BACKEND: send OTP to the new number.
  Future<void> requestPhoneChange(String phone) async {
    if (isLive) { await live!.requestPhoneChange(phone); pendingNewPhone=phone; return; }
    await _latency(700);
    pendingNewPhone = phone;
  }

  /// BACKEND: verify OTP, then update the account's phone.
  Future<bool> confirmPhoneChange(String code) async {
    if (isLive) { try { await live!.confirmPhoneChange(code); pendingNewPhone=''; return true; } catch(e) { set(()=>toast=backendError(e)); return false; } }
    await _latency(600);
    if (code != demoOtp) return false;
    customer?.phone = pendingNewPhone;
    pendingNewPhone = '';
    notifyListeners();
    return true;
  }

  /// The captain from the running wash, else from the most recent wash.
  Order? get latestCaptainOrder {
    final a = activeOrder;
    if (a != null && a.captain != null) return a;
    return pastOrders.where((o) => o.captain != null).firstOrNull;
  }

  /// Returns false while a wash is in progress.
  Future<bool> deleteAccount() async {
    if (isLive) {
      final result=await live!.call('deleteOwnAccount',{'confirm':true,'role':'customer'});
      if(result['deleted']!=true)throw StateError('Account deletion has not finished. Try again.');
      await live!.signOut();return true;
    }
    await _latency();
    if (orders.any((o) => o.status == OrderStatus.washing)) return false;
    customer = null;
    vehicles = [];
    orders = [];
    notifications = [];
    notificationPrefs = NotificationPrefs();
    notifyListeners();
    return true;
  }

  // MARK: Catalogue

  List<Society> searchSocieties(String q) {
    final s = q.trim().toLowerCase();
    final choices = isLive ? liveSocieties : societies;
    if (s.isEmpty) return choices;
    return choices.where((x) => '${x.name} ${x.area}'.toLowerCase().contains(s)).toList();
  }

  List<TimeSlot> timeSlots(DateTime day) {
    if (isLive) {
      return [
        for (final w in liveWindows)
          TimeSlot(startOfDay(day), w.$1, w.$2, available: bookingsEnabled && DateTime(day.year, day.month, day.day, w.$2).isAfter(DateTime.now())),
      ];
    }
    final today = isToday(day);
    final hour = DateTime.now().hour;
    return [
      for (final w in const [(6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18)])
        // Demo: early windows today look full so the crossed-out state shows.
        TimeSlot(startOfDay(day), w.$1, w.$2, available: !(today && (demo.noCaptainsToday || w.$1 == 6 || (hour >= w.$2 - 1 && hour < 20)))),
    ];
  }

  List<PaymentMethod> get paymentMethods {
    // Live: the same designed list; every choice opens Razorpay (passing the choice on is P0).
    final upi = !isLive && customer?.phone == samplePhone ? 'UPI · ananya@okhdfc' : 'UPI';
    return [
      PaymentMethod('gpay', 'Google Pay', upi),
      const PaymentMethod('phonepe', 'PhonePe', 'UPI'),
      const PaymentMethod('upi_id', 'Other UPI app', 'Enter UPI ID'),
      const PaymentMethod('card', 'Debit card', 'Credit cards not accepted'),
    ];
  }

  // MARK: Booking

  /// A photo taken in the guided camera screen itself (30 Oct). Kept on the phone and
  /// uploaded with the booking, like the picker path.
  void keepPhoto(PhotoAngle a, Uint8List bytes) {
    draftPhotoBytes[a] = bytes;
    draft.photos[a] = UploadState.done;
    changed();
  }

  /// BACKEND: storage upload. Fails the back photo once when the demo switch is on.
  Future<bool> uploadPhoto(PhotoAngle a, {bool gallery = false}) async {
    if (isLive || !kIsWeb) {
      final bytes = await Device.pickImage(camera: !gallery);
      if (bytes == null) return false;
      draftPhotoBytes[a] = bytes;
      draft.photos[a] = UploadState.done;
      changed();
      return true;
    }
    draft.photos[a] = UploadState.uploading;
    notifyListeners();
    await sleepMs(700);
    if (demo.failBackPhotoOnce && a == PhotoAngle.back && !_backPhotoFailed) {
      _backPhotoFailed = true;
      draft.photos[a] = UploadState.failed;
    } else {
      draft.photos[a] = UploadState.done;
    }
    notifyListeners();
    return draft.photos[a] == UploadState.done;
  }

  void startRepeat(Vehicle v, {Place? place, WashKind? wash}) {
    draftBookingId = null;
    draftRequestId = newId('draft');
    draftPhotoBytes.clear();
    draftMedia.clear();
    draft = BookingDraft(type: v.type, wash: wash, plate: v.plate, place: (place ?? v.place)?.copy(), isRepeat: true);
    prefetchAvailability();
    notifyListeners();
  }

  void startNewBooking() {
    draftBookingId = null;
    draftRequestId = newId('draft');
    draftPhotoBytes.clear();
    draftMedia.clear();
    draft = BookingDraft();
    prefetchAvailability();
    notifyListeners();
  }

  /// BACKEND: rpc create_order, then Razorpay checkout.
  Future<PaymentOutcome> createOrderAndPay() async {
    if (isLive) {
      final d = draft, p = d.place, s = d.slot;
      // Paying for a booking that already exists (opened from Bookings or a notification).
      final pending = currentOrder;
      if ((d.type == null || p == null || s == null) && pending != null && (pending.status == OrderStatus.pendingPayment || pending.status == OrderStatus.paymentPending)) {
        draftBookingId = pending.id;
        final paid = await live!.pay(pending.id, method: payMethodId);
        await _refreshLiveOrder(pending.id);
        return paid['paymentStatus'] == 'captured' && paid['status'] != 'cancelled' ? PaymentOutcome.success : PaymentOutcome.pending;
      }
      if (d.type == null || p == null || s == null) throw StateError('Complete the vehicle, parking and time details first.');
      final result = await live!.call('createBooking', {
        'requestId': draftRequestId,
        'plate': d.plate,
        'vehicleKind': d.type!.kind.name,
        'washKind': (d.wash ?? WashKind.wetOutside).wireName,
        'societyId': p.society.id,
        'tower': p.tower,
        'floor': p.floor,
        'parking': p.slot,
        'note': d.note.text,
        if(p.latitude!=null&&p.longitude!=null)'vehiclePosition':{'latitude':p.latitude,'longitude':p.longitude},
        'day': '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
        'windows': [for (final w in s.windows.isEmpty ? [(s.startHour, s.endHour)] : s.windows) {'startHour': w.$1, 'endHour': w.$2}],
        'anyTime': s.anyTime,
        'useFreeWash': d.useFreeWash,
        'useCredit': d.creditApplied > 0,
        'expectedAmountPaise': d.price * 100,
        if (p.addressKey != null) 'addressKey': p.addressKey,
        'startHour': s.startHour,
        'endHour': s.endHour,
      });
      final bookingId = result['bookingId'] as String;
      draftBookingId = bookingId;
      currentOrderId = bookingId;
      if (result['status'] == 'pendingPayment') {
      for (final entry in draftMedia.entries) { await live!.uploadCustomerMedia(bookingId, entry.key, entry.value.bytes,entry.value.contentType,entry.value.seconds); }
      for (final entry in draftPhotoBytes.entries) {
        await live!.uploadCustomerPhoto(bookingId, entry.key.name, entry.value);
      }
      }
      final paid = await live!.pay(bookingId, method: payMethodId);
      await _refreshLiveOrder(bookingId);
      return paid['paymentStatus'] == 'captured' && paid['status'] != 'cancelled' ? PaymentOutcome.success : PaymentOutcome.pending;
    }
    final d = draft;
    final type = d.type, place = d.place, slot = d.slot;
    if (type == null || place == null || slot == null) throw const AppError('server');
    await _latency(2200);
    var vehicle = vehicles.where((v) => v.plate == d.plate).firstOrNull;
    if (vehicle == null) {
      vehicle = Vehicle(newId('veh'), d.plate, type, place);
      vehicles.add(vehicle);
    }
    final method = paymentMethods.where((m) => m.id == payMethodId).firstOrNull ?? gpay;
    final o = Order(
      id: newId('ord'),
      ref: _nextRef(),
      vehicle: vehicle,
      place: place,
      slot: slot,
      price: d.price,
      status: OrderStatus.pendingPayment,
      createdAt: DateTime.now(),
      note: d.note,
      paidWith: method,
      usedFreeWash: d.useFreeWash,
      customerSkippedPhotos: !d.photosComplete,
      wash: d.wash,
    );
    orders.add(o);
    currentOrderId = o.id;
    switch (demo.payment) {
      case PaymentOutcome.failed:
        orders.removeWhere((x) => x.id == o.id);
        notifyListeners();
        return PaymentOutcome.failed;
      case PaymentOutcome.pending:
        _update(o.id, (o) => o.status = OrderStatus.paymentPending);
        return PaymentOutcome.pending;
      case PaymentOutcome.success:
        if (d.useFreeWash) customer?.freeWashes -= 1;
        if (!d.useFreeWash && d.creditApplied > 0) {
          o.creditUsed = d.creditApplied;
          customer?.credit -= d.creditApplied;
        }
        _startLifecycle(o.id);
        return PaymentOutcome.success;
    }
  }

  Future<PaymentOutcome> checkPendingPayment() async {
    if (isLive) {
      final id = draftBookingId ?? currentOrderId;
      if (id == null) throw StateError('No pending payment.');
      final result = await live!.call('checkPayment', {'bookingId': id});
      await _refreshLiveOrder(id);
      return result['paymentStatus'] == 'captured' && result['status'] != 'cancelled' ? PaymentOutcome.success : PaymentOutcome.pending;
    }
    await _latency(1200);
    demo.payment = PaymentOutcome.success;
    if (currentOrderId != null) _startLifecycle(currentOrderId!);
    return PaymentOutcome.success;
  }

  Future<void> _refreshLiveOrder(String id) async {
    final fresh = await live!.db.doc('orders/$id').get();
    if (!fresh.exists) return;
    orders.removeWhere((o) => o.id == id);
    orders.insert(0, _liveOrder(id, fresh.data()!));
    changed();
  }

  Future<bool> _steps(WTask job, double n) async {
    await sleepMs((demo.stepSeconds * n * 1000).round());
    return !job.cancelled;
  }

  void _startLifecycle(String id) {
    if (isLive) return;
    _update(id, (o) => o.status = OrderStatus.searching);
    // Booked for later: it stays "Booked" until the slot; no captain, wash or photos yet.
    if (orders.where((o) => o.id == id).firstOrNull?.slotAhead ?? false) return;
    _tasks[id]?.cancel();
    _tasks[id] = runTask((job) async {
      if (!await _steps(job, 1)) return;
      if (demo.noCaptainFound) {
        _update(id, (o) {
          o.status = OrderStatus.noCaptain;
          o.refund = autoRefund(o);
        });
        return;
      }
      _update(id, (o) {
        o.status = OrderStatus.onTheWay;
        o.captain = raju;
        final a = DateTime.now().add(const Duration(minutes: 25));
        final b = o.slot.start.add(const Duration(minutes: 40));
        o.arrivesBy = a.isAfter(b) ? a : b;
      });
      if (!await _steps(job, 1)) return;
      if (!demo.entryPassNeverArrives) _update(id, (o) => o.entryPassReceived = true);
      if (demo.captainNoShow) {
        // 1. Running late  2. Slot window passed, checking  3. 11:59 PM: full refund, captain penalised.
        _update(id, (o) => o.runningLateMinutes = 15);
        if (!await _steps(job, 2)) return;
        _update(id, (o) => o.noShowChecking = true);
        if (!await _steps(job, 2)) return;
        _update(id, (o) {
          o.status = OrderStatus.captainNoShow;
          o.refund = autoRefund(o);
        });
        return;
      }
      if (demo.captainRunsLate) _update(id, (o) => o.runningLateMinutes = 15);
      if (!await _steps(job, 1)) return;
      if (demo.captainCantFind) {
        // Waits for the customer's answer; see answerCantFind.
        _update(id, (o) => o.captainCantFind = true);
        return;
      }
      await _runWash(job, id);
    });
  }

  Future<void> _runWash(WTask job, String id) async {
    _update(id, (o) {
      o.status = OrderStatus.washing;
      o.startedAt = DateTime.now();
    });
    if (!await _steps(job, 2)) return;
    final done = DateTime.now();
    _update(id, (o) {
      o.status = OrderStatus.photosReady;
      o.finishedAt = done;
      o.autoApproveAt = BusinessRules.autoApproveTime(done);
    });
  }

  void answerCantFind(String answer) {
    final id = currentOrderId;
    if (id == null) return;
    if (isLive) {
      live!.call('updateVehicleHelp', {'orderId':id,'action':'answer','value':answer}).catchError((Object e) { set(()=>toast=backendError(e)); return <String,dynamic>{}; });
      return;
    }
    if (answer == 'not_here') {
      cancel(id);
      return;
    }
    _update(id, (o) => o.captainCantFind = false);
    _tasks[id] = runTask((job) async {
      if (!await _steps(job, 1)) return;
      await _runWash(job, id);
    });
  }

  String _bankRef() => 'RZP${8812000 + _rand.nextInt(99999)}';

  /// Refund for an automatic cancellation (no captain / captain no-show). Goes to the customer's
  /// UPI ID; if we don't have one yet, we ask for it.
  Refund autoRefund(Order o) {
    final upi = customer?.refundUPI;
    return Refund(
      amount: o.price,
      startedAt: DateTime.now(),
      method: upi != null ? 'UPI · $upi' : 'Waiting for your UPI ID',
      bankRef: _bankRef(),
      needsUPI: true,
      upi: upi,
    );
  }

  /// Saves the refund UPI ID to the profile and sends any refunds that were waiting for it.
  void saveRefundUPI(String raw) {
    if (blockLive('Refunds go back to the way you paid. UPI refunds aren’t available yet.')) return;
    final upi = raw.trim().toLowerCase();
    customer?.refundUPI = upi;
    for (final o in orders) {
      final r = o.refund;
      if (r != null && r.awaitingUPI) {
        r.upi = upi;
        r.method = 'UPI · $upi';
        r.startedAt = DateTime.now();
      }
    }
    notifyListeners();
  }

  Refund _refundFor(Order o, [int? amount]) => Refund(
    amount: amount ?? o.price,
    startedAt: DateTime.now(),
    method: o.paidWith != null ? '${o.paidWith!.title} · ${o.paidWith!.detail.replaceAll('UPI · ', '')}' : 'UPI',
    bankRef: _bankRef(),
  );

  /// Customer cancels before the wash starts. No cash refund:
  /// within 15 minutes of booking → 1 free wash; later → 50% of the booking's value as credit.
  /// BACKEND: rpc cancel_order must apply these rules on the server
  /// (today the live backend refunds instead; see docs/BACKEND-HOOKUP.md).
  Future<void> cancel(String id) async {
    if (isLive) {
      await live!.call('cancelBooking', {'orderId': id});
      return;
    }
    final o = orders.where((x) => x.id == id).firstOrNull;
    if (o == null || !o.canCancel()) throw StateError('This booking can no longer be cancelled.');
    await _latency(800);
    _tasks[id]?.cancel();
    final early = o.inFreeCancelWindow();
    final credit = early ? 0 : BusinessRules.lateCancelCredit(o.value);
    _update(id, (o) {
      o.refund = null;
      o.status = OrderStatus.cancelled;
      o.captainCantFind = false;
      o.freeWashGiven = early;
      o.creditGiven = credit;
    });
    if (early) {
      customer?.freeWashes += 1;
    } else {
      customer?.credit += credit;
    }
    notifyListeners();
  }

  /// BACKEND: rpc approve_order (releases the held money to the captain).
  Future<void> approve(String id) async {
    if (isLive) {
      await live!.call('approveWash', {'orderId': id});
      await _refreshLiveOrder(id);
      return;
    }
    await _latency(600);
    _tasks[id]?.cancel();
    _update(id, (o) => o.status = OrderStatus.approved);
  }

  Future<void> rate(String id, int stars, [Set<String> tags = const {}]) async {
    if (isLive) {
      await live!.call('rateWash', {'orderId': id, 'stars': stars, 'tags':tags.toList()});
      await _refreshLiveOrder(id);
      return;
    }
    await _latency(400);
    _update(id, (o) => o.rating = stars);
  }

  /// BACKEND: rpc report_problem.
  Future<void> reportProblem(String id, ProblemKind kind, String note, [List<Uint8List> photos = const []]) async {
    if (isLive) {
      for (var i=0;i<photos.length;i++) { await live!.uploadProblemPhoto(id,i,photos[i]); }
      await live!.call('reportWashProblem', {'orderId': id, 'kind': kind.name, 'note': note, 'photoCount':photos.length});
      await _refreshLiveOrder(id);
      return;
    }
    await _latency(900);
    _tasks[id]?.cancel();
    final dispute = Dispute(
      ref: _nextRef(),
      kind: kind,
      createdAt: DateTime.now(),
      note: note,
      outcome: kind == ProblemKind.damage ? DisputeOutcome.damagePriority : DisputeOutcome.underReview,
    );
    _update(id, (o) {
      o.status = OrderStatus.disputed;
      o.dispute = dispute;
    });
    if (kind == ProblemKind.damage) return;
    _tasks[id] = runTask((job) async {
      if (!await _steps(job, 2)) return;
      if (demo.disputeRejected) {
        _update(id, (o) {
          o.status = OrderStatus.disputeRejected;
          o.dispute?.outcome = DisputeOutcome.rejected;
          o.dispute?.decisionNote = 'The scratch near the left door is visible in the 8:33 AM before-photo.';
        });
      } else {
        customer?.freeWashes += 2;
        _update(id, (o) {
          o.status = OrderStatus.disputeUpheld;
          o.refund = _refundFor(o);
          o.dispute?.outcome = DisputeOutcome.upheld;
          o.dispute?.decisionNote = 'The after-photos show streaks on the bonnet. Raju won’t be paid for this wash.';
          o.dispute?.creditsAwarded = 2;
        });
      }
    });
  }

  // MARK: Gallery helpers

  /// Gallery: captain accepted, ran late, slot has passed and we're checking with him.
  void markNoShowChecking() {
    final o = sampleOrder(OrderStatus.onTheWay, late: true);
    o.noShowChecking = true;
    notifyListeners();
  }

  /// An order in a given state, built from sample data, made current.
  Order sampleOrder(
    OrderStatus status, {
    bool passMissing = false,
    bool late = false,
    bool cantFind = false,
    DisputeOutcome? dispute,
    bool damage = false,
    bool skippedPhotos = false,
  }) {
    final now = DateTime.now();
    final o = Order(
      id: newId('ord_sample'),
      ref: 'WH-20914',
      vehicle: car(),
      place: homePlace(),
      slot: TimeSlot(startOfDay(now), 8, 10),
      price: 149,
      status: status,
      createdAt: now,
      note: EntryNote(voiceSeconds: 12),
      captain: status == OrderStatus.searching ? null : raju,
      arrivesBy: now.add(const Duration(minutes: 25)),
      runningLateMinutes: late ? 15 : null,
      startedAt: now.subtract(const Duration(minutes: 22)),
      finishedAt: now.subtract(const Duration(minutes: 1)),
      autoApproveAt: BusinessRules.autoApproveTime(now),
      entryPassReceived: !passMissing,
      captainCantFind: cantFind,
      paidWith: gpay,
      customerSkippedPhotos: skippedPhotos,
    );
    if (status == OrderStatus.noCaptain || status == OrderStatus.captainNoShow) {
      o.refund = autoRefund(o);
    } else if (status == OrderStatus.cancelled || status == OrderStatus.disputeUpheld) {
      o.refund = Refund(amount: 149, startedAt: now, method: 'Google Pay · ananya@okhdfc', bankRef: 'RZP8812093');
    }
    if (dispute != null) {
      o.dispute = Dispute(
        ref: damage ? 'WH-20915' : 'WH-20914',
        kind: damage ? ProblemKind.damage : ProblemKind.notClean,
        createdAt: now,
        note: 'Water streaks on the bonnet and the left mirror wasn’t wiped.',
        outcome: dispute,
        decisionNote: dispute == DisputeOutcome.upheld
            ? 'The after-photos show streaks on the bonnet. Raju won’t be paid for this wash.'
            : 'The scratch near the left door is visible in the 8:33 AM before-photo.',
        creditsAwarded: dispute == DisputeOutcome.upheld ? 2 : 0,
      );
    }
    orders.removeWhere((x) => x.id.startsWith('ord_sample'));
    orders.add(o);
    currentOrderId = o.id;
    notifyListeners();
    return o;
  }

  void draftBasics() {
    draft = BookingDraft(type: VehicleType.all[1], plate: 'TS 09 EA 4521');
    notifyListeners();
  }

  void draftFull() {
    draftBasics();
    for (final a in PhotoAngle.values) {
      draft.photos[a] = UploadState.done;
    }
    draft.videoSeconds = 14;
    draft.place = homePlace();
    draft.note = EntryNote(voiceSeconds: 12);
    draft.slot = TimeSlot(startOfDay(DateTime.now()), 8, 10);
    notifyListeners();
  }

  void resetDemo() {
    showFirstWashHome = DesignFlags.firstWashHome;
    for (final t in _tasks.values) {
      t.cancel();
    }
    _tasks.clear();
    demo = DemoScenario();
    _backPhotoFailed = false;
    orders.removeWhere((o) => o.id.startsWith('ord_sample'));
    notifyListeners();
  }

  // MARK: Notifications (Notifications.swift)

  int get unreadCount => notifications.where((n) => !n.read).length;
  bool get notificationsOn => customer?.notificationsOn ?? false;

  /// Adds a notification to the list and, if the settings allow, shows it as a banner
  /// (in the app) or a system notification (when the app is in the background).
  void notify(NotificationKind kind, String title, String body, {String? orderId, DateTime? expiresAt, DateTime? date, bool deliver = true}) {
    if (customer == null) return;
    final d = date ?? DateTime.now();
    // Same update for the same order within a minute: keep one.
    final last = notifications.where((n) => n.kind == kind && n.orderId == orderId).firstOrNull;
    if (last != null && d.difference(last.date).inSeconds < 60 && !d.isBefore(last.date)) return;
    final n = AppNotification(id: newId('n'), kind: kind, title: title, body: body, date: d, orderId: orderId, expiresAt: expiresAt);
    notifications = [n, ...notifications]..sort((a, b) => b.date.compareTo(a.date));
    if (deliver) _present(n);
    notifyListeners();
  }

  /// Decide how (or whether) a new notification interrupts the customer.
  void _present(AppNotification n) {
    final cat = n.kind.category;
    if (!notificationsOn || !(cat == NotificationCategory.account || notificationPrefs.categories.contains(cat)) || notificationPrefs.isMuted) return;
    final silent = notificationPrefs.style == AlertStyle.bannerOnly || (notificationPrefs.quietHours && NotificationPrefs.inQuietHours);
    if (Device.appIsActive) {
      // Already looking at this booking: the screen updates itself, no banner needed.
      if (viewingOrderId != null && viewingOrderId == n.orderId) return;
      liveBanner = n;
      if (!silent) Device.ding();
      Device.buzz();
    } else if (systemPermission != Permission.denied) {
      Device.systemNotify(n.title, n.body, silent: silent);
    }
  }

  // Live inbox: read and deleted are kept on this phone (saving them on the server is P0).
  final Set<String> _readIds = {}, _unreadIds = {}, _deletedIds = {};
  void markRead(String id) { if (isLive) { _notificationAction([id],'read'); return; } set(() { _readIds.add(id); _unreadIds.remove(id); notifications.where((n) => n.id == id).firstOrNull?.read = true; }); }
  void markUnread(String id) { if (isLive) { _notificationAction([id],'unread'); return; } set(() { _unreadIds.add(id); _readIds.remove(id); notifications.where((n) => n.id == id).firstOrNull?.read = false; }); }
  void markAllRead() { if (isLive) { _notificationAction(notifications.where((n)=>!n.read).map((n)=>n.id).toList(),'read'); return; } set(() {
    for (final n in notifications) {
      n.read = true;
      _readIds.add(n.id);
      _unreadIds.remove(n.id);
    }
  }); }
  void deleteNotification(String id) { if (isLive) { _notificationAction([id],'delete'); return; } set(() { _deletedIds.add(id); notifications.removeWhere((n) => n.id == id); }); }
  void clearNotifications() { if (isLive) { _notificationAction(notifications.map((n)=>n.id).toList(),'delete'); return; } set(() { _deletedIds.addAll(notifications.map((n) => n.id)); notifications = []; }); }

  /// Master switch. Turning on asks for permission the first time.
  void setNotifications(bool on) {
    customer?.notificationsOn = on;
    notifyListeners();
    if (isLive) {
      _savePreferences();
      if(on && live!.supportsPush) {
        live!.enablePush('customer').catchError((Object e)=>set(()=>toast=backendError(e)));
      } else if (!on) { live!.call('setPushPreference',{'role':'customer','enabled':false}).catchError((Object e){set(()=>toast=backendError(e));return <String,dynamic>{};}); }
      else if(on) { requestSystemPermission(); }
      return;
    }
    if (on) requestSystemPermission();
  }

  void requestSystemPermission() => Device.requestNotifications().then((p) => set(() => systemPermission = p));
  void refreshSystemPermission() {if(isLive&&live!.supportsPush){live!.pushPermission().then((p)=>set(()=>systemPermission=p)).catchError((Object _){});}else{set(() => systemPermission = Device.notificationPermission);}}
  void mute(int? seconds) => set(() => notificationPrefs.mutedUntil = seconds == null ? null : DateTime.now().add(Duration(seconds: seconds)));

  /// Mute until 8 AM tomorrow.
  void muteUntilMorning() => set(() => notificationPrefs.mutedUntil = addDays(startOfDay(DateTime.now()), 1).add(const Duration(hours: 8)));

  /// Emits notifications for meaningful changes to an order (called from `_update`).
  void _notifyChanges(({OrderStatus status, int? late, bool checking, bool cantFind, bool credited}) old, Order o) {
    final name = o.captain?.name ?? 'Your captain';
    final price = Fmt.rupees(o.price);
    if (old.status != o.status) {
      switch (o.status) {
        case OrderStatus.searching:
          notify(NotificationKind.bookingConfirmed, 'Booking confirmed', '${o.vehicle.plate} · ${o.slot.full}. We’re finding a captain.', orderId: o.id);
          if (!o.entryPassReceived) {
            notify(
              NotificationKind.gatePassNeeded,
              'Share your gate pass',
              'Reply on WhatsApp with your MyGate or society pass so the captain can get in.',
              orderId: o.id,
              date: DateTime.now().add(const Duration(seconds: 1)),
            );
          }
        case OrderStatus.onTheWay:
          notify(
            NotificationKind.captainAssigned,
            '$name is on the way',
            'Arriving by ${Fmt.time(o.arrivesBy ?? DateTime.now())} for ${o.vehicle.plate}.',
            orderId: o.id,
          );
        case OrderStatus.washing:
          notify(
            NotificationKind.washStarted,
            'Washing has started',
            '$name started at ${Fmt.time(o.startedAt ?? DateTime.now())}. Photos when he’s done.',
            orderId: o.id,
          );
        case OrderStatus.photosReady:
          notify(
            NotificationKind.photosReady,
            'Check the wash',
            'Photos are ready. Approve to release $price to $name, or tell us if something’s wrong.',
            orderId: o.id,
          );
        case OrderStatus.autoApproved:
          notify(
            NotificationKind.autoApproved,
            'Wash approved automatically',
            '$price went to $name. You can still report a problem until midnight tomorrow.',
            orderId: o.id,
          );
        case OrderStatus.noCaptain:
          notify(
            NotificationKind.noCaptain,
            'No captain could take your wash',
            o.refund?.awaitingUPI == true
                ? 'We’ve cancelled it. Tell us your UPI ID and we’ll send your $price back.'
                : 'We’ve cancelled it. Your $price is on its way to ${o.refund?.upi ?? 'your UPI'}.',
            orderId: o.id,
          );
        case OrderStatus.captainNoShow:
          notify(
            NotificationKind.noShowRefund,
            'Full refund for your missed wash',
            o.refund?.awaitingUPI == true
                ? '$name didn’t turn up. Add your UPI ID and $price reaches you by 11:59 PM.'
                : '$name didn’t turn up. $price goes to ${o.refund?.upi ?? 'your UPI'} by 11:59 PM. We’ve taken action with the captain.',
            orderId: o.id,
          );
        case OrderStatus.cancelled:
          notify(
            NotificationKind.bookingCancelled,
            'Booking cancelled',
            o.freeWashGiven
                ? '1 free wash is added to your account. Use it on your next booking.'
                : o.creditGiven > 0
                ? '${Fmt.rupees(o.creditGiven)} credit is added. It comes off your next booking.'
                : 'Your refund of ${Fmt.rupees(o.refund?.amount ?? o.price)} has started.',
            orderId: o.id,
          );
        case OrderStatus.disputeUpheld || OrderStatus.disputeRejected:
          notify(NotificationKind.disputeDecision, 'We’ve checked your report', 'Tap to see the decision for ${o.vehicle.plate}.', orderId: o.id);
        case OrderStatus.paymentPending:
          notify(NotificationKind.paymentPending, 'Payment not confirmed yet', 'If money left your account, it comes back within 3 days.', orderId: o.id);
        default:
          break;
      }
    }
    if (old.late == null && o.runningLateMinutes != null) {
      notify(
        NotificationKind.captainRunningLate,
        'Your wash is running late',
        '$name is about ${o.runningLateMinutes} min behind. We’ll keep you posted.',
        orderId: o.id,
      );
    }
    if (!old.checking && o.noShowChecking) {
      notify(
        NotificationKind.washStatusCheck,
        'We’re checking on your wash',
        'Your slot has ended and $name hasn’t updated the wash. We’re checking with him and will update you.',
        orderId: o.id,
      );
    }
    if (!old.cantFind && o.captainCantFind) {
      notify(NotificationKind.captainCantFind, '$name can’t find your vehicle', 'He’s at ${o.place.parkingShort}. Tell him where it is.', orderId: o.id);
    }
    if (!old.credited && o.refund?.credited == true) {
      notify(NotificationKind.refundCredited, 'Refund credited', '${Fmt.rupees(o.refund!.amount)} reached ${o.refund!.method}.', orderId: o.id);
    }
  }

  /// Sample inbox for the demo customer: one of each kind, including edge cases
  /// (a booking that no longer exists, an expired offer, a step that has moved on).
  void seedSampleNotifications() {
    final now = DateTime.now();
    DateTime h(double x) => now.subtract(Duration(minutes: (x * 60).round()));
    final plate = car().plate;
    notifications = [
      AppNotification(
        id: 'n_offer',
        kind: NotificationKind.offer,
        title: 'Weekend shine, ₹20 off',
        body: 'On wet washes this Saturday and Sunday.',
        date: h(0.4),
        expiresAt: now.add(const Duration(days: 3)),
      ),
      AppNotification(
        id: 'n_free',
        kind: NotificationKind.freeWash,
        title: 'You’ve got a free wash',
        body: 'Thanks for the report last week. It’s applied at checkout.',
        date: h(5),
      ),
      AppNotification(
        id: 'n_photos_old',
        kind: NotificationKind.photosReady,
        title: 'Check the wash',
        body: 'Photos are ready for $plate. Approve to release ₹149 to Raju.',
        date: h(26),
        orderId: 'ord_past1',
        read: true,
      ),
      AppNotification(
        id: 'n_assigned_old',
        kind: NotificationKind.captainAssigned,
        title: 'Raju is on the way',
        body: 'Arriving by 8:40 AM for $plate.',
        date: h(27),
        orderId: 'ord_past1',
        read: true,
      ),
      AppNotification(
        id: 'n_refund',
        kind: NotificationKind.refundCredited,
        title: 'Refund credited',
        body: '₹149 reached Google Pay · ananya@okhdfc.',
        date: h(70),
        orderId: 'ord_past2',
      ),
      AppNotification(
        id: 'n_gone',
        kind: NotificationKind.bookingConfirmed,
        title: 'Booking confirmed',
        body: 'TS 09 AB 1234 · Mon, 8 – 10 AM.',
        date: h(140),
        orderId: 'ord_removed',
        read: true,
      ),
      AppNotification(
        id: 'n_offer_old',
        kind: NotificationKind.offer,
        title: 'Diwali double shine',
        body: 'Two washes for the price of one.',
        date: h(240),
        expiresAt: now.subtract(const Duration(days: 5)),
        read: true,
      ),
      AppNotification(
        id: 'n_phone',
        kind: NotificationKind.phoneChanged,
        title: 'Your phone number was changed',
        body: 'If this wasn’t you, contact us right away.',
        date: h(300),
        read: true,
      ),
      AppNotification(
        id: 'n_welcome',
        kind: NotificationKind.welcome,
        title: 'Welcome to ${Brand.name}',
        body: 'Book a wash, see the photos, then pay. That’s it.',
        date: h(600),
        read: true,
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }
}

/// Shared tap behaviour for a notification (list row, banner). Returns an info message, if any.
String? openNotification(AppNotification n, AppStore store, AppRouter router) {
  store.markRead(n.id);
  store.set(() => store.liveBanner = null);
  switch (n.kind) {
    case NotificationKind.offer:
      if (n.expiresAt != null && n.expiresAt!.isBefore(DateTime.now())) return 'This offer has ended.';
      store.startNewBooking();
      router.go(N.vehicleType);
      return null;
    case NotificationKind.freeWash:
      store.startNewBooking();
      router.go(N.vehicleType);
      return null;
    case NotificationKind.phoneChanged:
      router.popToRoot();
      router.tab = 3;
      return null;
    case NotificationKind.welcome:
      return null;
    default:
      break;
  }
  final o = n.orderId == null ? null : store.order(n.orderId!);
  if (o == null) return 'This booking isn’t available anymore. It may have been removed.';
  store.set(() => store.currentOrderId = o.id);
  switch (n.kind) {
    case NotificationKind.noCaptain || NotificationKind.noShowRefund:
      if (o.refund?.awaitingUPI == true) {
        router.push(R(N.refundUPI, id: o.id));
      } else {
        router.go(o.refund != null ? N.refund : N.live);
      }
    case NotificationKind.refundCredited || NotificationKind.bookingCancelled:
      router.go(o.refund != null ? N.refund : N.live);
    case NotificationKind.disputeDecision:
      router.go(N.disputeStatus);
    case NotificationKind.gatePassNeeded:
      if (o.entryPassReceived || !o.status.isActive) {
        store.set(() => store.toast = 'Gate pass already received. Here’s the latest.');
        router.go(N.live);
      } else {
        router.go(N.whatsApp);
      }
    case NotificationKind.paymentPending:
      if (o.status == OrderStatus.paymentPending) {
        router.push(const R(N.paying, pay: PayView.pending));
      } else {
        store.set(() => store.toast = 'Good news: the payment went through.');
        router.go(N.live);
      }
    default:
      final s = n.kind.liveStatuses;
      if (s != null && !s.contains(o.status)) store.set(() => store.toast = 'Things have moved on. Here’s the latest.');
      router.go(N.live);
  }
  return null;
}

/// Gives every screen the store and router, and redraws dependents when either changes.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({super.key, required this.store, required this.router, required super.child}) : super(notifier: Listenable.merge([store, router]));
  final AppStore store;
  final AppRouter router;

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;
}

extension AppContext on BuildContext {
  AppStore get store => AppScope.of(this).store;
  AppRouter get router => AppScope.of(this).router;
}
