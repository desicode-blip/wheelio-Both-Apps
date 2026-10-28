import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:washkrew_ui/washkrew_ui.dart' show Brand, Permission;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'phone_otp.dart';
import 'backend.dart' show kycUploadError;

import 'checkout_stub.dart'
    if (dart.library.io) 'checkout_native.dart'
    if (dart.library.js_interop) 'checkout_web.dart'
    as checkout;

class WashKrewRuntime {
  static bool get demo =>
      Uri.base.queryParameters['demo'] == 'true' ||
      const bool.fromEnvironment('WHEELIO_DEMO');
  static LiveBackend? backend;
}

class LiveBackend {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final storage = FirebaseStorage.instance;
  late final PhoneOtpSession _phoneOtp = PhoneOtpSession(auth);
  late final PhoneOtpSession _accountOtp = PhoneOtpSession(auth);
  String get pendingPhone => _phoneOtp.phone;
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
          options: HttpsCallableOptions(timeout: Duration(seconds:name=='checkWashPhotos'?120:60)),
        )
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> requestOtp(String raw) async {
    await _phoneOtp.request(raw);
  }

  Future<void> verifyOtp(
    String code, {
    required String role,
    String name = '',
  }) async {
    await _phoneOtp.confirm(code);
    // Sign-in/link already returned a fresh token. Retrying account registration
    // must not consume the one-use SMS session a second time.
    await call('registerAccount', {'role': role, 'name': name});
    _phoneOtp.registrationCompleted();
  }

  void invalidateOtp() {
    _phoneOtp.invalidate();
    _accountOtp.invalidate();
  }

  Future<void> requestPhoneChange(String number) =>
      _accountOtp.request(number, purpose: PhoneOtpPurpose.changeNumber);
  Future<void> confirmPhoneChange(String code) async {
    await _accountOtp.confirm(code);
    await auth.currentUser!.getIdToken(true);
    await call('syncVerifiedPhone');
    _accountOtp.registrationCompleted();
  }

  Future<void> requestAccountVerification() => _accountOtp.request(
    auth.currentUser!.phoneNumber!,
    purpose: PhoneOtpPurpose.reauthenticate,
  );
  Future<void> confirmAccountVerification(String code) async {
    await _accountOtp.confirm(code);
    await auth.currentUser!.getIdToken(true);
  }

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _pushOpened;
  bool get supportsPush =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<Permission> pushPermission()async{
    final settings=await FirebaseMessaging.instance.getNotificationSettings();
    return switch(settings.authorizationStatus){AuthorizationStatus.authorized||AuthorizationStatus.provisional=>Permission.allowed,AuthorizationStatus.denied=>Permission.denied,_=>Permission.unknown};
  }
  Future<void> enablePush(String role) async {
    if (!supportsPush)
      throw StateError(
        'Push alerts are available in the iPhone app. Your inbox works here.',
      );
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      throw StateError('Allow notifications for ${Brand.name} in Settings.');
    await call('setPushPreference', {'role': role, 'enabled': true});
    await registerPush(role);
  }

  Future<void> registerPush(String role) async {
    if (!supportsPush || !phoneVerified) return;
    final account = uid;
    final prefs = (await db.doc('users/$account').get()).data();
    if (prefs?[role == 'captain'
            ? 'captainPushEnabled'
            : 'customerPushEnabled'] !=
        true)
      return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      return;
    if (await FirebaseMessaging.instance.getAPNSToken() == null)
      throw StateError(
        'iPhone push setup is not ready yet. Your booking updates remain in the inbox.',
      );
    final token = await FirebaseMessaging.instance.getToken();
    if (account != uid || token == null) return;
    await call('registerPushToken', {'token': token, 'role': role});
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
    await _tokenRefresh?.cancel();
    _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (uid == account)
        call('registerPushToken', {
          'token': token,
          'role': role,
        }).catchError((Object _) => <String, dynamic>{});
    });
  }

  void listenPush(String role, void Function(String orderId) onOpen) {
    if (!supportsPush) return;
    _pushOpened?.cancel();
    void open(RemoteMessage message) {
      if (phoneVerified &&
          message.data['role'] == role &&
          message.data['orderId'] is String)
        onOpen(message.data['orderId']);
    }

    _pushOpened = FirebaseMessaging.onMessageOpenedApp.listen(open);
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) open(m);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> inbox(String uid) => db
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Future<Map<String,dynamic>> verifyCaptainIdentity(String orderId,Uint8List bytes)async{
    final attempt=await call('beginCaptainIdentity',{'orderId':orderId});
    if(attempt['verified']==true)return {'verified':true};
    await storage.ref(attempt['path'] as String).putData(bytes,SettableMetadata(contentType:'image/jpeg'));
    return call('verifyCaptainIdentity',{'orderId':orderId,'session':attempt['session']});
  }
  Future<void> signOut() async {
    invalidateOtp();
    await _tokenRefresh?.cancel();
    if (supportsPush) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await call('removePushToken', {'token': token});
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        /* Sign-out remains available offline. Push payloads contain no private booking details. */
      }
    }
    await auth.signOut();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> get catalog =>
      db.doc('config/operations').snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> wallet(
    String uid,
    String mode,
  ) => db.doc('wallets/${uid}_$mode').snapshots();
  Future<void> refreshCatalog() async {
    await db.enableNetwork();
    await db
        .doc('config/operations')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
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

  Future<Map<String, dynamic>> pay(String bookingId, {String? method}) async {
    final options = await call('createCheckout', {'bookingId': bookingId});
    if (method != null) options['selectedMethod'] = method;
    if (options['paid'] == true)
      return call('checkPayment', {'bookingId': bookingId});
    Map<String, dynamic>? result;
    try {
      result = await checkout.openCheckout(
        options,
        auth.currentUser?.phoneNumber ?? '',
      );
    } catch (_) {
      // A native app switch can lose the SDK callback after capture. Reconcile
      // with the provider before presenting an error or permitting another try.
      try {
        final checked = await call('checkPayment', {'bookingId': bookingId});
        if (checked['paymentStatus'] == 'captured') return checked;
      } catch (_) {
        /* The existing booking remains available for recovery. */
      }
      rethrow;
    }
    if (result == null) return call('checkPayment', {'bookingId': bookingId});
    return call('verifyPayment', {
      'bookingId': bookingId,
      'orderId': result['razorpay_order_id'],
      'paymentId': result['razorpay_payment_id'],
      'signature': result['razorpay_signature'],
    });
  }

  Future<void> saveProfilePhoto(String role, Uint8List? bytes) async {
    final account = uid;
    if (!['customer', 'captain'].contains(role) || uid == null)
      throw StateError('Log in to save your photo.');
    if (bytes != null) {
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024)
        throw ArgumentError('Choose a photo smaller than 8 MB.');
      final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
      await storage
          .ref('profiles/$uid/$role.jpg')
          .putData(
            bytes,
            SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
          );
    }
    if (uid != account)
      throw StateError('Your account changed. Choose the photo again.');
    await call('saveProfilePhoto', {'role': role, 'remove': bytes == null});
  }

  Future<void> notificationAction(List<String> ids, String action) async {
    for (var start = 0; start < ids.length; start += 100) {
      await call('readNotification', {
        'notificationIds': ids.sublist(
          start,
          (start + 100).clamp(0, ids.length),
        ),
        'action': action,
      });
    }
  }

  Future<void> uploadProblemPhoto(
    String orderId,
    int side,
    Uint8List bytes,
  ) async {
    if (side < 0 || side > 2 || bytes.isEmpty || bytes.length > 8 * 1024 * 1024)
      throw ArgumentError('Choose a problem photo smaller than 8 MB.');
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    await storage
        .ref('orders/$orderId/problems/${uid}_$side.jpg')
        .putData(
          bytes,
          SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
        );
  }
  Future<void> uploadDisputeResponse(String orderId,Uint8List bytes,int seconds)async{
    final account=uid;
    await storage.ref('orders/$orderId/dispute_response/$account.m4a').putData(bytes,SettableMetadata(contentType:'audio/mp4'));
    if(uid!=account)throw StateError('Your account changed. Reopen the report.');
    await call('recordCaptainDisputeResponse',{'orderId':orderId,'seconds':seconds});
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
  Future<Set<String>> uploadedKyc() async {
    final accountId = uid;
    if (accountId == null) throw StateError('Log in to continue.');
    final uploaded = <String>{};
    await Future.wait([
      for (final kind in ['aadhaar', 'selfie', 'bank'])
        () async {
          try {
            final metadata = await storage
                .ref('kyc/$accountId/$kind.jpg')
                .getMetadata();
            if ([
                  'image/jpeg',
                  'image/png',
                  'image/webp',
                ].contains(metadata.contentType) &&
                (metadata.size ?? 0) > 0 &&
                (metadata.size ?? 0) <= 8 * 1024 * 1024) {
              uploaded.add(kind);
            }
          } on FirebaseException catch (error) {
            if (error.code != 'object-not-found') rethrow;
          }
        }(),
    ]);
    return uploaded;
  }

  Future<void> uploadKyc(String kind, Uint8List bytes) async {
    final accountId = uid;
    if (accountId == null || !phoneVerified) throw StateError('Log in as a Captain before uploading your documents.');
    if (!['aadhaar', 'selfie', 'bank'].contains(kind) ||
        bytes.isEmpty || bytes.length > 8 * 1024 * 1024)
      throw ArgumentError('Choose an image smaller than 8 MB.');
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    try {
      await storage
          .ref('kyc/$accountId/$kind.jpg')
          .putData(
            bytes,
            SettableMetadata(contentType: png ? 'image/png' : 'image/jpeg'),
          );
    } catch (error) {
      throw StateError(kycUploadError(error));
    }
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

  Future<void> uploadCustomerMedia(
    String orderId,
    String kind,
    Uint8List bytes,
    String contentType,
    int seconds,
  ) async {
    if (!['vehicle', 'note_audio', 'note_video'].contains(kind) ||
        bytes.isEmpty ||
        bytes.length > 20 * 1024 * 1024 ||
        seconds < 1 ||
        seconds > 30)
      throw ArgumentError('Choose a recording of up to 30 seconds and 20 MB.');
    final path = 'orders/$orderId/customer/$kind';
    await storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
    await call('recordCustomerMedia', {
      'orderId': orderId,
      'kind': kind,
      'seconds': seconds,
    });
  }

  Future<Uint8List?> media(String path) =>
      storage.ref(path).getData(20 * 1024 * 1024);

  Future<Position> currentPosition() async {
    var permission = await Geolocator.checkPermission().timeout(
      const Duration(seconds: 5),
    );
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'Location permission is still waiting. Respond to the browser prompt, then try sharing again.',
        ),
      );
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw StateError(
        'Allow location access for ${Brand.name} to share your location.',
      );
    final position =
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'Your location could not be found. Check ${Brand.name} location access and try again.',
          ),
        );
    return position;
  }
  Future<void> shareLocation(String orderId) async {
    final position=await currentPosition();
    await call('updateCaptainLocation', {
      'orderId': orderId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    });
  }
}
