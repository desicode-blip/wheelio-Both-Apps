import 'dart:async';
import 'dart:math';

import '../config/app_config.dart';
import 'backend.dart';
import 'models.dart';

/// Switches that force edge cases so every designed state can be reached
/// without a real backend. Set from the in-app screen gallery.
class DemoScenario {
  PaymentOutcome payment = PaymentOutcome.success;
  bool noWasherFound = false;
  bool washerRunsLate = false;
  bool washerCantFind = false;
  bool entryPassNeverArrives = false;
  bool noWashersToday = false;
  bool failBackPhotoOnce = false;
  bool disputeRejected = false;
  bool offline = false;

  /// Hide past bookings and saved vehicles (first-time customer states).
  bool emptyHistory = false;

  /// Seconds between live order steps. Short so a demo takes under a minute.
  int stepSeconds = 5;

  void reset() {
    payment = PaymentOutcome.success;
    noWasherFound = false;
    washerRunsLate = false;
    washerCantFind = false;
    entryPassNeverArrives = false;
    noWashersToday = false;
    failBackPhotoOnce = false;
    disputeRejected = false;
    offline = false;
    emptyHistory = false;
    stepSeconds = 5;
  }
}

/// In-memory backend with the sample people and places from the designs
/// (Ananya, Raju, My Home Avatar Tower 3, TS 09 EA 4521).
///
/// Demo login: any valid mobile number, code 123456. Code 000000 = expired.
class MockBackend implements Backend {
  MockBackend({DateTime Function()? clock}) : _now = clock ?? DateTime.now {
    _seedPastOrders();
  }

  final DateTime Function() _now;
  final demo = DemoScenario();
  final _rng = Random();

  static const demoOtp = '123456';
  static const expiredOtp = '000000';

  // ---- Sample data -----------------------------------------------------------

  static const types = [
    VehicleType(kind: VehicleKind.bike, name: 'Bike or scooter', minutes: 15, price: 69),
    VehicleType(kind: VehicleKind.hatchback, name: 'Hatchback', minutes: 20, price: 149),
    VehicleType(kind: VehicleKind.sedan, name: 'Sedan or compact SUV', minutes: 20, price: 179),
    VehicleType(kind: VehicleKind.suv, name: 'SUV or MUV', minutes: 25, price: 219),
  ];

  static const societies = [
    Society(id: 'soc_avatar', name: 'My Home Avatar', area: 'Narsingi', city: 'Hyderabad', pincode: '500089'),
    Society(id: 'soc_avali', name: 'My Home Avali', area: 'Gachibowli', city: 'Hyderabad', pincode: '500032'),
    Society(id: 'soc_avishkaar', name: 'My Home Avishkaar', area: 'Kokapet', city: 'Hyderabad', pincode: '500075'),
  ];

  static const raju = Washer(id: 'wsh_raju', name: 'Raju', rating: 4.8, washes: 212);

  static final homePlace = Place(society: societies[0], tower: 'Tower 3', floor: 'B2', slot: '41', lat: 17.392, lng: 78.358);

  static final ananyaCar = Vehicle(id: 'veh_car', plate: 'TS 09 EA 4521', type: types[1], place: homePlace);
  static final ananyaScooter =
      Vehicle(id: 'veh_scooter', plate: 'TS 09 HB 0731', type: types[0], place: homePlace.copyWith(floor: 'B1', slot: ''));

  Customer? _customer;
  final Map<String, Order> _orders = {};
  final Map<String, List<Timer>> _timers = {};
  final _updates = StreamController<Order>.broadcast();
  final List<Vehicle> _vehicles = [];
  int _otpTries = 0;
  int _refCounter = 20914;
  bool _backPhotoFailed = false;

  Future<void> _latency([int ms = 450]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    if (demo.offline) throw const BackendException('No internet connection', offline: true);
  }

  String _nextRef() => 'WH-${_refCounter++}';

  void _seedPastOrders() {
    final today = _dateOnly(_now());
    Order past(String id, DateTime day, Vehicle v, OrderStatus status, {Refund? refund, int? rating}) => Order(
          id: id,
          ref: 'WH-${20800 + _orders.length * 13}',
          vehicle: v,
          place: v.place ?? homePlace,
          slot: TimeSlot(date: day, startHour: 8, endHour: 10),
          price: v.type.price,
          status: status,
          createdAt: day,
          washer: status == OrderStatus.cancelled ? null : raju,
          startedAt: day.add(const Duration(hours: 8, minutes: 32)),
          finishedAt: day.add(const Duration(hours: 8, minutes: 54)),
          beforePhotos: 4,
          afterPhotos: 4,
          rating: rating,
          refund: refund,
          entryPassReceived: true,
          paidWith: const PaymentMethod(id: 'gpay', title: 'Google Pay', detail: 'ananya@okhdfc', kind: 'upi'),
        );
    final d1 = today.subtract(const Duration(days: 7));
    final d2 = today.subtract(const Duration(days: 10));
    final d3 = today.subtract(const Duration(days: 13));
    _orders['ord_past1'] = past('ord_past1', d1, ananyaCar, OrderStatus.approved, rating: 4);
    _orders['ord_past2'] = past('ord_past2', d2, ananyaCar, OrderStatus.noWasher,
        refund: Refund(amount: 149, startedAt: d2, method: 'Google Pay · ananya@okhdfc', bankRef: 'RZP8812001', credited: true));
    _orders['ord_past3'] = past('ord_past3', d3, ananyaScooter, OrderStatus.cancelled);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _emit(Order o) {
    _orders[o.id] = o;
    _updates.add(o);
  }

  void _schedule(String orderId, int afterSteps, void Function() fn) {
    final t = Timer(Duration(seconds: demo.stepSeconds * afterSteps), () {
      if (_orders.containsKey(orderId)) fn();
    });
    _timers.putIfAbsent(orderId, () => []).add(t);
  }

  void _cancelTimers(String orderId) {
    for (final t in _timers.remove(orderId) ?? const <Timer>[]) {
      t.cancel();
    }
  }

  // ---- Auth -------------------------------------------------------------------

  @override
  Customer? get currentCustomer => _customer;

  @override
  Future<void> requestOtp(String phone) async {
    await _latency(700);
    _otpTries = 0;
  }

  @override
  Future<OtpResult> verifyOtp(String phone, String code) async {
    await _latency(600);
    if (code == expiredOtp) return const OtpResult(OtpStatus.expired);
    if (code != demoOtp) {
      _otpTries++;
      final left = 3 - _otpTries;
      return OtpResult(left <= 0 ? OtpStatus.tooManyTries : OtpStatus.wrong, triesLeft: max(left, 0));
    }
    final known = phone == '9848011223';
    _customer = Customer(id: 'cus_${phone.hashCode.abs()}', phone: phone, name: known ? 'Ananya Rao' : '');
    if (known && _vehicles.isEmpty) _vehicles.addAll([ananyaCar, ananyaScooter]);
    return OtpResult(OtpStatus.ok, customer: _customer, isNewCustomer: !known);
  }

  /// Gallery shortcut: log in as the sample customer.
  void signInAsSample({int freeWashes = 0}) {
    _customer = Customer(id: 'cus_ananya', phone: '9848011223', name: 'Ananya Rao', freeWashes: freeWashes, notificationsOn: true);
    if (_vehicles.isEmpty) _vehicles.addAll([ananyaCar, ananyaScooter]);
  }

  void signOutForDemo() {
    _customer = null;
    _vehicles.clear();
  }

  @override
  Future<Customer> updateName(String name) async {
    await _latency();
    final c = _customer;
    if (c == null) throw const BackendException('Not logged in');
    _customer = c.copyWith(name: name.trim());
    return _customer!;
  }

  @override
  Future<Customer> setNotifications(bool on) async {
    await _latency(200);
    final c = _customer;
    if (c == null) throw const BackendException('Not logged in');
    _customer = c.copyWith(notificationsOn: on);
    return _customer!;
  }

  @override
  Future<void> logout() async {
    await _latency(200);
    _customer = null;
    _vehicles.clear();
  }

  @override
  Future<bool> deleteAccount() async {
    await _latency();
    if (_orders.values.any((o) => o.status == OrderStatus.washing)) return false;
    _customer = null;
    _vehicles.clear();
    _orders.clear();
    return true;
  }

  // ---- Catalogue ----------------------------------------------------------------

  @override
  Future<List<VehicleType>> vehicleTypes() async {
    await _latency(250);
    return types;
  }

  @override
  Future<List<Society>> searchSocieties(String query) async {
    await _latency(250);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return societies;
    return societies.where((s) => '${s.name} ${s.area}'.toLowerCase().contains(q)).toList();
  }

  @override
  Future<Place?> placeFromLocation(double lat, double lng) async {
    await _latency(400);
    return Place(society: societies[0], tower: 'Tower 3', lat: lat, lng: lng);
  }

  @override
  Future<List<TimeSlot>> timeSlots(Place place, DateTime day) async {
    await _latency(300);
    final now = _now();
    final isToday = _dateOnly(day) == _dateOnly(now);
    const windows = [(6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18)];
    return [
      for (final (s, e) in windows)
        TimeSlot(
          date: _dateOnly(day),
          startHour: s,
          endHour: e,
          available: !(isToday && (demo.noWashersToday || now.hour >= e - 1 || s == 6)),
        ),
    ];
  }

  @override
  Future<List<PaymentMethod>> paymentMethods() async {
    await _latency(200);
    final upiId = _customer?.phone == '9848011223' ? 'ananya@okhdfc' : 'Pay with UPI';
    return [
      PaymentMethod(id: 'gpay', title: 'Google Pay', detail: 'UPI · $upiId', kind: 'upi_app'),
      const PaymentMethod(id: 'phonepe', title: 'PhonePe', detail: 'UPI', kind: 'upi_app'),
      const PaymentMethod(id: 'upi_id', title: 'Other UPI app', detail: 'Enter UPI ID', kind: 'upi_id'),
      const PaymentMethod(id: 'card', title: 'Card', detail: 'Debit or credit', kind: 'card'),
    ];
  }

  // ---- Booking ------------------------------------------------------------------

  @override
  Future<String> uploadPhoto(PhotoAngle angle, String localPath) async {
    await _latency(700);
    if (demo.failBackPhotoOnce && angle == PhotoAngle.back && !_backPhotoFailed) {
      _backPhotoFailed = true;
      throw const BackendException('Upload failed');
    }
    return 'mock://photos/${angle.name}_${_rng.nextInt(99999)}.jpg';
  }

  @override
  Future<Order> createOrder({
    required VehicleType type,
    required String plate,
    required Place place,
    required TimeSlot slot,
    required EntryNote note,
    required bool useFreeWash,
  }) async {
    await _latency();
    final vehicle = _vehicles.firstWhere(
      (v) => v.plate == plate,
      orElse: () {
        final v = Vehicle(id: 'veh_${_rng.nextInt(1 << 30)}', plate: plate, type: type, place: place);
        _vehicles.add(v);
        return v;
      },
    );
    final order = Order(
      id: 'ord_${_rng.nextInt(1 << 30)}',
      ref: _nextRef(),
      vehicle: vehicle,
      place: place,
      slot: slot,
      price: type.price,
      status: OrderStatus.pendingPayment,
      createdAt: _now(),
      note: note,
      usedFreeWash: useFreeWash,
    );
    _orders[order.id] = order;
    return order;
  }

  @override
  Future<PaymentOutcome> pay(String orderId, PaymentMethod method) async {
    await _latency(2200);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    switch (demo.payment) {
      case PaymentOutcome.failed:
        return PaymentOutcome.failed;
      case PaymentOutcome.pending:
        _emit(o.copyWith(status: OrderStatus.paymentPending, paidWith: method));
        return PaymentOutcome.pending;
      case PaymentOutcome.success:
        _startLifecycle(o.copyWith(paidWith: method));
        return PaymentOutcome.success;
    }
  }

  @override
  Future<PaymentOutcome> checkPayment(String orderId) async {
    await _latency(1200);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    // In the demo a pending payment clears on the second check.
    demo.payment = PaymentOutcome.success;
    _startLifecycle(o);
    return PaymentOutcome.success;
  }

  void _startLifecycle(Order paid) {
    final id = paid.id;
    _emit(paid.copyWith(status: OrderStatus.searching));
    if (demo.noWasherFound) {
      _schedule(id, 1, () {
        final o = _orders[id]!;
        _emit(o.copyWith(status: OrderStatus.noWasher, refund: _refundFor(o)));
      });
      return;
    }
    _schedule(id, 1, () {
      final o = _orders[id]!;
      final arrives = _now().add(const Duration(minutes: 25));
      _emit(o.copyWith(status: OrderStatus.onTheWay, washer: raju, arrivesBy: arrives));
    });
    if (!demo.entryPassNeverArrives) {
      _schedule(id, 2, () => _emit(_orders[id]!.copyWith(entryPassReceived: true)));
    }
    var nextStep = 3;
    if (demo.washerRunsLate) {
      _schedule(id, 2, () => _emit(_orders[id]!.copyWith(runningLateBy: const Duration(minutes: 15))));
      nextStep++;
    }
    if (demo.washerCantFind) {
      // Waits for the customer's answer; see [answerCantFind].
      _schedule(id, nextStep, () => _emit(_orders[id]!.copyWith(washerCantFind: true)));
      return;
    }
    _scheduleWash(id, nextStep);
  }

  void _scheduleWash(String id, int fromStep) {
    _schedule(id, fromStep, () {
      _emit(_orders[id]!.copyWith(status: OrderStatus.washing, startedAt: _now(), beforePhotos: 4));
    });
    _schedule(id, fromStep + 2, () {
      final done = _now();
      _emit(_orders[id]!.copyWith(
        status: OrderStatus.photosReady,
        finishedAt: done,
        afterPhotos: 4,
        autoApproveAt: done.add(const Duration(hours: 2)),
      ));
    });
  }

  Refund _refundFor(Order o, {int? amount}) => Refund(
        amount: amount ?? o.price,
        startedAt: _now(),
        method: o.paidWith == null ? 'UPI' : '${o.paidWith!.title} · ${o.paidWith!.detail.replaceFirst('UPI · ', '')}',
        bankRef: 'RZP${8812000 + _rng.nextInt(99999)}',
      );

  @override
  Stream<Order> watchOrder(String orderId) async* {
    final current = _orders[orderId];
    if (current != null) yield current;
    yield* _updates.stream.where((o) => o.id == orderId);
  }

  @override
  Future<Order> getOrder(String orderId) async {
    await _latency(150);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    return o;
  }

  @override
  Future<List<Order>> myOrders() async {
    await _latency(350);
    if (_customer == null || demo.emptyHistory) return [];
    final list = _orders.values.where((o) => o.status != OrderStatus.pendingPayment).toList()
      ..sort((a, b) => b.slot.start.compareTo(a.slot.start));
    return list;
  }

  @override
  Future<List<Vehicle>> myVehicles() async {
    await _latency(250);
    if (demo.emptyHistory) return const [];
    return List.unmodifiable(_vehicles);
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    await _latency(800);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    _cancelTimers(orderId);
    // After a washer accepts, [CANCELLATION FEE] applies. Not decided yet, so 0.
    final fee = o.status == OrderStatus.onTheWay ? (AppConfig.cancellationFeeRupees ?? 0) : 0;
    final cancelled = o.copyWith(status: OrderStatus.cancelled, refund: _refundFor(o, amount: o.price - fee));
    _emit(cancelled);
    return cancelled;
  }

  @override
  Future<void> answerCantFind(String orderId, String answer) async {
    await _latency(300);
    final o = _orders[orderId];
    if (o == null) return;
    if (answer == 'not_here') {
      await cancelOrder(orderId, reason: 'vehicle_not_here');
      return;
    }
    _emit(o.copyWith(washerCantFind: false));
    _scheduleWash(orderId, 1);
  }

  @override
  Future<Order> approve(String orderId) async {
    await _latency(600);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    _cancelTimers(orderId);
    final approved = o.copyWith(status: OrderStatus.approved);
    _emit(approved);
    return approved;
  }

  /// Gallery shortcut: let the approval window run out.
  void forceAutoApprove(String orderId) {
    final o = _orders[orderId];
    if (o != null) _emit(o.copyWith(status: OrderStatus.autoApproved));
  }

  @override
  Future<void> rate(String orderId, int stars, List<String> tags) async {
    await _latency(400);
    final o = _orders[orderId];
    if (o != null) _emit(o.copyWith(rating: stars));
  }

  @override
  Future<Dispute> reportProblem(String orderId, ProblemKind kind, {String note = '', int photoCount = 0}) async {
    await _latency(900);
    final o = _orders[orderId];
    if (o == null) throw const BackendException('Order not found');
    _cancelTimers(orderId);
    final dispute = Dispute(
      ref: _nextRef(),
      kind: kind,
      createdAt: _now(),
      note: note,
      outcome: kind == ProblemKind.damage ? DisputeOutcome.damagePriority : DisputeOutcome.underReview,
    );
    _emit(o.copyWith(status: OrderStatus.disputed, dispute: dispute));
    if (kind != ProblemKind.damage) {
      _schedule(orderId, 2, () {
        final cur = _orders[orderId]!;
        if (demo.disputeRejected) {
          _emit(cur.copyWith(
            status: OrderStatus.disputeRejected,
            dispute: Dispute(
              ref: dispute.ref,
              kind: kind,
              createdAt: dispute.createdAt,
              note: note,
              outcome: DisputeOutcome.rejected,
              decisionNote: 'The scratch near the left door is visible in the before-photo.',
            ),
          ));
        } else {
          _customer = _customer?.copyWith(freeWashes: (_customer?.freeWashes ?? 0) + 2);
          _emit(cur.copyWith(
            status: OrderStatus.disputeUpheld,
            refund: _refundFor(cur),
            dispute: Dispute(
              ref: dispute.ref,
              kind: kind,
              createdAt: dispute.createdAt,
              note: note,
              outcome: DisputeOutcome.upheld,
              decisionNote: 'The after-photos show streaks on the bonnet.',
              creditsAwarded: 2,
            ),
          ));
        }
      });
    }
    return dispute;
  }

  /// Gallery helper: an order in a given state, built from sample data.
  Order sampleOrder(OrderStatus status, {bool passMissing = false, bool isLate = false, bool cantFind = false}) {
    final now = _now();
    final slot = TimeSlot(date: _dateOnly(now), startHour: 8, endHour: 10);
    final order = Order(
      id: 'ord_sample_${status.name}${passMissing ? '_pass' : ''}${isLate ? '_late' : ''}${cantFind ? '_find' : ''}',
      ref: 'WH-20914',
      vehicle: ananyaCar,
      place: homePlace,
      slot: slot,
      price: 149,
      status: status,
      createdAt: now,
      note: const EntryNote(voiceSeconds: 12),
      washer: status == OrderStatus.searching ? null : raju,
      arrivesBy: now.add(const Duration(minutes: 25)),
      runningLateBy: isLate ? const Duration(minutes: 15) : null,
      startedAt: now.subtract(const Duration(minutes: 22)),
      finishedAt: now.subtract(const Duration(minutes: 1)),
      autoApproveAt: now.add(const Duration(hours: 2)),
      entryPassReceived: !passMissing,
      washerCantFind: cantFind,
      beforePhotos: 4,
      afterPhotos: 4,
      paidWith: const PaymentMethod(id: 'gpay', title: 'Google Pay', detail: 'ananya@okhdfc', kind: 'upi'),
      refund: switch (status) {
        OrderStatus.cancelled || OrderStatus.noWasher || OrderStatus.disputeUpheld =>
          Refund(amount: 149, startedAt: now, method: 'Google Pay · ananya@okhdfc', bankRef: 'RZP8812093'),
        _ => null,
      },
      dispute: switch (status) {
        OrderStatus.disputed => Dispute(ref: 'WH-20914', kind: ProblemKind.notClean, createdAt: now),
        OrderStatus.disputeUpheld => Dispute(
            ref: 'WH-20914',
            kind: ProblemKind.notClean,
            createdAt: now,
            outcome: DisputeOutcome.upheld,
            decisionNote: 'The after-photos show streaks on the bonnet.',
            creditsAwarded: 2),
        OrderStatus.disputeRejected => Dispute(
            ref: 'WH-20914',
            kind: ProblemKind.damage,
            createdAt: now,
            outcome: DisputeOutcome.rejected,
            decisionNote: 'The scratch near the left door is visible in the before-photo.'),
        _ => null,
      },
    );
    _orders[order.id] = order;
    return order;
  }

  /// Gallery helper: a damage report in priority handling.
  Order sampleDamageOrder() {
    final base = sampleOrder(OrderStatus.disputed);
    final o = base.copyWith(
      dispute: Dispute(ref: 'WH-20915', kind: ProblemKind.damage, createdAt: _now(), outcome: DisputeOutcome.damagePriority),
    );
    _orders[o.id] = o;
    return o;
  }

  /// Gallery helper: remove the sample orders made by [sampleOrder].
  void clearSamples() {
    _orders.removeWhere((id, _) => id.startsWith('ord_sample_'));
  }

  void dispose() {
    for (final id in _timers.keys.toList()) {
      _cancelTimers(id);
    }
    _updates.close();
  }
}
