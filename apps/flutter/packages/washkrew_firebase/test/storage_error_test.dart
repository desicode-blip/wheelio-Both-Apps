import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

void main() {
  test('failed document uploads give recovery instructions without success or sensitive provider text', () {
    for (final code in ['unauthorized', 'unauthenticated', 'unknown', 'retry-limit-exceeded', 'quota-exceeded', 'canceled']) {
      final message = kycUploadError(FirebaseException(plugin: 'firebase_storage', code: code, message: 'PRIVATE_PROVIDER_DETAIL'));
      expect(message, isNot(contains('PRIVATE_PROVIDER_DETAIL')));
      expect(message, isNot('Your changes could not be saved. Please try again.'));
    }
    expect(kycUploadError(FirebaseException(plugin: 'firebase_storage', code: 'unknown')), contains('could not be confirmed'));
    expect(kycUploadError(FirebaseException(plugin: 'firebase_storage', code: 'unauthorized')), contains('Documents cannot be replaced while under review'));
  });
}
