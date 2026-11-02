import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/apns_readiness.dart';

void main() {
  test('ready APNs token proceeds immediately without waiting', () async {
    expect(
      await waitForApns(
        readToken: () async => 'apns',
        stillCurrent: () => true,
        pause: (_) async => fail('Already ready; must not wait.'),
      ),
      isTrue,
    );
  });
  test(
    'delayed Apple token can register without another permission request',
    () async {
      var reads = 0;
      final delays = <int>[];
      expect(
        await waitForApns(
          readToken: () async => ++reads == 3 ? 'apns' : null,
          stillCurrent: () => true,
          pause: (delay) async => delays.add(delay.inMilliseconds),
        ),
        isTrue,
      );
      expect(reads, 3);
      expect(delays, [250, 500]);
    },
  );
  test(
    'sign-out during waiting stops before another native token request',
    () async {
      var current = true, reads = 0;
      expect(
        await waitForApns(
          readToken: () async {
            reads++;
            return null;
          },
          stillCurrent: () => current,
          pause: (_) async {
            current = false;
          },
        ),
        isFalse,
      );
      expect(reads, 1);
    },
  );
  test(
    'account change during token request cannot proceed with that result',
    () async {
      var current = true;
      expect(
        await waitForApns(
          readToken: () async {
            current = false;
            return 'apns';
          },
          stillCurrent: () => current,
        ),
        isFalse,
      );
    },
  );
  test(
    'unavailable APNs is bounded and gives a truthful retry instruction',
    () async {
      var reads = 0;
      await expectLater(
        waitForApns(
          readToken: () async {
            reads++;
            return null;
          },
          stillCurrent: () => true,
          pause: (_) async {},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('reopen the app to retry'),
          ),
        ),
      );
      expect(reads, 6);
    },
  );
}
