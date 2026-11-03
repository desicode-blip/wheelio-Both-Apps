import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/src/account_deletion.dart';

void main() {
  for (final role in ['customer', 'captain']) {
    test('$role deletes and signs out only after server completion', () async {
      var signedOut = false;
      await runAccountDeletion(
        role: role,
        remove: () async => {'deleted': true},
        canReconcile: (_) => false,
        readProfile: () async => throw StateError('No recovery needed.'),
        signOut: () async {
          signedOut = true;
        },
      );
      expect(signedOut, isTrue);
    });
    test('$role lost response recovers only this completed role', () async {
      var signedOut = false, calls = 0;
      await runAccountDeletion(
        role: role,
        remove: () async {
          calls++;
          throw StateError('Response lost');
        },
        canReconcile: (_) => true,
        readProfile: () async => {
          'deletedRoles': {role: 1},
        },
        signOut: () async {
          signedOut = true;
        },
      );
      expect(calls, 1);
      expect(signedOut, isTrue);
    });
  }
  for (final profile in <Map<String, dynamic>?>[
    null,
    {},
    {'deletionStatus': 'pending'},
    {
      'deletedRoles': {'captain': 1},
    },
    {
      'deletedRoles': {'customer': 1},
      'deletingRole': 'customer',
    },
  ]) {
    test(
      'incomplete/other-role status $profile cannot claim success',
      () async {
        var signedOut = false;
        await expectLater(
          runAccountDeletion(
            role: 'customer',
            remove: () async => throw StateError('Response lost'),
            canReconcile: (_) => true,
            readProfile: () async => profile,
            signOut: () async {
              signedOut = true;
            },
          ),
          throwsStateError,
        );
        expect(signedOut, isFalse);
      },
    );
  }
  test(
    'last-role completed tombstone recovers without another delete request',
    () async {
      var signedOut = false;
      await runAccountDeletion(
        role: 'captain',
        remove: () async => throw StateError('Response lost'),
        canReconcile: (_) => true,
        readProfile: () async => {'deletionStatus': 'completed'},
        signOut: () async {
          signedOut = true;
        },
      );
      expect(signedOut, isTrue);
    },
  );
  test(
    'authorization failure does not read recovery data or sign out',
    () async {
      await expectLater(
        runAccountDeletion(
          role: 'customer',
          remove: () async => throw StateError('Open booking'),
          canReconcile: (_) => false,
          readProfile: () async =>
              fail('Authorization/business failures cannot reconcile.'),
          signOut: () async => fail('Account was not deleted.'),
        ),
        throwsStateError,
      );
    },
  );
  test('failed server read cannot turn a timeout into success', () async {
    await expectLater(
      runAccountDeletion(
        role: 'customer',
        remove: () async => throw StateError('Response lost'),
        canReconcile: (_) => true,
        readProfile: () async => throw StateError('Offline'),
        signOut: () async => fail('No proof of deletion.'),
      ),
      throwsStateError,
    );
  });
}
