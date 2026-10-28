import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'build_options.dart';

/// No service-account keys belong in an app. These are Firebase public app IDs.
class WashKrewFirebase {
  static Future<void> initialize({required bool captain}) async {
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const emulator = bool.fromEnvironment('FIREBASE_USE_EMULATORS');
    final options = buildOptions(
      nativeIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      captain: captain,
      emulator: emulator,
      projectId: projectId,
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
    await Firebase.initializeApp(options: options);
    if (emulator) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    }
    if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
}

String backendError(Object error) {
  // Error identifiers only: never log phone numbers, OTPs, provider payloads or tokens.
  if (error is FirebaseException)
    debugPrint('Firebase operation failed: ${error.plugin}/${error.code}');
  if (error is FirebaseFunctionsException)
    return error.message ??
        'This action could not be completed. Please try again.';
  if (error is ArgumentError) return error.message.toString();
  if (error is StateError) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' =>
        'This email already has an account. Choose Log in.',
      'weak-password' => 'Use a password with at least 8 characters.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' => 'Check your connection and try again.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled yet. Please try email sign-in or contact the WashKrew team.',
      'invalid-verification-code' =>
        'That code does not match. Check the SMS and try again.',
      'session-expired' => 'The code expired. Request a new code.',
      'requires-recent-login' => 'For your security, sign out and log in again before changing your account.',
      'credential-already-in-use' || 'phone-number-already-exists' => 'This mobile number is linked to another account. Choose a different number.',
      'quota-exceeded' || 'billing-not-enabled' =>
        'SMS sign-in is currently unavailable. Please use email sign-in.',
      _ => 'Sign-in could not be completed. Please try again.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'This action is not allowed for your account.',
      'unavailable' =>
        'We could not reach WashKrew. Check your connection and try again.',
      _ => 'Your changes could not be saved. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}

/// Upload-specific wording must not mislabel errors from reading existing photos.
String kycUploadError(Object error) {
  if (error is FirebaseException && error.plugin == 'firebase_storage') {
    debugPrint('KYC photo upload failed: ${error.plugin}/${error.code}');
    return switch (error.code) {
      'unauthenticated' => 'Log in again, then retry the photo upload.',
      'unauthorized' || 'permission-denied' =>
        'The photo upload was blocked. Refresh your application status and try again. Documents cannot be replaced while under review or after approval.',
      'retry-limit-exceeded' || 'unavailable' || 'unknown' =>
        'The photo upload could not be confirmed. Check your connection and try again.',
      'quota-exceeded' => 'Photo uploads are temporarily unavailable. Please try again later.',
      'canceled' => 'The photo upload was cancelled. Please try again.',
      _ => 'The photo could not be saved. Please try again.',
    };
  }
  return backendError(error);
}
