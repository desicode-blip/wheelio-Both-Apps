// Owner-only local operations. Uses the existing Firebase CLI login in memory.
// Never put an Admin key, Razorpay secret, or access token in this repository.
const {readFileSync} = require('node:fs');
const {execFileSync} = require('node:child_process');
const path = require('node:path');
async function main() {
  let auth;
  try { auth = require('firebase-tools/lib/auth.js'); }
  catch { const root=execFileSync(process.platform==='win32'?'npm.cmd':'npm',['root','-g'],{encoding:'utf8',shell:process.platform==='win32'}).trim(); auth=require(path.join(root,'firebase-tools/lib/auth.js')); }
  const account=auth.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');
  if(!account)throw Error('Log in first: firebase login:add (ajay@trustkeyper.com).');
  const token=account.tokens.expires_at>Date.now()+60000?account.tokens:await auth.getAccessToken(account.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
  const base='https://firestore.googleapis.com/v1/projects/wheelio-apps/databases/(default)/documents';
  async function api(route,method='GET',body){const r=await fetch(base+route,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});const d=await r.json();if(!r.ok)throw Error(`${r.status}: ${d.error?.message}`);return d;}
  function value(v){if(v===null)return {nullValue:null};if(Array.isArray(v))return {arrayValue:{values:v.map(value)}};if(typeof v==='object')return {mapValue:{fields:fields(v)}};if(typeof v==='boolean')return {booleanValue:v};if(typeof v==='number')return Number.isInteger(v)?{integerValue:String(v)}:{doubleValue:v};return {stringValue:v};}
  function fields(v){return Object.fromEntries(Object.entries(v).map(([k,v])=>[k,value(v)]));}
  async function secret(name) {
    const response=await fetch(`https://secretmanager.googleapis.com/v1/projects/wheelio-apps/secrets/${name}/versions/latest:access`,{headers:{Authorization:`Bearer ${token.access_token}`},signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw Error(`Secret access failed (${response.status}).`);
    return Buffer.from((await response.json()).payload.data,'base64').toString();
  }
  const [command,uid,...societyIds]=process.argv.slice(2);
  if(command==='configure-test') {
    const config=JSON.parse(readFileSync(path.join(__dirname,'operations.test.json'),'utf8'));
    await api('/config/operations','PATCH',{fields:fields(config)});
    console.log('Configured Wheelio test payments, catalog and societies. No captains were fabricated or approved.');
  } else if(command==='check-payments') {
    const [key,credential]=await Promise.all([secret('RAZORPAY_KEY_ID'),secret('RAZORPAY_KEY_SECRET')]);
    const response=await fetch('https://api.razorpay.com/v1/orders?count=1',{headers:{Authorization:`Basic ${Buffer.from(`${key}:${credential}`).toString('base64')}`},signal:AbortSignal.timeout(20000)});
    if(!response.ok)throw Error(`Razorpay authentication failed (${response.status}).`);
    console.log(JSON.stringify({razorpayAuthenticated:true,mode:key.startsWith('rzp_live_')?'live':'test',chargesCreated:0}));
  } else if(command==='check-webhook') {
    const {createHmac}=require('node:crypto'),key=await secret('RAZORPAY_WEBHOOK_SECRET'),body=JSON.stringify({event:'wheelio.setup_check'});
    const url='https://asia-south1-wheelio-apps.cloudfunctions.net/razorpayWebhook';
    const good=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','X-Razorpay-Signature':createHmac('sha256',key).update(body).digest('hex')},body});
    const bad=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','X-Razorpay-Signature':'0'.repeat(64)},body});
    if(good.status!==200||bad.status!==401)throw Error(`Webhook checks failed (${good.status}/${bad.status}).`);
    console.log('Webhook accepts a correctly signed setup event and rejects an invalid signature. No payments changed. Merchant dashboard registration is a separate step.');
  } else if(command==='approve-captain') {
    if(!/^[A-Za-z0-9_-]{1,128}$/.test(uid??'')||!societyIds.length)throw Error('Usage: node backend/firebase/operations.cjs approve-captain UID SOCIETY_ID [...]');
    const c=await api(`/captains/${uid}`), requested=c.fields.requestedSocietyIds?.arrayValue?.values?.map(v=>v.stringValue)??[];
    if(c.fields.kycStatus?.stringValue!=='underReview'||societyIds.some(s=>!requested.includes(s)))throw Error('Review the submitted documents and choose requested societies first.');
    const changes={approved:true,kycStatus:'approved',societyIds,online:false};
    await api(`/captains/${uid}?${Object.keys(changes).map(k=>`updateMask.fieldPaths=${k}`).join('&')}`,'PATCH',{fields:fields(changes)});
    console.log('Captain approved for the selected societies. They must go online to receive offers.');
  } else throw Error('Commands: configure-test | approve-captain UID SOCIETY_ID [...]. Review identity and bank proof in Firebase Console before approval.');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
