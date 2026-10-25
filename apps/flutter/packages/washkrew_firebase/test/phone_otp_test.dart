import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/phone_otp.dart';

class FakeCredentialResult extends Fake implements UserCredential {}

class FakeAuth extends Fake implements FirebaseAuth {
  User? user;
  int confirmations = 0;
  String? requestedPhone;
  PhoneCodeSent? sent;
  PhoneVerificationFailed? failed;
  PhoneVerificationCompleted? automatic;
  @override
  User? get currentUser => user;
  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
    String? autoRetrievedSmsCodeForTesting,
  }) async {
    requestedPhone = phoneNumber;
    sent = codeSent;
    failed = verificationFailed;
    automatic = verificationCompleted;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    confirmations++;
    return FakeCredentialResult();
  }
}

void main() {
  test(
    'native code is verified once while failed account registration can retry',
    () async {
      final auth = FakeAuth(),
          session = PhoneOtpSession(FakeAuth(), web: false);
      final actual = PhoneOtpSession(auth, web: false);
      final sending = actual.request('+91 90000 00001');
      auth.sent!('native-verification', null);
      await sending;
      expect(auth.requestedPhone, '+919000000001');
      await actual.confirm('123456');
      await actual.confirm('123456');
      expect(auth.confirmations, 1);
      actual.registrationCompleted();
      await expectLater(actual.confirm('123456'), throwsStateError);
      await expectLater(session.request('123'), throwsArgumentError);
    },
  );

  test(
    'editing a number invalidates old native callbacks and prevents stale confirmation',
    () async {
      final auth = FakeAuth(),
          session = PhoneOtpSession(FakeAuth(), web: false);
      final actual = PhoneOtpSession(auth, web: false);
      final sending = actual.request('9000000001');
      final oldCallback = auth.sent!;
      final cancelled = expectLater(sending, throwsStateError);
      actual.invalidate();
      oldCallback('obsolete', null);
      await cancelled;
      await expectLater(actual.confirm('123456'), throwsStateError);
      expect(auth.confirmations, 0);
      expect(session.phone, '');
    },
  );

  test(
    'native provider failures restore the UI instead of hanging a request',
    () async {
      final auth = FakeAuth();
      final session = PhoneOtpSession(auth, web: false);
      final sending = session.request('9000000001');
      auth.failed!(FirebaseAuthException(code: 'quota-exceeded'));
      await expectLater(sending, throwsA(isA<FirebaseAuthException>()));
      final retry = session.request('9000000001');
      auth.sent!('retry-session', null);
      await retry;
      await session.confirm('123456');
      expect(auth.confirmations, 1);
    },
  );
}
