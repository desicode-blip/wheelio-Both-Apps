/// Apple registers its token asynchronously, including after permission is granted.
/// Never fetch an FCM token before APNs is ready or for a signed-out account.
Future<bool> waitForApns({
  required Future<String?> Function() readToken,
  required bool Function() stillCurrent,
  Future<void> Function(Duration)? pause,
}) async {
  final wait = pause ?? Future<void>.delayed;
  for (final delay in [0, 250, 500, 1000, 2000, 3000]) {
    if (!stillCurrent()) return false;
    if (delay > 0) await wait(Duration(milliseconds: delay));
    if (!stillCurrent()) return false;
    final token = await readToken();
    if (!stillCurrent()) return false;
    if (token != null && token.isNotEmpty) return true;
  }
  throw StateError(
    'iPhone push registration is not ready yet. Check your connection and reopen the app to retry. Your updates remain in the inbox.',
  );
}
