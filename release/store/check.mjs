// Source checks are portable. Submission checks deliberately fail on unresolved owner inputs.
import {readFile, access} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const config = JSON.parse(await readFile(resolve(root, 'release/store/release.json'), 'utf8'));
const sourceOnly = process.argv[2] === '--source-only';
if (process.argv.length > (sourceOnly ? 3 : 2)) throw Error('Use check.mjs [--source-only].');
const problems = [];
for (const [role, app] of Object.entries(config.apps)) {
  if (app.package !== 'com.amanmaheshwari.wheelio.' + role) problems.push(role + ': wrong package');
  for (const [key, max] of [['name', 30], ['subtitle', 30], ['shortDescription', 80], ['description', 4000]])
    if (!app[key] || app[key].length > max) problems.push(`${role}: ${key} must be 1–${max} characters`);
  for (const file of ['ios/Runner/PrivacyInfo.xcprivacy', 'ios/Runner.xcworkspace/contents.xcworkspacedata', 'android/app/google-services.json'])
    await access(resolve(root, 'apps/flutter', role, file));
  if (!sourceOnly && !/^\d+$/.test(app.appStoreConnectId ?? '')) problems.push(role + ': App Store Connect numeric app ID not recorded');
}
if (!sourceOnly) {
  for (const [key, value] of Object.entries(config.approvals)) if (value !== true) problems.push('Owner/store gate: ' + key);
  await Promise.all(['privacyUrl', 'termsUrl', 'supportUrl', 'deletionUrl', 'policiesUrl'].map(async key => {
    const url = config.business[key];
    try {
      const response = await fetch(url, {signal: AbortSignal.timeout(15000)});
      const text = await response.text();
      if (!response.ok || !text.includes('WashKrew') || /REVIEW DRAFT|draft for owner review/i.test(text))
        problems.push(key + ': page missing, unapproved or incorrect');
      if (key === 'deletionUrl' && !text.includes('mailto:info@washkrew.com')) problems.push('Deletion page must offer the public request route');
    } catch { problems.push(key + ': HTTPS page is unreachable'); }
  }));
}
if (problems.length) {
  console.error('NOT READY FOR SUBMISSION:\n- ' + problems.join('\n- ')); process.exitCode = 2;
} else console.log(sourceOnly ? 'Store source/metadata checks passed. Public policies/reviewer/assets/owner gates not checked.' : 'Recorded submission gates and public URLs passed. Confirm console/signing/screenshots before final submission.');
