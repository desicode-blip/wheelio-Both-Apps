// Owner-authorized activation of the existing private photo service. This
// verifies deployed model/IAM/AI inference, not physical camera acceptance.
const {execFileSync}=require('node:child_process');
const path=require('node:path');
const {firebaseOwnerAuth}=require('./owner.cjs');
async function main(){
  if(process.argv.slice(2).join(' ')!=='live')throw Error('Usage: node backend/photo-check/activate.cjs live');
  execFileSync(process.execPath,[path.join(__dirname,'check.cjs')],{stdio:'inherit'});
  const auth=firebaseOwnerAuth(),owner=auth.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');
  if(!owner)throw Error('Sign in as the Firebase owner.');
  const token=await auth.getAccessToken(owner.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
  const response=await fetch('https://run.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/services/washkrew-photo-check',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
  if(!response.ok)throw Error('Cannot verify the health-checked private service.');
  const checkedUrl=(await response.json()).uri;
  const {Firestore,FieldValue}=require('../firebase/functions/node_modules/@google-cloud/firestore');
  const {OAuth2Client}=require('../firebase/functions/node_modules/google-auth-library');
  const client=new OAuth2Client();client.setCredentials({access_token:token.access_token,expiry_date:Date.now()+3500000});
  const db=new Firestore({projectId:'wheelio-apps',authClient:client});
  try{
    const ref=db.doc('privateConfig/photoChecks');
    await db.runTransaction(async tx=>{
      const [settings,operations]=await Promise.all([tx.get(ref),tx.get(db.doc('config/operations'))]),cfg=settings.data(),op=operations.data();
      if(op?.paymentMode!=='live'||op.paymentMerchant!=='washkrew')throw Error('Activate only for the configured separate WashKrew live merchant.');
      if(!cfg?.enabled||!cfg.aiEnabled||!/^https:\/\/[a-z0-9.-]+\.run\.app$/.test(cfg.url??'')||cfg.url!==checkedUrl||!/^gemini-[a-z0-9.-]+$/.test(cfg.aiModel??'')||cfg.aiLocation!=='global')throw Error('The health-checked private photo service and model must match configuration.');
      const modes=cfg.paymentModes??[cfg.paymentMode];
      if(!Array.isArray(modes)||!modes.length||modes.some(m=>!['test','live'].includes(m)))throw Error('Review the existing photo-mode configuration first.');
      tx.update(ref,{paymentModes:[...new Set([...modes,'live'])],runtimeCheckedAt:FieldValue.serverTimestamp(),liveEnabledAt:FieldValue.serverTimestamp(),liveEnabledBy:owner.user.email});
    });
    console.log('Live photo processing enabled after deployed runtime checks; existing test processing is preserved. No Captain, training, payment or device acceptance was approved.');
  }finally{await db.terminate();}
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
