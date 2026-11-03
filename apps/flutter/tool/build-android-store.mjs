// Production bundles: all supported ABIs, R8/resource shrinking, private upload signing.
// This command builds artifacts only. It never publishes a release or changes Firebase.
import {access, copyFile, mkdir, readFile, writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const role = process.argv[2] ?? 'both';
if (!['both', 'customer', 'captain'].includes(role) || process.argv.length > 3)
  throw Error('Use build-android-store.mjs [both|customer|captain].');
const signing = process.env.WASHKREW_ANDROID_KEY_PROPERTIES;
if (!signing) throw Error('Set WASHKREW_ANDROID_KEY_PROPERTIES to the existing private upload properties file outside Git.');
await access(signing);
const flutter = process.env.FLUTTER_BIN ?? 'flutter';
const env = {...process.env, WASHKREW_ANDROID_INTERNAL_TEST: '0'};
function run(executable, args, cwd = root, capture = false) {
  const options = {cwd, env, ...(capture ? {encoding: 'utf8'} : {stdio: 'inherit'})};
  const literal = v => "'" + v.replaceAll("'", "''") + "'";
  const result = process.platform === 'win32' && (/\.(bat|cmd)$/i.test(executable) || executable === 'flutter')
    ? spawnSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
      '& ' + [executable, ...args].map(literal).join(' ') + '; exit $LASTEXITCODE'], options)
    : spawnSync(executable, args, options);
  if (result.error) throw result.error;
  if (result.status !== 0) throw Error(`${executable} failed (${result.status}). ${capture ? result.stderr : ''}`);
  return capture ? result.stdout.trim() : '';
}
const version = JSON.parse(run(flutter, ['--version', '--machine'], root, true));
if (version.frameworkVersion !== '3.38.6') throw Error('Use the pinned Flutter 3.38.6 SDK for this release.');
const sourceCommit = run('git', ['rev-parse', 'HEAD'], root, true);
const sourceDirty = run('git', ['status', '--porcelain', '--untracked-files=no'], root, true) !== '';
const destination = resolve(root, 'build/store/android');
await mkdir(destination, {recursive: true});
for (const app of role === 'both' ? ['customer', 'captain'] : [role]) {
  const cwd = resolve(root, 'apps/flutter', app);
  const spec = await readFile(resolve(cwd, 'pubspec.yaml'), 'utf8');
  const [, name, number] = spec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m) ?? [];
  if (!number) throw Error(`${app}: invalid source version.`);
  run(flutter, ['pub', 'get', '--enforce-lockfile'], cwd);
  run(flutter, ['build', 'appbundle', '--release', '--no-pub', '--target-platform=android-arm,android-arm64,android-x64',
    '--dart-define=WHEELIO_DEMO=false', '--dart-define=FIREBASE_USE_EMULATORS=false'], cwd);
  const prefix = `WashKrew-${app === 'customer' ? 'Customer' : 'Captain'}-${name}-${number}`;
  const bundle = resolve(destination, prefix + '.aab');
  await copyFile(resolve(cwd, 'build/app/outputs/bundle/release/app-release.aab'), bundle);
  // Keep R8 mappings alongside their exact bundle for Play diagnostics.
  const mapping = resolve(destination, prefix + '-mapping.txt');
  await copyFile(resolve(cwd, 'build/app/outputs/mapping/release/mapping.txt'), mapping);
  const sha256 = createHash('sha256').update(await readFile(bundle)).digest('hex');
  await writeFile(resolve(destination, prefix + '.json'), JSON.stringify({
    app, package: 'com.amanmaheshwari.wheelio.' + app, version: name, build: Number(number),
    sourceCommit, sourceDirty, flutter: version.frameworkVersion, builtAt: new Date().toISOString(),
    profile: 'store', nativeShrinking: true, abis: ['armeabi-v7a', 'arm64-v8a', 'x86_64'],
    firebaseProject: 'wheelio-apps', demo: false, emulators: false, sha256,
    validation: 'Run verify-android-store.py before uploading. Building does not publish.',
  }, null, 2) + '\n');
  console.log(`Store bundle: ${bundle}\nSHA-256: ${sha256}`);
}
