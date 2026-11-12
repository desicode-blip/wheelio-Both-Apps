/// Request only app features, one OS dialog at a time. A denial is a valid
/// answer, not a reason to block onboarding or repeatedly ask at launch.
Future<void> runPermissionSequence({
  required Future<bool> Function(String) alreadyAsked,
  required Future<void> Function(String) remember,
  required Future<void> Function(String) request,
}) async {
  for (final name in ['camera', 'microphone', 'location', 'notifications']) {
    if (await alreadyAsked(name)) continue;
    try {
      await request(name);
      await remember(name);
    } catch (_) {
      // An interrupted/platform-unavailable request is retryable next launch.
      // One unavailable feature must not suppress the other OS prompts.
    }
  }
}
