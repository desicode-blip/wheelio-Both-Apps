import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:washkrew_ui/washkrew_ui.dart' show Brand, Permission, aiPhotoConsentVersion;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'phone_otp.dart';
import 'checkout_flow.dart';
import 'photo_review_flow.dart';
import 'apns_readiness.dart';
import 'account_deletion.dart';
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
  late final auth = FirebaseAuth.instance;
  late final db = FirebaseFirestore.instance;
  late final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  late final storage = FirebaseStorage.instance;
  late final PhoneOtpSession _phoneOtp = PhoneOtpSession(auth);
  late final PhoneOtpSession _accountOtp = PhoneOtpSession(auth);
  String get pendingPhone => _phoneOtp.phone;
  String? get uid => auth.currentUser?.uid;
  bool get phoneVerified => auth.currentUser?.phoneNumber != null;
  String? get verifiedPhone => auth.currentUser?.phoneNumber;
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

  bool registrationInProgress = false;
  Future<Map<String,dynamic>> verifyOtp(
    String code, {
    required String role,
    String name = '',
  }) async {
    registrationInProgress = true;
    try {
    await _phoneOtp.confirm(code);
    // Sign-in/link already returned a fresh token. Retrying account registration
    // must not consume the one-use SMS session a second time.
    final result = await call('registerAccount', {'role': role, 'name': name});
    _phoneOtp.registrationCompleted();
    return result;
    } finally { registrationInProgress = false; }
  }

  /// The name saved on the Captain profile (empty when missing).
  Future<String> captainProfileName() async =>
      ((await db.doc('captains/$uid').get(const GetOptions(source:Source.server))).data()?['name'] as String?) ?? '';

  Future<Map<String,dynamic>> completeRegistration(String role,String name) =>
      call('registerAccount',{'role':role,'name':name});

  Future<Map<String,dynamic>> freshProfile() async =>
      (await db.doc('users/$uid').get(const GetOptions(source:Source.server))).data() ?? {};

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

  Future<void> deleteAppAccount(String role) {
    if (!['customer', 'captain'].contains(role) || !phoneVerified) {
      throw StateError('Open your signed-in app account before deleting it.');
    }
    final account = uid!;
    return runAccountDeletion(
      role: role,
      remove: () async {
        final result = await functions.httpsCallable('deleteOwnAccount',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
        ).call({'confirm': true, 'role': role});
        return Map<String, dynamic>.from(result.data as Map);
      },
      canReconcile: (error) => account == uid && error is FirebaseFunctionsException &&
        ['unavailable', 'deadline-exceeded', 'internal'].contains(error.code),
      readProfile: () async {
        if (account != uid) throw StateError('Your signed-in account changed.');
        return (await db.doc('users/$account').get(const GetOptions(source: Source.server))).data();
      },
      signOut: () async { if (account == uid) await signOut(); },
    );
  }

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _pushOpened;
  final Map<String, Future<void>> _pushRegistrations = {};
  int _pushGeneration = 0;
  bool get supportsPush =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<Permission> pushPermission()async{
    final settings=await FirebaseMessaging.instance.getNotificationSettings();
    return switch(settings.authorizationStatus){AuthorizationStatus.authorized||AuthorizationStatus.provisional=>Permission.allowed,AuthorizationStatus.denied=>Permission.denied,_=>Permission.unknown};
  }
  /// v2 SH-NOTIFY: show the iPhone notification prompt without needing an
  /// account yet (the server preference is saved after sign-in).
  Future<Permission> requestPushPermission() async {
    if (!supportsPush) return Permission.unknown;
    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => Permission.allowed,
      AuthorizationStatus.denied => Permission.denied,
      _ => Permission.unknown,
    };
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

  Future<void> registerPush(String role) {
    if (!supportsPush || !phoneVerified) return Future.value();
    final account = uid!, generation = _pushGeneration, key = '$uid/$role';
    final pending = _pushRegistrations[key];
    if (pending != null) return pending;
    late final Future<void> task;
    task = _registerPush(role, account, generation).whenComplete(() {
      if (identical(_pushRegistrations[key], task)) _pushRegistrations.remove(key);
    });
    _pushRegistrations[key] = task;
    return task;
  }

  Future<void> _registerPush(String role, String account, int generation) async {
    bool current() => generation == _pushGeneration && account == uid && phoneVerified;
    final prefs = (await db.doc('users/$account').get()).data();
    if (!current()) return;
    if (prefs?[role == 'captain'
            ? 'captainPushEnabled'
            : 'customerPushEnabled'] !=
        true)
      return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (!current()) return;
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      return;
    if (!await waitForApns(
      readToken: FirebaseMessaging.instance.getAPNSToken,
      stillCurrent: current,
    )) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (!current() || token == null) return;
    await call('registerPushToken', {'token': token, 'role': role});
    if (!current()) return;
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
    await _tokenRefresh?.cancel();
    _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (current())
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
      .snapshots(includeMetadataChanges:true);

  Future<Map<String,dynamic>> verifyCaptainIdentity(String orderId,Uint8List bytes)async{
    final attempt=await call('beginCaptainIdentity',{'orderId':orderId});
    if(attempt['verified']==true)return {'verified':true};
    await storage.ref(attempt['path'] as String).putData(bytes,SettableMetadata(contentType:'image/jpeg'));
    return call('verifyCaptainIdentity',{'orderId':orderId,'session':attempt['session']});
  }
  Future<Map<String,dynamic>> reviewWashPhotos(String orderId,{bool aiAllowed=false}) async {
    final result=await runPhotoReview(
    requiredConsentVersion:aiPhotoConsentVersion,
    invoke:(statusOnly)=>call('checkWashPhotos',{'orderId':orderId,'requiredConsentPolicyVersion':aiPhotoConsentVersion,if(statusOnly)'statusOnly':true,if(!statusOnly)...{'aiPhotoConsent':aiAllowed,'aiPhotoConsentVersion':aiPhotoConsentVersion}}),
    canReconcile:(error)=>error is FirebaseFunctionsException&&['unavailable','deadline-exceeded','failed-precondition'].contains(error.code),
  );
    if(result['status']=='settingsChanged')throw StateError('The AI setting or photos changed. Check the current choice and try again, or send without AI.');
    return result;
  }
  Future<void> signOut() async {
    _pushGeneration++;
    _pushRegistrations.clear();
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
      db.doc('config/operations').snapshots(includeMetadataChanges:true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> wallet(
    String uid,
    String mode,
  ) => db.doc('wallets/${uid}_$mode').snapshots(includeMetadataChanges:true);
  Stream<void> get availabilityChanges => db.doc('availabilitySignals/current').snapshots().map((_)=>null);
  Future<void> refreshCatalog() async {
    await db.enableNetwork();
    await db
        .doc('config/operations')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      db.doc('users/$uid').snapshots(includeMetadataChanges:true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> captain(String uid) =>
      db.doc('captains/$uid').snapshots(includeMetadataChanges:true);
  Stream<QuerySnapshot<Map<String, dynamic>>> orders(
    String uid, {
    bool captain = false,
  }) => db
      .collection('orders')
      .where(captain ? 'captainId' : 'customerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges:true);
  Future<Map<String,dynamic>?> readAssignedOrder(String orderId) async =>
      (await db.doc('orders/$orderId').get(const GetOptions(source:Source.server))).data();
  Stream<QuerySnapshot<Map<String, dynamic>>> offers(String uid) =>
      db.collection('jobOffers').where('captainId', isEqualTo: uid).snapshots(includeMetadataChanges:true);
  Stream<QuerySnapshot<Map<String, dynamic>>> earnings(String uid) =>
      db.collection('earnings').where('captainId', isEqualTo: uid).snapshots(includeMetadataChanges:true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> tracking(String orderId) =>
      db.doc('orders/$orderId/tracking/current').snapshots(includeMetadataChanges:true);
  Future<void> saveName(String name) => db.doc('users/$uid').update({
    'name': name.trim(),
    'customerName': name.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> preloadCheckout() async {
    try { await checkout.preloadCheckout(); }
    catch (_) { /* Optional cache fill; the Pay action retries actual loading. */ }
  }
  Future<Map<String, dynamic>> pay(String bookingId, {void Function(CheckoutStage)? onStage}) =>
      startCheckout(bookingId: bookingId, onStage: onStage);

  Future<Map<String, dynamic>> startCheckout({
    String? bookingId,
    Map<String, dynamic>? booking,
    List<CheckoutUpload> uploads = const [],
    void Function(String)? onBookingReady,
    void Function(CheckoutStage)? onStage,
  }) => CheckoutFlow(call: (name, data) => call(name, data), open: (options,phone)=>checkout.openCheckout(options,phone,onReturn:() async=>(await call('checkPayment',{'bookingId':options['bookingId']}))['paymentStatus']=='captured',
        onReturned:()=>onStage?.call(CheckoutStage.confirming)),
      phone: auth.currentUser?.phoneNumber ?? '').run(
        bookingId: bookingId, booking: booking, uploads: uploads,
        onBookingReady: onBookingReady, onStage: onStage);

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

  /// Search can reuse a granted permission; opening a field never prompts for GPS.
  Future<Position?> positionIfAllowed()async{
    final permission=await Geolocator.checkPermission().timeout(const Duration(seconds:5));
    if(permission!=LocationPermission.whileInUse&&permission!=LocationPermission.always)return null;
    return currentPosition();
  }
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
