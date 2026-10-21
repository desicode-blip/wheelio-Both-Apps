// One static deployment: landing /, Customer /app/, Captain /captain/.
import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const configPath = resolve(root, process.argv[2] ?? 'firebase.local.json');
const config = JSON.parse(await readFile(configPath, 'utf8'));
for (const key of ['FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID', 'FIREBASE_APP_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_AUTH_DOMAIN']) {
  if (!config[key]) throw new Error(`${key} is missing in ${configPath}`);
}
const flutter = process.env.FLUTTER_BIN ?? 'flutter';
const output = resolve(root, process.argv[3] ?? 'build/firebase-hosting');
await mkdir(output, { recursive: true });
function runFlutter(cwd,args) {
  const literal = (value) => `'${value.replaceAll("'", "''")}'`;
  const result = process.platform === 'win32'
    ? spawnSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
        `& ${[flutter, ...args].map(literal).join(' ')}; exit $LASTEXITCODE`], { cwd, stdio: 'inherit' })
    : spawnSync(flutter, args, { cwd, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
for (const [app, path] of [['customer', 'app'], ['captain', 'captain']]) {
  const cwd = join(root, 'apps/flutter', app);
  // A shared path package may add plugins without changing either app pubspec.
  runFlutter(cwd,['pub','get']);
  // FlutterFire restores Auth emulator routing during debug initialization.
  const mode = config.FIREBASE_USE_EMULATORS ? '--debug' : '--release';
  const args = ['build', 'web', mode, '--pwa-strategy=none', '--no-wasm-dry-run', `--base-href=/${path}/`, `--dart-define-from-file=${configPath}`];
  // Quote Windows paths as PowerShell literals; do not concatenate raw shell arguments.
  runFlutter(cwd,args);
  await cp(join(cwd, 'build/web'), join(output, path), { recursive: true });
}
await cp(join(root, 'apps/hosting'), output, { recursive: true });
await cp(join(root, 'apps/flutter/packages/wheelio_ui/lib/fonts'), join(output, 'fonts'), { recursive: true });
await writeFile(join(output, 'robots.txt'), 'User-agent: *\nDisallow: /app/\nDisallow: /captain/\n');
console.log(`Firebase Hosting build ready: ${output}`);
