/// A lost callable response is success only when a fresh, authenticated server
/// read confirms that this app role has finished deletion. Pending is not done.
Future<void> runAccountDeletion({
  required String role,
  required Future<Map<String, dynamic>> Function() remove,
  required bool Function(Object) canReconcile,
  required Future<Map<String, dynamic>?> Function() readProfile,
  required Future<void> Function() signOut,
}) async {
  try {
    final result = await remove();
    if (result['deleted'] != true) {
      throw StateError('Account deletion has not finished. Try again.');
    }
  } catch (error, stack) {
    var completed = false;
    if (canReconcile(error)) {
      try {
        final profile = await readProfile();
        completed =
            profile?['deletionStatus'] == 'completed' ||
            (profile?['deletedRoles'] is Map &&
                profile!['deletedRoles'][role] != null &&
                profile['deletingRole'] != role);
      } catch (_) {
        // Failure to read is never evidence of successful deletion.
      }
    }
    if (!completed) Error.throwWithStackTrace(error, stack);
  }
  await signOut();
}
