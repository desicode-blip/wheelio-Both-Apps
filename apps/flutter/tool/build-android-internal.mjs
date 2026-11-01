import {access} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../../..');
const role=process.argv[2]??'both';
if(!['customer','captain','both'].includes(role))throw Error('Choose customer, captain or both.');
if(!process.env.WASHKREW_ANDROID_KEY_PROPERTIES)throw Error('Set WASHKREW_ANDROID_KEY_PROPERTIES to your private upload-key properties file outside Git.');
await access(process.env.WASHKREW_ANDROID_KEY_PROPERTIES);
const config=resolve(root,process.env.FIREBASE_CONFIG??'firebase.local.json');
await access(config);
const flutter=process.env.FLUTTER_BIN??'flutter';
for(const app of role==='both'?['customer','captain']:[role]){
  // These are privately signed arm64 internal-test releases. Native shrinking is
  // skipped to keep acceptance builds practical; Dart still uses release/AOT.
  // Payment mode remains server-owned and is NEVER changed by this build flag.
  const args=['build','appbundle','--release','--target-platform','android-arm64','--no-pub','--dart-define-from-file='+config];
  const options={cwd:resolve(root,'apps/flutter/'+app),stdio:'inherit',env:{...process.env,WASHKREW_ANDROID_INTERNAL_TEST:'1'}};
  const literal=v=>"'"+v.replaceAll("'","''")+"'";
  const result=process.platform==='win32'
    ?spawnSync('powershell.exe',['-NoLogo','-NoProfile','-NonInteractive','-Command','& '+[flutter,...args].map(literal).join(' ')+'; exit $LASTEXITCODE'],options)
    :spawnSync(flutter,args,options);
  if(result.error)throw result.error;
  if(result.status!==0)process.exit(result.status??1);
  console.log(app+': '+resolve(root,'apps/flutter/'+app+'/build/app/outputs/bundle/release/app-release.aab'));
}
