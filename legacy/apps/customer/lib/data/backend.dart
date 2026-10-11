import 'models.dart';

/// Everything the customer app needs from the server.
///
/// Two implementations:
///  * [MockBackend] (mock_backend.dart) — sample data, no network. Used today.
///  * SupabaseBackend — to be written when the Supabase project is connected.
///    The tables and functions it calls are in backend/supabase/migrations and
///    the contract is in backend/API-CONTRACT.md.
abstract class Backend {
  // ---- Auth (roadmap F08: phone + OTP, asked at the payment step) --------

  /// Sends a 6-digit code by SMS.
  Future<void> requestOtp(String phone);

  Future<OtpResult> verifyOtp(String phone, String code);

  /// The logged-in customer, or null for a guest (roadmap F01).
  Customer? get currentCustomer;

  Future<Customer> updateName(String name);

  Future<Customer> setNotifications(bool on);

  Future<void> logout();

  /// App Store requirement. Refused while a wash is in progress.
  Future<bool> deleteAccount();

  // ---- Catalogue ------------------------------------------------------------

  Future<List<VehicleType>> vehicleTypes();

  Future<List<Society>> searchSocieties(String query);

  /// The society nearest the device location, if any.
  Future<Place?> placeFromLocation(double lat, double lng);

  /// Slots for one day at this place. Full slots come back with available = false.
  Future<List<TimeSlot>> timeSlots(Place place, DateTime day);

  Future<List<PaymentMethod>> paymentMethods();

  // ---- Booking --------------------------------------------------------------

  /// Uploads one identification photo. Throws on failure.
  Future<String> uploadPhoto(PhotoAngle angle, String localPath);

  /// Creates the order in "pending payment" state.
  Future<Order> createOrder({
    required VehicleType type,
    required String plate,
    required Place place,
    required TimeSlot slot,
    required EntryNote note,
    required bool useFreeWash,
  });

  /// Starts payment. Money is held by the payment provider until approval
  /// (roadmap F09, Razorpay Route).
  Future<PaymentOutcome> pay(String orderId, PaymentMethod method);

  /// Re-checks a pending payment.
  Future<PaymentOutcome> checkPayment(String orderId);

  /// Live updates for one order (roadmap F11).
  Stream<Order> watchOrder(String orderId);

  Future<Order> getOrder(String orderId);

  Future<List<Order>> myOrders();

  Future<List<Vehicle>> myVehicles();

  /// Before a washer accepts: full refund. After: refund minus cancellation fee.
  Future<Order> cancelOrder(String orderId, {String? reason});

  /// Customer's answer when the washer can't find the vehicle.
  Future<void> answerCantFind(String orderId, String answer);

  /// Releases the held payment to the washer (roadmap F14).
  Future<Order> approve(String orderId);

  /// 1–5 stars plus quick tags (roadmap F15).
  Future<void> rate(String orderId, int stars, List<String> tags);

  /// Raises a dispute; payment stays on hold while it is checked (roadmap F16).
  Future<Dispute> reportProblem(String orderId, ProblemKind kind, {String note = '', int photoCount = 0});
}

enum OtpStatus { ok, wrong, expired, tooManyTries }

class OtpResult {
  const OtpResult(this.status, {this.triesLeft = 0, this.customer, this.isNewCustomer = false});

  final OtpStatus status;
  final int triesLeft;
  final Customer? customer;

  /// True when the customer still needs to give a name.
  final bool isNewCustomer;
}

class BackendException implements Exception {
  const BackendException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  @override
  String toString() => 'BackendException($message)';
}
