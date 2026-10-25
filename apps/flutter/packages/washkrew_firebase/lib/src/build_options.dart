import 'package:firebase_core/firebase_core.dart';

import 'ios_options.dart';

/// Resolve and validate the target before initializing any Firebase SDK.
FirebaseOptions buildOptions({
  required bool nativeIos,
  required bool captain,
  required bool emulator,
  required String projectId,
  required String apiKey,
  required String appId,
  required String messagingSenderId,
  required String authDomain,
  required String storageBucket,
}) {
  if (emulator && !projectId.startsWith('demo-')) {
    throw StateError('Emulator builds require a demo Firebase project.');
  }
  if (nativeIos && !emulator) {
    final options = iosOptions(captain: captain);
    if (projectId.isNotEmpty && projectId != options.projectId) {
      throw StateError(
        'This iPhone build is registered with ${options.projectId}.',
      );
    }
    return options;
  }
  if ([projectId, apiKey, appId, messagingSenderId].any((v) => v.isEmpty)) {
    throw StateError('Firebase has not been configured for this build.');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
    iosBundleId: nativeIos ? iosOptions(captain: captain).iosBundleId : null,
  );
}
