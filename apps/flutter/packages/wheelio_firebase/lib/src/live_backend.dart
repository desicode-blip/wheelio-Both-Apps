import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

import 'checkout_stub.dart'
    if (dart.library.js_interop) 'checkout_web.dart'
    as checkout;

class WheelioRuntime {
  static bool get demo => Uri.base.queryParameters['demo'] == 'true';
  static LiveBackend? backend;
}

class LiveBackend {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final storage = FirebaseStorage.instance;
  ConfirmationResult? _confirmation;
  bool _otpConfirmed = false;
  String pendingPhone = '';
  String? get uid => auth.currentUser?.uid;
  bool get phoneVerified => auth.currentUser?.phoneNumber != null;
  Stream<User?> get sessions => auth.idTokenChanges();

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        )
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> requestOtp(String raw) async {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(national))
      throw ArgumentError('Enter a valid 10-digit mobile number.');
    _confirmation = null;
    _otpConfirmed = false;
    pendingPhone = national;
    final current = auth.currentUser;
    if (current != null && current.phoneNumber == null) {
      _confirmation = await current.linkWithPhoneNumber('+91$national');
    } else {
      _confirmation = await auth.signInWithPhoneNumber('+91$national');
    }
  }

  Future<void> verifyOtp(
    String code, {
    required String role,
    String name = '',
  }) async {
    if (!_otpConfirmed) {
      final confirmation = _confirmation;
      if (confirmation == null) throw StateError('Request a new SMS code.');
      await confirmation.confirm(code);
      _otpConfirmed = true;
      _confirmation = null;
    }
    // Sign-in/link already returned a fresh token. Retrying account registration
    // must not consume the one-use SMS session a second time.
    await call('registerAccount', {'role': role, 'name': name});
    _otpConfirmed = false;
  }

  void invalidateOtp() {
    _confirmation = null;
    _otpConfirmed = false;
    pendingPhone = '';
  }

  Future<void> signOut() async {
    invalidateOtp();
    await auth.signOut();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> get catalog =>
      db.doc('config/operations').snapshots();
  Future<void> refreshCatalog() async {
    await db.enableNetwork();
    await db.doc('config/operations').get(const GetOptions(source:Source.server)).timeout(const Duration(seconds:15));
  }
  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      db.doc('users/$uid').snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> captain(String uid) =>
      db.doc('captains/$uid').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> orders(
    String uid, {
    bool captain = false,
  }) => db
      .collection('orders')
      .where(captain ? 'captainId' : 'customerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> offers(String uid) =>
      db.collection('jobOffers').where('captainId', isEqualTo: uid).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> earnings(String uid) =>
      db.collection('earnings').where('captainId', isEqualTo: uid).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> tracking(String orderId) =>
      db.doc('orders/$orderId/tracking/current').snapshots();
  Future<void> saveName(String name) => db.doc('users/$uid').update({
    'name': name.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<Map<String, dynamic>> pay(String bookingId) async {
    final options = await call('createCheckout', {'bookingId': bookingId});
    if (options['paid'] == true)
      return call('checkPayment', {'bookingId': bookingId});
    final result = await checkout.openCheckout(
      options,
      auth.currentUser?.phoneNumber ?? '',
    );
    if (result == null)
      return {
        'bookingId': bookingId,
        'status': 'pendingPayment',
        'paymentStatus': 'unpaid',
      };
    return call('verifyPayment', {
      'bookingId': bookingId,
      'orderId': result['razorpay_order_id'],
      'paymentId': result['razorpay_payment_id'],
      'signature': result['razorpay_signature'],
    });
  }

  Future<void> uploadEvidence({
    required String orderId,
    required bool after,
    required int side,
    required Uint8List bytes,
  }) async {
    if (bytes.length > 8 * 1024 * 1024)
      throw ArgumentError('Choose a photo smaller than 8 MB.');
    final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final png =
        bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final webp =
        bytes.length > 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
    if (!jpeg && !png && !webp)
      throw ArgumentError('Choose a JPEG, PNG or WebP photo.');
    final stage = after ? 'after' : 'before';
    final path = 'orders/$orderId/$uid/${stage}_$side.jpg';
    await storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: jpeg
                ? 'image/jpeg'
                : png
                ? 'image/png'
                : 'image/webp',
          ),
        );
    await call('recordWashEvidence', {
      'orderId': orderId,
      'stage': stage,
      'side': side,
    });
  }

  Future<Uint8List?> photo(String path) =>
      storage.ref(path).getData(8 * 1024 * 1024);
  Future<void> uploadKyc(String kind, Uint8List bytes) async {
    if (!['aadhaar', 'selfie', 'bank'].contains(kind) ||
        bytes.length > 8 * 1024 * 1024)
      throw ArgumentError('Choose an image smaller than 8 MB.');
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    await storage
        .ref('kyc/$uid/$kind.jpg')
        .putData(
          bytes,
          SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
        );
  }

  Future<void> uploadCustomerPhoto(
    String orderId,
    String angle,
    Uint8List bytes,
  ) async {
    if (bytes.length > 8 * 1024 * 1024)
      throw ArgumentError('Choose a photo smaller than 8 MB.');
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    await storage
        .ref('orders/$orderId/customer/$angle.jpg')
        .putData(
          bytes,
          SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
        );
    await call('recordCustomerPhoto', {'orderId': orderId, 'angle': angle});
  }

  Future<void> shareLocation(String orderId) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw StateError(
        'Allow location access in your browser to share your location.',
      );
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    await call('updateCaptainLocation', {
      'orderId': orderId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    });
  }
}
