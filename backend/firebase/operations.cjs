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
  if(command==='configure-refund-coupons'){
    const deployedAfter=Date.parse(uid??'');
    if(!Number.isFinite(deployedAfter))throw Error('Supply the verified deployment start time in ISO format.');
    for(const name of ['createBooking','createCheckout','verifyPayment','checkPayment','abandonCheckout','cancelBooking','getCancellationQuote','reportWashProblem','reviewWashReport','prepareMyCoupons','previewRefundCoupon','listRefundRequests','reviewRefundRequest','getVehiclePricing','updateVehiclePricing','deleteOwnAccount','maintainBookings','createWalletTopup','verifyWalletTopup','checkWalletTopup','washkrewRazorpayLiveWebhook','razorpayWebhook','razorpayLiveWebhook']){
      const r=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/'+name,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
      const fn=await r.json();
      if(!r.ok||fn.state!=='ACTIVE'||!(Date.parse(fn.updateTime)>=deployedAfter))throw Error('Deploy and verify the coupon release of '+name+' first.');
    }
    for(const [group,expected] of [['coupons',['customerId','paymentMode','issuedAt']],['refundRequests',['status','createdAt']]]){
      const r=await fetch('https://firestore.googleapis.com/v1/projects/wheelio-apps/databases/(default)/collectionGroups/'+group+'/indexes',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
      const data=await r.json();
      if(!r.ok||!data.indexes?.some(i=>i.state==='READY'&&expected.every((key,index)=>i.fields?.[index]?.fieldPath===key)&&i.fields?.[expected.length-1]?.order==='DESCENDING'))throw Error('Wait for the '+group+' index to become READY.');
    }
    const current=await api('/config/operations');
    if(current.fields.paymentMerchant?.stringValue!=='washkrew'||current.fields.paymentMode?.stringValue!=='live')throw Error('This activation is only for the separate WashKrew live merchant.');
    const {approvedCouponPolicy}=await import('./functions/src/coupon-policy.mjs');
    const patch={paymentBalanceMode:'refundCouponsV1',refundCouponsReady:true,walletTopupsEnabled:false,captainEarningsPolicy:'netGatewayPlusPlatformV1',platformFeeBps:300,cancellationPolicy:approvedCouponPolicy};
    const masks=Object.keys(patch).map(k=>'updateMask.fieldPaths='+k).join('&');
    await api('/config/operations?'+masks+'&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields(patch)});
    console.log('New bookings use refund coupons and actual gateway fees plus the 3% successful-wash commission. Historical orders and prices were preserved.');
  } else if(command==='configure-captain-coverage'){
    for(const name of ['saveCaptainServiceArea','getAvailability','createBooking','claimJob','captainCoverageChanged']){const response=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/'+name,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});if(!response.ok||(await response.json()).state!=='ACTIVE')throw Error('Deploy all coverage controllers and indexes first.');}
    const indexResponse=await fetch('https://firestore.googleapis.com/v1/projects/wheelio-apps/databases/(default)/collectionGroups/captains/indexes',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
    const indexes=await indexResponse.json();if(!indexResponse.ok||!indexes.indexes?.some(i=>i.state==='READY'&&i.fields?.some(f=>f.fieldPath==='approved')&&i.fields?.some(f=>f.fieldPath==='serviceArea.geohash')))throw Error('Wait for the approved Captain/geohash index to become READY.');
    const current=await api('/config/operations');
    await api('/config/operations?updateMask.fieldPaths=coveragePolicy&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({coveragePolicy:'captainAreaV1'})});
    console.log('Captain-defined 1–10 km coverage enabled. Human identity/payout review remains required. No Captain was approved.');
  } else if(command==='configure-place-search') {
    for(const name of ['searchPlaceSuggestions','selectPlaceSuggestion']){
      const response=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/'+name,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
      if(!response.ok||(await response.json()).state!=='ACTIVE')throw Error('Deploy and verify both place search controllers before activating the feature.');
    }
    const current=await api('/config/operations');
    await api('/config/operations?updateMask.fieldPaths=maps.places&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:{maps:{mapValue:{fields:{places:{mapValue:{fields:fields({enabled:true,dailyLimit:1000})}}}}}}});
    console.log('Google Places search enabled with 1,000 provider lookups/day, server rate limits and unchanged service coverage.');
  } else if(command==='configure-payment-methods') {
    const current=await api('/config/operations');
    if(current.fields?.paymentMode?.stringValue!=='live'||current.fields?.paymentMerchant?.stringValue!=='washkrew')throw Error('Verify the separate WashKrew live merchant before changing new checkout presentation.');
    await api('/config/operations?updateMask.fieldPaths=checkoutPresentation&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({checkoutPresentation:'allNonCredit'})});
    console.log('New orders use explicit runtime UPI, debit-card, netbanking and provider-wallet groups instead of pinning the historical saved checkout layout. The saved configuration ID, merchant keys, funding ban and existing order snapshots are preserved. No payment was created.');
  } else if(command==='configure-release-policy') {
    for(const name of ['getWallet','accountDeletionRequest','listDeletionRequests','reviewDeletionRequest','maintainDataRetention']){
      const r=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/'+name,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
      if(!r.ok||(await r.json()).state!=='ACTIVE')throw Error('Deploy and verify the release policy controllers before activation.');
    }
    const {Firestore,Timestamp,FieldPath}=require('./functions/node_modules/@google-cloud/firestore');
    const {OAuth2Client}=require('./functions/node_modules/google-auth-library');
    const {walletCredits}=await import('./functions/src/wallet-credits.mjs');
    const client=new OAuth2Client();client.setCredentials({access_token:token.access_token,expiry_date:Date.now()+3500000});
    const db=new Firestore({projectId:'wheelio-apps',authClient:client});
    try{
      const ref=db.doc('config/operations'),old=(await ref.get()).data(),start=old.walletExpiryStartedAt?.toMillis()??Date.now();
      // Mark the single cutover time first. No existing cancellation snapshot is edited.
      await ref.set({walletExpiryStartedAt:Timestamp.fromMillis(start)},{merge:true});
      let after=null,count=0;
      for(;;){let q=db.collection('wallets').orderBy(FieldPath.documentId());if(after)q=q.startAfter(after);const page=await q.limit(100).get();
        for(const doc of page.docs)await db.runTransaction(async tx=>{const row=await tx.get(doc.ref),d=row.data();if(d&&d.creditLotVersion!==1){tx.set(doc.ref,walletCredits(d,Date.now(),start),{merge:true});count++;}});
        if(page.size<100)break;after=page.docs.at(-1).id;
      }
      await ref.set({cancellationPolicy:{kind:'walletByTime',earlyCreditBps:9800,creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,serviceFailure:'wallet'},walletCreditExpiryMonths:12},{merge:true});
      console.log('Release rules active for new bookings: 98/50/0 percent wallet credit, full service-failure credit. Existing balances receive a full year from cutover; '+count+' legacy wallets dated. Historical booking terms and merchant preserved.');
    }finally{await db.terminate();}
  } else if(command==='configure-cancellation-wallet-time') {
    const response=await fetch('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/getCancellationQuote',{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(30000)});
    if(!response.ok||(await response.json()).state!=='ACTIVE')throw Error('Deploy and verify the wallet-by-time backend and Customer build before activation.');
    const current=await api('/config/operations');
    await api('/config/operations?updateMask.fieldPaths=cancellationPolicy&currentDocument.updateTime='+encodeURIComponent(current.updateTime),'PATCH',{fields:fields({cancellationPolicy:{kind:'walletByTime',creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,serviceFailure:'wallet'}})});
    console.log('Future bookings: full wallet credit within five minutes; later 50% credit until two hours before the confirmed window, then zero. Grace takes priority. Service failures return full wallet value. Historical snapshots, refunds and balances are unchanged.');
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
    // Auth removal also needs private object cleanup. The previous viewer role
    // could read/list files but every real delete failed with Storage HTTP 403.
    const bucket='wheelio-apps.firebasestorage.app',bucketApi='https://storage.googleapis.com/storage/v1/b/'+bucket;
    const metadata=await cloud(bucketApi+'?fields=iamConfiguration');
    if(!metadata.iamConfiguration?.uniformBucketLevelAccess?.enabled)throw Error('Private deletion requires the existing uniform bucket access setting.');
    const storageRole='projects/wheelio-apps/roles/washkrewPrivateDataDeletion';
    const storageRoleUrl='https://iam.googleapis.com/v1/'+storageRole;
    const foundRole=await fetch(storageRoleUrl,{headers});
    if(foundRole.status===404)await cloud('https://iam.googleapis.com/v1/projects/wheelio-apps/roles','POST',{roleId:'washkrewPrivateDataDeletion',role:{title:'WashKrew private account object deletion',description:'Delete only objects in the conditional account-cleanup paths; no object creation or IAM access.',includedPermissions:['storage.objects.delete'],stage:'GA'}});
    else if(!foundRole.ok)throw Error('Cannot verify private deletion role.');
    else {const existingRole=await foundRole.json();if(existingRole.includedPermissions?.length!==1||existingRole.includedPermissions[0]!=='storage.objects.delete')throw Error('Unexpected private deletion role permissions.');}
    const objectRoot='projects/_/buckets/'+bucket+'/objects/';
    const expression="resource.type == 'storage.googleapis.com/Object' && ("+
      ['kyc/','identity/','profiles/'].map(prefix=>"resource.name.startsWith('"+objectRoot+prefix+"')").concat(['customer/','problems/'].map(folder=>"resource.name.extract('"+objectRoot+"orders/{order}/"+folder+"') != ''")).join(' || ')+')';
    const bucketPolicy=await cloud(bucketApi+'/iam?optionsRequestedPolicyVersion=3');
    const condition={title:'washkrew-private-account-cleanup',expression};
    const grant=bucketPolicy.bindings.find(b=>b.role===storageRole&&b.condition?.title===condition.title);
    if(grant){grant.condition=condition;if(!grant.members.includes(member))grant.members.push(member);}
    else bucketPolicy.bindings.push({role:storageRole,members:[member],condition});
    bucketPolicy.version=3;
    await cloud(bucketApi+'/iam','PUT',bucketPolicy);
    console.log('Configured Auth user deletion and conditional private-object deletion for the actual runtime. Authenticated ownership, role isolation and open-job/payment guards remain. No user or private object was deleted by this permission setup.');
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
    const names=['listWashReports','reviewWashReport','washReportPhoto','listIdentityReviews','reviewCaptainIdentity','identityReviewPhoto','getWallet','accountDeletionRequest','listDeletionRequests','reviewDeletionRequest','setBookingPhotoAi','saveCaptainServiceArea','registerAccount','getAvailability','getCancellationQuote','checkServiceAddress','setCaptainPreferences','saveCaptainPayout','setCaptainPosition','matchServiceLocation','abandonCheckout','createBooking','createCheckout','verifyPayment','checkPayment','setCaptainOnline','submitCaptainApplication','startCaptainTraining','recordTrainingProgress','submitTrainingQuiz','beginCaptainIdentity','verifyCaptainIdentity','checkWashPhotos','claimJob','rejectJob','updateWashProgress','recordWashEvidence','recordCustomerPhoto','recordCustomerMedia','createSupportRequest','registerPushToken','setPushPreference','removePushToken','readNotification','saveNotificationPreferences','updateVehicleHelp','saveProfilePhoto','saveCustomerPlace','syncVerifiedPhone','deleteOwnAccount','createBookingDocument','downloadBookingDocument','recordCaptainDisputeResponse','updateCaptainLocation','approveWash','rateWash','cancelBooking','reportWashProblem','razorpayWebhook','razorpayLiveWebhook','washkrewRazorpayLiveWebhook','listCaptainApplications','getCaptainApplication','reviewCaptainApplication','captainApplicationPhoto'];
    names.push('searchPlaceSuggestions','selectPlaceSuggestion','createWalletTopup','verifyWalletTopup','checkWalletTopup','prepareMyCoupons','previewRefundCoupon','listRefundRequests','reviewRefundRequest','getVehiclePricing','updateVehiclePricing');
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
  } else throw Error('Commands: configure-refund-coupons DEPLOYMENT_START_ISO | configure-cancellation-refund-wallet | configure-payment-methods | configure-admin-approval | configure-live-no-credit CHECKOUT_CONFIG_ID | configure-captain-reviewers PRIVATE_REVIEWERS_JSON | prepare-payment-modes | check-live-webhook | configure-test | configure-storage | configure-storage-rules | configure-api-access | check-payments | check-webhook | approve-address REQUEST_ID SOCIETY_ID | approve-captain UID SOCIETY_ID [...]. Use /admin/ for human Captain application reviews.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
