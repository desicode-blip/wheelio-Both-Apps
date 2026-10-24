import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';

import '../data/models.dart';
import '../data/store.dart';

/// Screens gallery (demo mode only). Opens every designed screen and state (C01–C55)
/// with the right sample data, and holds the switches that force edge cases in the live flow.
class _E {
  const _E(this.id, this.title, this.prep, {this.route, this.tab});
  final String id;
  final String title;
  final void Function(AppStore s) prep;
  final R? route;

  /// -1 = splash; 0…3 = a tab.
  final int? tab;
}

void _none(AppStore s) {}

final _sections = <(String, List<_E>)>[
  ('01 · Book a wash', [
    const _E('C01', 'Splash', _none, tab: -1),
    _E('C02', 'Welcome', (s) => s.signOut(), route: const R(N.welcome)),
    _E('C05', 'Vehicle type', (s) => s.draftBasics(), route: const R(N.vehicleType)),
    _E('C05w', 'Wash type – car', (s) => s..draftBasics()..draft.wash = null, route: const R(N.washType)),
    _E('C05wb', 'Wash type – bike', (s) => s..draftBasics()..draft.type = VehicleType.all[0]..draft.wash = null, route: const R(N.washType)),
    _E('C06', 'Vehicle number', (s) => s.draftBasics(), route: const R(N.vehicleNumber)),
    _E('C07', 'Vehicle photos – empty', (s) => s.draftBasics(), route: const R(N.photos)),
    _E('C07b', 'Vehicle photos – one failed', (s) => s..draftBasics()..draft.photos[PhotoAngle.front] = UploadState.done..draft.photos[PhotoAngle.back] = UploadState.failed, route: const R(N.photos)),
    _E('C07c', 'Vehicle photos – all done', (s) => s..draftFull()..draft.place = null, route: const R(N.photos)),
    _E('C08', 'Camera – guided angle', (s) => s.draftBasics(), route: const R(N.camera, angle: PhotoAngle.front)),
    const _E('C08b', 'Camera access needed', _none, route: R(N.camera, angle: PhotoAngle.front, denied: true)),
    _E('C09', 'Confirm location', (s) => s..draftFull()..draft.place = null, route: const R(N.location)),
    const _E('C09b', 'Location is off', _none, route: R(N.location, off: true)),
    _E('C09c', 'Search address', (s) => s.draftFull(), route: const R(N.addressSearch)),
    _E('C09d', 'Type the address by hand', (s) => s.draftFull(), route: const R(N.manualAddress)),
    _E('C10', 'Floor and slot', (s) => s.draftFull(), route: const R(N.floorSlot)),
    _E('C11', 'Message for the captain – nothing yet', (s) => s..draftFull()..draft.note = EntryNote(), route: const R(N.entryNotes)),
    _E('C11v', 'Message – voice note + text', (s) => s..draftFull()..draft.note = EntryNote(text: 'White car next to the pillar', voiceSeconds: 12), route: const R(N.entryNotes)),
    _E('C11d', 'Message – video recorded', (s) => s..draftFull()..draft.note = EntryNote(videoSeconds: 15), route: const R(N.entryNotes)),
    _E('C12', 'Pick a time', (s) => s.draftFull(), route: const R(N.timeSlot)),
    _E('C12b', 'No captains free today', (s) => s..draftFull()..demo.noCaptainsToday = true, route: const R(N.timeSlot)),
    _E('C13', 'Check and pay', (s) => s.draftFull(), route: const R(N.review)),
    _E('C14', 'Log in with phone', (s) => s..signOut()..draftFull(), route: const R(N.login)),
    _E('C14b', 'Phone number – invalid', (s) => s.signOut(), route: const R(N.login, error: true)),
    _E('C15', 'Enter code', (s) => s.pendingPhone = AppStore.samplePhone, route: const R(N.otp)),
    _E('C15b', 'Code – wrong', (s) => s.pendingPhone = AppStore.samplePhone, route: const R(N.otp, otp: OtpStart.wrong)),
    _E('C15c', 'Code – expired', (s) => s.pendingPhone = AppStore.samplePhone, route: const R(N.otp, otp: OtpStart.expired)),
    _E('C16', 'Your name', (s) => s.signInAsSample(), route: const R(N.name)),
    _E('C17', 'Payment method sheet', (s) => s..signInAsSample()..draftFull(), route: const R(N.review)),
    _E('C18', 'Payment processing', (s) => s..signInAsSample()..draftFull(), route: const R(N.paying)),
    _E('C18b', 'Payment failed', (s) => s..signInAsSample()..draftFull(), route: const R(N.paying, pay: PayView.failed)),
    _E('C18c', 'Payment pending', (s) => s..signInAsSample()..draftFull()..sampleOrder(OrderStatus.paymentPending), route: const R(N.paying, pay: PayView.pending)),
    _E('C19', 'Booked – send entry pass', (s) => s..signInAsSample()..sampleOrder(OrderStatus.searching), route: const R(N.booked)),
    _E('C19b', 'WhatsApp bot (reference)', (s) => s..signInAsSample()..sampleOrder(OrderStatus.searching), route: const R(N.whatsApp)),
  ]),
  ('02 · Live order, approve, cancel', [
    _E('C20', 'Finding a captain', (s) => s..signInAsSample()..sampleOrder(OrderStatus.searching), route: const R(N.live)),
    _E('C21', 'No captain found – add UPI for refund', (s) => s..signInAsSample()..customer?.refundUPI = null..sampleOrder(OrderStatus.noCaptain), route: const R(N.live)),
    _E('C21u', 'Refund UPI ID', (s) => s..signInAsSample()..customer?.refundUPI = null..sampleOrder(OrderStatus.noCaptain), route: const R(N.refundUPI, id: 'current')),
    _E('C24x', 'Captain no-show – checking', (s) => s..signInAsSample()..markNoShowChecking(), route: const R(N.live)),
    _E('C24y', 'Captain no-show – refunded', (s) => s..signInAsSample()..customer?.refundUPI = null..sampleOrder(OrderStatus.captainNoShow), route: const R(N.live)),
    _E('C22', 'Captain on the way', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay), route: const R(N.live)),
    _E('C22b', 'Entry pass missing', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay, passMissing: true), route: const R(N.live)),
    _E('C24', 'Captain running late', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay, late: true), route: const R(N.live)),
    _E('C30', 'Captain can’t find vehicle', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay, cantFind: true), route: const R(N.live)),
    _E('C23', 'Washing in progress', (s) => s..signInAsSample()..sampleOrder(OrderStatus.washing), route: const R(N.live)),
    _E('C25', 'Wash done – check photos', (s) => s..signInAsSample()..sampleOrder(OrderStatus.photosReady), route: const R(N.live)),
    _E('C26', 'Photo compare', (s) => s..signInAsSample()..sampleOrder(OrderStatus.photosReady), route: const R(N.photoCompare)),
    _E('C27', 'Rate the captain', (s) => s..signInAsSample()..sampleOrder(OrderStatus.approved), route: const R(N.rate)),
    _E('C28', 'Approved automatically', (s) => s..signInAsSample()..sampleOrder(OrderStatus.autoApproved), route: const R(N.live)),
    _E('C29', 'Cancel sheet (open from C20)', (s) => s..signInAsSample()..sampleOrder(OrderStatus.searching), route: const R(N.live)),
    _E('C29c', 'Cancel after accept (open from C22)', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay), route: const R(N.live)),
    _E('C29b', 'Booking cancelled', (s) => s..signInAsSample()..sampleOrder(OrderStatus.cancelled), route: const R(N.live)),
  ]),
  ('03 · Problems, disputes, refunds', [
    _E('C31', 'Report a problem', (s) => s..signInAsSample()..sampleOrder(OrderStatus.photosReady), route: const R(N.reportProblem)),
    _E('C31s', 'Report a problem – photos skipped', (s) => s..signInAsSample()..sampleOrder(OrderStatus.photosReady, skippedPhotos: true), route: const R(N.reportProblem)),
    _E('C32', 'Show us the problem', (s) => s..signInAsSample()..sampleOrder(OrderStatus.photosReady), route: const R(N.problemPhotos, kind: ProblemKind.notClean)),
    _E('C33', 'Report sent – under review', (s) => s..signInAsSample()..sampleOrder(OrderStatus.disputed, dispute: DisputeOutcome.underReview), route: const R(N.disputeStatus)),
    _E('C34', 'Dispute upheld', (s) => s..signInAsSample()..sampleOrder(OrderStatus.disputeUpheld, dispute: DisputeOutcome.upheld), route: const R(N.disputeStatus)),
    _E('C35', 'Dispute rejected', (s) => s..signInAsSample()..sampleOrder(OrderStatus.disputeRejected, dispute: DisputeOutcome.rejected), route: const R(N.disputeStatus)),
    _E('C36', 'Damage report', (s) => s..signInAsSample()..sampleOrder(OrderStatus.disputed, dispute: DisputeOutcome.damagePriority, damage: true), route: const R(N.disputeStatus)),
    _E('C37', 'Refund status', (s) => s..signInAsSample()..sampleOrder(OrderStatus.cancelled), route: const R(N.refund)),
  ]),
  ('04 · Home, bookings, account, system', [
    _E('C40', 'Home – first time (now: straight to vehicle)', (s) => s..signInAsSample()..demo.emptyHistory = true, tab: 0),
    _E('C40h', 'Home – first time (hidden design)', (s) => s..signInAsSample()..demo.emptyHistory = true..showFirstWashHome = true, tab: 0),
    _E('C41', 'Home – active booking', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay), tab: 0),
    _E('C42', 'Home – free washes', (s) => s.signInAsSample(2), tab: 0),
    _E('C43', 'Bookings – upcoming', (s) => s..signInAsSample()..sampleOrder(OrderStatus.onTheWay), tab: 1),
    _E('C43b', 'Bookings – empty', (s) => s..signInAsSample()..demo.emptyHistory = true, tab: 1),
    _E('C43c', 'Bookings – past', (s) => s.signInAsSample(), tab: 1),
    _E('C44', 'Booking detail', (s) => s.signInAsSample(), route: const R(N.bookingDetail, id: 'ord_past1')),
    _E('C45', 'Book again', (s) => s.signInAsSample(), route: const R(N.repeatBooking, id: 'veh_car')),
    _E('C46', 'Your vehicles', (s) => s.signInAsSample(), tab: 2),
    _E('C47', 'Profile', (s) => s.signInAsSample(2), tab: 3),
    const _E('C48', 'Help', _none, route: R(N.help)),
    _E('N1', 'Notifications', (s) => s.signInAsSample(), route: const R(N.notifications)),
    _E('N2', 'Notification settings', (s) => s.signInAsSample(), route: const R(N.notificationSettings)),
    _E('C49', 'Notifications ask', (s) => s..signInAsSample()..sampleOrder(OrderStatus.searching), route: const R(N.notifyAsk)),
    const _E('C50', 'Offline', _none, route: R(N.offline)),
    const _E('C51', 'Server error', _none, route: R(N.serverError)),
    _E('C52', '200% text', (s) => s.draftBasics(), route: const R(N.vehicleType, large: true)),
    _E('C53', 'Delete account (Profile → Delete)', (s) => s.signInAsSample(2), tab: 3),
    _E('C54', 'Session expired', (s) => s.signInAsSample(), route: const R(N.sessionExpired)),
  ]),
];

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  void _open(BuildContext context, _E e) {
    final store = context.store, router = context.router;
    store.resetDemo();
    e.prep(store);
    store.changed();
    if (e.tab == -1) {
      router.popToRoot();
      router.setSplash(true);
      return;
    }
    if (e.tab != null) {
      store.set(() => store.hasSeenWelcome = true);
      router.tab = e.tab!;
      router.popToRoot();
      return;
    }
    final r = e.route!;
    if (r.n == N.welcome) {
      store.set(() => store.hasSeenWelcome = false);
      router.popToRoot();
      return;
    }
    router.replace([r]);
    if (e.id == 'C17') Future.delayed(const Duration(milliseconds: 600), () => router.openPaySheet(true));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final d = store.demo;
    Widget toggle(String title, bool on, void Function(bool) set) =>
        WToggleRow(padding: const EdgeInsets.symmetric(vertical: 6), on: on, onChanged: (v) => store.set(() => set(v)), child: WText(title, WType.body, size: 15, color: WColor.heading));
    return WScreen(
      header: WAppBar(title: 'Screens', subtitle: 'Demo mode · sample data', trailing: null, onLeading: context.router.pop),
      children: [
        const WSectionLabel('Switches for the live flow', top: 10),
        toggle('Payment fails', d.payment == PaymentOutcome.failed, (v) => d.payment = v ? PaymentOutcome.failed : PaymentOutcome.success),
        toggle('Payment stays pending', d.payment == PaymentOutcome.pending, (v) => d.payment = v ? PaymentOutcome.pending : PaymentOutcome.success),
        toggle('No captain found', d.noCaptainFound, (v) => d.noCaptainFound = v),
        toggle('Captain runs late', d.captainRunsLate, (v) => d.captainRunsLate = v),
        toggle('Captain doesn’t show up', d.captainNoShow, (v) => d.captainNoShow = v),
        toggle('Captain can’t find vehicle', d.captainCantFind, (v) => d.captainCantFind = v),
        toggle('Entry pass never arrives', d.entryPassNeverArrives, (v) => d.entryPassNeverArrives = v),
        toggle('Back photo fails once', d.failBackPhotoOnce, (v) => d.failBackPhotoOnce = v),
        toggle('Dispute gets rejected', d.disputeRejected, (v) => d.disputeRejected = v),
        const SizedBox(height: 8),
        WButton('Reset demo', kind: ButtonKind.tonal, onTap: store.resetDemo),
        for (final s in _sections) ...[
          Padding(padding: const EdgeInsets.only(top: 22, bottom: 4), child: WText(s.$1, WType.section, weight: semibold)),
          for (final e in s.$2) ...[
            Pressable(
              feedback: false,
              onTap: () => _open(context, e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  SizedBox(width: 46, child: WText(e.id, WType.label, color: WColor.primaryStrong)),
                  const SizedBox(width: 12),
                  Expanded(child: WText(e.title, WType.rowTitle)),
                  const WIconView(WIcon.chevron, size: 12, color: WColor.secondary),
                ]),
              ),
            ),
            const WDivider(),
          ],
        ],
      ],
    );
  }
}
