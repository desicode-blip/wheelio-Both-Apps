// Owner-only local operations. Uses the existing Firebase CLI login in memory.
// Never put an Admin key, Razorpay secret, or access token in this repository.
const {readFileSync} = require('node:fs');
const {execFileSync} = require('node:child_process');
const path = require('node:path');
async function main() {
  let auth;
  try { auth = require('firebase-tools/lib/auth.js'); }
  catch {
    if(process.platform==='win32'&&process.env.APPDATA) {
      try { auth=require(path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib/auth.js')); } catch { /* Custom npm prefix: resolve below. */ }
    }
    if(!auth) { const root=execFileSync(process.platform==='win32'?'npm.cmd':'npm',['root','-g'],{encoding:'utf8',shell:process.platform==='win32'}).trim(); auth=require(path.join(root,'firebase-tools/lib/auth.js')); }
  }
  const account=auth.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');
  if(!account)throw Error('Log in first: firebase login:add (ajay@trustkeyper.com).');
  const token=account.tokens.expires_at>Date.now()+60000?account.tokens:await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
  const base='https://firestore.googleapis.com/v1/projects/wheelio-apps/databases/(default)/documents';
  async function api(route,method='GET',body){const r=await fetch(base+route,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});const d=await r.json();if(!r.ok)throw Error(`${r.status}: ${d.error?.message}`);return d;}
  function value(v){if(v===null)return {nullValue:null};if(Array.isArray(v))return {arrayValue:{values:v.map(value)}};if(typeof v==='object')return {mapValue:{fields:fields(v)}};if(typeof v==='boolean')return {booleanValue:v};if(typeof v==='number')return Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v};return {stringValue:v};}
  function fields(v){return Object.fromEntries(Object.entries(v).map(([k,v])=>[k,value(v)]));}
  async function secret(name) {
    const response=await fetch(`https://secretmanager.googleapis.com/v1/projects/wheelio-apps/secrets/${name}/versions/latest:access`,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw Error(`Secret access failed (${response.status}).`);
    return Buffer.from((await response.json()).payload.data,'base64').toString();
  }
  async function ensureSecret(name,plain) {
    // Never overwrite an existing archived key or write credentials to disk.
    const url=`https://secretmanager.googleapis.com/v1/projects/wheelio-apps/secrets/${name}`;
    let response=await fetch(url,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
    if(response.status===404){
      response=await fetch(`https://secretmanager.googleapis.com/v1/projects/wheelio-apps/secrets?secretId=${encodeURIComponent(name)}`,{method:'POST',headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:JSON.stringify({replication:{automatic:{}}}),signal:AbortSignal.timeout(20000)});
      if(!response.ok)throw Error(`Could not create ${name} (${response.status}).`);
    }else if(!response.ok)throw Error(`Could not inspect ${name} (${response.status}).`);
    const existing=await fetch(url+'/versions/latest:access',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
    if(existing.ok)return false;
    if(existing.status!==404)throw Error(`Could not verify ${name} (${existing.status}).`);
    response=await fetch(url+':addVersion',{method:'POST',headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:JSON.stringify({payload:{data:Buffer.from(plain).toString('base64')}}),signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw Error(`Could not save ${name} (${response.status}).`);
    return true;
  }
  const [command,uid,...societyIds]=process.argv.slice(2);
  if(command==='prepare-payment-modes') {
    const [key,credential]=await Promise.all([secret('RAZORPAY_KEY_ID'),secret('RAZORPAY_KEY_SECRET')]);
    if(!key.startsWith('rzp_test_'))throw Error('Preserve the verified historical test pair before changing the current keys to live.');
    const verify=await fetch('https://api.razorpay.com/v1/orders?count=1',{headers:{Authorization:`Basic ${Buffer.from(`${key}:${credential}`).toString('base64')}`},signal:AbortSignal.timeout(20000)});
    if(!verify.ok)throw Error(`Existing test credentials did not authenticate (${verify.status}).`);
    await ensureSecret('RAZORPAY_TEST_KEY_ID',key);
    await ensureSecret('RAZORPAY_TEST_KEY_SECRET',credential);
    const archivedKey=await secret('RAZORPAY_TEST_KEY_ID'),archivedCredential=await secret('RAZORPAY_TEST_KEY_SECRET');
    if(archivedKey!==key||archivedCredential!==credential)throw Error('Archived test credentials differ. Review before changing any key.');
    await ensureSecret('RAZORPAY_LIVE_WEBHOOK_SECRET',require('node:crypto').randomBytes(32).toString('hex'));
    console.log('Preserved the verified test credentials and prepared a separate live webhook secret. No merchant key or payment mode changed; no charges created.');
  } else if(command==='configure-test') {
    const config=JSON.parse(readFileSync(path.join(__dirname,'operations.test.json'),'utf8'));
    await api('/config/operations','PATCH',{fields:fields(config)});
    console.log('Configured Wheelio test payments, catalog and societies. No captains were fabricated or approved.');
  } else if(command==='configure-storage') {
    const url='https://storage.googleapis.com/storage/v1/b/wheelio-apps.firebasestorage.app';
    const request=async(route,options={})=>{
      const response=await fetch(url+route,{...options,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(20000)});
      if(!response.ok)throw Error(`Storage configuration failed (${response.status}).`);
      return response.json();
    };
    const bucket=await request(''), desired=JSON.parse(readFileSync(path.join(__dirname,'storage.cors.json'),'utf8'));
    const cors=[...(bucket.cors??[])];
    for(const rule of desired) if(!cors.some(existing=>rule.origin.every(origin=>existing.origin?.includes('*')||existing.origin?.includes(origin))&&rule.method.every(method=>existing.method?.includes(method))))cors.push(rule);
    if(cors.length!==(bucket.cors??[]).length)await request(`?ifMetagenerationMatch=${encodeURIComponent(bucket.metageneration)}`,{method:'PATCH',body:JSON.stringify({cors})});
    console.log('Storage allows authenticated photo downloads from the Wheelio Hosting origins. Existing bucket policies were preserved.');
  } else if(command==='configure-api-access') {
    // Only the app callables and signed webhook are public HTTP gateways.
    // Scheduler and Firestore-trigger services retain their IAM checks.
    const names=['registerAccount','getAvailability','checkServiceAddress','setCaptainPreferences','createBooking','createCheckout','verifyPayment','checkPayment','setCaptainOnline','submitCaptainApplication','claimJob','rejectJob','updateWashProgress','recordWashEvidence','recordCustomerPhoto','recordCustomerMedia','createSupportRequest','registerPushToken','setPushPreference','removePushToken','readNotification','updateCaptainLocation','approveWash','rateWash','cancelBooking','reportWashProblem','razorpayWebhook','razorpayLiveWebhook'];
    const request=async(url,options={})=>{
      const response=await fetch(url,{...options,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(20000)});
      const data=await response.json();if(!response.ok)throw Error(`API gateway setup failed (${response.status}): ${data.error?.message}`);return data;
    };
    for(const name of names) {
      const config=await request(`https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/${name}`),service=config.serviceConfig?.service;
      if(!service?.startsWith('projects/wheelio-apps/locations/asia-south1/services/'))throw Error(`Unexpected service for ${name}.`);
      const url=`https://run.googleapis.com/v2/${service}`,current=await request(url);
      if(!current.invokerIamDisabled) {
        // Functions fixes revision names. Let Cloud Run generate a fresh name
        // for this service-level update instead of reusing an immutable one.
        let operation=await request(url+'?updateMask=invokerIamDisabled,template.revision',{method:'PATCH',body:JSON.stringify({name:service,etag:current.etag,invokerIamDisabled:true,template:{revision:''}})});
        const deadline=Date.now()+90000;
        while(!operation.done&&Date.now()<deadline) {
          await new Promise(resolve=>setTimeout(resolve,1500));
          operation=await request(`https://run.googleapis.com/v2/${operation.name}`);
        }
        if(!operation.done||operation.error)throw Error(`Gateway update did not complete for ${name}: ${operation.error?.message??'timeout'}`);
      }
      console.log(`${name}: HTTP gateway enabled; application authentication/signatures remain enforced.`);
    }
  } else if(command==='check-payments') {
    const [key,credential]=await Promise.all([secret('RAZORPAY_KEY_ID'),secret('RAZORPAY_KEY_SECRET')]);
    const response=await fetch('https://api.razorpay.com/v1/orders?count=1',{headers:{Authorization:`Basic ${Buffer.from(`${key}:${credential}`).toString('base64')}`},signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw Error(`Razorpay authentication failed (${response.status}).`);
    console.log(JSON.stringify({razorpayAuthenticated:true,mode:key.startsWith('rzp_live_')?'live':'test',chargesCreated:0}));
  } else if(command==='check-webhook'||command==='check-live-webhook') {
    const {createHmac}=require('node:crypto'),key=await secret(command==='check-live-webhook'?'RAZORPAY_LIVE_WEBHOOK_SECRET':'RAZORPAY_WEBHOOK_SECRET'),body=JSON.stringify({event:'wheelio.setup_check'});
    const url='https://asia-south1-wheelio-apps.cloudfunctions.net/'+(command==='check-live-webhook'?'razorpayLiveWebhook':'razorpayWebhook');
    const good=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','X-Razorpay-Signature':createHmac('sha256',key).update(body).digest('hex')},body,signal:AbortSignal.timeout(20000)});
    const bad=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','X-Razorpay-Signature':'0'.repeat(64)},body,signal:AbortSignal.timeout(20000)});
    if(good.status!==200||bad.status!==401)throw Error(`Webhook checks failed (${good.status}/${bad.status}).`);
    console.log('Webhook accepts a correctly signed setup event and rejects an invalid signature. No payments changed. Merchant dashboard registration is a separate step.');
  } else if(command==='approve-address') {
    if(!/^[a-f0-9]{32}$/.test(uid??'')||societyIds.length!==1)throw Error('Usage: approve-address REQUEST_ID SOCIETY_ID');
    const request=await api(`/addressRequests/${uid}`),key=request.fields.addressKey?.stringValue;
    const cfg=await api('/config/operations'),societies=cfg.fields.societies?.arrayValue?.values??[];
    if(!/^[a-f0-9]{32}$/.test(key??'')||!societies.some(s=>s.mapValue?.fields?.id?.stringValue===societyIds[0]&&s.mapValue?.fields?.active?.booleanValue))throw Error('Review the address and select an active served society.');
    await api(`/serviceAddresses/${key}`,'PATCH',{fields:fields({approved:true,societyId:societyIds[0]})});
    console.log('Service address mapping saved. The customer can check the typed address again.');
  } else if(command==='approve-captain') {
    if(!/^[A-Za-z0-9_-]{1,128}$/.test(uid??'')||!societyIds.length)throw Error('Usage: node backend/firebase/operations.cjs approve-captain UID SOCIETY_ID [...]');
    const c=await api(`/captains/${uid}`), requested=c.fields.requestedSocietyIds?.arrayValue?.values?.map(v=>v.stringValue)??[];
    if(c.fields.kycStatus?.stringValue!=='underReview'||societyIds.some(s=>!requested.includes(s)))throw Error('Review the submitted documents and choose requested societies first.');
    const changes={approved:true,kycStatus:'approved',societyIds,online:false};
    await api(`/captains/${uid}?${Object.keys(changes).map(k=>`updateMask.fieldPaths=${k}`).join('&')}`,'PATCH',{fields:fields(changes)});
    console.log('Captain approved for the selected societies. They must go online to receive offers.');
  } else throw Error('Commands: prepare-payment-modes | check-live-webhook | configure-test | configure-storage | configure-api-access | check-payments | check-webhook | approve-address REQUEST_ID SOCIETY_ID | approve-captain UID SOCIETY_ID [...]. Review identity and bank proof in Firebase Console before approval.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
