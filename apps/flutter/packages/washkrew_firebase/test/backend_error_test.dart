import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

void main() {
  test('a callable timeout gives a readable retry instruction', () {
    final message = backendError(
      FirebaseFunctionsException(
        code: 'deadline-exceeded',
        message: 'deadline-exceeded',
      ),
    );
    expect(message, 'This is taking longer than expected. Please try again.');
  });
  test('a specific server validation message is preserved', () {
    expect(
      backendError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Your application is under review.',
        ),
      ),
      'Your application is under review.',
    );
  });
  test('an expired job offer keeps its actionable server message', () {
    expect(
      backendError(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'This offer expired.',
        ),
      ),
      'This offer expired.',
    );
  });
}
