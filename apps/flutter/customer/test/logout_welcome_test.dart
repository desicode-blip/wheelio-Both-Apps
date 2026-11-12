import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/store.dart';

// 13 Nov (Aman): logged out → the Welcome slides; logged in → Home as before.
void main() {
  test('logging out shows Welcome again', () {
    final s = AppStore()..signInAsSample()..hasSeenWelcome = true;
    expect(s.isLoggedIn, isTrue);
    s.signOut();
    expect(s.isLoggedIn, isFalse);
    expect(s.hasSeenWelcome, isFalse);
    s.dispose();
  });
}
