import {cp,mkdir,writeFile,readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,join} from 'node:path';
const root=fileURLToPath(new URL('../../',import.meta.url));
export async function buildAdmin(config,output){
  await mkdir(output,{recursive:true});
  await cp(join(root,'apps/admin/public'),output,{recursive:true});
  await cp(join(root,'brand/washkrew-wordmark-light.svg'),join(output,'logo.svg'));
  const emulator=config.FIREBASE_USE_EMULATORS===true;
  if(emulator&&!config.FIREBASE_PROJECT_ID?.startsWith('demo-'))throw Error('Admin emulators require a demo project.');
  const firebase={apiKey:config.FIREBASE_API_KEY,appId:config.FIREBASE_APP_ID,projectId:config.FIREBASE_PROJECT_ID,authDomain:config.FIREBASE_AUTH_DOMAIN,messagingSenderId:config.FIREBASE_MESSAGING_SENDER_ID,storageBucket:config.FIREBASE_STORAGE_BUCKET};
  await writeFile(join(output,'config.mjs'),'export const config='+JSON.stringify({firebase,emulator,host:emulator?'127.0.0.1':null})+';\n');
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const config=JSON.parse(await readFile(resolve(process.argv[2]??'firebase.local.json'),'utf8'));
  await buildAdmin(config,resolve(process.argv[3]??'build/firebase-hosting/admin'));
  console.log('Private Captain review frontend built. No secrets or reviewer list are included.');
}
