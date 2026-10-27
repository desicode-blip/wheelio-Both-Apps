// Owner-operated deployment to the existing billed Firebase project. No keys on disk.
const fs=require('node:fs'),path=require('node:path'),{execFileSync}=require('node:child_process'),{createHash}=require('node:crypto');
async function main(){
  const root=path.resolve(__dirname,'../..'),cache=path.join(root,'.cache');fs.mkdirSync(cache,{recursive:true});
  const auth=require('./owner.cjs').firebaseOwnerAuth();
  const account=auth.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');if(!account)throw Error('Sign in as the Firebase owner first.');
  const token=await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']);
  const headers={Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'};
  async function api(url,method='GET',body){const r=await fetch(url,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(60000)});const d=await r.json();if(!r.ok)throw Error(`${r.status}: ${d.error?.message??'Cloud operation failed'}`);return d;}
  async function wait(op,base){for(let i=0;!op.done&&i<180;i++){await new Promise(r=>setTimeout(r,5000));op=await api(base+op.name);}if(!op.done||op.error)throw Error(op.error?.message??'Cloud operation timed out');return op.response;}
  await wait(await api('https://serviceusage.googleapis.com/v1/projects/763324255731/services:batchEnable','POST',{serviceIds:['cloudbuild.googleapis.com','artifactregistry.googleapis.com','run.googleapis.com']}),'https://serviceusage.googleapis.com/v1/');
  const repo='projects/wheelio-apps/locations/asia-south1/repositories/washkrew-services',repoUrl='https://artifactregistry.googleapis.com/v1/'+repo;
  const check=await fetch(repoUrl,{headers});if(check.status===404)await wait(await api('https://artifactregistry.googleapis.com/v1/projects/wheelio-apps/locations/asia-south1/repositories?repositoryId=washkrew-services','POST',{format:'DOCKER',description:'Private WashKrew services'}),'https://artifactregistry.googleapis.com/v1/');else if(!check.ok)throw Error('Could not inspect artifact repository');
  const archive=path.join(cache,'photo-check-build.tgz');execFileSync('tar',['-czf',archive,'--exclude=models','--exclude=__pycache__','-C',__dirname,'.']);const bytes=fs.readFileSync(archive),digest=createHash('sha256').update(bytes).digest('hex').slice(0,12);
  const bucket='wheelio-apps.firebasestorage.app',object=`operations-builds/photo-check-${digest}.tgz`;
  const upload=await fetch(`https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(object)}`,{method:'POST',headers:{Authorization:headers.Authorization,'Content-Type':'application/gzip'},body:bytes,signal:AbortSignal.timeout(60000)});if(!upload.ok)throw Error('Could not upload private build source');
  const image=`asia-south1-docker.pkg.dev/wheelio-apps/washkrew-services/photo-check:${digest}`;
  const build=await api('https://cloudbuild.googleapis.com/v1/projects/wheelio-apps/builds','POST',{source:{storageSource:{bucket,object}},steps:[{name:'gcr.io/cloud-builders/docker',args:['build','-t',image,'.']}],images:[image],timeout:'1200s',options:{logging:'CLOUD_LOGGING_ONLY'}});
  fs.writeFileSync(path.join(cache,'photo-check-build.json'),JSON.stringify({operation:build.name,image}));console.log('Private photo-check image build started.');
  const result=await wait(build,'https://cloudbuild.googleapis.com/v1/');if(result.status!=='SUCCESS')throw Error('Image build failed: '+result.status);
  const service='projects/wheelio-apps/locations/asia-south1/services/washkrew-photo-check',url='https://run.googleapis.com/v2/'+service;
  const existing=await fetch(url,{headers});const specification={template:{maxInstanceRequestConcurrency:1,scaling:{minInstanceCount:0,maxInstanceCount:3},timeout:'40s',containers:[{image,resources:{limits:{cpu:'1',memory:'1Gi'}}}]}};
  const op=existing.status===404?await api('https://run.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/services?serviceId=washkrew-photo-check','POST',specification):await api(url+'?updateMask=template','PATCH',specification);
  const deployed=await wait(op,'https://run.googleapis.com/v2/');
  const fn=await api('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/updateCaptainLocation');const caller=fn.serviceConfig.serviceAccountEmail;
  const iam=await api(url+':getIamPolicy');const bindings=(iam.bindings??[]).filter(b=>b.role!=='roles/run.invoker');bindings.push({role:'roles/run.invoker',members:[`serviceAccount:${caller}`]});await api(url+':setIamPolicy','POST',{policy:{...iam,bindings}});
  const {Firestore}=require('../firebase/functions/node_modules/@google-cloud/firestore'),{OAuth2Client}=require('../firebase/functions/node_modules/google-auth-library');const client=new OAuth2Client();client.setCredentials({access_token:token.access_token,expiry_date:Date.now()+3500000});const db=new Firestore({projectId:'wheelio-apps',authClient:client});const current=(await db.doc('privateConfig/photoChecks').get()).data()??{};await db.doc('privateConfig/photoChecks').set({url:deployed.uri,enabled:current.enabled??true,paymentMode:current.paymentMode??'test'},{merge:true});await db.terminate();
  const anonymous=await fetch(deployed.uri);if(anonymous.ok)throw Error('Photo checks must not allow anonymous access');console.log('Private photo service deployed for test-mode jobs. Anonymous access denied; no existing merchant or payment configuration changed.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
