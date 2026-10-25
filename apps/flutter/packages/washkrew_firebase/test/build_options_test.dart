import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:washkrew_firebase/src/build_options.dart';
import 'package:washkrew_firebase/src/ios_options.dart';

FirebaseOptions resolve({
  bool ios = true,
  bool captain = false,
  bool emulator = false,
  String project = '',
  bool configured = false,
}) => buildOptions(
  nativeIos: ios,
  captain: captain,
  emulator: emulator,
  projectId: project,
  apiKey: configured ? 'local-api-key' : '',
  appId: configured ? 'local-app-id' : '',
  messagingSenderId: configured ? '123' : '',
  authDomain: configured ? '$project.firebaseapp.com' : '',
  storageBucket: configured ? '$project.appspot.com' : '',
);

void main() {
  test('native defaults select the registered app for each role', () {
    expect(resolve(), customerIos);
    expect(resolve(captain: true), captainIos);
    expect(resolve(project: 'wheelio-apps'), customerIos);
  });
  test(
    'emulators reject production and missing project before initialization',
    () {
      for (final ios in [true, false]) {
        for (final project in ['', 'wheelio-apps']) {
          expect(
            () => resolve(
              ios: ios,
              emulator: true,
              project: project,
              configured: true,
            ),
            throwsStateError,
          );
        }
      }
    },
  );
  test('native emulators use only the supplied demo project and bucket', () {
    final result = resolve(
      emulator: true,
      project: 'demo-wheelio',
      configured: true,
    );
    expect(result.projectId, 'demo-wheelio');
    expect(result.storageBucket, 'demo-wheelio.appspot.com');
    expect(result.appId, 'local-app-id');
    expect(result.iosBundleId, customerIos.iosBundleId);
  });
  test('web keeps the supplied build configuration', () {
    expect(
      resolve(ios: false, project: 'demo-wheelio', configured: true).projectId,
      'demo-wheelio',
    );
    expect(() => resolve(ios: false), throwsStateError);
  });
  test('native production builds reject an unrelated project override', () {
    expect(
      () => resolve(project: 'another-project', configured: true),
      throwsStateError,
    );
    expect(
      () => resolve(emulator: true, project: 'demo-wheelio'),
      throwsStateError,
    );
  });
}
