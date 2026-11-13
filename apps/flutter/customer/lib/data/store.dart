// Customer state uses live Firebase controllers in normal builds and isolated
// authored sample state in explicit demo builds. See docs/BACKEND-HOOKUP.md.

import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions, Source;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';
import 'package:washkrew_purchase_ui/washkrew_purchase_ui.dart';
import 'package:washkrew_referrals/demo_tools.dart';
import 'package:washkrew_service_recovery/demo_tools.dart';
import 'place_search.dart';
import 'report_submission.dart';

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
  coupons,
  booked,
  whatsApp,
  notifyAsk,
  notifyFirst,
  live,
  photoCompare,
  rate,
  reportProblem,
  problemPhotos,
  disputeStatus,
  refund,
  bookingDetail,
  repeatBooking,
  repeatPhotos,
  vehiclePick,
  vehicleEdit,
  vehicleDetail,
  vehicleCheck,
  careRoutine,
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
  // v2 CU-WASHCHOICE phases 2–4 (ChatGPT handoff, 8 Nov).
  purchaseTime,
  purchaseConfirmation,
  planDetails,
  referrals,
  referralJoin,
  referralScenarios,
  recovery,
  recoveryScenarios,
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

  /// v2 CU-BOOKINGS: drop every screen above the last [n] (used to return to Book again).
  void popTo(N n) {
    final i = path.lastIndexWhere((e) => e.route.n == n);
    if (i < 0) return;
    path = path.sublist(0, i + 1);
    notifyListeners();
  }
  void resetAccountNavigation(){showPaySheet=false;path=[];tab=0;}

  void setSplash(bool v) {
    showSplash = v;
    notifyListeners();
  }

  void openPaySheet(bool v) {
    showPaySheet = v;
    notifyListeners();
  }

  /// After login: resume checkout (or the legacy address form), or go home.
  void finishLogin({bool directCheckout = false, bool reviewOnly = false}) {
    final address = path.lastIndexWhere((e) => e.route.n == N.manualAddress);
    final i = path.lastIndexWhere((e) => e.route.n == N.review);
    final coupons=path.lastIndexWhere((e)=>e.route.n==N.coupons);
    if(coupons>=0&&coupons>i&&coupons>address){keep(coupons+1);showPaySheet=false;return;}
    if (address >= 0 && address > i) { keep(address + 1); return; }
    if (i >= 0) {
      keep(i + 1);
      if(reviewOnly){showPaySheet=false;return;}
      if (directCheckout) {
        showPaySheet = false;
        // Let Review apply the just-loaded wallet balance before preparing the
        // server amount. One frame, with no artificial sheet/navigation timer.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isAt(N.review)) push(const R(N.paying));
        });
      } else {
        Future.delayed(const Duration(milliseconds: 450), () => openPaySheet(true));
      }
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
  refundCoupon,
  paymentPending,
  freeWash,
  offer,
  phoneChanged,
  welcome;

  NotificationCategory get category => switch (this) {
    refundCredited || refundCoupon || paymentPending => NotificationCategory.payments,
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
    freeWash || refundCoupon => WIcon.gift,
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

/// v2 CU-BOOKINGS: the parts of a Book again the customer can change.
enum RepeatEdit { vehicle, wash, place }

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
  bool walletOnly = false;
  String couponCode='';
  int couponAppliedPaise=0;
  int couponForfeitPaise=0;
  bool couponForfeitAccepted=false;
  String? couponVehicleKind;
  int? couponBasePricePaise;

  /// Rupees of the customer's credit taken off this booking (set on Check and pay).
  num creditApplied;
  bool isRepeat;

  /// v2 CU-BOOKINGS: the order or vehicle this Book again started from.
  String? repeatFrom;

  /// v2 CU-BOOKINGS: which part of a Book again is being changed (null = none).
  RepeatEdit? editing;

  /// v2 CU-BOOKINGS: the customer's photos from the booking this Book again
  /// started from (angle name -> storage path). Empty when there are none.
  Map<String, String> lastPhotoPaths = {};
  String? lastPhotosOrderId;

  /// v2 CU-CARE: what the customer confirmed about the vehicle (make, model, colour,
  /// paint, seats, source) and the care routine built from it. Sent with the booking.
  Map<String, dynamic>? vehicleProfile;
  List<Map<String, String>> careRoutine = const [];

  /// v2 CU-VEHICLE: this draft only adds a vehicle to the list (no booking).
  bool addingVehicle = false;

  /// v2 CU-VEHICLE: a booking started from a saved vehicle (its id).
  String? pickedVehicleId;

  /// v2 CU-VEHICLE: adding photos later to this saved vehicle (its id).
  String? photosForVehicleId;

  /// v2 CU-VEHICLE: photos saved with the vehicle, offered on the photos step.
  Map<PhotoAngle, Uint8List> lastPhotoBytes = {};

  /// v2 CU-BOOKINGS: set when the customer chose "Use these photos".
  /// BACKEND (Ajay): copy that booking's customerPhotos onto the new booking.
  String? reusePhotosFrom;

  int get photosDone => photos.values.where((s) => s == UploadState.done).length;
  bool get photosComplete => PhotoAngle.values.every((a) => photos[a] == UploadState.done);
  bool get hasFailedPhoto => photos.values.contains(UploadState.failed);
  /// v2 CU-WASHCHOICE: the chosen service, coverage and its server price.
  ServiceLevel? serviceLevel;
  WashCoverage? coverage;
  num? chosenPrice;
  num get basePrice => chosenPrice ?? type?.price ?? 0;
  int get basePricePaise => (basePrice * 100).round();
  int get pricePaise => useFreeWash ? 0 : (basePricePaise - couponAppliedPaise - (creditApplied * 100).round()).clamp(0, basePricePaise);
  num get price => pricePaise / 100;
  void applyWalletCredit(num balance, {bool enabled = true}) {
    var applied = enabled && !useFreeWash ? (balance * 100).round().clamp(0, basePricePaise) : 0;
    final remainder = basePricePaise - applied;
    if (remainder > 0 && remainder < 100) applied = max(0, basePricePaise - 100);
    creditApplied = applied / 100;
  }
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
  bool _accountActive = false;
  int _accountGeneration = 0;
  int accountResetRevision = 0;
  String draftRequestId = newId('draft');
  String? draftBookingId;
  String _couponPreparedIdentity='';
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
            _prepareCoupons();
            final types = (config['vehicleTypes'] as List? ?? []).where((v) => v['active'] == true && v['pricePaise'] is num).toList();
            if (types.isNotEmpty) {
              VehicleType.all = [
                for (final v in types)
                  VehicleType(VehicleKind.values.byName(v['kind']), v['name'], (v['minutes'] as num).toInt(), (v['pricePaise'] as num) / 100),
              ];
              if (draft.type != null) draft.type = VehicleType.all.where((t) => t.kind == draft.type!.kind).firstOrNull;
            }
            liveSocieties = [
              ...liveSocieties.where((s)=>s.id.startsWith('loc_')),
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

  void _prepareCoupons() {
    customer?.freeWashes=0;customer?.credit=0;
    final identity=_accountActive&&_liveUid.isNotEmpty&&liveConfig['paymentBalanceMode']=='refundCouponsV1'?'${_liveUid}_${testPayments?'test':'live'}':'';
    if(identity.isEmpty||identity==_couponPreparedIdentity)return;
    _couponPreparedIdentity=identity;final generation=_accountGeneration;
    live!.call('prepareMyCoupons',{}).catchError((Object e){if(generation==_accountGeneration){_couponPreparedIdentity='';backendMessage=backendError(e);changed();}return <String,dynamic>{};});
  }

  /// Clear private role state before another screen/account can observe it.
  void resetDeletedAccountData() {
    _accountActive=false;
    customer=null;profilePhoto=null;_profilePhotoPath=null;savedPlaces=[];
    vehicles=[];orders=[];notifications=[];_inbox=[];_inboxLoaded=false;
    notificationPrefs=NotificationPrefs();liveBanner=null;toast=null;
    currentOrderId=null;viewingOrderId=null;draft=BookingDraft();
    draftBookingId=null;draftRequestId=newId('draft');draftPhotoBytes.clear();draftMedia.clear();
    _checkoutIdentity=null;checkoutCancelled=false;
    _couponPreparedIdentity='';
    _preferenceSave?.cancel();_readIds.clear();_unreadIds.clear();_deletedIds.clear();
    _invalidateAvailability();backendMessage=null;returningCustomer=false;
    pendingPhone='';pendingNewPhone='';hasSeenWelcome=false;payMethodId='gpay';
    for(final task in _tasks.values){task.cancel();}_tasks.clear();
    accountResetRevision++;changed();
  }

  void _bindLiveAccount(String uid) {
    final old = _liveUid;
    _accountGeneration++;
    _accountActive = false;
    if(uid!=old){_checkoutIdentity=null;checkoutCancelled=false;}
    if(uid.isEmpty && old.isNotEmpty) resetDeletedAccountData();
    _liveUid = uid;
    final generation = _accountGeneration;
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
    _prepareCoupons();
    orders = [];
    vehicles = [];
    notifications = [];
    _inbox = [];
    currentOrderId = null;
    if (uid.isEmpty) {
      changed();
      return;
    }
    _accountSubscriptions.add(
      live!
          .profile(uid)
          .listen(
            (snapshot) {
              if (_liveUid != uid || generation != _accountGeneration || snapshot.metadata.isFromCache) return;
              final data = snapshot.data();
              if(data == null || appAccountRoleState(data,'customer') != AppAccountRoleState.active) {
                final wasActive = _accountActive;
                _accountActive = false;
                if(wasActive || (!live!.registrationInProgress && appAccountRoleState(data,'customer') != AppAccountRoleState.absent)){resetDeletedAccountData();}
                else {customer=null;}
                _prepareCoupons();
                if(data != null && appAccountRoleState(data,'customer') != AppAccountRoleState.absent && !live!.registrationInProgress) {
                  live!.signOut().catchError((Object _){});
                }
                if(wasActive) changed();
                return;
              }
              if(!_accountActive) {
                _accountActive=true;
                _bindCustomerData(uid,generation);
                _prepareCoupons();
              }
              customer = Customer(id: uid, phone: (data['phone'] as String? ?? '').replaceFirst('+91', ''), name: appAccountName(data,'customer'), freeWashes: 0, notificationsOn: data['customerPushEnabled'] == true);
              _restorePreferences(data);
              final photoPath = data['customerPhotoPath'] as String?;
              if (photoPath != _profilePhotoPath) {
                _profilePhotoPath = photoPath;
                if (photoPath == null) {
                  profilePhoto = null;
                } else {
                  live!.photo(photoPath).then((bytes) { if (_accountActive && generation == _accountGeneration && _liveUid == uid && photoPath == _profilePhotoPath) { profilePhoto = bytes; changed(); } }).catchError((Object e) { if (_liveUid == uid) set(() => toast = backendError(e)); });
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

    changed();
  }

  void _bindCustomerData(String uid,int generation) {
    live!.registerPush('customer').catchError((Object _) {});
    _accountSubscriptions.add(live!.availabilityChanges.listen((_){_invalidateAvailability();changed();},onError:(Object _){}));
    _accountSubscriptions.add(live!.inbox(uid).listen((s){
      if(_liveUid!=uid || generation!=_accountGeneration || !_accountActive || s.metadata.isFromCache)return;
      final oldIds=_inbox.map((e)=>e.$1).toSet();
      _inbox=[for(final doc in s.docs) if(doc.data()['role']=='customer') (doc.id, doc.data())];
      _mapInbox();
      if(_inboxLoaded){for(final n in notifications.where((n)=>!oldIds.contains(n.id))) { _present(n); }}
      _inboxLoaded=true;
      changed();
    },onError:(Object e){backendMessage=backendError(e);changed();}));
    _accountSubscriptions.add(
      live!
          .orders(uid)
          .listen(
            (snapshot) {
              if (_liveUid != uid || generation != _accountGeneration || !_accountActive || snapshot.metadata.isFromCache) return;
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
      'refundCoupon' => (NotificationKind.refundCoupon,d['title'] as String? ?? 'Refund coupon update',d['body'] as String? ?? 'Open your coupons for the latest update.'),
      'vehicleHelp' => (NotificationKind.captainCantFind, '$name cannot find your vehicle', 'Open your booking to reply.'),
      'washStatusCheck' => (NotificationKind.washStatusCheck, 'We’re checking your wash', 'Your slot ended. Open your booking for the latest status.'),
      'disputeDecision' => (NotificationKind.disputeDecision, 'Your report has an update', o?.dispute?.decisionNote ?? 'Open your report to see the review decision.'),
      'phoneChanged' => (NotificationKind.phoneChanged, 'Mobile number updated', 'Your verified mobile number was updated.'),
      'cancelled' => (NotificationKind.bookingCancelled, 'Booking cancelled', o?.cancellationSummary ?? (o?.freeWashGiven == true
          ? '1 free wash is added to your account. Use it on your next booking.'
          : (o?.creditGiven ?? 0) > 0
          ? '${Fmt.rupees(o!.creditGiven)} credit is added. It comes off your next booking.'
          : d['body'] as String? ?? 'Open your booking to check the cancellation outcome.')),
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
        VehicleType.all.where((t) => t.kind == kind).firstOrNull ?? VehicleType(kind, data['vehicleName'], 20, (data['basePricePaise'] as num? ?? data['pricePaise']) / 100);
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
      price: (data['pricePaise'] as num) / 100,
      status: data['dispute']?['outcome']=='rejected'?OrderStatus.disputeRejected:data['status'] == 'approved' && data['approvalSource'] == 'automatic' ? OrderStatus.autoApproved : data['status'] == 'cancelled' && data['cancellationReason'] == 'slotExpired' ? data['captainId'] == null ? OrderStatus.noCaptain : OrderStatus.captainNoShow : data['status'] == 'scheduled' ? OrderStatus.searching : OrderStatus.values.byName(data['status']),
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
      gatePassPath: data['entryPass']?['path'] as String?,
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
    order.bookedAt = date(data['bookedAt']);
    order.cancellationOutcome = data['cancellationBenefit'] is Map ? Map<String, dynamic>.from(data['cancellationBenefit']) : null;
    order.walletReleased = data['walletReleased'] == true;
    order.creditUsed = (data['creditUsedPaise'] as num? ?? 0) / 100;
    order.freeWashGiven = data['cancellationBenefit']?['kind'] == 'freeWash';
    order.creditGiven = data['cancellationBenefit']?['kind'] == 'credit' ? (data['cancellationBenefit']?['creditPaise'] as num? ?? 0) / 100 : 0;
    order.arrivalUpdatedAt=date(data['arrivalUpdatedAt']);
    order.serverSlotStart = date(data['slotStart']);
    order.paymentStatus = data['paymentStatus'] ?? 'unpaid';
    final ai=data['aiPhotoConsent']?['customer'];
    order.aiPhotoCheckEnabled=ai is Map && ai['allowed']==true && ai['version']==aiPhotoConsentVersion;
    order.aiPhotoCheckRevision=ai is Map ? (ai['revision'] as num? ?? 0).toInt() : 0;
    order.aiPhotoCheckStarted=data['photoReview']?['aiSentAt']!=null;
    order.refundStatus = data['refundStatus'] ?? 'none';
    order.refundRequestStatus=data['refundRequestStatus'] as String?;
    order.refundCouponId=data['refundCouponId'] as String?;
    order.refundDecisionNote=data['refundDecisionNote'] as String?;
    order.refundCouponAmount=(data['refundCouponAmountPaise'] as num? ?? 0)/100;
    order.couponReleased=data['couponReleased']==true;
    order.couponApplied=order.couponReleased?0:(data['couponReservedPaise'] as num? ?? 0)/100;
    order.couponForfeit=order.couponReleased?0:(data['couponForfeitPaise'] as num? ?? 0)/100;
    order.cancellationReason = data['cancellationReason'] as String?;
    order.testPayment = data['paymentMode'] == 'test';
    order.evidencePaths = {for (final entry in (data['evidence'] as Map? ?? {}).entries) entry.key as String: entry.value['path'] as String};
    order.customerPhotoPaths = {for (final entry in (data['customerPhotos'] as Map? ?? {}).entries) entry.key as String: entry.value as String};
    order.customerSkippedPhotos = order.customerPhotoPaths.length < 4;
    if (data['dispute'] is Map) {
      final d = data['dispute'] as Map;
      order.dispute = Dispute(
        ref: 'SUP-${id.toUpperCase()}',
        kind: ProblemKind.values.byName(d['kind']),
        createdAt: date(d['createdAt']) ?? DateTime.now(),
        note: d['note'] ?? '',
        outcome: DisputeOutcome.values.where((v) => v.name == d['outcome']).firstOrNull ?? DisputeOutcome.underReview,
        decisionNote: d['decisionNote'] ?? '',
        creditsAwarded: (d['creditsAwarded'] as num? ?? 0).toInt(),
        photos: List<String>.from(d['photos'] ?? const []),
      );
    }
    if (order.refundStatus != 'none') {
      order.refund = Refund(
        amount: (data['refundAmountPaise'] as num? ?? data['pricePaise']) / 100,
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
    _recovery?.dispose();
    _referrals?.dispose();
    _invalidateAvailability();
    _preferenceSave?.cancel();
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
    final account=_liveUid, generation=_accountGeneration, value=_preferences();
    _preferenceSave?.cancel();
    _preferenceSave=Timer(const Duration(milliseconds:300),(){
      _preferenceQueue=_preferenceQueue.then((_) async { if(_accountActive && generation==_accountGeneration && _liveUid==account) await live!.call('saveNotificationPreferences',value); }).catchError((Object e){if(_accountActive && generation==_accountGeneration && _liveUid==account) {toast=backendError(e);changed();}});
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
    final place=draft.place?.society.id==societyId?draft.place:savedPlaces.where((p)=>p.society.id==societyId).firstOrNull;
    final position=place?.latitude!=null&&place?.longitude!=null?{'latitude':place!.latitude,'longitude':place.longitude}:null;
    return _availability.load('$societyId:$d:${position?['latitude']}:${position?['longitude']}', () async {
      final r = await live!.call('getAvailability', {'societyId': societyId, 'day': d,if(captainAreaEnabled&&position!=null)'position':position});
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
  (double,double)? _searchOrigin;
  DateTime? _searchOriginAt;
  Map<String,dynamic>? searchedAddress;
  bool get placeSearchEnabled=>isLive&&liveConfig['maps']?['places']?['enabled']==true;
  bool get hasSearchOrigin=>_searchOriginAt!=null&&DateTime.now().difference(_searchOriginAt!)<const Duration(minutes:10);
  Future<(double,double)?> locateForSearch({bool requestPermission=true})async{
    if(_searchOriginAt!=null&&DateTime.now().difference(_searchOriginAt!)<const Duration(minutes:10))return _searchOrigin;
    final position=requestPermission?await live!.currentPosition():await live!.positionIfAllowed();
    if(position==null)return null;
    _searchOrigin=(position.latitude,position.longitude);_searchOriginAt=DateTime.now();return _searchOrigin;
  }
  Future<List<PlaceSuggestion>> searchPlaceSuggestions(String query,String token)async{
    final origin=_searchOriginAt!=null&&DateTime.now().difference(_searchOriginAt!)<const Duration(minutes:10)?_searchOrigin:null;
    if(query.isEmpty&&origin==null)return [];
    final result=await live!.call('searchPlaceSuggestions',{'query':query,'sessionToken':token,if(origin!=null)'origin':{'latitude':origin.$1,'longitude':origin.$2}});
    return [for(final p in result['suggestions'] as List? ?? [])PlaceSuggestion.fromMap(Map<String,dynamic>.from(p as Map))];
  }
  Future<Map<String,dynamic>> selectPlaceSuggestion(String id,String token)async{
    final r=await live!.call('selectPlaceSuggestion',{'placeId':id,'sessionToken':token});
    if(r['society'] is Map){final m=r['society'] as Map;liveSocieties=[...liveSocieties.where((s)=>s.id!=m['id']),Society(m['id'],m['name'],m['area'],m['city'],m['pincode'])];}
    return r;
  }
  bool get captainAreaEnabled=>liveConfig['coveragePolicy']=='captainAreaV1';

  // v2 CU-WASHCHOICE (8 Nov): ChatGPT handoff wash choice and custom time windows.
  // Off until Ajay turns on liveConfig.washChoiceV2; "Preview new features" (tap the
  // app version 7 times in Profile) shows it on this phone without paying.
  final purchase = PurchaseSelection();
  /// "Change" on Check and pay opens the wash choice and comes straight back.
  bool washChoiceFromReview = false;

  /// 13 Nov: Make payment was tapped while logged out; continue to payment after log in.
  bool payAfterLogin = false;
  /// "Change frequency" on the monthly days screen returns there after the choice.
  bool purchaseReturningToSchedule = false;
  bool previewFeatures = false;
  Future<void> loadPreviewFeatures() async {
    final on = await LocalFlags.get('previewFeatures');
    if (on != previewFeatures) set(() => previewFeatures = on);
  }

  Future<void> setPreviewFeatures(bool on) async {
    set(() => previewFeatures = on);
    await LocalFlags.set('previewFeatures', on);
  }

  /// v2 (12 Nov, Aman): the handoff features are a standard part of the app. The server
  /// can still turn them off with liveConfig.v2Features = false. `previewFeatures`
  /// (7 taps in Profile) now only shows the review tools.
  bool get v2Features => liveConfig['v2Features'] != false;
  bool get washChoiceV2 => v2Features;
  /// The server stores exact-minute windows (liveConfig.customTimeWindows).
  bool get customTimesLive => !isLive || liveConfig['customTimeWindows'] == true;
  /// The server prices and records Basic/Premium/Extra Premium and interior (liveConfig.washTiers).
  bool get washTiersLive => !isLive || liveConfig['washTiers'] == true;
  /// Monthly plans (phase 2) stay hidden until their server work is live.
  bool get monthlyPlansLive => liveConfig['monthlyPlans'] == true;

  /// 13 Nov (Aman): features the live server can't do yet are "Coming soon" at their entry
  /// point. Sample builds keep everything open for review.
  bool get referralsLive => !isLive || liveConfig['referrals'] == true;
  bool get gatePassLive => !isLive || liveConfig['gatePass'] == true;

  /// Service hours for custom windows: liveConfig.serviceHours {startMinute, endMinute},
  /// else 4 AM – 11 PM (Aman, 8 Nov).
  /// 13 Nov (Aman): on live, before exact times are switched on, the picker covers only the
  /// hours the server's slots serve (e.g. 4 AM–10 PM), so every window can be booked.
  int get washDayStart {
    final set = ((liveConfig['serviceHours'] as Map?)?['startMinute'] as num?)?.toInt();
    if (set != null) return set;
    if (isLive && !customTimesLive && liveWindows.isNotEmpty) return liveWindows.map((w) => w.$1 * 60).reduce((a, b) => a < b ? a : b).clamp(washDayStartMinute, washDayEndMinute);
    return washDayStartMinute;
  }

  int get washDayEnd {
    final set = ((liveConfig['serviceHours'] as Map?)?['endMinute'] as num?)?.toInt();
    if (set != null) return set;
    if (isLive && !customTimesLive && liveWindows.isNotEmpty) return liveWindows.map((w) => w.$2 * 60).reduce((a, b) => a > b ? a : b).clamp(washDayStartMinute, washDayEndMinute);
    return washDayEndMinute;
  }

  /// Server price in rupees for a service: liveConfig.washPrices[kind][level][coverage],
  /// else today's vehicle price for Basic exterior. Null = no approved price yet.
  num? washPrice(VehicleType t, ServiceLevel level, WashCoverage coverage) {
    final table = liveConfig['washPrices'];
    if (table is Map) {
      final v = ((table[t.kind.name] as Map?)?[level.name] as Map?)?[coverage.name];
      if (v is num) return v;
    }
    if (level == ServiceLevel.basic && coverage == WashCoverage.exterior) return t.price;
    return null;
  }

  /// Price shown on Choose your wash: the reward (free), else the server price, else —
  /// on this phone's preview only — the handoff's draft price (marked "draft").
  num? purchasePrice(VehicleType t, ServiceLevel level) {
    final p = purchase;
    if (p.usingPremiumReward && level == ServiceLevel.premium && !p.monthly) return 0;
    if (p.monthly && monthlyPlansLive) return monthlyPlanPrice(t, level);
    final real = p.monthly ? null : washPrice(t, level, p.coverage);
    if (real != null) return real;
    // Sample price until the server sends liveConfig.washPrices (see V2-FEATURES.md).
    return v2Features ? p.quotePaiseFor(level) / 100 : null;
  }

  bool purchasePriceIsDraft(VehicleType t, ServiceLevel level) {
    final p = purchase;
    if (p.usingPremiumReward && level == ServiceLevel.premium && !p.monthly) return false;
    if (p.monthly && monthlyPlansLive) return false;
    return (p.monthly || washPrice(t, level, p.coverage) == null) && v2Features;
  }

  /// 13 Nov: the monthly price the server charges (rupees): liveConfig.monthlyPlanPricing
  /// {car|bike: {base, perDay, levelPerDay, interiorPerDay}}, else Aman's tariff in the app.
  num monthlyPlanPrice(VehicleType t, ServiceLevel level) {
    final p = purchase, bike = t.kind == VehicleKind.bike;
    final set = (liveConfig['monthlyPlanPricing'] as Map?)?[bike ? 'bike' : 'car'];
    if (set is! Map) return p.quotePaiseFor(level) / 100;
    num v(String k) => (set[k] as num?) ?? 0;
    final f = p.frequency;
    return v('base') + v('perDay') * f + v('levelPerDay') * f * level.index + (p.coverage == WashCoverage.exteriorInterior ? v('interiorPerDay') * f : 0);
  }

  // v2 phase 2 (monthly plans): the paid plan, saved next-cycle changes and an open edit.
  // Preview only — Ajay's plan/mandate server is the real source (CU-WASHCHOICE.md).
  PurchaseSelection? activePlan;
  PurchaseSelection? nextCyclePlan;
  PurchaseSelection? planEditDraft;
  /// Set when a live monthly plan was just paid: payment opens its confirmation.
  bool planJustPaid = false;

  // v2 phases 3–4: the handoff's in-memory previews, made only when the preview opens
  // (the recovery one checks for changes every second, so never at app start).
  DemoReferralRepository? _referrals;
  DemoReferralRepository get referrals => _referrals ??= (DemoReferralRepository(actorId: 'customer_ananya')..addListener(changed));
  DemoRecoveryRepository? _recovery;
  DemoRecoveryRepository get recovery => _recovery ??= (DemoRecoveryRepository()..addListener(changed));
  bool get recoveryStarted => _recovery != null;

  /// Why this booking can't be paid yet on the live server, or null.
  /// v2: the server's fixed slots that exactly make up the customer's own windows
  /// (e.g. 8–10 AM, or 8 AM–12 PM = 8–10 + 10–12), or null when they don't line up.
  /// Lets today's server take the booking until it stores exact minutes.
  /// 13 Nov (Aman): any window the customer picks can be booked. The server's fixed slots
  /// that lie inside the customer's windows are booked; a short window inside no slot books
  /// the slot it overlaps most. The exact minutes go along for the Captain (`minuteWindows`).
  List<(int, int)>? serverWindowsFor(TimeSlot s) {
    if (s.minuteWindows.isEmpty) return null;
    final out = <(int, int)>{};
    for (final w in s.orderedMinuteWindows) {
      final inside = [for (final x in liveWindows) if (x.$1 * 60 >= w.$1 && x.$2 * 60 <= w.$2) x];
      if (inside.isNotEmpty) {
        out.addAll(inside);
        continue;
      }
      int overlap((int, int) x) => (w.$2 < x.$2 * 60 ? w.$2 : x.$2 * 60) - (w.$1 > x.$1 * 60 ? w.$1 : x.$1 * 60);
      final best = [...liveWindows]..sort((a, b) => overlap(b).compareTo(overlap(a)));
      if (best.isNotEmpty && overlap(best.first) > 0) out.add(best.first);
    }
    return out.isEmpty ? null : (out.toList()..sort((a, b) => a.$1.compareTo(b.$1)));
  }

  /// Why this booking can't be paid yet on the live server, or null. Sample (non-live)
  /// builds complete everything with sample data.
  /// 13 Nov: what fixes the block — the time step for times, the wash step otherwise.
  bool get washChoiceBlockedByTime {
    final s = draft.slot;
    return isLive && !(purchase.chosen && purchase.monthly) && !purchase.usingPremiumReward && s != null && s.minuteWindows.isNotEmpty && !customTimesLive && serverWindowsFor(s) == null;
  }

  String? get washChoiceBlockedReason {
    if (!isLive) return null;
    if (purchase.chosen && purchase.monthly && !monthlyPlansLive) {
      return 'Monthly plans open for payment soon. A one-time wash can be booked today.';
    }
    if (purchase.usingPremiumReward) {
      return 'Free Premium washes open soon. You can book a paid wash today.';
    }
    final s = draft.slot;
    if (s != null && s.minuteWindows.isNotEmpty && !customTimesLive && serverWindowsFor(s) == null) {
      // Each end keeps its own AM/PM: "10 AM–12 PM", "6–8 AM".
      String h(int x) => '${x % 12 == 0 ? 12 : x % 12}';
      String ap(int x) => x < 12 || x == 24 ? 'AM' : 'PM';
      final slots = [for (final w in liveWindows) ap(w.$1) == ap(w.$2) ? '${h(w.$1)}–${h(w.$2)} ${ap(w.$2)}' : '${h(w.$1)} ${ap(w.$1)}–${h(w.$2)} ${ap(w.$2)}'].join(', ');
      return 'Exact times open soon. For now, pick one of these: $slots.';
    }
    final level = draft.serviceLevel, coverage = draft.coverage;
    if (level != null && coverage != null && (level != ServiceLevel.basic || coverage != WashCoverage.exterior) && !washTiersLive) {
      return '${level.label}${coverage == WashCoverage.exteriorInterior ? ' with interior' : ''} opens for booking soon. Basic, outside only, can be booked today.';
    }
    return null;
  }
  Future<Place> confirmPlace(Place p)async{
    final r=await live!.call('checkServiceAddress',{'name':p.society.name,'area':p.society.area,'city':p.society.city,'pincode':p.society.pincode,'location':{'latitude':mapCenter(p).$1,'longitude':mapCenter(p).$2}});
    final m=r['society'] as Map;
    final society=Society(m['id'],m['addressName'],m['addressArea'],m['addressCity'],m['addressPincode']);
    return Place(society,tower:p.tower,floor:p.floor,slot:p.slot,latitude:mapCenter(p).$1,longitude:mapCenter(p).$2);
  }
  (double,double) mapCenter(Place place){
    final society=(liveConfig['societies'] as List? ?? []).where((s)=>s['id']==place.society.id).firstOrNull;
    return (place.latitude??(society?['location']?['latitude'] as num?)?.toDouble()??17.385,place.longitude??(society?['location']?['longitude'] as num?)?.toDouble()??78.4867);
  }
  Future<Place?> locatePlace()async{
    final position=await live!.currentPosition();
    _searchOrigin=(position.latitude,position.longitude);_searchOriginAt=DateTime.now();
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
  Future<bool> setBookingPhotoAi(Order order,bool enabled) async {
    if(!isLive)throw StateError('AI checks require a paid live booking.');
    final generation=_accountGeneration;
    final result=await live!.call('setBookingPhotoAi',{'orderId':order.id,'enabled':enabled,'expectedRevision':order.aiPhotoCheckRevision,'policyVersion':aiPhotoConsentVersion});
    final current=orders.where((o)=>o.id==order.id).firstOrNull;
    final revision=(result['revision'] as num).toInt();
    if(_accountActive&&generation==_accountGeneration&&current!=null&&current.aiPhotoCheckRevision<=revision){
      current.aiPhotoCheckEnabled=result['enabled']==true;current.aiPhotoCheckRevision=revision;changed();
    }
    return result['checkMayHaveStarted']==true;
  }
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
  List<Vehicle> get myVehicles {
    if (demo.emptyHistory) return [];
    // v2 CU-VEHICLE: photos/edits saved on this phone also apply to vehicles from past bookings.
    final local = {for (final v in localVehicles) v.id: v};
    return [
      for (final v in vehicles) ...[if (local[v.id] != null) local[v.id]! else v],
      for (final v in localVehicles) if (!vehicles.any((o) => o.id == v.id || o.plate == v.plate)) v,
    ].where((v) => !_deletedVehicles.contains(v.id) && !(v.plate.isNotEmpty && _deletedVehicles.contains(plateKey(v.plate)))).toList();
  }

  // v2 CU-VEHICLE (12 Nov): delete a saved vehicle. Vehicles from past bookings can't be
  // removed on the server yet, so deleted ones are remembered on this phone and hidden.
  // BACKEND (Ajay): a `deleteCustomerVehicle` callable when saved vehicles move to the account.
  Set<String> _deletedVehicles = {};
  String get _deletedVehiclesKey => 'vehiclesDeleted:${customer?.id ?? 'guest'}';

  /// Bookings of this vehicle, newest first.
  List<Order> washesFor(Vehicle v) => orders.where((o) => o.status != OrderStatus.pendingPayment && (o.vehicle.id == v.id || (v.plate.isNotEmpty && plateKey(o.vehicle.plate) == plateKey(v.plate)))).toList()
    ..sort((a, b) => b.slot.start.compareTo(a.slot.start));

  /// Why this vehicle can't be deleted now, or null.
  String? vehicleDeleteBlocked(Vehicle v) => washesFor(v).any((o) => o.status.isUpcoming)
      ? 'This vehicle has a wash booked. You can delete it after the wash is done or cancelled.'
      : null;

  Future<void> deleteVehicle(Vehicle v) async {
    if (vehicleDeleteBlocked(v) != null) return;
    _deletedVehicles = {..._deletedVehicles, v.id, if (v.plate.isNotEmpty) plateKey(v.plate)};
    localVehicles = [for (final x in localVehicles) if (x.id != v.id) x];
    notifyListeners();
    await LocalFlags.setList(_deletedVehiclesKey, [for (final k in _deletedVehicles) {'key': k}]);
    await LocalFlags.setList(_vehicleKey, [
      for (final x in localVehicles) {'id': x.id, 'plate': x.plate, 'kind': x.type.kind.name, 'photos': [for (final a in x.photos.keys) a.name]},
    ]);
  }

  /// A vehicle that is added or booked again comes back to the list.
  Future<void> _restoreVehicle(String plate) async {
    final k = plateKey(plate);
    if (k.isEmpty || !_deletedVehicles.contains(k)) return;
    _deletedVehicles = {for (final x in _deletedVehicles) if (x != k && !vehicles.any((v) => v.id == x && plateKey(v.plate) == k)) x};
    await LocalFlags.setList(_deletedVehiclesKey, [for (final x in _deletedVehicles) {'key': x}]);
  }

  // MARK: v2 CU-VEHICLE — vehicles added without a booking
  /// BACKEND (Ajay): store these on the account (e.g. `customers/{uid}/vehicles`
  /// via a `saveCustomerVehicle` callable) and stream them here. Until then they
  /// are kept on this phone, per account.
  List<Vehicle> localVehicles = [];
  String get _vehicleKey => 'vehicles:${customer?.id ?? 'guest'}';

  Future<void> loadLocalVehicles() async {
    final list = await LocalFlags.getList(_vehicleKey);
    final loaded = <Vehicle>[];
    for (final m in list) {
      final kind = VehicleKind.values.where((k) => k.name == m['kind']).firstOrNull;
      final type = VehicleType.all.where((t) => t.kind == kind).firstOrNull;
      if (type == null) continue;
      final v = Vehicle(m['id'] as String, m['plate'] as String, type, null);
      for (final name in (m['photos'] as List? ?? const [])) {
        final angle = PhotoAngle.values.where((a) => a.name == name).firstOrNull;
        final bytes = angle == null ? null : await LocalFlags.readBytes('${v.id}_${angle.name}.jpg');
        if (angle != null && bytes != null) v.photos[angle] = bytes;
      }
      loaded.add(v);
    }
    final deleted = {for (final m in await LocalFlags.getList(_deletedVehiclesKey)) if (m['key'] is String) m['key'] as String};
    set(() {
      localVehicles = loaded;
      _deletedVehicles = deleted;
    });
  }

  /// The first booking screen: pick a saved vehicle, or start from the type.
  N get firstBookingStep => myVehicles.isEmpty ? N.vehicleType : N.vehiclePick;

  void startAddVehicle() {
    startNewBooking();
    draft.addingVehicle = true;
    notifyListeners();
  }

  bool plateTaken(String plate) => plate.trim().isNotEmpty && myVehicles.any((v) => v.plate.replaceAll(' ', '') == plate.trim().replaceAll(' ', ''));

  /// Saves the vehicle in the draft. Returns an error message, or null.
  Future<String?> saveNewVehicle({bool withPhotos = false}) async {
    final type = draft.type, plate = draft.plate.trim();
    if (type == null) return 'Choose the vehicle type.';
    // The plate may be skipped and added later (Edit vehicle, or when booking).
    if (plate.isNotEmpty && plateTaken(plate)) return 'This vehicle is already saved.';
    final v = Vehicle('local_${newId('veh')}', plate, type, null);
    await _restoreVehicle(v.plate);
    localVehicles = [...localVehicles, v];
    await _saveVehiclePhotos(v, withPhotos);
    draft.addingVehicle = false;
    notifyListeners();
    return null;
  }

  /// v2 CU-VEHICLE: edit a saved vehicle on this phone. Type and plate can be
  /// changed for vehicles added here; photos for any saved vehicle. Nothing is
  /// sent anywhere until the vehicle is used for a booking.
  Future<String?> updateVehicle(Vehicle v, {VehicleType? type, String? plate, required Map<PhotoAngle, Uint8List> photos}) async {
    final raw = (plate ?? v.plate).trim();
    final newPlate = raw.isEmpty ? '' : Fmt.plate(raw);
    if (newPlate.isNotEmpty && plate != null) {
      final problem = plateProblem(newPlate);
      if (problem != null) return problem;
    }
    final clash = newPlate.isNotEmpty && myVehicles.any((x) => x.id != v.id && x.plate.replaceAll(' ', '') == newPlate.replaceAll(' ', ''));
    if (clash) return 'Another saved vehicle has this number plate.';
    final updated = Vehicle(v.id, newPlate, type ?? v.type, v.place)..photos = Map.of(photos);
    localVehicles = [for (final x in localVehicles) if (x.id != v.id) x, updated];
    for (final e in photos.entries) {
      await LocalFlags.saveBytes('${v.id}_${e.key.name}.jpg', e.value);
    }
    await _saveVehiclePhotos(updated, false);
    notifyListeners();
    return null;
  }

  /// "Add photos" later for a saved vehicle: reuse the photos screen.
  void startAddVehiclePhotos(Vehicle v) {
    startNewBooking();
    draft.addingVehicle = true;
    draft.photosForVehicleId = v.id;
    draft.type = v.type;
    draft.plate = v.plate;
    notifyListeners();
  }

  /// Finish the photos step of Add a vehicle (new vehicle or photos later).
  Future<String?> finishVehiclePhotos({required bool withPhotos}) async {
    final id = draft.photosForVehicleId;
    if (id == null) return saveNewVehicle(withPhotos: withPhotos);
    final v = localVehicles.where((x) => x.id == id).firstOrNull;
    if (v != null) await _saveVehiclePhotos(v, withPhotos);
    draft.addingVehicle = false;
    draft.photosForVehicleId = null;
    notifyListeners();
    return null;
  }

  Future<void> _saveVehiclePhotos(Vehicle v, bool withPhotos) async {
    if (withPhotos) {
      for (final e in draftPhotoBytes.entries) {
        v.photos[e.key] = e.value;
        await LocalFlags.saveBytes('${v.id}_${e.key.name}.jpg', e.value);
      }
    }
    await LocalFlags.setList(_vehicleKey, [
      for (final x in localVehicles) {'id': x.id, 'plate': x.plate, 'kind': x.type.kind.name, 'photos': [for (final a in x.photos.keys) a.name]},
    ]);
  }

  /// A new booking for a saved vehicle: type and plate are filled in, and the
  /// photos from its latest booking are offered on the photos step.
  void pickVehicleForBooking(Vehicle v) {
    startNewBooking();
    draft.type = v.type;
    draft.plate = v.plate;
    draft.pickedVehicleId = v.id;
    draft.lastPhotoBytes = Map.of(v.photos);
    final last = v.photos.isNotEmpty ? null : orders.where((o) => o.vehicle.plate == v.plate && o.customerPhotoPaths.isNotEmpty).firstOrNull;
    if (last != null) {
      draft.lastPhotoPaths = Map.of(last.customerPhotoPaths);
      draft.lastPhotosOrderId = last.id;
    }
    notifyListeners();
  }
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
      final data = await live!.freshProfile();
      if(appAccountRoleState(data,'customer') != AppAccountRoleState.active) throw StateError('Account setup has not finished. Try again.');
      _bindLiveAccount(uid);
      customer = Customer(id: uid, phone: (data['phone'] as String? ?? '').replaceFirst('+91',''), name: appAccountName(data,'customer'));
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

  /// 13 Nov (Aman): waits for the server to sign out before clearing the screen, so the
  /// app resets once (no flicker from a late Firebase sign-out).
  Future<void> signOut() async {
    if (isLive) {
      try {
        await live!.signOut();
      } catch (_) {
        // Signing out on this phone still completes below.
      }
    }
    customer = null;
    vehicles = [];
    notifications = [];
    liveBanner = null;
    // 13 Nov (Aman): logged out → back to the Welcome slides, like a fresh start.
    hasSeenWelcome = false;
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

  /// Deferred integrations are listed in docs/STATUS.md.
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
      await live!.deleteAppAccount('customer');await LocalFlags.setList(_vehicleKey, []);await LocalFlags.setList(_deletedVehiclesKey, []);localVehicles=[];_deletedVehicles={};resetDeletedAccountData();return true;
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
    // Reuse the designed rows; checkout reorders groups and retains all supported methods.
    final upi = !isLive && customer?.phone == samplePhone ? 'UPI · ananya@okhdfc' : 'UPI';
    return [
      PaymentMethod('gpay', 'Google Pay', upi),
      const PaymentMethod('phonepe', 'PhonePe', 'UPI'),
      const PaymentMethod('upi_id', 'Other UPI app', 'Enter UPI ID'),
      const PaymentMethod('card', 'Debit card', 'Credit cards not accepted'),
      if (isLive) const PaymentMethod('netbanking', 'Netbanking', 'Pay using your bank'),
      if (isLive) const PaymentMethod('wallet', 'Other wallets', 'Supported Razorpay wallets'),
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
    purchase.reset();
    draftBookingId = null;
    draftRequestId = newId('draft');
    draftPhotoBytes.clear();
    draftMedia.clear();
    draft = BookingDraft(type: v.type, wash: wash, plate: v.plate, place: (place ?? v.place)?.copy(), isRepeat: true);
    prefetchAvailability();
    notifyListeners();
  }

  /// v2 CU-BOOKINGS: prefill a booking from a past order (or a saved vehicle).
  /// Keeps an already-open Book again for the same id, so returning from a
  /// "Change" step does not reset the customer's edits.
  void openRepeat(String id) {
    if (draft.isRepeat && draft.repeatFrom == id) return;
    final from = order(id);
    final v0 = from?.vehicle ?? myVehicles.where((v) => v.id == id).firstOrNull ?? AppStore.car();
    final place = from?.place ?? v0.place;
    final lastNote = orders.where((o) => o.vehicle.id == v0.id && !o.note.isEmpty).firstOrNull?.note ?? (isLive ? EntryNote() : EntryNote(voiceSeconds: 12));
    startRepeat(Vehicle(v0.id, v0.plate, v0.type, place), place: place, wash: from?.wash);
    draft.repeatFrom = id;
    draft.note = lastNote.copy();
    draft.lastPhotoBytes = Map.of(v0.photos);
    final photoSource = (from != null && from.customerPhotoPaths.isNotEmpty)
        ? from
        : orders.where((o) => o.vehicle.id == v0.id && o.customerPhotoPaths.isNotEmpty).firstOrNull;
    if (photoSource != null) {
      draft.lastPhotoPaths = Map.of(photoSource.customerPhotoPaths);
      draft.lastPhotosOrderId = photoSource.id;
    }
    draft.wash ??= WashKind.wetOutside;
    notifyListeners();
  }

  /// v2 CU-BOOKINGS: start changing one part of a Book again.
  void editRepeat(RepeatEdit part) {
    draft.editing = part;
    notifyListeners();
  }

  /// v2 CU-BOOKINGS: true when [part] was being changed from Book again. The
  /// caller then returns to the Book again summary instead of the next step.
  bool finishRepeatEdit(RepeatEdit part) {
    if (!draft.isRepeat || draft.editing != part) return false;
    draft.editing = null;
    if (part == RepeatEdit.vehicle) {
      final options = WashKind.options(draft.type?.kind);
      final w = draft.wash;
      if (w == null || !options.contains(w) || !w.available) draft.wash = WashKind.wetOutside;
    }
    notifyListeners();
    return true;
  }

  /// v2 CU-LIVE: the customer uploads their society gate pass for this booking.
  /// BACKEND (Ajay): upload to Storage (e.g. `orders/{id}/gatePass.jpg`), set
  /// `entryPass = {status:'received', path, uploadedAt}` and let the assigned
  /// Captain read it. Until then, live mode keeps the photo on this phone only.
  Future<void> uploadGatePass(Order o, Uint8List bytes) async {
    o.gatePassBytes = bytes;
    if (!isLive) o.entryPassReceived = true;
    notifyListeners();
  }

  void startNewBooking() {
    final reward = purchase.premiumRewardId;
    if (reward != null) unawaited(referrals.releasePremiumWash(reward));
    planEditDraft = null;
    purchase.reset();
    draftBookingId = null;
    draftRequestId = newId('draft');
    draftPhotoBytes.clear();
    draftMedia.clear();
    draft = BookingDraft();
    prefetchAvailability();
    notifyListeners();
  }

  /// BACKEND: rpc create_order, then Razorpay checkout.
  CheckoutStage checkoutStage = CheckoutStage.preparing;
  /// The signed-in customer's refund coupons in this payment mode, newest first (raw
  /// Firestore fields: code, availablePaise, status, expiresAt). Empty when signed out.
  Stream<List<Map<String, dynamic>>> refundCouponDocs() {
    if (!isLive || !isLoggedIn || live == null) return Stream.value(const []);
    return live!.db
        .collection('coupons')
        .where('customerId', isEqualTo: live!.uid)
        .where('paymentMode', isEqualTo: testPayments ? 'test' : 'live')
        .orderBy('issuedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((q) => [for (final d in q.docs) d.data()]);
  }

  Future<void> applyCoupon(String code)async{
    if(!isLive||!isLoggedIn||draft.type==null)throw StateError('Log in and choose a vehicle before applying a coupon.');
    final current=draft,account=live!.uid,kind=draft.type!.kind.name;
    final result=await live!.call('previewRefundCoupon',{'code':code,'vehicleKind':kind});
    if(live!.uid!=account||!identical(current,draft)||draft.type?.kind.name!=kind)throw StateError('The booking changed. Apply your coupon again.');
    final applied=result['appliedPaise'];
    if(applied is! int||applied<=0||applied>draft.basePricePaise||result['basePricePaise']!=draft.basePricePaise)throw StateError('The coupon or wash price changed. Review this booking again.');
    final forfeit=result['forfeitPaise']??0;
    if(forfeit is! int||forfeit<0)throw StateError('The unused coupon amount could not be confirmed.');
    draft.couponCode=result['code'] as String;draft.couponAppliedPaise=applied;draft.couponVehicleKind=kind;draft.couponBasePricePaise=draft.basePricePaise;draft.couponForfeitPaise=forfeit;draft.couponForfeitAccepted=false;changed();
  }
  Future<PaymentOutcome>? _checkoutFuture;
  String? _checkoutIdentity;
  bool checkoutCancelled = false;

  void prefetchPaymentResources() {
    if (live != null) unawaited(live!.preloadCheckout());
    // v2 CU-PAY (6 Nov): confirm the parking place while the customer reads Check
    // and pay, so Pay does not wait for that server call before Razorpay opens.
    final p = draft.place;
    if (isLive && captainAreaEnabled && p != null && !p.society.id.startsWith('loc_')) {
      _placeCheck = (p, confirmPlace(p)..ignore());
    }
  }

  (Place, Future<Place>)? _placeCheck;

  void _checkoutStage(CheckoutStage stage) {
    if (_disposed) return;
    checkoutStage = stage;
    changed();
  }

  Future<PaymentOutcome> createOrderAndPay() => _checkoutFuture ??=
      _createOrderAndPay().whenComplete(() => _checkoutFuture = null);

  Future<PaymentOutcome> _createOrderAndPay() async {
    if (isLive) {
      checkoutCancelled = false;
      _checkoutStage(CheckoutStage.preparing);
      final d=draft,s=d.slot;
      var p=d.place;
      // Paying for a booking that already exists (opened from Bookings or a notification).
      final pending = currentOrder;
      if ((d.type == null || p == null || s == null) && pending != null && (pending.status == OrderStatus.pendingPayment || pending.status == OrderStatus.paymentPending)) {
        draftBookingId = pending.id;
        final paid = await live!.pay(pending.id, onStage: _checkoutStage);
        if(paid['checkoutCancelled']==true){checkoutCancelled=true;draftBookingId=null;_checkoutIdentity=null;return PaymentOutcome.failed;}
        try { await _refreshLiveOrder(pending.id); } catch (_) { if(paid['paymentStatus']!='captured')rethrow; }
        return paid['paymentStatus'] == 'captured' && paid['status'] != 'cancelled' ? PaymentOutcome.success : PaymentOutcome.pending;
      }
      if (d.type == null || p == null || s == null) throw StateError('Complete the vehicle, parking and time details first.');
      final blocked = washChoiceBlockedReason;
      if (blocked != null) throw StateError(blocked);
      // The confirmed server location is already saved by the map flow. The
      // booking transaction still resolves it and validates the parking pin.
      if(captainAreaEnabled&&!p.society.id.startsWith('loc_')){
        final pre=_placeCheck;_placeCheck=null;
        Place? done;
        if(pre!=null&&identical(pre.$1,p)){try{done=await pre.$2;}catch(_){done=null;}}
        p=done??await confirmPlace(p);draft.place=p;
      }
      final planCheckout = purchase.chosen && purchase.monthly && d.serviceLevel != null;
      final booking = <String,dynamic>{
        'cancellationPolicyVersion':2,
        'refundCouponPolicyVersion':1,
        'replaceUnpaidCheckout':true,
        'plate': plateKey(d.plate), // v2 CU-VEHICLE: letters and digits, as the server stores it
        'vehicleKind': d.type!.kind.name,
        'washKind': (d.wash ?? WashKind.wetOutside).wireName,
        'societyId': p.society.id,
        'tower': p.tower,
        'floor': p.floor,
        'parking': p.slot,
        'note': d.note.text,
        if(p.latitude!=null&&p.longitude!=null)'vehiclePosition':{'latitude':p.latitude,'longitude':p.longitude},
        'day': '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
        'windows': [for (final w in serverWindowsFor(s) ?? (s.windows.isEmpty ? [(s.startHour, s.endHour)] : s.windows)) {'startHour': w.$1, 'endHour': w.$2}],
        'anyTime': s.anyTime,
        // v2 CU-WASHCHOICE: exact windows and the chosen service, only once the server
        // accepts them (liveConfig switches set by Ajay).
        if (s.minuteWindows.isNotEmpty) 'minuteWindows': [for (final w in s.orderedMinuteWindows) {'startMinute': w.$1, 'endMinute': w.$2}],
        if (washTiersLive && d.serviceLevel != null) 'serviceLevel': d.serviceLevel!.name,
        // v2 CU-CARE: the Captain's job shows these (server copies them onto the job).
        if (d.vehicleProfile != null) 'vehicleProfile': d.vehicleProfile,
        if (d.careRoutine.isNotEmpty) 'careRoutine': d.careRoutine,
        if (washTiersLive && d.coverage != null) 'coverage': d.coverage!.name,
        'useFreeWash': false,
        'useCredit': false,
        'paymentChoice':d.couponAppliedPaise>0?'coupon':'razorpay',
        if(d.couponAppliedPaise>0)'couponCode':d.couponCode,
        if(d.couponAppliedPaise>0)'expectedCouponPaise':d.couponAppliedPaise,
        if(d.couponAppliedPaise>0)'acceptedCouponForfeitPaise':d.couponForfeitAccepted?d.couponForfeitPaise:0,
        'expectedAmountPaise': d.pricePaise,
        // 13 Nov (Aman): a monthly plan pays the whole cycle once; the server splits it into visits.
        if (planCheckout) 'plan': {'frequency': purchase.frequency, 'weekdays': (purchase.weekdays.toList()..sort()), 'start': _isoDay(purchase.start)},
        if (usesCancellationQuote(liveConfig['cancellationPolicy'] is Map ? Map<String,dynamic>.from(liveConfig['cancellationPolicy']) : null)) 'acceptedCancellationPolicy': Map<String, dynamic>.from(liveConfig['cancellationPolicy']),
        if (p.addressKey != null) 'addressKey': p.addressKey,
        'startHour': s.startHour,
        'endHour': s.endHour,
      };
      final identity = jsonEncode(booking);
      if (_checkoutIdentity != identity) {
        draftRequestId = newId('draft');
        draftBookingId = null;
        _checkoutIdentity = identity;
      }
      booking['requestId'] = draftRequestId;
      unawaited(_restoreVehicle(d.plate)); // v2 CU-VEHICLE: a deleted vehicle that is booked again comes back
      final paid = await live!.startCheckout(
        booking: booking,
        uploads: [
          for (final entry in draftMedia.entries.toList())
            (id) => live!.uploadCustomerMedia(id, entry.key, entry.value.bytes, entry.value.contentType, entry.value.seconds),
          for (final entry in draftPhotoBytes.entries.toList())
            (id) => live!.uploadCustomerPhoto(id, entry.key.name, entry.value),
        ],
        onBookingReady: (id) { draftBookingId = id; currentOrderId = id; },
        onStage: _checkoutStage,
      );
      final bookingId = draftBookingId!;
      if (paid['checkoutCancelled'] == true) {
        checkoutCancelled = true;
        _checkoutIdentity = null;
        draftBookingId = null;
        draftRequestId = newId('draft');
        return PaymentOutcome.failed;
      }
      try { await _refreshLiveOrder(bookingId); }
      catch (_) { if(paid['paymentStatus']!='captured')rethrow; }
      final ok = paid['paymentStatus'] == 'captured' && paid['status'] != 'cancelled';
      if (ok && planCheckout) {
        // 13 Nov: the paid plan opens its confirmation (visits are on Bookings).
        purchase.confirmed = true;
        activePlan = purchase.snapshot();
        nextCyclePlan = null;
        planJustPaid = true;
      }
      return ok ? PaymentOutcome.success : PaymentOutcome.pending;
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
    final fresh = await live!.db.doc('orders/$id').get(const GetOptions(source: Source.server));
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

  /// Live cancellation uses the saved server policy and a confirmed quote.
  /// The disconnected design reference retains its original free-wash rule.
  Future<Map<String, dynamic>?> cancellationQuote(String id) async {
    if (!isLive) return null;
    final result = await live!.call('getCancellationQuote', {'orderId': id});
    return result['quote'] is Map ? Map<String, dynamic>.from(result['quote']) : null;
  }
  Future<void> cancel(String id, {String? confirmation}) async {
    if (isLive) {
      final data = {'orderId': id};
      if (confirmation != null) data['confirmation'] = confirmation;
      await live!.call('cancelBooking', data);
      await _refreshLiveOrder(id);
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
      final account=live!.uid;
      if(account==null)throw StateError('Log in to report a problem.');
      await submitProblemReport(orderId:id,ownerId:account,kind:kind.name,note:note,photos:photos,
        load:(id)async=>(await live!.db.doc('orders/$id').get(const GetOptions(source:Source.server))).data(),
        upload:live!.uploadProblemPhoto,
        submit:(data)async{await live!.call('reportWashProblem',data);});
      if(live!.uid!=account)return;
      _update(id,(o){o.status=OrderStatus.disputed;o.dispute??=Dispute(ref:'SUP-${id.toUpperCase()}',kind:kind,note:note,createdAt:DateTime.now(),outcome:kind==ProblemKind.damage?DisputeOutcome.damagePriority:DisputeOutcome.underReview);});
      try { await _refreshLiveOrder(id); } catch (_) { /* Server acknowledged; snapshots retry the display refresh. */ }
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

  // MARK: v2 SH-NOTIFY — ask once after install
  /// True once the first-time notification screen was answered (this device).
  bool notifyAsked = false;

  Future<Permission> pushStatus() async => isLive && live!.supportsPush ? await live!.pushPermission() : Device.notificationPermission;

  /// Whether to show the one-time ask now. Also saves a pending "yes" to the
  /// account once the customer is signed in.
  Future<bool> shouldAskNotificationsFirst() async {
    notifyAsked = await LocalFlags.get('notifyAsked');
    await syncWantedNotifications();
    if (notifyAsked) return false;
    if (await pushStatus() == Permission.allowed) {
      notifyAsked = true;
      await LocalFlags.set('notifyAsked', true);
      return false;
    }
    return true;
  }

  Future<void> answerNotificationsFirst({required bool yes, bool denied = false}) async {
    notifyAsked = true;
    await LocalFlags.set('notifyAsked', true);
    if (!yes) return;
    if (denied) {
      await LocalFlags.set('pushWanted', true);
      await Device.openSettings();
      return;
    }
    if (isLoggedIn) {
      setNotifications(true);
      return;
    }
    await LocalFlags.set('pushWanted', true);
    if (isLive && live!.supportsPush) {
      final p = await live!.requestPushPermission();
      set(() => systemPermission = p);
    } else {
      requestSystemPermission();
    }
  }

  /// A "yes" given before sign-in is saved to the account after sign-in.
  Future<void> syncWantedNotifications() async {
    if (!isLoggedIn || notificationsOn) return;
    if (!await LocalFlags.get('pushWanted')) return;
    if (await pushStatus() != Permission.allowed) return;
    await LocalFlags.set('pushWanted', false);
    setNotifications(true);
  }
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
    case NotificationKind.refundCoupon:
      router.go(N.coupons);return null;
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

String _isoDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
