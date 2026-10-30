// Optional: keep only three short interactive reads/saves warm. Payment, photo,
// scheduled and background controllers retain the global scale-to-zero policy.
// Local emulators never reserve instances. CPU, memory and maxInstances remain
// capped by the existing global configuration unless a photo check needs more.
const warmMethods = new Set(['availability', 'savePlace', 'captainPreferences']);
// Owner is asking Aman about the recurring idle cost. Do not enable it merely
// because the code was pulled or redeployed; wait for that explicit decision.
export const interactiveWarmMinimum = 0;
export function callableRuntime(method, emulator = process.env.FUNCTIONS_EMULATOR === 'true', minimum = interactiveWarmMinimum) {
  if (minimum !== 0 && minimum !== 1) throw new Error('Interactive warming must be zero or one.');
  return {
    minInstances: !emulator && warmMethods.has(method) ? minimum : 0,
    ...(['checkWashPhotos', 'verifyIdentity'].includes(method)
      ? {timeoutSeconds: 120, memory: '512MiB'} : {}),
  };
}
