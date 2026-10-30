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
  if(command==='configure-payment-methods') {
    const current=await api('/config/operations');
    if(current.fields?.paymentMode?.stringValue!=='live'||current.fields?.paymentMerchant?.stringValue!=='washkrew')throw Error('Verify the separate WashKrew live merchant before changing new checkout presentation.');
    await api('/config/operations?updateMask.fieldPaths=checkoutPresentation&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({checkoutPresentation:'allNonCredit'})});
    console.log('New orders use explicit runtime UPI, debit-card, netbanking and provider-wallet groups instead of pinning the historical saved checkout layout. The saved configuration ID, merchant keys, funding ban and existing order snapshots are preserved. No payment was created.');
  } else if(command==='configure-cancellation-refund-wallet') {
    const response=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/getCancellationQuote',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
    if(!response.ok||(await response.json()).state!=='ACTIVE')throw Error('Deploy and verify getCancellationQuote before activating the new cancellation terms.');
    const current=await api('/config/operations');
    await api('/config/operations?updateMask.fieldPaths=cancellationPolicy&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({cancellationPolicy:{kind:'refundThenCredit',refundMinutes:5,lateCreditBps:5000}})});
    console.log('New bookings: original-method cash refund and reserved-credit restoration within five minutes of confirmation; later, 50% of total cash-plus-wallet value is a fee and 50% returns to the wallet. Existing booking snapshots, merchant, payment mode and balances were preserved.');
  } else if(command==='configure-admin-approval') {
    const current=await api('/config/operations');
    await api('/config/operations?updateMask.fieldPaths=training.enabled&updateMask.fieldPaths=training.required&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:{training:{mapValue:{fields:fields({enabled:false,required:false})}}}});
    console.log('Training and quiz are hidden and not required. Human admin approval still gates work. No Captain was approved and no training completion was awarded. Other configuration was preserved.');
  } else if(command==='configure-captain-reviewers') {
    if(!uid)throw Error('Usage: configure-captain-reviewers PRIVATE_REVIEWERS_JSON');
    const input=JSON.parse(readFileSync(uid,'utf8')),emails=input.emails?.map(v=>typeof v==='string'?v.trim().toLowerCase():'');
    if(!Array.isArray(emails)||!emails.length||emails.length>20||new Set(emails).size!==emails.length||emails.some(e=>! /^[a-z0-9.!#$%&'+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}$/.test(e)))throw Error('Supply distinct approved reviewer Google emails.');
    await api('/privateConfig/captainReviewers?updateMask.fieldPaths=emails&updateMask.fieldPaths=updatedAt','PATCH',{fields:{...fields({emails}),updatedAt:{timestampValue:new Date().toISOString()}}});
    console.log(`Configured ${emails.length} authorized Captain reviewers. No Captain was approved and no project IAM access was granted.`);
  } else if(command==='configure-live-no-credit') {
    if(!/^[A-Za-z0-9_-]{8,100}$/.test(uid??''))throw Error('Supply the saved WashKrew no-credit checkout configuration ID.');
    const [key,password]=await Promise.all([secret('WASHKREW_RAZORPAY_LIVE_KEY_ID'),secret('WASHKREW_RAZORPAY_LIVE_KEY_SECRET')]);
    if(!key.startsWith('rzp_live_'))throw Error('Separate WashKrew live credentials are required.');
    const providerHeaders={Authorization:'Basic '+Buffer.from(key+':'+password).toString('base64')};
    const verify=await fetch('https://api.razorpay.com/v1/payments?count=1',{headers:providerHeaders,signal:AbortSignal.timeout(30000)});
    if(!verify.ok)throw Error('Separate WashKrew live credentials did not authenticate.');
    const hooks=await fetch('https://api.razorpay.com/v1/webhooks?count=100',{headers:providerHeaders,signal:AbortSignal.timeout(30000)});
    if(!hooks.ok)throw Error('Cannot verify the new merchant webhook.');
    const hook=(await hooks.json()).items?.find(h=>h.url==='https://asia-south1-wheelio-apps.cloudfunctions.net/washkrewRazorpayLiveWebhook');
    const enabled=e=>Array.isArray(hook?.events)?hook.events.includes(e):hook?.events?.[e]===true;
    if(!hook?.active||!hook.secret_exists||!['payment.captured','order.paid','refund.processed'].every(enabled))throw Error('The separate signed WashKrew webhook is not ready.');
    const current=await api('/config/operations'),patch={paymentMode:'live',paymentMerchant:'washkrew',paymentPolicy:'no-credit-card-checkout',checkoutConfigId:uid};
    await api('/config/operations?'+Object.keys(patch).map(k=>'updateMask.fieldPaths='+k).join('&')+'&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields(patch)});
    console.log('Live payment configuration enabled on the separate WashKrew merchant, with the saved no-credit checkout configuration. Existing orders, prices, approvals and historical refund credentials were not relabelled.');
  } else if(command==='configure-account-deletion') {
    const headers={Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'};
    async function cloud(url,method='GET',body){const response=await fetch(url,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(30000)}),result=await response.json();if(!response.ok)throw Error(`${response.status}: ${result.error?.message??'Runtime permission setup failed'}`);return result;}
    const fn=await cloud('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/deleteOwnAccount'),account=fn.serviceConfig.serviceAccountEmail;
    const role='projects/wheelio-apps/roles/washkrewAccountDeletion',url='https://iam.googleapis.com/v1/'+role;
    const existing=await fetch(url,{headers});
    if(existing.status===404)await cloud('https://iam.googleapis.com/v1/projects/wheelio-apps/roles','POST',{roleId:'washkrewAccountDeletion',role:{title:'WashKrew self-service account deletion',description:'The authenticated backend can remove the requesting idle account; no user creation, listing or modification.',includedPermissions:['firebaseauth.users.delete'],stage:'GA'}});
    else if(!existing.ok)throw Error('Cannot verify the account-deletion role.');
    const project='https://cloudresourcemanager.googleapis.com/v1/projects/wheelio-apps',policy=await cloud(project+':getIamPolicy','POST',{}),member=`serviceAccount:${account}`;
    let binding=policy.bindings.find(b=>b.role===role);if(!binding){binding={role,members:[]};policy.bindings.push(binding);}if(!binding.members.includes(member))binding.members.push(member);
    await cloud(project+':setIamPolicy','POST',{policy});
    console.log('Configured only Firebase Auth user deletion for the actual deletion-function runtime account. App recent-auth and open-booking checks remain enforced. No account was created, read or deleted.');
  } else if(command==='prepare-payment-modes') {
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
  } else if(command==='configure-test-hours') {
    const current=await api('/config/operations');
    if(current.fields?.paymentMode?.stringValue!=='test')throw Error('This operation only changes the test catalog.');
    const {slotWindows}=JSON.parse(readFileSync(path.join(__dirname,'operations.test.json'),'utf8'));
    await api('/config/operations?updateMask.fieldPaths=slotWindows&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({slotWindows})});
    console.log('Updated only test booking windows to 4 AM–10 PM. Other configuration and payment mode preserved.');
  } else if(command==='configure-test') {
    const config=JSON.parse(readFileSync(path.join(__dirname,'operations.test.json'),'utf8'));
    await api('/config/operations','PATCH',{fields:fields(config)});
    console.log('Configured WashKrew test payments, catalog and societies. No captains were fabricated or approved.');
  } else if(command==='configure-storage-rules') {
    // Cross-service Storage rules read Firestore to enforce account ownership,
    // KYC review locks and assigned-job access. Noninteractive CLI deploys can
    // skip this permission check. Grant only Google's documented service role
    // to the existing Storage service agent, never to a person or allUsers.
    const project='https://cloudresourcemanager.googleapis.com/v1/projects/wheelio-apps';
    const request=async(url,method='GET',body)=>{
      const response=await fetch(url,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});
      if(!response.ok)throw Error(`Storage rules IAM setup failed (${response.status}).`);
      return response.json();
    };
    const metadata=await request(project),number=String(metadata.projectNumber);
    if(!/^\d+$/.test(number))throw Error('Cannot resolve the existing Firebase project number.');
    const member=`serviceAccount:service-${number}@gcp-sa-firebasestorage.iam.gserviceaccount.com`,role='roles/firebaserules.firestoreServiceAgent';
    const read=()=>request(project+':getIamPolicy','POST',{options:{requestedPolicyVersion:3}});
    const has=policy=>(policy.bindings??[]).some(b=>b.role===role&&!b.condition&&b.members?.includes(member));
    let configured=false;
    for(let attempt=0;attempt<3;attempt++){
      const policy=await read();
      if(has(policy)){configured=true;break;}
      if(!policy.etag||!(policy.bindings??[]).some(b=>b.role==='roles/firebasestorage.serviceAgent'&&!b.condition&&b.members?.includes(member)))throw Error('The existing Firebase Storage service agent could not be verified.');
      const binding=policy.bindings.find(b=>b.role===role&&!b.condition);
      if(binding)binding.members.push(member);else policy.bindings.push({role,members:[member]});
      const response=await fetch(project+':setIamPolicy',{method:'POST',headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:JSON.stringify({policy}),signal:AbortSignal.timeout(20000)});
      if(response.status===409)continue;
      if(!response.ok)throw Error(`Storage rules IAM setup failed (${response.status}).`);
      configured=has(await read());break;
    }
    if(!configured)throw Error('Storage rules permission was not confirmed; retry after checking concurrent IAM changes.');
    console.log('Verified Firebase Storage can read Firestore for its existing security rules. Private KYC/job rules, human admin approval and all other IAM bindings remain enforced. No documents or Captains were created or approved.');
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
    console.log('Storage allows authenticated photo downloads from the WashKrew Hosting origins. Existing bucket policies were preserved.');
  } else if(command==='configure-api-access') {
    // Only the app callables and signed webhook are public HTTP gateways.
    // Scheduler and Firestore-trigger services retain their IAM checks.
    const names=['registerAccount','getAvailability','getCancellationQuote','checkServiceAddress','setCaptainPreferences','saveCaptainPayout','setCaptainPosition','matchServiceLocation','createBooking','createCheckout','verifyPayment','checkPayment','setCaptainOnline','submitCaptainApplication','startCaptainTraining','recordTrainingProgress','submitTrainingQuiz','beginCaptainIdentity','verifyCaptainIdentity','checkWashPhotos','claimJob','rejectJob','updateWashProgress','recordWashEvidence','recordCustomerPhoto','recordCustomerMedia','createSupportRequest','registerPushToken','setPushPreference','removePushToken','readNotification','saveNotificationPreferences','updateVehicleHelp','saveProfilePhoto','saveCustomerPlace','syncVerifiedPhone','deleteOwnAccount','createBookingDocument','downloadBookingDocument','recordCaptainDisputeResponse','updateCaptainLocation','approveWash','rateWash','cancelBooking','reportWashProblem','razorpayWebhook','razorpayLiveWebhook','washkrewRazorpayLiveWebhook','listCaptainApplications','getCaptainApplication','reviewCaptainApplication','captainApplicationPhoto'];
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
    const cfg=await api('/config/operations');
    if(cfg.fields.training?.mapValue?.fields?.required?.booleanValue===true&&(!c.fields.trainingCompletedAt||!c.fields.quizPassedAt||c.fields.trainingVersion?.stringValue!==cfg.fields.training.mapValue.fields.version?.stringValue))throw Error('Captain must complete the current training and quiz before approval.');
    const changes={approved:true,kycStatus:'approved',societyIds,online:false};
    await api(`/captains/${uid}?${Object.keys(changes).map(k=>`updateMask.fieldPaths=${k}`).join('&')}`,'PATCH',{fields:fields(changes)});
    console.log('Captain approved for the selected societies. They must go online to receive offers.');
  } else throw Error('Commands: configure-cancellation-refund-wallet | configure-payment-methods | configure-admin-approval | configure-live-no-credit CHECKOUT_CONFIG_ID | configure-captain-reviewers PRIVATE_REVIEWERS_JSON | prepare-payment-modes | check-live-webhook | configure-test | configure-storage | configure-storage-rules | configure-api-access | check-payments | check-webhook | approve-address REQUEST_ID SOCIETY_ID | approve-captain UID SOCIETY_ID [...]. Use /admin/ for human Captain application reviews.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
