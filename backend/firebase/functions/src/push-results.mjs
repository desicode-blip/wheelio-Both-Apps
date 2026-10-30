// Firebase can resolve a multicast request while every per-device delivery
// failed (for example, missing APNs credentials). Do not mistake that for success.
// Extract only bounded error codes/counts, never tokens or provider messages.
const invalidTokenCodes = new Set([
  'messaging/registration-token-not-registered', 'messaging/invalid-registration-token',
]);
const configurationCodes = new Set([
  'messaging/third-party-auth-error', 'messaging/invalid-apns-credentials',
  'messaging/mismatched-credential', 'messaging/authentication-error',
]);
export function pushResultSummary(result, count) {
  const summary = {sent: 0, failed: 0, invalidTokenIndexes: [], errors: {}, configurationError: false};
  for (let index = 0; index < count; index++) {
    const response = result?.responses?.[index];
    if (response?.success === true) { summary.sent++; continue; }
    const raw = response?.error?.code;
    const code = typeof raw === 'string' && /^messaging\/[a-z-]{1,80}$/.test(raw)
      ? raw : 'messaging/incomplete-response';
    summary.failed++;
    summary.errors[code] = (summary.errors[code] ?? 0) + 1;
    if (invalidTokenCodes.has(code)) summary.invalidTokenIndexes.push(index);
    if (configurationCodes.has(code)) summary.configurationError = true;
  }
  return summary;
}
