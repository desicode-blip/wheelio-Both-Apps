// Captain app state with sample data from the designs (Raju, TS 09 EA 4521).
// Ported from apps/ios/Captain/Data/CaptainStore.swift and WNotifications.swift.
// BACKEND: when the real services are connected these methods call the captain API
// (backend/API-CONTRACT.md); screens don't change.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

/// Captain app language. Captains pick it on the first screen (W01).
enum Lang { en, hi, te }

/// What the owner booked (mirrors the customer app's wash choices).
enum WashType {
  dryDusting,
  wetOutside,
  wetOutsideDryInside;

  bool get water => this != dryDusting;
  bool get inside => this == wetOutsideDryInside;
}

enum JobStatus { now, next, done }

class Job {
  Job({
    required this.id, required this.plate, required this.type, required this.isBike, required this.pay, required this.tower, required this.floor,
    required this.slot, required this.window, required this.time, this.distance = '600 m', this.status = JobStatus.next, this.reachBy = '8:40 AM',
    this.finishBy = '8:55 AM', this.owner = 'Ananya', this.society = 'My Home Avatar', this.wash = WashType.wetOutside, this.area = 'Narsingi',
    this.windows = const [], this.flexible = false, this.day = 0, this.typedAddress = false, this.pincode = '', this.cancelled = false, this.tripPaid = false,
  });
  final String id;
  final String plate;
  final String type;
  final bool isBike;
  final int pay;
  final String tower;
  final String floor;
  final String slot;
  final String window;
  final String time;
  final String distance;
  JobStatus status;
  final String reachBy;
  final String finishBy;
  final String owner;
  final String society;
  final WashType wash;
  final String area;

  /// The owner picked several windows ("10–12", "16–18"). [window] is the one the plan uses.
  final List<String> windows;

  /// The owner said "any time". The app fits it into the captain's plan ([window] is that choice)
  /// and the job carries a "Flexible" tag.
  final bool flexible;

  /// 0 = today, 1 = tomorrow… Later-day jobs stay in the Jobs tab until their day starts.
  final int day;

  /// The owner typed the address by hand (not from our list of societies).
  final bool typedAddress;
  final String pincode;

  /// The owner cancelled. It stays in the plan, struck through.
  bool cancelled;

  /// Cancelled after the captain set off: they get the trip fee.
  bool tripPaid;

  Job copyWith({JobStatus? status, String? window, String? time, int? day}) => Job(
      id: id, plate: plate, type: type, isBike: isBike, pay: pay, tower: tower, floor: floor, slot: slot, window: window ?? this.window, time: time ?? this.time,
      distance: distance, status: status ?? this.status, reachBy: reachBy, finishBy: finishBy, owner: owner, society: society, wash: wash, area: area,
      windows: windows, flexible: flexible, day: day ?? this.day, typedAddress: typedAddress, pincode: pincode, cancelled: cancelled, tripPaid: tripPaid);

  /// What the owner chose, for cards: "8–10", "10–12, 16–18" or the any-time range.
  String get whenLabel => windows.length > 1 ? windows.join(', ') : window;

  /// "Tower 3 · Floor B2 · Slot 41"
  String get spot => [tower, 'Floor $floor', if (slot.isNotEmpty) 'Slot $slot'].join(' · ');

  /// Full address for the job card.
  String get fullAddress => '$spot, $society, $area, Hyderabad${pincode.isEmpty ? '' : ' $pincode'}';

  /// Distance in km from the "600 m" / "1.2 km" label.
  double get km {
    final n = double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return distance.contains('km') ? n : n / 1000;
  }
}

/// Gated societies the captain can choose to work in (sample data).
class Society {
  const Society(this.name, this.area, this.km);
  final String name;
  final String area;
  final double km;

  static const all = [
    Society('My Home Avatar', 'Narsingi', 0.6),
    Society('Lanco Hills', 'Manikonda', 2.1),
    Society('Aparna Sarovar Zenith', 'Nallagandla', 3.2),
    Society('Prestige High Fields', 'Gachibowli', 4.5),
    Society('SMR Vinay Iconia', 'Kondapur', 6.8),
  ];

  /// Demo: where the captain's phone is right now.
  static const current = Society('My Home Avatar', 'Narsingi', 0.6);
  static const places = ['Narsingi', 'Manikonda', 'Nallagandla', 'Gachibowli', 'Kondapur', 'Kokapet', 'Madhapur', 'Financial District'];
}

/// Which jobs the captain wants to be offered.
enum WorkMode { all, radius, societies, place }

enum KycStep { aadhaar, photo, bank, training, quiz }

enum KycState { todo, done, problem }

List<Job> sampleQueue() => [
      Job(id: 'j1', plate: 'TS 09 EA 4521', type: 'Hatchback', isBike: false, pay: 116, tower: 'Tower 3', floor: 'B2', slot: '41', window: '8–10', time: '8:30', status: JobStatus.now),
      Job(id: 'j2', plate: 'TS 09 HB 0731', type: 'Scooter', isBike: true, pay: 54, tower: 'Tower 3', floor: 'B1', slot: '', window: '9:30–11:30', time: '9:30'),
      Job(id: 'j3', plate: 'TS 08 GK 2210', type: 'Sedan', isBike: false, pay: 140, tower: 'Tower 1', floor: 'B1', slot: '', window: '6–8', time: '7:40', status: JobStatus.done, society: 'Lanco Hills', area: 'Manikonda'),
      Job(id: 'j4', plate: 'AP 28 BQ 9911', type: 'Scooter', isBike: true, pay: 54, tower: 'Tower 1', floor: 'Open', slot: '', window: '6–8', time: '7:05', status: JobStatus.done, society: 'Lanco Hills', wash: WashType.dryDusting, area: 'Manikonda'),
      // Owner cancelled before the captain set off: struck through in the plan.
      Job(id: 'j5', plate: 'TS 07 GH 5512', type: 'Sedan', isBike: false, pay: 140, tower: 'Tower 4', floor: 'B2', slot: '9', window: '10–12', time: '10:30', cancelled: true),
      // Owner said "any time": fitted next to the other My Home Avatar jobs, tagged Flexible.
      Job(id: 'j6', plate: 'TS 09 KL 7788', type: 'Hatchback', isBike: false, pay: 116, tower: 'Tower 3', floor: 'B2', slot: '18', window: '12–14', time: '12:00', flexible: true),
      // Tomorrow: shows in the Jobs tab only, until tomorrow starts.
      Job(id: 'j7', plate: 'TS 09 MN 4410', type: 'SUV', isBike: false, pay: 140, tower: 'Tower 2', floor: 'B1', slot: '7', window: '8–10', time: '8:00', day: 1, windows: ['8–10', '16–18']),
    ];

/// Other jobs that can ring while an alert is already open (demo).
final offerPool = [
  Job(id: 'o1', plate: 'TS 08 HK 1207', type: 'Hatchback', isBike: false, pay: 116, tower: 'Tower 3', floor: 'B2', slot: '27', window: '8–10', time: '8:40', owner: 'Ravi'),
  Job(id: 'o2', plate: 'TS 07 FK 3390', type: 'SUV', isBike: false, pay: 140, tower: 'Tower 2', floor: 'Open', slot: '12', window: '8–10', time: '8:45', distance: '2.1 km', owner: 'Kiran', society: 'Lanco Hills', wash: WashType.wetOutsideDryInside, area: 'Manikonda'),
  Job(id: 'o3', plate: 'TS 10 MB 6614', type: 'Scooter', isBike: true, pay: 54, tower: 'Tower 5', floor: 'B1', slot: '', window: '8–10', time: '9:10', distance: '3.2 km', owner: 'Sneha', society: 'Aparna Sarovar Zenith', wash: WashType.dryDusting, area: 'Nallagandla'),
  // Any time today; the app picks a window when it's accepted.
  Job(id: 'o4', plate: 'TS 09 PQ 1188', type: 'Hatchback', isBike: false, pay: 116, tower: 'Tower 1', floor: 'B1', slot: '30', window: '6–18', time: '6:00', owner: 'Meera', flexible: true),
  // Address typed by hand by the owner.
  Job(id: 'o5', plate: 'TS 11 RS 2045', type: 'Sedan', isBike: false, pay: 140, tower: 'Block B', floor: 'Ground', slot: '', window: '10–12', time: '10:00', distance: '1.4 km', owner: 'Farhan',
      society: 'Prestige Lakeside', area: 'Kokapet', pincode: '500075', typedAddress: true, windows: ['10–12', '16–18']),
];

/// Two-hour windows the plan is built from.
const planWindows = ['6–8', '8–10', '10–12', '12–14', '14–16', '16–18'];

/// "When I work": one or more time ranges the captain picks with sliders (minutes from
/// midnight, 30-minute steps), e.g. 9:00–10:00 and 13:00–19:00 with a break in between.
/// Only a preference for which jobs ring; the captain still decides on each job.
typedef WorkSlot = (int start, int end);

/// Slider range for working times.
const workDayStart = 4 * 60, workDayEnd = 22 * 60;

/// The server's working windows today (hours). A captain's slots are saved as every window
/// they touch, so he is offered as many jobs as possible ("lump sum", Aman 27 Oct).
const serverWorkWindows = [(6, 10), (10, 14), (14, 18)];

List<(int, int)> serverWindowsFor(List<WorkSlot> slots) => slots.isEmpty
    ? serverWorkWindows
    : [for (final w in serverWorkWindows) if (slots.any((s) => s.$1 < w.$2 * 60 && s.$2 > w.$1 * 60)) w];

/// Sorted, with overlapping or touching ranges merged.
List<WorkSlot> mergeSlots(List<WorkSlot> slots) {
  final sorted = [...slots]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <WorkSlot>[];
  for (final s in sorted) {
    if (s.$2 <= s.$1) continue;
    if (out.isNotEmpty && s.$1 <= out.last.$2) {
      out.last = (out.last.$1, s.$2 > out.last.$2 ? s.$2 : out.last.$2);
    } else {
      out.add(s);
    }
  }
  return out;
}

/// "9 AM", "1:30 PM".
String fmtClock(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
}

int _hour(String s) => int.tryParse(s.split(':').first) ?? 0;
(int, int) windowHours(String w) {
  final p = w.split('–');
  return p.length == 2 ? (_hour(p[0]), _hour(p[1])) : (0, 24);
}

// MARK: Routes

enum HelpTopic { money, job, rating, app }

/// One route per captain screen ID (W01–W57).
enum N {
  welcome, signUp, otp, steps, aadhaar, selfie, bank, training, video, quiz, quizResult, rules, workSetup, jobAlert, jobMissed,
  goToVehicle, gateProblem, cantFind, ownerCancelled, faceCheck, beforePhotos, camera, photoDark, washing, afterPhotos, aiCheck, uploading,
  jobDone, payoutDetail, payoutHeld, level, probationExtended, refresher, blocked, help, notifications, notificationSettings, changePhone,
  editUPI, noShowCancelled, workArea, ownerNote, helpFlow, gallery,
}

class R {
  const R(this.n, {this.flag = false, this.index = 0, this.topic});
  final N n;

  /// login / problem / unclear / passed / batched / after / late, depending on the screen.
  final bool flag;

  /// Video index or camera side.
  final int index;
  final HelpTopic? topic;
}

class WRouterC extends WRouter<R> {
  /// Index into the gallery while stepping through screens (demo only).
  int? tour;
  Lang? tourLang;

  bool isAt(N n) => last?.n == n;
  void go(N n) => push(R(n));
  void home() {
    path = [];
    tab = 0;
  }

  void setTour(int? i, Lang? l) {
    tour = i;
    tourLang = l;
    notifyListeners();
  }
}

// MARK: Notifications

enum WNotifCategory { jobs, money, level, account }

enum WNotifKind {
  newJob, jobTaken, ownerCancelled, ownerCancelledEarly, gatePassReady, runningLate, slotEnded, noShowPenalty, windowOpen, finishSoon, washApproved, problemReported, payoutSent, upiChanged,
  levelUp, probation, blocked, phoneChanged, vehicleHelpAnswered;

  WNotifCategory get category => switch (this) {
        washApproved || problemReported || payoutSent || upiChanged => WNotifCategory.money,
        levelUp || probation => WNotifCategory.level,
        blocked || phoneChanged => WNotifCategory.account,
        _ => WNotifCategory.jobs,
      };

  WIcon get icon => switch (this) {
        newJob => WIcon.bell,
        jobTaken || runningLate => WIcon.clock,
        windowOpen || finishSoon => WIcon.timer,
        ownerCancelled || ownerCancelledEarly => WIcon.close,
        gatePassReady => WIcon.door,
        vehicleHelpAnswered => WIcon.location,
        slotEnded => WIcon.warning,
        noShowPenalty || blocked => WIcon.ban,
        washApproved => WIcon.check,
        problemReported || phoneChanged => WIcon.lock,
        payoutSent || upiChanged => WIcon.rupee,
        levelUp => WIcon.star,
        probation => WIcon.calendar,
      };

  Tone get tone => switch (this) {
        slotEnded || noShowPenalty || blocked || phoneChanged => Tone.error,
        runningLate || finishSoon || problemReported || probation || jobTaken => Tone.wait,
        washApproved || payoutSent || levelUp || gatePassReady => Tone.ok,
        _ => Tone.info,
      };
}

class WNotif {
  WNotif({required this.id, required this.kind, required this.date, this.jobId, this.payoutId, this.plate = '', this.amount = 0, this.read = false});
  final String id;
  final WNotifKind kind;
  final DateTime date;
  final String? jobId;
  final String? payoutId;
  final String plate;
  final int amount;
  bool read;
}

class WNotifPrefs {
  bool soundOn = true;
  DateTime? mutedUntil;
  bool quietHours = false;
  Set<WNotifCategory> off = {};
  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
  static bool get inQuietHours {
    final h = DateTime.now().hour;
    return h >= 22 || h < 7;
  }
}

// MARK: Store

class CaptainStore extends ChangeNotifier {
  /// [live] is the Firebase backend; null runs the designed sample app.
  CaptainStore({this.live}) {
    if (live != null) _startLive();
  }

  Lang lang = Lang.en;
  String phone = '9876543210';
  String name = 'Raju Yadav';
  String upi = 'raju.yadav@ybl';
  double rating = 4.8;

  /// KYC done and approved: can accept jobs.
  bool signedUp = false;

  /// Past the welcome page: browsing the app as a guest.
  bool exploring = false;

  /// Name and number verified with a code (light sign-up).
  bool registered = false;

  /// Go online right after the light sign-up finishes.
  bool onlineAfterSignUp = false;

  /// KYC was started by tapping Accept on a job.
  bool kycFromJob = false;

  /// The "save your spot" nudge was shown once.
  bool nudgeShown = false;

  Map<KycStep, KycState> steps = {};
  int videosWatched = 1;

  bool online = false;
  int levelDay = 2;
  int jobsToday = 6;
  int jobLimit = 8;
  int earnedToday = 1040;
  int approvedToday = 820;
  int waitingToday = 220;

  // Demo switches (Screens gallery)
  bool lowSignal = false;
  bool batchedAlert = false;
  bool lateWash = false;
  bool darkPhoto = false;
  bool aiFlag = true;

  Uint8List? profilePhoto;
  String pendingPhone = '';
  String pendingUPI = '';

  List<WNotif> notifications = [];
  bool notificationsOn = true;
  WNotifPrefs notifPrefs = WNotifPrefs();
  Permission systemPermission = Permission.unknown;
  WNotif? liveBanner;
  String? toast;

  // No-show (accepted but didn't reach / update the job)
  bool noShowDemo = false;
  bool jobLate = false;
  bool slotEnded = false;
  bool noShowCancelled = false;
  String noShowPlate = '';

  List<Job> queue = sampleQueue();

  /// Photos taken for the current job (before / after), 4 sides each.
  Set<int> beforeDone = {};
  Set<int> afterDone = {};

  // Where I work
  WorkMode workMode = WorkMode.all;
  int radiusKm = 3;
  Set<String> chosenSocieties = {};
  String workPlace = 'Narsingi';

  /// "When I work": empty means any time. Only a preference for which jobs ring.
  List<WorkSlot> workSlots = [];

  /// "9 AM–10 AM, 1 PM–7 PM" or "Any time".
  String get workSlotsLabel => workSlots.isEmpty
      ? t('Any time', 'कभी भी', 'ఎప్పుడైనా')
      : workSlots.map((s) => '${fmtClock(s.$1)}–${fmtClock(s.$2)}').join(', ');

  /// How many more jobs ring while the alert is open (demo; 0 = single job).
  int extraOffers = 2;

  /// Set when the captain taps edit next to the number on the code screen.
  bool editPhoneRequested = false;

  // Plan clock (demo)
  /// BACKEND: use the real clock. For the demo the day starts at 9:29:20 AM, so the current job
  /// is ~30 min from the end of its window and the next job's window opens in ~40 s.
  final DateTime planRealStart = DateTime.now();
  int planSkipSeconds = 0;
  DateTime get planNow => isLive ? DateTime.now().add(Duration(seconds: planSkipSeconds)) : startOfDay(DateTime.now())
      .add(const Duration(hours: 9, minutes: 29, seconds: 20))
      .add(DateTime.now().difference(planRealStart))
      .add(Duration(seconds: planSkipSeconds));

  /// Plan alerts already sent ("open-j2", "soon-j1", "late-j1").
  Set<String> planAlerts = {};

  /// The owner's voice note was played for the current job.
  bool ownerNoteHeard = false;
  int acceptedToday = 0;
  WTask? _noShowJob;

  void set(VoidCallback f) {
    if(_disposed)return;
    final before = isLive ? jsonEncode(_preferences()) : '';
    f();
    notifyListeners();
    if (isLive && before != jsonEncode(_preferences())) _savePreferences();
  }

  void changed() {if(!_disposed)notifyListeners();}

  String get firstName => name.split(' ').where((p) => p.isNotEmpty).firstOrNull ?? (isLive ? '' : 'Raju');
  bool get canGoOnline => isLive ? signedUp : registered;
  bool get canAccept => signedUp;
  Job get current => (isLive ? queue.where((j) => j.id == _workflowOrderId).firstOrNull : null) ?? queue.where((j) => j.status == JobStatus.now).firstOrNull ?? (isLive ? Job(id:'',plate:'',type:'',isBike:false,pay:0,tower:'',floor:'',slot:'',window:'',time:'',owner:'',society:'',area:'',distance:'',reachBy:'',finishBy:'') : sampleQueue()[0]);
  List<Job> get upNext => queue.where((j) => j.status != JobStatus.done).toList();
  KycStep? get nextStep => KycStep.values.where((s) => steps[s] != KycState.done).firstOrNull;
  int get stepsDone => steps.values.where((s) => s == KycState.done).length;

  /// KYC as the captain sees it: Aadhaar, photo, bank, onboarding (videos + quiz).
  int get kycStagesDone =>
      [steps[KycStep.aadhaar], steps[KycStep.photo], steps[KycStep.bank]].where((s) => s == KycState.done).length +
      (steps[KycStep.training] == KycState.done && steps[KycStep.quiz] == KycState.done ? 1 : 0);
  String get langName => switch (lang) { Lang.hi => 'हिन्दी', Lang.te => 'తెలుగు', Lang.en => 'English' };

  /// Inline translation: English, Hindi, Telugu.
  String t(String en, String hi, String te) => switch (lang) { Lang.hi => hi, Lang.te => te, Lang.en => en };

  /// Light sign-up finished (name + number + code).
  void finishRegistration() {
    registered = true;
    exploring = true;
    if (notifications.isEmpty && !isLive) seedNotifications();
    if (onlineAfterSignUp && !isLive) online = true;
    onlineAfterSignUp = false;
    toast = t('Welcome, $firstName!', 'स्वागत है, $firstName!', 'స్వాగతం, $firstName!');
    notifyListeners();
  }

  /// KYC approved: jobs can be accepted now.
  // MARK: Review after "I agree" (27 Oct: the W13 review-call screen was removed)
  // After the first-time work profile the captain lands on Home. Approved: online straight away.
  // Not yet: the "Your profile is under review" pop-up; its call option shows after 30 minutes.

  /// Automatic review is expected within this time; then the captain may call the team.
  static const reviewWait = Duration(minutes: 30);
  DateTime? _reviewStartedLocal;

  /// Set when the captain agrees to the rules; going online happens once approval arrives.
  bool awaitingApproval = false;

  /// Home shows the under-review pop-up once when this is set.
  bool reviewNoticePending = false;

  /// First-time work profile closing into Home's "Jobs from" chip (animation running).
  bool workSetupLanding = false;

  /// The "Jobs from" chip glows right after the work profile lands in it.
  bool chipGlow = false;

  DateTime? get reviewStartedAt => (isLive ? _date(liveCaptain['submittedAt']) : null) ?? _reviewStartedLocal;

  /// Application sent (or agreed to, when testing) and not yet approved.
  bool get underReview => registered && !signedUp && (reviewStartedAt != null || kycStatus == 'underReview');

  /// Time left before the call option shows (zero once 30 minutes have passed).
  Duration get callUnlocksIn {
    final start = reviewStartedAt;
    if (start == null) return Duration.zero;
    final left = start.add(reviewWait).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void startReview() => set(() {
        _reviewStartedLocal ??= DateTime.now();
        awaitingApproval = true;
      });

  /// Approved: go online without the captain having to tap anything.
  void goOnlineAfterApproval() {
    if (isLive && liveCaptain['approved'] != true) return;
    awaitingApproval = false;
    if (online) return;
    set(() => online = true);
    if (isLive) liveSetOnline(true).catchError((Object _) => set(() => online = false));
  }

  void testSkipReview() {
    if (isLive) return;
    finishKyc();
    goOnlineAfterApproval();
  }

  void finishKyc() => set(() {
        signedUp = true;
        registered = true;
        exploring = true;
        kycFromJob = false;
        levelDay = 1;
        jobsToday = 0;
        jobLimit = 2;
        earnedToday = 0;
        approvedToday = 0;
        waitingToday = 0;
      });

  void logOut() {
    if (isLive) liveSignOut().catchError((Object e) => set(() => toast = backendError(e)));
    _logOut();
  }

  void _logOut() => set(() {
        _reviewStartedLocal = null;
        workSetupLanding = false;
        awaitingApproval = false;
        reviewNoticePending = false;
        testSkipped.clear();
        signedUp = false;
        registered = false;
        exploring = false;
        online = false;
        notifications = [];
      });

  /// Fits the captain's area and, unless the job is flexible, their working hours.
  bool wantsJob(Job j) => _wantsArea(j) && (j.flexible || workSlots.isEmpty || _fitsTime(j));

  bool _fitsTime(Job j) => (j.windows.isEmpty ? [j.window] : j.windows).any((w) {
        final (a, b) = windowHours(w);
        return workSlots.any((t) => a * 60 < t.$2 && b * 60 > t.$1);
      });

  /// Jobs for today's plan (later days wait in the Jobs tab).
  List<Job> get todayJobs => queue.where((j) => j.day == 0).toList();
  List<Job> get laterJobs => queue.where((j) => j.day > 0).toList();

  /// "Any time" job: pick the window next to the captain's other jobs in the same building
  /// (least walking), else the first free window still ahead today.
  String fitFlexible(Job j) {
    final now = planNow.hour;
    final ahead = planWindows.where((w) => windowHours(w).$2 > now + 1).toList();
    final taken = {for (final q in todayJobs) if (!q.cancelled && q.status != JobStatus.done) q.window};
    final free = ahead.where((w) => !taken.contains(w)).toList();
    final pool = free.isEmpty ? ahead : free;
    if (pool.isEmpty) return planWindows.last;
    final mates = todayJobs.where((q) => q.society == j.society && !q.cancelled && q.status != JobStatus.done).map((q) => windowHours(q.window).$1).toList();
    if (mates.isEmpty) return pool.first;
    int gap(String w) => mates.map((m) => (windowHours(w).$1 - m).abs()).reduce((a, b) => a < b ? a : b);
    return (pool..sort((a, b) => gap(a).compareTo(gap(b)))).first;
  }

  /// The owner cancelled. If the captain had set off, they get the trip fee.
  /// BACKEND: comes from the server with the cancellation.
  void ownerCancels(String id, {required bool trip}) {
    final j = queue.where((x) => x.id == id).firstOrNull;
    if (j == null || j.cancelled) return;
    final wasNow = j.status == JobStatus.now;
    j.cancelled = true;
    j.tripPaid = trip;
    if (wasNow) {
      j.status = JobStatus.next;
      ownerNoteHeard = false;
      queue.where((x) => x.status == JobStatus.next && !x.cancelled && x.day == 0).firstOrNull?.status = JobStatus.now;
    }
    notify(trip ? WNotifKind.ownerCancelled : WNotifKind.ownerCancelledEarly, job: j);
    notifyListeners();
  }

  bool _wantsArea(Job j) => switch (workMode) {
        WorkMode.all => true,
        WorkMode.radius => j.km <= radiusKm,
        WorkMode.societies => chosenSocieties.isEmpty || chosenSocieties.contains(j.society),
        WorkMode.place => j.area == workPlace,
      };

  String get workSummary {
    switch (workMode) {
      case WorkMode.all:
        return t('All jobs', 'सभी काम', 'అన్ని పనులు');
      case WorkMode.radius:
        return t('Within $radiusKm km', '$radiusKm km के अंदर', '$radiusKm కి.మీ లోపు');
      case WorkMode.societies:
        final list = societyChoices.map((s) => s.name).where(chosenSocieties.contains).toList();
        if (list.isEmpty) return t('All jobs', 'सभी काम', 'అన్ని పనులు');
        return list.length > 1 ? '${list.first} +${list.length - 1}' : list.first;
      case WorkMode.place:
        return workPlace;
    }
  }

  /// Accept a job from the alert stack: it joins today's jobs (now if nothing is in progress,
  /// otherwise next in line) and shows on Home.
  void acceptOffer(Job j) {
    if (queue.any((x) => x.id == j.id)) return;
    if (j.flexible) {
      // Any time: the app picks the window that fits the plan best.
      final w = fitFlexible(j);
      j = j.copyWith(window: w, time: '${windowHours(w).$1}:00');
    }
    final later = j.day > 0;
    final nj = j.copyWith(status: later || queue.any((x) => x.status == JobStatus.now && x.day == 0) ? JobStatus.next : JobStatus.now);
    final at = queue.lastIndexWhere((x) => x.status != JobStatus.done) + 1;
    queue.insert(at, nj);
    acceptedToday += 1;
    notifyListeners();
  }

  void complete(KycStep s) => set(() => steps[s] = KycState.done);

  /// Sample-app shortcuts cannot complete steps in a Firebase session.
  final Set<KycStep> testSkipped = {};
  void testSkipStep(KycStep s) {
    if (isLive) return;
    set(() {
        testSkipped.add(s);
        steps[s] = KycState.done;
        if (s == KycStep.training && videosWatched < 3) videosWatched = 3;
    });
  }

  void resetJob() {
    beforeDone = {};
    afterDone = {};
    notifyListeners();
  }

  /// The captain picked a different job to do first: it becomes the current one.
  void startJob(String id) {
    if (isLive) {
      final j=queue.where((j)=>j.id==id&&!j.cancelled).firstOrNull;
      if(j==null) return;
      _workflowOrderId=id;
      _rebuildQueue(); changed(); return;
    }
    final j = queue.where((x) => x.id == id).firstOrNull;
    if (j == null || j.status != JobStatus.next) return;
    queue.where((x) => x.status == JobStatus.now).firstOrNull?.status = JobStatus.next;
    j.status = JobStatus.now;
    notifyListeners();
  }

  void finishJob() {
    if (isLive) { _workflowOrderId=null; shots.clear(); ownerNoteHeard=false; _rebuildQueue(); changed(); return; }
    ownerNoteHeard = false;
    final j = queue.where((x) => x.status == JobStatus.now).firstOrNull;
    if (j != null) {
      j.status = JobStatus.done;
      jobsToday += 1;
      earnedToday += j.pay;
      waitingToday += j.pay;
      queue.where((x) => x.status == JobStatus.next).firstOrNull?.status = JobStatus.now;
    }
    resetJob();
  }

  /// BACKEND: send a code to the new number / verify it.
  Future<void> requestPhoneChange(String p) async {
    if (isLive) { await _call(()=>live!.requestPhoneChange(p)); pendingPhone=p; return; }
    await sleepMs(700);
    pendingPhone = p;
  }

  Future<bool> confirmPhoneChange(String code) async {
    if(isLive){try{await _call(()=>live!.confirmPhoneChange(code));pendingPhone='';return true;}catch(_){return false;}}
    await sleepMs(600);
    if (code != '123456') return false;
    phone = pendingPhone;
    notify(WNotifKind.phoneChanged, deliver: false);
    return true;
  }

  /// BACKEND: payout UPI changes need a code to the registered phone first.
  Future<void> requestUPIChange(String u) async {
    if(isLive){await _call(()=>live!.requestAccountVerification());pendingUPI=u.trim();return;}
    await sleepMs(700);
    pendingUPI = u.toLowerCase();
  }

  Future<bool> confirmUPIChange(String code) async {
    if(isLive){try{await _call(()=>live!.confirmAccountVerification(code));await liveSavePayout(upi:pendingUPI);return true;}catch(_){return false;}}
    await sleepMs(600);
    if (code != '123456') return false;
    upi = pendingUPI;
    notify(WNotifKind.upiChanged, deliver: false);
    return true;
  }

  void resetDemo() {
    captainArrived();
    extraOffers = 2;
    acceptedToday = 0;
    workMode = WorkMode.all;
    chosenSocieties = {};
    workSlots = [];
    kycFromJob = false;
    onlineAfterSignUp = false;
    noShowCancelled = false;
    noShowDemo = false;
    notificationsOn = true;
    liveBanner = null;
    toast = null;
    lowSignal = false;
    batchedAlert = false;
    lateWash = false;
    darkPhoto = false;
    aiFlag = true;
    queue = sampleQueue();
    beforeDone = {};
    afterDone = {};
    online = false;
    jobsToday = 6;
    jobLimit = 8;
    earnedToday = 1040;
    waitingToday = 220;
    levelDay = 2;
    notifyListeners();
  }

  // MARK: Notification copy (English · Hindi · Telugu)

  String title(WNotif n) {
    final rs = Fmt.rupees(n.amount);
    return switch (n.kind) {
      WNotifKind.newJob => t('New job: $rs', 'नया काम: $rs', 'కొత్త పని: $rs'),
      WNotifKind.jobTaken => t('Job went to someone else', 'काम किसी और को मिल गया', 'పని వేరొకరికి వెళ్ళింది'),
      WNotifKind.ownerCancelled || WNotifKind.ownerCancelledEarly => t('Owner cancelled ${n.plate}', 'मालिक ने ${n.plate} रद्द किया', 'యజమాని ${n.plate} రద్దు చేశారు'),
      WNotifKind.gatePassReady => t('Gate pass is ready', 'गेट पास तैयार है', 'గేట్ పాస్ సిద్ధం'),
      WNotifKind.vehicleHelpAnswered => 'Your owner replied',
      WNotifKind.runningLate => t('You’re late for ${n.plate}', 'आप ${n.plate} के लिए लेट हैं', '${n.plate} కి మీరు ఆలస్యం'),
      WNotifKind.windowOpen => t('Time to start: ${n.plate}', 'शुरू करने का समय: ${n.plate}', 'మొదలుపెట్టే సమయం: ${n.plate}'),
      WNotifKind.finishSoon => t('25 min left for ${n.plate}', '${n.plate} के लिए 25 मिनट बचे', '${n.plate} కి 25 నిమిషాలే ఉన్నాయి'),
      WNotifKind.slotEnded => t('Slot is over. Update the job', 'समय खत्म। काम अपडेट करें', 'సమయం ముగిసింది. పని అప్‌డేట్ చేయండి'),
      WNotifKind.noShowPenalty => t('Job cancelled: penalty applied', 'काम रद्द: जुर्माना लगा', 'పని రద్దు: జరిమానా విధించబడింది'),
      WNotifKind.washApproved => t('Owner approved your wash', 'मालिक ने धुलाई मंज़ूर की', 'యజమాని మీ వాష్ ఆమోదించారు'),
      WNotifKind.problemReported => t('Money on hold: $rs', 'पैसे रोके गए: $rs', 'డబ్బు నిలిపివేయబడింది: $rs'),
      WNotifKind.payoutSent => t('$rs sent to your UPI', '$rs आपके UPI पर भेजे गए', '$rs మీ UPI కి పంపబడింది'),
      WNotifKind.upiChanged => t('Payout UPI changed', 'पेमेंट UPI बदला गया', 'చెల్లింపు UPI మార్చబడింది'),
      WNotifKind.levelUp => t('Day 2 done. Now 4 jobs a day', 'दिन 2 पूरा। अब रोज़ 4 काम', 'రోజు 2 పూర్తి. ఇప్పుడు రోజుకు 4 పనులు'),
      WNotifKind.probation => t('1 more day at 4 jobs', '4 कामों पर 1 दिन और', '4 పనులతో ఇంకో రోజు'),
      WNotifKind.blocked => t('You can’t take jobs now', 'आप अभी काम नहीं ले सकते', 'మీరు ఇప్పుడు పనులు తీసుకోలేరు'),
      WNotifKind.phoneChanged => t('Your phone number was changed', 'आपका फ़ोन नंबर बदला गया', 'మీ ఫోన్ నంబర్ మార్చబడింది'),
    };
  }

  String body(WNotif n) {
    final rs = Fmt.rupees(n.amount);
    return switch (n.kind) {
      WNotifKind.newJob => '${n.plate} · ${t('Tap to see', 'देखने के लिए दबाएं', 'చూడటానికి నొక్కండి')}',
      WNotifKind.jobTaken => t('Keep the app open. Next job comes soon.', 'ऐप खुला रखें। अगला काम जल्दी आएगा।', 'యాప్ తెరిచి ఉంచండి. తదుపరి పని త్వరలో వస్తుంది.'),
      WNotifKind.ownerCancelled => t('You get ₹[CANCELLATION FEE] for the trip.', 'सफ़र के ₹[CANCELLATION FEE] मिलेंगे।', 'ప్రయాణానికి ₹[CANCELLATION FEE] వస్తుంది.'),
      WNotifKind.ownerCancelledEarly => t('It’s off your plan. Nothing to do.', 'यह आपके प्लान से हट गया। कुछ नहीं करना है।', 'ఇది మీ ప్లాన్ నుండి తీసేశాం. ఏమీ చేయనక్కర్లేదు.'),
      WNotifKind.gatePassReady => t('Show it at the gate for ${n.plate}.', '${n.plate} के लिए गेट पर दिखाएं।', '${n.plate} కోసం గేట్ వద్ద చూపించండి.'),
      WNotifKind.vehicleHelpAnswered => 'Open the job for the updated parking answer.',
      WNotifKind.runningLate => t('Reach now. −₹1 for every late minute.', 'अभी पहुँचें। हर लेट मिनट पर −₹1।', 'ఇప్పుడే చేరుకోండి. ప్రతి ఆలస్య నిమిషానికి −₹1.'),
      WNotifKind.windowOpen => t('Its time window has started. The timer is on.', 'इसका समय शुरू हो गया है। टाइमर चालू है।', 'దీని సమయం మొదలైంది. టైమర్ ఆన్‌లో ఉంది.'),
      WNotifKind.finishSoon => t('You haven’t started yet. Go now to finish on time.', 'आपने अभी शुरू नहीं किया। समय पर पूरा करने के लिए अभी जाएं।', 'మీరు ఇంకా మొదలుపెట్టలేదు. సమయానికి పూర్తి చేయడానికి ఇప్పుడే వెళ్ళండి.'),
      WNotifKind.slotEnded => t('Tap I’m at the vehicle, or tell us in Help. Otherwise the job is cancelled.', '‘मैं गाड़ी के पास हूँ’ दबाएं या मदद में बताएं। नहीं तो काम रद्द होगा।',
          '‘నేను వాహనం దగ్గర ఉన్నాను’ నొక్కండి లేదా సహాయంలో చెప్పండి. లేదంటే పని రద్దవుతుంది.'),
      WNotifKind.noShowPenalty => t('You didn’t reach ${n.plate} in time. Owner got a full refund.', 'आप ${n.plate} तक समय पर नहीं पहुँचे। मालिक को पूरे पैसे वापस मिले।',
          'మీరు ${n.plate} కి సమయానికి చేరుకోలేదు. యజమానికి పూర్తి డబ్బు తిరిగి వచ్చింది.'),
      WNotifKind.washApproved => isLive?'$rs in approved earnings. Open Money for payout records.':t('$rs comes tonight before 12.', '$rs आज रात 12 से पहले आएंगे।', '$rs ఈ రాత్రి 12 లోపు వస్తుంది.'),
      WNotifKind.problemReported => t('Owner reported a problem. We decide in 24 hours.', 'मालिक ने समस्या बताई। 24 घंटे में फ़ैसला होगा।', 'యజమాని సమస్య చెప్పారు. 24 గంటల్లో నిర్ణయం.'),
      WNotifKind.payoutSent => isLive?'Open Money to view the recorded transfer and reference.':t('For 9 jobs on Fri, 9 Oct.', 'शुक्र, 9 अक्टू के 9 कामों के लिए।', 'శుక్ర, 9 అక్టో 9 పనులకు.'),
      WNotifKind.upiChanged => t('Money now goes to $upi.', 'अब पैसे $upi पर जाएंगे।', 'ఇకపై డబ్బు $upi కి వెళ్తుంది.'),
      WNotifKind.levelUp => t('Keep ratings at 4★ or more.', 'रेटिंग 4★ या ज़्यादा रखें।', 'రేటింగ్ 4★ లేదా ఎక్కువ ఉంచండి.'),
      WNotifKind.probation => t('An owner gave 3★. Watch the 30-sec tip.', 'एक मालिक ने 3★ दिए। 30 सेकंड की टिप देखें।', 'ఒక యజమాని 3★ ఇచ్చారు. 30 సెకన్ల టిప్ చూడండి.'),
      WNotifKind.blocked => t('Too many low ratings. You can ask us to check.', 'बहुत सी कम रेटिंग। हमसे जाँच करवा सकते हैं।', 'చాలా తక్కువ రేటింగ్‌లు. మమ్మల్ని తనిఖీ చేయమని అడగవచ్చు.'),
      WNotifKind.phoneChanged => t('If this wasn’t you, open Help now.', 'अगर यह आपने नहीं किया, तो अभी मदद खोलें।', 'ఇది మీరు కాకపోతే, ఇప్పుడే సహాయం తెరవండి.'),
    };
  }

  String categoryTitle(WNotifCategory c) => switch (c) {
        WNotifCategory.jobs => t('Jobs', 'काम', 'పనులు'),
        WNotifCategory.money => t('Money', 'पैसे', 'డబ్బు'),
        WNotifCategory.level => t('Level', 'लेवल', 'స్థాయి'),
        WNotifCategory.account => t('Account', 'अकाउंट', 'ఖాతా'),
      };

  String categoryDetail(WNotifCategory c) => switch (c) {
        WNotifCategory.jobs => t('New jobs, gate pass, cancellations', 'नए काम, गेट पास, रद्द काम', 'కొత్త పనులు, గేట్ పాస్, రద్దులు'),
        WNotifCategory.money => t('Approvals, payouts, money on hold', 'मंज़ूरी, पेमेंट, रोके गए पैसे', 'ఆమోదాలు, చెల్లింపులు, నిలిపివేసిన డబ్బు'),
        WNotifCategory.level => t('Your level and job limit', 'आपका लेवल और काम की सीमा', 'మీ స్థాయి మరియు పనుల పరిమితి'),
        WNotifCategory.account => t('Blocks and number changes. Always on.', 'ब्लॉक और नंबर बदलना। हमेशा चालू।', 'బ్లాక్ మరియు నంబర్ మార్పులు. ఎప్పుడూ ఆన్.'),
      };

  // MARK: Notification actions

  int get unreadCount => notifications.where((n) => !n.read).length;

  /// Records a notification and, if settings allow, alerts the captain.
  /// New-job alerts always ring while Online (going Offline is how to stop them).
  void notify(WNotifKind kind, {Job? job, int? amount, bool deliver = true}) {
    final jobId = job?.id;
    final last = notifications.where((n) => n.kind == kind && n.jobId == jobId).firstOrNull;
    if (last != null && DateTime.now().difference(last.date).inSeconds < 60) return;
    final n = WNotif(id: newId('w'), kind: kind, date: DateTime.now(), jobId: jobId, plate: job?.plate ?? '', amount: amount ?? job?.pay ?? 0);
    notifications = [n, ...notifications];
    notifyListeners();
    if (!deliver) return;
    _present(n);
  }
  void _present(WNotif n){
    final kind=n.kind;
    final ringsAnyway = kind == WNotifKind.newJob && online;
    if (!notificationsOn) return;
    if (!ringsAnyway && kind.category != WNotifCategory.account && notifPrefs.off.contains(kind.category)) return;
    if (!ringsAnyway && notifPrefs.isMuted) return;
    final silent = !ringsAnyway && (!notifPrefs.soundOn || (notifPrefs.quietHours && WNotifPrefs.inQuietHours));
    if (Device.appIsActive) {
      liveBanner = n;
      if (!silent) Device.ding();
      Device.buzz(true);
      notifyListeners();
    } else if (systemPermission != Permission.denied) {
      Device.systemNotify(title(n), body(n), silent: silent);
    }
  }

  // Live inbox actions persist on the server; these sets are demo-only.
  final Set<String> _readNotifs = {}, _unreadNotifs = {};
  void markRead(String id) { if(isLive){_notificationAction([id],'read');return;} set(() { _readNotifs.add(id); _unreadNotifs.remove(id); notifications.where((n) => n.id == id).firstOrNull?.read = true; }); }
  void markUnread(String id) { if(isLive){_notificationAction([id],'unread');return;} set(() { _unreadNotifs.add(id); _readNotifs.remove(id); notifications.where((n) => n.id == id).firstOrNull?.read = false; }); }
  void markAllRead() { if(isLive){_notificationAction(notifications.where((n)=>!n.read).map((n)=>n.id).toList(),'read');return;} set(() {
        for (final n in notifications) {
          n.read = true;
          _readNotifs.add(n.id);
          _unreadNotifs.remove(n.id);
        }
      }); }
  void deleteNotification(String id) { if(isLive){_notificationAction([id],'delete');return;} set(() { _deletedNotifs.add(id); notifications.removeWhere((n) => n.id == id); }); }
  void clearNotifications() { if(isLive){_notificationAction(notifications.map((n)=>n.id).toList(),'delete');return;} set(() { _deletedNotifs.addAll(notifications.map((n) => n.id)); notifications = []; }); }

  void setNotifications(bool on) {
    set(() => notificationsOn = on);
    if(isLive) {
      if(on && live!.supportsPush) {
        live!.enablePush('captain').catchError((Object e)=>set(()=>toast=backendError(e)));
      } else if(!on) {live!.call('setPushPreference',{'role':'captain','enabled':false}).catchError((Object e){set(()=>toast=backendError(e));return <String,dynamic>{};});}
      else if(on){Device.requestNotifications().then((p)=>set(()=>systemPermission=p));}
      return;
    }
    if (on) Device.requestNotifications().then((p) => set(() => systemPermission = p));
  }

  void refreshSystemPermission() {if(isLive&&live!.supportsPush){live!.pushPermission().then((p)=>set(()=>systemPermission=p)).catchError((Object _){});}else{set(() => systemPermission = Device.notificationPermission);}}
  void mute(int? seconds) => set(() => notifPrefs.mutedUntil = seconds == null ? null : DateTime.now().add(Duration(seconds: seconds)));
  void muteUntilMorning() => set(() => notifPrefs.mutedUntil = addDays(startOfDay(DateTime.now()), 1).add(const Duration(hours: 8)));

  void seedNotifications() {
    final now = DateTime.now();
    DateTime h(double x) => now.subtract(Duration(minutes: (x * 60).round()));
    final j = sampleQueue()[0];
    notifications = [
      WNotif(id: 'w_gate', kind: WNotifKind.gatePassReady, date: h(0.2), jobId: j.id, plate: j.plate),
      WNotif(id: 'w_approved', kind: WNotifKind.washApproved, date: h(1.5), jobId: 'j3', plate: 'TS 08 GK 2210', amount: 140),
      WNotif(id: 'w_held', kind: WNotifKind.problemReported, date: h(3), jobId: 'j_old', plate: 'TS 09 EA 4521', amount: 116),
      WNotif(id: 'w_oldjob', kind: WNotifKind.newJob, date: h(5), jobId: 'j_gone', plate: 'TS 07 CC 1188', amount: 116, read: true),
      WNotif(id: 'w_payout', kind: WNotifKind.payoutSent, date: h(17), amount: 1262),
      WNotif(id: 'w_level', kind: WNotifKind.levelUp, date: h(20), read: true),
      WNotif(id: 'w_phone', kind: WNotifKind.phoneChanged, date: h(60), read: true),
    ];
    notifyListeners();
  }

  // MARK: No-show (captain accepted but doesn't reach / update the job)

  /// Demo: late → slot over, update the job → job cancelled + penalty. Stops if the captain
  /// taps "I'm at the vehicle" in time.
  void startNoShowDemo(VoidCallback onCancelled) {
    if (_noShowJob != null || noShowCancelled) return;
    final j = current;
    _noShowJob = runTask((task) async {
      await sleepMs(5000);
      if (task.cancelled) return;
      jobLate = true;
      notify(WNotifKind.runningLate, job: j);
      await sleepMs(8000);
      if (task.cancelled) return;
      slotEnded = true;
      notify(WNotifKind.slotEnded, job: j);
      await sleepMs(9000);
      if (task.cancelled) return;
      noShowCancelled = true;
      noShowPlate = j.plate;
      queue.removeWhere((x) => x.id == j.id);
      queue.where((x) => x.status == JobStatus.next).firstOrNull?.status = JobStatus.now;
      notify(WNotifKind.noShowPenalty, job: j);
      _noShowJob = null;
      onCancelled();
    });
  }

  // MARK: Live data (Firebase)
  // The designed screens read the same fields as the sample app. With [live] set they are filled
  // from Firebase, and actions call the backend. Designed parts without a backend are listed as
  // P0 in docs/P0-BACKEND-FOR-DESIGN.md and show [notYet] instead of pretending.

  final LiveBackend? live;
  bool get isLive => live != null;
  String liveUid = '';
  bool liveLoaded = false;
  Map<String, dynamic> liveCaptain = {}, liveConfig = {};
  final Map<String, Map<String, dynamic>> liveOrders = {};
  List<Job> liveOffers = [];
  bool _inboxLoaded=false;
  final Map<String, DateTime> offerExpiry = {};
  List<Map<String, dynamic>> liveEarnings = [];
  String? selectedPayoutId,selectedHeldOrderId;
  List<Map<String,dynamic>> get payouts=>[for(final p in liveCaptain['payouts'] as List? ?? [])if(p['paymentMode']==(liveCaptain['paymentMode']??'test'))Map<String,dynamic>.from(p)];
  Map<String,dynamic>? get selectedPayout=>payouts.where((p)=>p['id']==selectedPayoutId).firstOrNull??payouts.firstOrNull;
  Map<String,dynamic>? get selectedHeldOrder=>liveOrders[selectedHeldOrderId??heldEarnings.firstOrNull?['orderId']];
  Future<void> explainHeld(BuildContext context)async{
    if(!isLive)return;
    final order=selectedHeldOrder;
    if(order==null)return;
    try{final clip=await captureVoice(context);if(clip==null)return;await live!.uploadDisputeResponse(order['id'],clip.bytes,clip.seconds);set(()=>toast=t('Response sent','जवाब भेज दिया','సమాధానం పంపబడింది'));}catch(e){set(()=>toast=e is MediaAccessException?e.message:backendError(e));}
  }
  void Function(String orderId,String reason)? onJobCancelled;
  Set<String> kycUploaded = {};
  String kycStatus = 'notSubmitted';
  final List<StreamSubscription<dynamic>> _liveSubs = [], _accountSubs = [];
  Timer? _heartbeat;
  Timer? _locationTimer;
  bool _sharingLocation=false,_locationBusy=false,_foreground=true;
  void foreground(bool value){_foreground=value;}
  Future<void> openDirections()async{
    final job=current;
    if(!isLive){await Device.openMapsSearch(job.fullAddress);return;}
    if(job.id.isEmpty||job.cancelled)return;
    try{
      final p=await live!.currentPosition();
      await live!.call('setCaptainPosition',{'latitude':p.latitude,'longitude':p.longitude});
      _sharingLocation=true;
      await _shareCurrentLocation();
      _locationTimer??=Timer.periodic(const Duration(seconds:15),(_)=>_shareCurrentLocation());
    }catch(e){set(()=>toast=backendError(e));}
    final pin=liveOrder(job.id)?['vehiclePosition'];
    final destination=pin is Map&&pin['latitude'] is num&&pin['longitude'] is num?'${pin['latitude']},${pin['longitude']}':job.fullAddress;
    await Device.openMapsSearch(destination);
  }
  Future<void> _shareCurrentLocation()async{
    if(!_sharingLocation||!_foreground||_locationBusy||liveUid.isEmpty||!['onTheWay','washing'].contains(liveOrder(current.id)?['status']))return;
    _locationBusy=true;try{await live!.shareLocation(current.id);}catch(_){/* Existing samples expire; never invent a new position. */}finally{_locationBusy=false;}
  }
  Timer? _preferenceSave;
  bool _disposed=false;
  Future<void> _preferenceQueue = Future.value();
  String? _profilePhotoPath, _workflowOrderId, _shotJobId;
  final Map<String,String> _evidenceVersions = {};

  Map<String,dynamic> _preferences()=>{'role':'captain','enabled':notificationsOn,'soundOn':notifPrefs.soundOn,'quietHours':notifPrefs.quietHours,'mutedUntil':notifPrefs.mutedUntil?.millisecondsSinceEpoch,'offCategories':[for(final c in notifPrefs.off) if(c!=WNotifCategory.account)c.name]};
  void _savePreferences(){
    if(!isLive||liveUid.isEmpty)return;
    final account=liveUid,value=_preferences();
    _preferenceSave?.cancel();
    _preferenceSave=Timer(const Duration(milliseconds:300),(){_preferenceQueue=_preferenceQueue.then((_)async{if(liveUid==account)await live!.call('saveNotificationPreferences',value);}).catchError((Object e){if(liveUid==account){toast=backendError(e);changed();}});});
  }
  Future<void> setProfilePhoto(Uint8List? bytes) async {
    if(!isLive){set(()=>profilePhoto=bytes);return;}
    try{await live!.saveProfilePhoto('captain',bytes);profilePhoto=bytes;changed();}catch(e){set(()=>toast=backendError(e));}
  }
  Future<void> _notificationAction(List<String> ids,String action)async{try{await live!.notificationAction(ids,action);}catch(e){set(()=>toast=backendError(e));}}

  static const notYet = 'This isn’t available yet. Call us and we’ll do it for you.';
  bool blockLive([String? message]) {
    if (!isLive) return false;
    set(() => toast = message ?? t(notYet, 'यह अभी उपलब्ध नहीं है। हमें कॉल करें, हम कर देंगे।', 'ఇది ఇంకా అందుబాటులో లేదు. మాకు కాల్ చేయండి, మేము చేస్తాము.'));
    return true;
  }

  /// Profile → Delete account. Returns an error for the dialog, or null when the account is gone.
  Future<String?> deleteAccount() async {
    if (isLive) {
      try {
        final result = await live!.call('deleteOwnAccount', {'confirm': true, 'role': 'captain'});
        if (result['deleted'] != true) return 'Account deletion has not finished. Try again.';
        await live!.signOut();
        return null;
      } catch(e) { return backendError(e); }
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _logOut();
    return null;
  }

  void _startLive() {
    queue = [];
    notifications = [];
    online = false;
    jobsToday = 0;
    earnedToday = 0;
    approvedToday = 0;
    waitingToday = 0;
    levelDay = 1;
    jobLimit = 0;
    rating = 0;
    name = '';
    phone = '';
    upi = '';
    _liveSubs.add(live!.catalog.listen((s) => set(() {liveConfig = s.data() ?? {};Support.configure(liveConfig);_applySteps();}), onError: (Object e) => set(() => toast = backendError(e))));
    _liveSubs.add(live!.sessions.listen((user) {
      final uid = user?.phoneNumber != null ? user!.uid : '';
      if (uid != liveUid) _bindLive(uid);
    }));
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      if(liveUid.isNotEmpty) { _rebuildQueue(); _applyEarnings(); changed(); }
      if (isLive && online && liveUid.isNotEmpty) live!.call('setCaptainOnline', {'online': true}).catchError((Object _) => <String, dynamic>{});
    });
  }

  void _bindLive(String uid) {
    for (final s in _accountSubs) {
      s.cancel();
    }
    _accountSubs.clear();
    liveUid = uid;
    liveLoaded = uid.isEmpty;
    liveCaptain = {};
    _workflowOrderId=null; _shotJobId=null; _evidenceVersions.clear(); shots.clear();
    _sharingLocation=false;_locationTimer?.cancel();_locationTimer=null;
    profilePhoto=null;_profilePhotoPath=null;_preferenceSave?.cancel();
    _readNotifs.clear();_unreadNotifs.clear();_deletedNotifs.clear();
    liveOrders.clear();
    liveOffers = [];_inboxLoaded=false;
    liveEarnings = [];
    kycUploaded = {};
    queue = [];
    notifications = [];
    registered = false;
    signedUp = false;
    online = false;
    if (uid.isEmpty) {
      changed();
      return;
    }
    live!.registerPush('captain').catchError((Object _) {});
    _accountSubs.add(live!.profile(uid).listen((s){
      if(liveUid!=uid)return;
      final d=s.data()??{},p=d['notificationPreferences']?['captain'];
      notificationsOn=d['captainPushEnabled']==true;
      if(p is Map){notifPrefs.soundOn=p['soundOn']!=false;notifPrefs.quietHours=p['quietHours']==true;notifPrefs.mutedUntil=p['mutedUntil'] is num?DateTime.fromMillisecondsSinceEpoch((p['mutedUntil'] as num).toInt()):null;notifPrefs.off={for(final c in WNotifCategory.values)if(c!=WNotifCategory.account&&(p['offCategories'] as List? ?? []).contains(c.name))c};}
      final path=d['captainPhotoPath'] as String?;
      if(path!=_profilePhotoPath){_profilePhotoPath=path;if(path==null) {
        profilePhoto=null;
      } else {
        live!.photo(path).then((bytes){if(liveUid==uid&&path==_profilePhotoPath){profilePhoto=bytes;changed();}}).catchError((Object e){if(liveUid==uid)set(()=>toast=backendError(e));});
      }}
      changed();
    },onError:(Object e)=>set(()=>toast=backendError(e))));
    _accountSubs.add(live!.captain(uid).listen((s) {
      if (liveUid != uid) return;
      final d = s.data() ?? {};
      final status = d['kycStatus'] as String? ?? 'notSubmitted';
      if (status != kycStatus || liveCaptain.isEmpty) {
        live!.uploadedKyc().then((files) {
          if (liveUid != uid) return;
          kycUploaded = files;
          _applySteps();
          changed();
        }).catchError((Object _) {});
      }
      liveCaptain = d;
      videosWatched=(d['trainingVideos'] as List? ?? []).length;
      _applySteps();
      liveLoaded = true;
      kycStatus = status;
      if (d.isNotEmpty) {
        name = d['name'] as String? ?? name;
        phone = (d['phone'] as String? ?? '').replaceFirst('+91', '');
        upi = d['upi'] as String? ?? upi;
        rating = (d['ratingCount'] as num? ?? 0) > 0 ? (d['rating'] as num).toDouble() : 0;
        online = d['online'] == true;
        registered = true;
        exploring = true;
        final wasApproved = signedUp;
        signedUp = d['approved'] == true;
        // Approved while waiting after 'I agree': go online by itself.
        if (!wasApproved && signedUp && awaitingApproval) Future.microtask(goOnlineAfterApproval);
        levelDay = (d['levelDay'] as num? ?? levelDay).toInt();
        jobLimit = (d['jobLimit'] as num? ?? 0).toInt();
        // New preferences survive restarts at their exact half-hour boundaries.
        // Historical accounts retain the legacy whole-window interpretation.
        final windows = [for (final w in d['workingWindows'] as List? ?? []) ((w['startHour'] as num).toInt(), (w['endHour'] as num).toInt())]..sort((a, b) => a.$1.compareTo(b.$1));
        final mine = serverWindowsFor(workSlots);
        final same = windows.length == mine.length && [for (var i = 0; i < mine.length; i++) windows[i] == mine[i]].every((x) => x);
        if (d['workingSlots'] is List) {
          workSlots = mergeSlots([for (final s in d['workingSlots']) ((s['startMinute'] as num).toInt(), (s['endMinute'] as num).toInt())]);
        } else if (!same) {
          workSlots = windows.isEmpty || windows.length >= serverWorkWindows.length ? [] : mergeSlots([for (final w in windows) (w.$1 * 60, w.$2 * 60)]);
        }
        final societies = [for (final id in (d['societyIds'] as List? ?? d['requestedSocietyIds'] as List? ?? [])) _societyName(id)];
        if (societies.isNotEmpty) {
          workMode = WorkMode.societies;
          chosenSocieties = societies.toSet();
        }
        final pref=d['areaPreference'];
        if(pref is Map){workMode=WorkMode.values.where((w)=>w.name==pref['mode']).firstOrNull??WorkMode.all;radiusKm=(pref['radiusKm'] as num? ?? radiusKm).toInt();workPlace=pref['place'] as String? ?? workPlace;if(pref['societyIds'] is List)chosenSocieties={for(final id in pref['societyIds'])_societyName(id)};}
      }
      _applySteps();
      _applyEarnings();
      changed();
    }, onError: (Object e) => set(() => toast = backendError(e))));
    _accountSubs.add(live!.orders(uid, captain: true).listen((s) {
      if (liveUid != uid) return;
      final previousId=current.id,previousStatus=liveOrders[current.id]?['status'];
      liveOrders
        ..clear()
        ..addAll({for (final d in s.docs) d.id: {...d.data(), 'id': d.id}});
      _rebuildQueue();
      _applyEarnings();
      if(['onTheWay','washing'].contains(previousStatus)&&liveOrders[previousId]?['status']=='cancelled'){
        _workflowOrderId=previousId;
        noShowCancelled=liveOrders[previousId]?['cancellationReason']=='slotExpired';noShowPlate=liveOrders[previousId]?['plate']??'';
        scheduleMicrotask((){if(liveUid==uid)onJobCancelled?.call(previousId,liveOrders[previousId]?['cancellationReason']??'customerCancelled');});
      }
      changed();
    }, onError: (Object e) => set(() => toast = backendError(e))));
    _accountSubs.add(live!.offers(uid).listen((s) {
      if (liveUid != uid) return;
      final now = DateTime.now();
      offerExpiry.clear();
      liveOffers = [
        for (final d in s.docs)
          if (d.data()['status'] == 'pending' && (d.data()['paymentMode'] ?? 'test') == (liveCaptain['paymentMode'] ?? 'test') && _date(d.data()['expiresAt'])?.isAfter(now) == true)
            _offerJob(d.data()),
      ];
      for (final d in s.docs) {
        final at = _date(d.data()['expiresAt']);
        if (at != null) offerExpiry[d.data()['orderId'] as String] = at;
      }
      changed();
    }, onError: (Object e) => set(() => toast = backendError(e))));
    _accountSubs.add(live!.earnings(uid).listen((s) {
      if (liveUid != uid) return;
      liveEarnings = [for (final d in s.docs) {...d.data(), 'id': d.id}];
      _applyEarnings();
      changed();
    }, onError: (Object e) => set(() => toast = backendError(e))));
    _accountSubs.add(live!.inbox(uid).listen((s) {
      if (liveUid != uid) return;
      final previous=notifications.map((n)=>n.id).toSet();
      notifications = [
        for (final d in s.docs)
          if (d.data()['role'] == 'captain' && d.data()['deletedAt']==null) _liveNotif(d.id, d.data()),
      ];
      if(_inboxLoaded){for(final n in notifications.where((n)=>!previous.contains(n.id))) { _present(n); }}
      _inboxLoaded=true;
      changed();
    }, onError: (Object e) => set(() => toast = backendError(e))));
    changed();
  }

  DateTime? _date(dynamic v) => v == null ? null : (v.toDate() as DateTime).toLocal();
  String _societyName(dynamic id) => (liveConfig['societies'] as List? ?? []).where((s) => s['id'] == id).firstOrNull?['name'] as String? ?? '$id';
  String _window(int a, int b) => '$a–$b';

  /// Uploads and payout details follow the server. Submission is not training proof.
  void _applySteps() {
    videosWatched=liveCaptain['trainingVersion']==liveConfig['training']?['version']?(liveCaptain['trainingVideos'] as List? ?? []).length:0;
    final submitted = kycStatus == 'underReview' || kycStatus == 'approved' || liveCaptain['approved'] == true;
    steps = {
      if (kycUploaded.contains('aadhaar') || submitted) KycStep.aadhaar: KycState.done,
      if (kycUploaded.contains('selfie') || submitted) KycStep.photo: KycState.done,
      if (liveCaptain['payout'] != null || (kycUploaded.contains('bank') && upi.isNotEmpty) || submitted) KycStep.bank: KycState.done,
      if (liveCaptain['trainingVersion']==liveConfig['training']?['version'] && liveCaptain['trainingCompletedAt'] != null) KycStep.training: KycState.done,
      if (liveCaptain['trainingVersion']==liveConfig['training']?['version'] && liveCaptain['quizPassedAt'] != null) KycStep.quiz: KycState.done,
    };
    if (kycStatus == 'changesRequested') steps[KycStep.aadhaar] = KycState.problem;
    for (final s in testSkipped) {
      steps[s] = KycState.done;
    }
  }

  WashType _wash(dynamic w) => switch (w) { 'dryDusting' => WashType.dryDusting, 'wetOutsideDryInside' => WashType.wetOutsideDryInside, _ => WashType.wetOutside };

  Job _orderJob(Map<String, dynamic> o, JobStatus status) {
    final start = _date(o['slotStart']) ?? DateTime.now(), end = _date(o['slotEnd']) ?? start;
    final day = startOfDay(start).difference(startOfDay(DateTime.now())).inDays;
    return Job(
      id: o['id'] as String,
      plate: Fmt.plate(o['plate'] as String? ?? ''),
      type: o['vehicleName'] as String? ?? '',
      isBike: o['vehicleKind'] == 'bike',
      pay: (o['captainPayPaise'] as num? ?? 0).toInt() ~/ 100,
      tower: o['tower'] as String? ?? '',
      floor: o['floor'] as String? ?? '',
      slot: o['parking'] as String? ?? '',
      window: _window(start.hour, end.hour),
      time: '${start.hour}:${start.minute.toString().padLeft(2,'0')}',
      distance: o['distanceMetres'] is num ? (o['distanceMetres'] as num)>=1000?'${((o['distanceMetres'] as num)/1000).toStringAsFixed(1)} km':'${(o['distanceMetres'] as num).round()} m' : '—',
      status: status,
      reachBy: Fmt.time(start),
      finishBy: Fmt.time(end),
      owner: o['customerFirstName'] as String? ?? '',
      society: o['societyName'] as String? ?? '',
      wash: _wash(o['washKind']),
      area: o['area'] as String? ?? '',
      windows: [for (final w in o['requestedWindows'] as List? ?? o['windows'] as List? ?? []) _window((w['startHour'] as num).toInt(), (w['endHour'] as num).toInt())],
      flexible: o['anyTime'] == true,
      day: day < 0 ? 0 : day,
      typedAddress: o['manualAddress'] == true,
      pincode: o['pincode'] as String? ?? '',
      cancelled: o['status'] == 'cancelled',
    );
  }

  // Offers hide plate, tower and parking until accepted (P0: confirm with the design), so they show a dash.
  Job _offerJob(Map<String, dynamic> o) => _orderJob({'plate': '—', 'tower': '—', 'floor': '—', ...o, 'id': o['orderId']}, JobStatus.next);

  void _rebuildQueue() {
    final orders = liveOrders.values.toList()..sort((a, b) => (_date(a['slotStart']) ?? DateTime.now()).compareTo(_date(b['slotStart']) ?? DateTime.now()));
    final active = orders.where((o) => ['onTheWay', 'washing'].contains(o['status']) && !(_date(o['slotStart'])?.isAfter(DateTime.now()) ?? false)).firstOrNull;
    queue = [
      for (final o in orders)
        _orderJob(
          o,
          ['photosReady', 'approved', 'disputed', 'disputeUpheld'].contains(o['status'])
              ? JobStatus.done
              : o['id'] == active?['id']
              ? JobStatus.now
              : JobStatus.next,
        ),
    ];
    final cur = queue.where((j) => j.id==_workflowOrderId).firstOrNull ?? queue.where((j) => j.status == JobStatus.now).firstOrNull;
    final o = cur == null ? null : liveOrders[cur.id];
    jobLate=(o?['runningLateMinutes'] as num? ?? 0)>0;
    slotEnded=o!=null&&o['status']=='onTheWay'&&(_date(o['slotEnd'])?.isBefore(DateTime.now())??false);
    ownerNoteHeard=o?['noteHeard']==true;
    if(_shotJobId!=cur?.id){_shotJobId=cur?.id;shots.clear();_evidenceVersions.clear();}
    final evidence = o?['evidence'] as Map? ?? {};
    beforeDone = {for (var i = 0; i < 4; i++) if (evidence['before_$i'] != null) i};
    afterDone = {for (var i = 0; i < 4; i++) if (evidence['after_$i'] != null) i};
    if(cur!=null){
      final jobId=cur.id,account=liveUid;
      for(final e in evidence.entries){final path=e.value['path'] as String?,version='${e.value['path']}:${e.value['uploadedAt']}';
        if(path==null||_evidenceVersions[e.key]==version)continue;
        _evidenceVersions[e.key]=version;
        live!.photo(path).then((bytes){if(liveUid==account&&_shotJobId==jobId&&bytes!=null){shots[e.key]=bytes;changed();}}).catchError((Object _){_evidenceVersions.remove(e.key);});
      }
    }
  }

  void _applyEarnings() {
    final today = startOfDay(DateTime.now());
    final todays = liveEarnings.where((e) => (e['paymentMode']??'test')==(liveCaptain['paymentMode']??'test') && !(_date(e['createdAt']) ?? _date(e['updatedAt']) ?? DateTime(2000)).isBefore(today)).toList();
    int sum(Iterable<Map<String, dynamic>> l) => l.fold(0, (a, e) => a + (e['amount'] as num? ?? 0).toInt() ~/ 100);
    earnedToday = sum(todays.where((e) => ['approved','awaitingApproval'].contains(e['status'])));
    approvedToday = sum(todays.where((e) => e['status'] == 'approved'));
    waitingToday = sum(todays.where((e) => e['status'] == 'awaitingApproval'));
    jobsToday = liveOrders.values.where((o)=>(o['paymentMode']??'test')==(liveCaptain['paymentMode']??'test') && o['day']==DateTime.now().toIso8601String().substring(0,10) && o['status']!='cancelled').length;
  }

  /// This week's earnings (live), in rupees: (total, approved, waiting).
  (int, int, int) get weekMoney {
    final from = startOfDay(DateTime.now()).subtract(Duration(days: DateTime.now().weekday - 1));
    final week = liveEarnings.where((e) => (e['paymentMode']??'test')==(liveCaptain['paymentMode']??'test') && !(_date(e['createdAt']) ?? _date(e['updatedAt']) ?? DateTime(2000)).isBefore(from));
    int sum(Iterable<Map<String, dynamic>> l) => l.fold(0, (a, e) => a + (e['amount'] as num? ?? 0).toInt() ~/ 100);
    return (sum(week.where((e) => ['approved','awaitingApproval'].contains(e['status']))), sum(week.where((e) => e['status'] == 'approved')), sum(week.where((e) => e['status'] == 'awaitingApproval')));
  }

  /// Earnings the owner disputed (live), newest first.
  List<Map<String, dynamic>> get heldEarnings => liveEarnings.where((e) => e['status'] == 'onHold' && (e['paymentMode']??'test')==(liveCaptain['paymentMode']??'test')).toList();

  final Set<String> _deletedNotifs = {};
  WNotif _liveNotif(String id, Map<String, dynamic> d) {
    final o = liveOrders[d['orderId']];
    final kind = switch (d['kind']) {
      'approved' => WNotifKind.washApproved,
      'cancelled' => WNotifKind.ownerCancelledEarly,
      'disputed' => WNotifKind.problemReported,
      'payoutSent' => WNotifKind.payoutSent,
      'upiChanged' => WNotifKind.upiChanged,
      'phoneChanged' => WNotifKind.phoneChanged,
      'slotEnded' => WNotifKind.slotEnded,
      'vehicleHelpAnswered' => WNotifKind.vehicleHelpAnswered,
      'levelUp'=>WNotifKind.levelUp,
      'probation'=>WNotifKind.probation,
      'blocked'=>WNotifKind.blocked,
      _ => WNotifKind.newJob,
    };
    return WNotif(
      id: id,
      kind: kind,
      date: _date(d['createdAt']) ?? DateTime.now(),
      jobId: d['orderId'] as String?,
      payoutId: d['payoutId'] as String?,
      plate: Fmt.plate(o?['plate'] as String? ?? ''),
      amount: (d['amount'] as num? ?? o?['captainPayPaise'] as num? ?? 0).toInt() ~/ 100,
      read: d['read'] == true,
    );
  }

  /// Societies to pick from: the live catalogue, or the sample list.
  List<Society> get societyChoices => isLive
      ? [for (final s in liveConfig['societies'] as List? ?? []) if (s['active'] == true) Society(s['name'] as String, s['area'] as String? ?? '', 0)]
      : Society.all;

  /// An actual, recent match only; an approved society is not proof of location.
  String get hereSociety => isLive ? (DateTime.now().difference(_date(liveCaptain['position']?['updatedAt'])??DateTime(2000)).inMinutes<5 && liveCaptain['locationSocietyId']!=null ? _societyName(liveCaptain['locationSocietyId']) : '') : Society.current.name;

  /// Live: photos taken on this phone for the current job, shown in the designed photo boxes.
  final Map<String, Uint8List> shots = {};

  /// Order data behind a job (evidence, arrival) or null in the sample app.
  Map<String, dynamic>? liveOrder(String id) => liveOrders[id];
  bool get currentArrived => liveOrders[current.id]?['arrivedAt'] != null;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      set(() => toast = e is MediaAccessException ? e.message : backendError(e));
      rethrow;
    }
  }

  Future<void> liveRequestOtp(String number) => _call(() => live!.requestOtp(number));
  Future<void> liveVerifyOtp(String code) => _call(() => live!.verifyOtp(code, role: 'captain', name: name.trim()));
  Future<void> liveSetOnline(bool on) => _call(() => live!.call('setCaptainOnline', {'online': on}));
  Future<void> liveClaim(String orderId) => _call(() => live!.call('claimJob', {'orderId': orderId}));
  Future<void> liveReject(String orderId) => _call(() => live!.call('rejectJob', {'orderId': orderId}));
  List<Map<String,dynamic>> get photoReviewIssues=>[for(final i in liveOrder(current.id)?['photoReview']?['issues'] as List? ?? [])Map<String,dynamic>.from(i as Map)];
  int get photoReviewSide=>photoReviewIssues.firstOrNull?['side'] as int? ?? 0;
  Future<List<dynamic>> liveCheckPhotos()async{final result=await live!.call('checkWashPhotos',{'orderId':current.id});return result['issues'] as List? ?? [];}
  Future<void> liveProgress(String action,{bool acknowledgePhotoIssues=false}) async {
    final orderId=current.id;
    if(orderId.isEmpty)throw StateError('Open your assigned job first.');
    _workflowOrderId=orderId;
    await _call(() => live!.call('updateWashProgress', {'orderId':orderId, 'action': action,if(action=='finish')'acknowledgePhotoIssues':acknowledgePhotoIssues}));
  }
  Future<void> liveVehicleHelp(String reason)=>_call(()=>live!.call('updateVehicleHelp',{'orderId':current.id,'action':'request','value':reason}));
  Future<void> liveEvidence({required bool after, required int side, required Uint8List bytes}) =>
      _call(() => live!.uploadEvidence(orderId: current.id, after: after, side: side, bytes: bytes));
  Future<void> liveUploadKyc(String kind, Uint8List bytes) async {
    await _call(() => live!.uploadKyc(kind, bytes));
    set(() {
      kycUploaded = {...kycUploaded, kind};
      _applySteps();
    });
  }
  Future<void> liveSavePayout({String? upi,String? accountNumber})=>_call(()=>live!.call('saveCaptainPayout',{'method':accountNumber==null?'upi':'bank',if(accountNumber==null)'upi':upi,if(accountNumber!=null)'accountNumber':accountNumber.replaceAll(' ','')}));

  /// Rules accepted: send the application for review (societies from "Where I work", else all).
  Future<void> liveSubmitApplication() {
    final all = [for (final s in liveConfig['societies'] as List? ?? []) if (s['active'] == true) s];
    final chosen = all.where((s) => chosenSocieties.contains(s['name'])).toList();
    return _call(() => live!.call('submitCaptainApplication', {'societyIds': [for (final s in chosen.isEmpty ? all : chosen) s['id']], 'upi': upi.trim()}));
  }

  Future<void> liveSaveWorkPreferences(WorkMode mode,int radius,Set<String> societies,String place,List<WorkSlot> slots)async{
    final config=liveConfig['societies'] as List? ?? [];
    if(mode==WorkMode.radius){final p=await live!.currentPosition();await live!.call('setCaptainPosition',{'latitude':p.latitude,'longitude':p.longitude});}
    // Legacy windows remain for older installed clients. Exact slots govern matching.
    final chosen=serverWindowsFor(slots);
    await _call(()=>live!.call('setCaptainPreferences',{'workingSlots':[for(final s in mergeSlots(slots)){'startMinute':s.$1,'endMinute':s.$2}],'workingWindows':[for(final w in chosen){'startHour':w.$1,'endHour':w.$2}],'areaPreference':{'mode':mode.name,if(mode==WorkMode.radius)'radiusKm':radius,if(mode==WorkMode.place)'place':place,if(mode==WorkMode.societies)'societyIds':[for(final s in config)if(societies.contains(s['name']))s['id']]}}));
  }

  Future<void> liveSignOut() async {
    if (online) await live!.call('setCaptainOnline', {'online': false}).catchError((Object _) => <String, dynamic>{});
    await live!.signOut();
  }

  @override
  void dispose() {
    _disposed=true;liveUid='';
    _heartbeat?.cancel();
    _locationTimer?.cancel();
    _preferenceSave?.cancel();
    for (final s in [..._liveSubs, ..._accountSubs]) {
      s.cancel();
    }
    super.dispose();
  }

  /// The captain reached the car in time: no penalty.
  void captainArrived() {
    _noShowJob?.cancel();
    _noShowJob = null;
    jobLate = false;
    slotEnded = false;
    notifyListeners();
  }
}

/// Plan alerts: open that job (it becomes the current one if it wasn't).
String? _openPlanJob(WNotif n, CaptainStore store, WRouterC router) {
  final j = store.queue.where((x) => x.id == n.jobId).firstOrNull;
  if (j == null || j.status == JobStatus.done) return store.t('This job has moved on.', 'यह काम आगे बढ़ चुका है।', 'ఈ పని ముందుకు వెళ్ళింది.');
  if (j.status == JobStatus.next) store.startJob(j.id);
  router.go(N.goToVehicle);
  return null;
}

/// Where a tapped notification goes, with the "moved on" / "gone" edge cases. Returns an info message, if any.
String? openWNotif(WNotif n, CaptainStore store, WRouterC router) {
  store.markRead(n.id);
  store.set(() => store.liveBanner = null);
  final isCurrent = n.jobId != null && store.queue.any((j) => j.id == n.jobId && j.status == JobStatus.now);
  switch (n.kind) {
    case WNotifKind.newJob:
      if (!store.online || !store.queue.any((j) => j.id == n.jobId && j.status != JobStatus.done)) {
        return store.t('This job is no longer available.', 'यह काम अब उपलब्ध नहीं है।', 'ఈ పని ఇప్పుడు అందుబాటులో లేదు.');
      }
      router.push(const R(N.jobAlert));
    case WNotifKind.jobTaken:
      return null;
    case WNotifKind.ownerCancelled || WNotifKind.ownerCancelledEarly:
      // Already handled when it happened: show the plan, where the job is struck through.
      router.home();
    case WNotifKind.windowOpen || WNotifKind.finishSoon:
      return _openPlanJob(n, store, router);
    case WNotifKind.runningLate when !isCurrent:
      return _openPlanJob(n, store, router);
    case WNotifKind.gatePassReady || WNotifKind.vehicleHelpAnswered || WNotifKind.runningLate || WNotifKind.slotEnded:
      if (!isCurrent || (store.noShowCancelled && n.kind != WNotifKind.gatePassReady)) {
        return store.t('This job has moved on.', 'यह काम आगे बढ़ चुका है।', 'ఈ పని ముందుకు వెళ్ళింది.');
      }
      router.go(N.goToVehicle);
    case WNotifKind.noShowPenalty:
      router.go(N.noShowCancelled);
    case WNotifKind.washApproved:
      router.home();router.tab=2;
    case WNotifKind.payoutSent:
      store.selectedPayoutId=n.payoutId;
      router.go(N.payoutDetail);
    case WNotifKind.problemReported:
      store.selectedHeldOrderId=n.jobId;
      router.go(N.payoutHeld);
    case WNotifKind.levelUp:
      router.go(N.level);
    case WNotifKind.probation:
      router.go(N.probationExtended);
    case WNotifKind.blocked:
      router.go(N.blocked);
    case WNotifKind.phoneChanged || WNotifKind.upiChanged:
      router.home();
      router.tab = 3;
  }
  return null;
}

class CaptainScope extends InheritedNotifier<Listenable> {
  CaptainScope({super.key, required this.store, required this.router, required super.child}) : super(notifier: Listenable.merge([store, router]));
  final CaptainStore store;
  final WRouterC router;
  static CaptainScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<CaptainScope>()!;
}

extension CaptainContext on BuildContext {
  CaptainStore get store => CaptainScope.of(this).store;
  WRouterC get router => CaptainScope.of(this).router;
}
