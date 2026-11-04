/// Recovers a lost review response from server state, without running AI again
/// or treating an unfinished check as permission to submit a wash.
Future<Map<String,dynamic>> runPhotoReview({
  required Future<Map<String,dynamic>> Function(bool statusOnly) invoke,
  required bool Function(Object error) canReconcile,
  Future<void> Function(Duration duration)? wait,
  String? requiredConsentVersion,
}) async {
  if(requiredConsentVersion!=null){
    // A read-only probe prevents a new app from accidentally sending photos
    // through an older server that ignores the new consent fields.
    final policy=await invoke(true);
    if(policy['consentPolicyVersion']!=requiredConsentVersion){
      throw StateError('Photo permission protection is awaiting a server update. Your photos have not been sent to Google AI. Try again later or contact Help.');
    }
  }
  try {
    return await invoke(false);
  } catch (error) {
    if(!canReconcile(error))rethrow;
    final delay=wait??Future<void>.delayed;
    for(var attempt=0;attempt<30;attempt++){
      final result=await invoke(true);
      if(['checked','unavailable','manualReview'].contains(result['status']))return result;
      if(result['status']!='checking')throw error;
      await delay(const Duration(seconds:2));
    }
    throw error;
  }
}
