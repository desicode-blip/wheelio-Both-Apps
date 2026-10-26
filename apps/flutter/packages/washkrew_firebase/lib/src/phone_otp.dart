import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One SMS session on either the browser or the native Firebase SDK.
/// Editing a number invalidates callbacks from older requests.
enum PhoneOtpPurpose { login, changeNumber, reauthenticate }

class PhoneOtpSession {
  PhoneOtpSession(this.auth, {bool? web}) : web = web ?? kIsWeb;
  final FirebaseAuth auth;
  final bool web;
  ConfirmationResult? _confirmation;
  String? _verificationId, _linkUid;
  PhoneAuthCredential? _automaticCredential;
  int? _resendToken;
  int _generation = 0;
  bool _confirmed = false;
  Completer<void>? _pendingRequest;
  String phone = '';
  PhoneOtpPurpose _purpose = PhoneOtpPurpose.login;
  String? _accountUid;

  Future<void> request(
    String raw, {
    PhoneOtpPurpose purpose = PhoneOtpPurpose.login,
  }) async {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final national = digits.length == 12 && digits.startsWith('91')
        ? digits.substring(2)
        : digits;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(national)) {
      throw ArgumentError('Enter a valid 10-digit mobile number.');
    }
    final resend = national == phone ? _resendToken : null;
    invalidate();
    phone = national;
    final generation = _generation;
    final user = auth.currentUser;
    _purpose = purpose;
    if (purpose != PhoneOtpPurpose.login) {
      if (user == null)
        throw StateError('Log in before changing your account.');
      if (purpose == PhoneOtpPurpose.reauthenticate &&
          user.phoneNumber != '+91$national')
        throw StateError('Verify your current mobile number.');
      _accountUid = user.uid;
    }
    _linkUid = user != null && user.phoneNumber == null ? user.uid : null;
    if (web && purpose == PhoneOtpPurpose.login) {
      final result = _linkUid != null
          ? await user!.linkWithPhoneNumber('+91$national')
          : await auth.signInWithPhoneNumber('+91$national');
      if (generation != _generation)
        throw StateError('Request a new SMS code.');
      _confirmation = result;
      return;
    }
    final sent = Completer<void>();
    _pendingRequest = sent;
    final waiting = sent.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        if (generation == _generation) invalidate();
        throw StateError(
          'SMS verification did not finish. Check your connection and request a new code.',
        );
      },
    );
    bool getCurrent() => generation == _generation;
    void ready() {
      if (!sent.isCompleted) sent.complete();
    }

    final sending = auth
        .verifyPhoneNumber(
          phoneNumber: '+91$national',
          forceResendingToken: resend,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) {
            if (!getCurrent()) return;
            _automaticCredential = credential;
            ready();
          },
          verificationFailed: (error) {
            if (!getCurrent()) return;
            if (!sent.isCompleted) sent.completeError(error);
          },
          codeSent: (verificationId, resendToken) {
            if (!getCurrent()) return;
            _verificationId = verificationId;
            _resendToken = resendToken;
            ready();
          },
          codeAutoRetrievalTimeout: (verificationId) {
            if (!getCurrent()) return;
            _verificationId = verificationId;
            ready();
          },
        )
        .catchError((Object error, StackTrace stack) {
          if (!sent.isCompleted) sent.completeError(error, stack);
        });
    try {
      await Future.wait([waiting, sending]);
    } finally {
      if (identical(_pendingRequest, sent)) _pendingRequest = null;
    }
    if (!getCurrent()) throw StateError('Request a new SMS code.');
  }

  Future<void> confirm(String code) async {
    if (_confirmed) return;
    if (web && _purpose == PhoneOtpPurpose.login) {
      if (_confirmation == null) throw StateError('Request a new SMS code.');
      await _confirmation!.confirm(code);
    } else {
      if (_automaticCredential == null && _verificationId == null) {
        throw StateError('Request a new SMS code.');
      }
      if (_automaticCredential == null && !RegExp(r'^\d{6}$').hasMatch(code)) {
        throw ArgumentError('Enter the 6-digit SMS code.');
      }
      final credential =
          _automaticCredential ??
          PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: code,
          );
      if (_purpose != PhoneOtpPurpose.login) {
        if (auth.currentUser?.uid != _accountUid)
          throw StateError('Your account changed. Request a new code.');
        if (_purpose == PhoneOtpPurpose.changeNumber)
          await auth.currentUser!.updatePhoneNumber(credential);
        else
          await auth.currentUser!.reauthenticateWithCredential(credential);
      } else if (_linkUid != null) {
        if (auth.currentUser?.uid != _linkUid)
          throw StateError('Your account changed. Request a new code.');
        await auth.currentUser!.linkWithCredential(credential);
      } else {
        await auth.signInWithCredential(credential);
      }
    }
    _confirmed = true;
    _confirmation = null;
    _automaticCredential = null;
    _verificationId = null;
  }

  /// Retain confirmation if account registration fails; do not reuse an OTP.
  void registrationCompleted() => invalidate();

  void invalidate() {
    _generation++;
    if (_pendingRequest != null && !_pendingRequest!.isCompleted) {
      _pendingRequest!.completeError(StateError('Request a new SMS code.'));
    }
    _pendingRequest = null;
    _confirmation = null;
    _verificationId = null;
    _automaticCredential = null;
    _resendToken = null;
    _linkUid = null;
    _confirmed = false;
    _purpose = PhoneOtpPurpose.login;
    _accountUid = null;
    phone = '';
  }
}
