// Mobile (iOS / Android) versions of the device services. Speech and system notifications
// are wired when the native builds start (flutter_tts, firebase_messaging); until then the
// owner's note "plays" for its length on a timer.

import 'dart:async';

import 'device.dart' show Permission;
Future<void> downloadDocument(Future<String> url) async => throw StateError('Open this document from the app.');

void ding() {}
Permission notificationPermission() => Permission.unknown;
Future<Permission> requestNotifications() async => Permission.unknown;
void systemNotify(String title, String body, bool silent) {}
bool appIsActive() => true;
bool isTouchDevice() => true;

void Function() speak(String text, String lang, void Function() onEnd) {
  final t = Timer(const Duration(seconds: 12), onEnd);
  return t.cancel;
}
