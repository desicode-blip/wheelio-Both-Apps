// Root commands always launch the maintained Flutter apps.
import { access } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const [action, app = 'customer'] = process.argv.slice(2);
if (!['dev', 'analyze', 'test'].includes(action) || !['customer', 'captain'].includes(app)) {
  throw new Error('Use workspace.mjs dev [customer|captain], analyze, or test.');
}
const flutter = process.env.FLUTTER_BIN || 'flutter';
function run(appName, args) {
  const literal = value => `'${value.replaceAll("'", "''")}'`;
  const options = { cwd: join(root, 'apps/flutter', appName), stdio: 'inherit' };
  const result = process.platform === 'win32'
    ? spawnSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
        `& ${[flutter, ...args].map(literal).join(' ')}; exit $LASTEXITCODE`], options)
    : spawnSync(flutter, args, options);
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

if (action === 'dev') {
  const config = resolve(root, process.env.FIREBASE_CONFIG || 'firebase.local.json');
  await access(config).catch(() => {
    throw new Error('Copy firebase.example.json to firebase.local.json and configure public Firebase app IDs. See docs/FIREBASE-BOOKINGS.md.');
  });
  const port = app === 'customer' ? '8081' : '8082';
  console.log(`WashKrew ${app}: http://localhost:${port} (Flutter). Payment mode is server controlled.`);
  run(app, ['run', '-d', 'web-server', '--web-hostname=localhost', `--web-port=${port}`, `--dart-define-from-file=${config}`]);
} else {
  for (const target of ['customer', 'captain', 'packages/washkrew_ui', 'packages/washkrew_firebase']) {
    run(target, ['pub', 'get', ...(target.startsWith('packages/') ? [] : ['--enforce-lockfile'])]);
    // The UI package has no independent test suite; its widgets are covered by both apps.
    if (action === 'test' && target === 'packages/washkrew_ui') continue;
    run(target, [action]);
  }
}
