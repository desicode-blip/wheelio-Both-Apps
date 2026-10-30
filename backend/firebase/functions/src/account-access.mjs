const customerMethods = new Set(['checkAddress','createBooking','checkout','verifyPayment','checkPayment','customerPhoto','customerMedia','approve','rate','cancel','getCancellationQuote','reportProblem','savePlace','createDocument']);
const captainMethods = new Set(['captainOnline','captainPreferences','captainPosition','submitCaptainApplication','startTraining','trainingHeartbeat','submitQuiz','beginIdentity','verifyIdentity','checkWashPhotos','captainPayout','claim','reject','progress','evidenceUploaded','location','captainDisputeResponse']);

// Cached tokens from a removed role cannot recreate app data. Registering that
// role again requires fresh SMS authentication in the registration transaction.
export function removedAppAccess(profile, method, data = {}) {
  if (['deleteAccount','register'].includes(method)) return false;
  if (profile?.deletionStatus) return true;
  const role = customerMethods.has(method) ? 'customer' : captainMethods.has(method) ? 'captain' :
    ['profilePhoto','setPushPreference','registerPushToken','notificationPreferences','supportRequest'].includes(method) ? data.role :
    method === 'vehicleHelp' ? (data.action === 'request' ? 'captain' : 'customer') : null;
  return !!role && (!!profile?.deletedRoles?.[role] || profile?.deletingRole === role);
}
