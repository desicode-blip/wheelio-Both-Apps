import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/mock_backend.dart';
import '../data/models.dart';
import '../routes.dart';
import '../state/app_state.dart';

/// Developer screen gallery (mock mode only). Opens every designed screen
/// and state (C01–C55, CA1–CA4) with the right sample data, and holds the
/// switches that force edge cases in the live flow.
class DevGalleryScreen extends StatefulWidget {
  const DevGalleryScreen({super.key});

  @override
  State<DevGalleryScreen> createState() => _DevGalleryScreenState();
}

typedef _Prep = Future<void> Function(AppState app, MockBackend mock);

class _Entry {
  const _Entry(this.id, this.title, this.route, [this.prep, this.note]);

  final String id;
  final String title;

  /// Null for system screens that the app does not draw itself.
  final String? route;
  final _Prep? prep;
  final String? note;
}

// ---- Prep helpers -------------------------------------------------------------

Future<void> _signIn(AppState app, MockBackend m, {int free = 0}) async {
  m.signInAsSample(freeWashes: free);
  app.changed();
}

void _draftBasics(AppState app) {
  final d = app.draft;
  d.clear();
  d.type = MockBackend.types[1];
  d.plate = 'TS 09 EA 4521';
}

void _draftFull(AppState app) {
  _draftBasics(app);
  final d = app.draft;
  for (final a in PhotoAngle.values) {
    d.photos[a] = const PhotoRef(localPath: '', state: UploadState.done);
  }
  d.videoSeconds = 14;
  d.place = MockBackend.homePlace;
  d.note = const EntryNote(voiceSeconds: 12);
  final now = DateTime.now();
  d.slot = TimeSlot(date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)), startHour: 8, endHour: 10);
}

_Prep _order(OrderStatus s, {bool pass = false, bool isLate = false, bool find = false, int free = 0}) =>
    (app, m) async {
      await _signIn(app, m, free: free);
      app.setOrder(m.sampleOrder(s, passMissing: pass, isLate: isLate, cantFind: find));
    };

Future<void> _payReady(AppState app, MockBackend m) async {
  await _signIn(app, m);
  _draftFull(app);
  app.currentOrder = null;
}

final _entries = <_Entry>[
  // 01 · Book a wash
  const _Entry('C01', 'Splash', '${R.splash}?state=static'),
  _Entry('C02', 'Welcome', R.welcome, (app, m) async => m.signOutForDemo()),
  _Entry('C05', 'Vehicle type', R.vehicleType, (app, m) async => _draftBasics(app)),
  _Entry('C06', 'Vehicle number', R.vehicleNumber, (app, m) async => _draftBasics(app)),
  _Entry('C06b', 'Vehicle number – invalid', '${R.vehicleNumber}?state=error', (app, m) async => _draftBasics(app)),
  _Entry('C07', 'Vehicle photos – empty', R.photos, (app, m) async => _draftBasics(app)),
  _Entry('C07b', 'Vehicle photos – partial, one failed', R.photos, (app, m) async {
    _draftBasics(app);
    app.draft.photos[PhotoAngle.front] = const PhotoRef(localPath: '', state: UploadState.done);
    app.draft.photos[PhotoAngle.back] = const PhotoRef(localPath: '', state: UploadState.failed);
  }),
  _Entry('C07c', 'Vehicle photos – all done', R.photos, (app, m) async {
    _draftFull(app);
    app.draft.place = null;
  }),
  const _Entry('C08', 'Camera – guided angle', '${R.camera}?angle=front'),
  const _Entry('C08b', 'Camera access needed', '${R.camera}?state=denied'),
  _Entry('C09', 'Confirm location', R.location, (app, m) async {
    _draftFull(app);
    app.draft.place = null;
  }),
  const _Entry('C09b', 'Location is off', '${R.location}?state=off'),
  const _Entry('C09c', 'Search address', R.addressSearch),
  _Entry('C10', 'Floor and slot', R.floorSlot, (app, m) async {
    _draftFull(app);
    app.draft.place = Place(society: MockBackend.societies[0], tower: 'Tower 3');
  }),
  _Entry('C11', 'Notes for the washer', R.entryNotes, (app, m) async => _draftFull(app)),
  _Entry('C12', 'Pick a time', R.timeSlot, (app, m) async => _draftFull(app)),
  _Entry('C12b', 'No washers free today', R.timeSlot, (app, m) async {
    _draftFull(app);
    m.demo.noWashersToday = true;
  }),
  _Entry('C13', 'Review booking', R.review, (app, m) async => _draftFull(app)),
  _Entry('C14', 'Log in with phone', R.login, (app, m) async {
    m.signOutForDemo();
    app.afterLogin = R.payMethod;
  }),
  const _Entry('C14b', 'Phone number – invalid', '${R.login}?state=error'),
  _Entry('C15', 'Enter code', R.otp, (app, m) async {
    app.pendingPhone = '9848011223';
  }),
  _Entry('C15b', 'Code – wrong', '${R.otp}?state=wrong', (app, m) async {
    app.pendingPhone = '9848011223';
  }),
  _Entry('C15c', 'Code – expired', '${R.otp}?state=expired', (app, m) async {
    app.pendingPhone = '9848011223';
  }),
  _Entry('C16', 'Your name', R.name, (app, m) async => _signIn(app, m)),
  _Entry('C17', 'Payment method sheet', R.payMethod, _payReady),
  _Entry('C18', 'Payment processing (runs the payment)', R.payMethod, _payReady,
      'Tap Pay to see the processing screen.'),
  const _Entry('C18b', 'Payment failed', '${R.paying}?state=failed'),
  const _Entry('C18c', 'Payment pending', '${R.paying}?state=pending'),
  _Entry('C19', 'Booked – send entry pass', R.booked, _order(OrderStatus.searching)),
  _Entry('C19b', 'WhatsApp bot – entry pass (reference)', R.whatsApp, _order(OrderStatus.searching)),
  // 02 · Live order
  _Entry('C20', 'Finding a washer', R.searching, _order(OrderStatus.searching)),
  _Entry('C21', 'No washer found – refunded', R.noWasher, _order(OrderStatus.noWasher)),
  _Entry('C22', 'Washer on the way', R.onTheWay, _order(OrderStatus.onTheWay)),
  _Entry('C22b', 'Entry pass missing', R.onTheWay, _order(OrderStatus.onTheWay, pass: true)),
  _Entry('C24', 'Washer running late', R.onTheWay, _order(OrderStatus.onTheWay, isLate: true)),
  _Entry('C30', 'Washer can’t find vehicle', R.onTheWay, _order(OrderStatus.onTheWay, find: true)),
  _Entry('C23', 'Washing in progress', R.washing, _order(OrderStatus.washing)),
  _Entry('C25', 'Wash done – check photos', R.checkPhotos, _order(OrderStatus.photosReady)),
  _Entry('C26', 'Photo compare', R.photoCompare, _order(OrderStatus.photosReady)),
  _Entry('C27', 'Approved – rate washer', R.rate, _order(OrderStatus.approved)),
  _Entry('C28', 'Auto-approved', R.autoApproved, _order(OrderStatus.autoApproved)),
  _Entry('C29', 'Cancel booking', R.cancel, _order(OrderStatus.searching)),
  _Entry('C29c', 'Cancel after washer accepted', R.cancel, _order(OrderStatus.onTheWay)),
  _Entry('C29b', 'Cancelled – refund started', R.cancelled, _order(OrderStatus.cancelled)),
  // 03 · Problems
  _Entry('C31', 'Report – what happened', R.reportProblem, _order(OrderStatus.photosReady)),
  _Entry('C32', 'Report – add photos', R.problemPhotos, _order(OrderStatus.photosReady)),
  _Entry('C33', 'Report sent – under review', R.disputeSent, _order(OrderStatus.disputed)),
  _Entry('C34', 'Decision – in your favour', R.disputeDecision, _order(OrderStatus.disputeUpheld)),
  _Entry('C35', 'Decision – wash looks complete', R.disputeDecision, _order(OrderStatus.disputeRejected)),
  _Entry('C36', 'Damage reported – serious', R.disputeDecision, (app, m) async {
    await _signIn(app, m);
    app.setOrder(m.sampleDamageOrder());
  }),
  _Entry('C37', 'Refund status', R.refund, _order(OrderStatus.cancelled)),
  // 04 · Home, bookings, account, system
  _Entry('C40', 'Home – first time', R.home, (app, m) async {
    await _signIn(app, m);
    m.demo.emptyHistory = true;
  }),
  _Entry('C41', 'Home – active booking', R.home, _order(OrderStatus.onTheWay)),
  _Entry('C42', 'Home – free wash credits', R.home, (app, m) async => _signIn(app, m, free: 2)),
  _Entry('C43', 'Bookings – upcoming', R.bookings, _order(OrderStatus.onTheWay)),
  _Entry('C43b', 'Bookings – empty', R.bookings, (app, m) async {
    await _signIn(app, m);
    m.demo.emptyHistory = true;
  }),
  _Entry('C43c', 'Bookings – past', '${R.bookings}?tab=past', (app, m) async => _signIn(app, m)),
  _Entry('C44', 'Booking detail – past', R.bookingDetail, (app, m) async {
    await _signIn(app, m);
    app.setOrder(await m.getOrder('ord_past1'));
  }),
  _Entry('C45', 'Repeat booking', R.repeat, (app, m) async {
    await _signIn(app, m);
    app.draft.startRepeat(MockBackend.ananyaCar);
    app.draft.note = const EntryNote(voiceSeconds: 12);
  }),
  _Entry('C46', 'Vehicles', R.vehicles, (app, m) async => _signIn(app, m)),
  _Entry('C47', 'Profile', R.profile, (app, m) async => _signIn(app, m, free: 2)),
  const _Entry('C48', 'Help and support', R.help),
  _Entry('C53', 'Delete account dialog', '${R.profile}?state=delete', (app, m) async => _signIn(app, m, free: 2)),
  _Entry('C49', 'Notifications – ask first', R.notifyAsk, _order(OrderStatus.searching)),
  const _Entry('C50', 'Offline', R.offline),
  const _Entry('C51', 'Something went wrong', R.error),
  const _Entry('C54', 'Session expired', R.sessionExpired),
  _Entry('C55', 'Home – loading skeleton', '${R.home}?state=loading', (app, m) async => _signIn(app, m)),
  _Entry('C52', 'Vehicle type at 200% text', '${R.vehicleType}?state=large', (app, m) async => _draftBasics(app)),
  // 05 · Android differences
  _Entry('CA1', 'Android – home', R.home, _order(OrderStatus.onTheWay),
      'Same screen; Android shows Material system bars and back gesture.'),
  const _Entry('CA2', 'Android – location permission (system)', null, null,
      'Drawn by Android when the app asks for location. Nothing to build; the in-app fallback is C09b.'),
  const _Entry('CA3', 'Android – UPI app chooser (system)', null, null,
      'Shown by the payment SDK (UPI intent) on Android. Returns to C18 Payment processing.'),
  _Entry('CA4', 'Android – back while paying', R.payMethod, _payReady, 'Press the back button on the pay screen.'),
];

class _DevGalleryScreenState extends State<DevGalleryScreen> {
  Future<void> _open(_Entry e) async {
    final app = AppScope.read(context);
    final mock = app.backend as MockBackend;
    if (e.route == null) {
      showWSnack(context, e.note ?? 'System screen');
      return;
    }
    // Every entry starts from a clean demo state.
    mock.demo.reset();
    mock.clearSamples();
    app.currentOrder = null;
    await e.prep?.call(app, mock);
    app.changed();
    if (!mounted) return;
    if (e.note != null) showWSnack(context, e.note!);
    context.push(e.route!);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final backend = app.backend;
    if (backend is! MockBackend) {
      return const Scaffold(body: Center(child: Text('The gallery works in mock mode only.')));
    }
    final demo = backend.demo;
    Widget toggle(String label, bool value, ValueChanged<bool> set) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: WText.bodyStrong),
          value: value,
          onChanged: (v) => setState(() => set(v)),
        );

    return WScreen(
      header: WHeader(
        appBar: WAppBar(title: 'Screen gallery', subtitle: 'Demo mode · sample data', onBack: () => context.go(R.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(WSpace.gutter, 8, WSpace.gutter, 32),
        children: [
          Text('Run the real flow', style: WText.section),
          const SizedBox(height: 8),
          Text(
            'These switches change what happens when you book from the start. Login code: ${MockBackend.demoOtp}.',
            style: WText.caption,
          ),
          const SizedBox(height: 8),
          WSegmented(
            labels: const ['Pay OK', 'Pay fails', 'Pay pending'],
            index: PaymentOutcome.values.indexOf(demo.payment),
            onTap: (i) => setState(() => demo.payment = PaymentOutcome.values[i]),
          ),
          toggle('No washer found', demo.noWasherFound, (v) => demo.noWasherFound = v),
          toggle('Washer runs late', demo.washerRunsLate, (v) => demo.washerRunsLate = v),
          toggle('Washer can’t find vehicle', demo.washerCantFind, (v) => demo.washerCantFind = v),
          toggle('Gate pass never arrives', demo.entryPassNeverArrives, (v) => demo.entryPassNeverArrives = v),
          toggle('Back photo fails once', demo.failBackPhotoOnce, (v) => demo.failBackPhotoOnce = v),
          toggle('Dispute is rejected', demo.disputeRejected, (v) => demo.disputeRejected = v),
          toggle('Offline', demo.offline, (v) => demo.offline = v),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: WButton(
                label: 'Start as guest',
                onPressed: () {
                  backend.signOutForDemo();
                  backend.clearSamples();
                  app.draft.clear();
                  app.currentOrder = null;
                  app.changed();
                  context.go(R.splash);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WButton(
                variant: WButtonVariant.tonal,
                label: 'As Ananya',
                onPressed: () {
                  backend.signInAsSample();
                  backend.clearSamples();
                  app.currentOrder = null;
                  app.changed();
                  context.go(R.home);
                },
              ),
            ),
          ]),
          const SizedBox(height: 28),
          Text('Every screen (${_entries.length})', style: WText.section),
          const SizedBox(height: 8),
          for (final e in _entries)
            WListRow(
              leading: SizedBox(width: 48, child: Text(e.id, style: WText.label.copyWith(color: WColors.primaryStrong))),
              title: e.title,
              subtitle: e.route == null ? 'System screen · info only' : null,
              onTap: () => _open(e),
            ),
        ],
      ),
    );
  }
}
