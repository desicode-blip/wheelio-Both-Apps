import {cp,mkdir,writeFile,readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const root=fileURLToPath(new URL('../../',import.meta.url));
export async function buildAdmin(config,output){
  await mkdir(output,{recursive:true});
  await cp(join(root,'apps/admin/public'),output,{recursive:true});
  await cp(join(root,'brand/washkrew-wordmark-light.svg'),join(output,'logo.svg'));
  const emulator=config.FIREBASE_USE_EMULATORS===true;
  if(emulator&&!config.FIREBASE_PROJECT_ID?.startsWith('demo-'))throw Error('Admin emulators require a demo project.');
  const firebase={apiKey:config.FIREBASE_API_KEY,appId:config.FIREBASE_APP_ID,projectId:config.FIREBASE_PROJECT_ID,authDomain:config.FIREBASE_AUTH_DOMAIN,messagingSenderId:config.FIREBASE_MESSAGING_SENDER_ID,storageBucket:config.FIREBASE_STORAGE_BUCKET};
  await writeFile(join(output,'config.mjs'),'export const config='+JSON.stringify({firebase,emulator,host:emulator?'127.0.0.1':null})+';\n');
  // Old browsers may still hold the previous one-hour static asset cache.
  // Version the whole local module graph and stylesheet as one deployment.
  const names=['admin.mjs','review-form.mjs','config.mjs','styles.css'];
  const sources=await Promise.all(names.map(name=>readFile(join(output,name),'utf8')));
  const hash=createHash('sha256').update(JSON.stringify(sources)).digest('hex').slice(0,16);
  const script=sources[0].replace("'./config.mjs'",`'./config.mjs?v=${hash}'`).replace("'./review-form.mjs'",`'./review-form.mjs?v=${hash}'`);
  await writeFile(join(output,'admin.mjs'),script);
  const index=await readFile(join(output,'index.html'),'utf8');
  await writeFile(join(output,'index.html'),index.replace('src="admin.mjs"',`src="admin.mjs?v=${hash}"`).replace('href="styles.css"',`href="styles.css?v=${hash}"`));
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const config=JSON.parse(await readFile(resolve(process.argv[2]??'firebase.local.json'),'utf8'));
  await buildAdmin(config,resolve(process.argv[3]??'build/firebase-hosting/admin'));
  console.log('Private Captain review frontend built. No secrets or reviewer list are included.');
}
