// Disposable local integration check. Never run against a real Firebase project.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getAuth} from './functions/node_modules/firebase-admin/lib/esm/auth/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {getStorage} from './functions/node_modules/firebase-admin/lib/esm/storage/index.js';
import {WashKrewService} from './functions/src/service.mjs';

if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099'||process.env.STORAGE_EMULATOR_HOST!=='http://127.0.0.1:9199')throw Error('Only the loopback demo-wheelio emulators are allowed.');
const app=initializeApp({projectId:'demo-wheelio',storageBucket:'demo-wheelio.appspot.com'}),db=getFirestore(app),auth=getAuth(app),bucket=getStorage(app).bucket();
const customerId='photo-qa-customer',captainId='photo-qa-captain',reference=await fs.readFile('.cache/nasa-astronaut.jpg'),evidence=await fs.readFile('.cache/design-evidence.png');
async function token(uid){
  const custom=await auth.createCustomToken(uid),r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token:custom,returnSecureToken:true})}),data=await r.json();
  assert.ok(data.idToken,'Local authentication failed');return data.idToken;
}
async function call(name,data,idToken){
  const response=await fetch(`http://127.0.0.1:5001/demo-wheelio/asia-south1/${name}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${idToken}`},body:JSON.stringify({data}),signal:AbortSignal.timeout(60000)}),body=await response.json();
  if(!response.ok)throw Object.assign(Error(`${name}: ${body.error?.message??response.status}`),{code:body.error?.status});return body.result;
}
async function upload(path,bytes,idToken){
  const r=await fetch(`http://127.0.0.1:9199/v0/b/demo-wheelio.appspot.com/o?uploadType=media&name=${encodeURIComponent(path)}`,{method:'POST',headers:{Authorization:`Bearer ${idToken}`,'Content-Type':'image/png'},body:bytes});assert.equal(r.ok,true,`Private upload denied: ${r.status}`);
}
async function clientOrder(orderId,idToken){
  const r=await fetch(`http://127.0.0.1:8080/v1/projects/demo-wheelio/databases/(default)/documents/orders/${orderId}`,{headers:{Authorization:`Bearer ${idToken}`}});assert.equal(r.ok,true,'Customer cannot read their booking');return (await r.json()).fields;
}
try{
  const config=JSON.parse(await fs.readFile('backend/firebase/operations.test.json','utf8')),prior=(await db.doc('config/operations').get()).data();if(prior?.maps)config.maps=prior.maps;config.societies=config.societies.map(s=>{const mapped=prior?.societies?.find(p=>p.id===s.id);return {...s,...(mapped?.location?{location:mapped.location,mapViewport:mapped.mapViewport}:{} )};});await db.doc('config/operations').set(config);
  await db.doc('privateConfig/photoChecks').set({enabled:true,paymentMode:'test',aiEnabled:true,url:'http://127.0.0.1:8089'});
  const phones={customer:'+919000000051',captain:'+919000000052'};
  for(const [uid,phone] of [[customerId,phones.customer],[captainId,phones.captain]]){try{await auth.createUser({uid,phoneNumber:phone});}catch(e){if(e.code!=='auth/uid-already-exists')throw e;}}
  const owner=await token(customerId),captain=await token(captainId);
  await call('registerAccount',{role:'customer',name:'Local QA Customer'},owner);await call('registerAccount',{role:'captain',name:'Local QA Captain'},captain);
  await db.doc(`captains/${captainId}`).update({approved:true,kycStatus:'approved',online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.now(),paymentMode:'test'});
  await bucket.file(`kyc/${captainId}/selfie.jpg`).save(reference,{metadata:{contentType:'image/png'}});
  let day=new Date(Date.now()+19800000).toISOString().slice(0,10);
  let window=(await call('getAvailability',{societyId:'soc_avatar',day},owner)).slots.find(s=>s.available);
  if(!window){day=new Date(Date.now()+19800000+86400000).toISOString().slice(0,10);window=(await call('getAvailability',{societyId:'soc_avatar',day},owner)).slots.find(s=>s.available);}
  assert.ok(window,'No disposable local fixture capacity is available. Restart fresh emulators.');
  const booking=await call('createBooking',{requestId:'photo-flow-'+Date.now(),plate:'TS09QA0051',societyId:'soc_avatar',vehicleKind:'hatchback',tower:'Local QA',floor:'B2',parking:'51',note:'Disposable loopback acceptance',washKind:'wetOutside',day,startHour:window.startHour,endHour:window.endHour},owner);
  // Only the capture is simulated. No Razorpay request or real funds are used.
  const provider={keyId:'rzp_test_local_disabled',createOrder:async({amount})=>({id:'order_local_photo_'+Date.now(),amount,currency:'INR'})},service=new WashKrewService({db,payments:provider});
  const checkout=await service.checkout({uid:customerId,token:{phone_number:phones.customer}},booking);await service.capturePayment({id:'pay_local_photo_'+Date.now(),order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'});
  const orderId=booking.bookingId;await assert.rejects(call('claimJob',{orderId},owner));await call('claimJob',{orderId},captain);
  assert.equal((await clientOrder(orderId,owner)).captainId.stringValue,captainId);
  // Move the local fixture into its booking window; real clients cannot do this.
  await db.doc(`orders/${orderId}`).update({slotStart:Timestamp.fromMillis(Date.now()-60000),slotEnd:Timestamp.fromMillis(Date.now()+3600000)});
  await call('updateWashProgress',{orderId,action:'arrived'},captain);
  const attempt=await call('beginCaptainIdentity',{orderId},captain);await upload(attempt.path,reference,captain);
  const privateRead=await fetch(`http://127.0.0.1:9199/v0/b/demo-wheelio.appspot.com/o/${encodeURIComponent(attempt.path)}?alt=media`,{headers:{Authorization:`Bearer ${owner}`}});assert.equal(privateRead.ok,false,'Captain selfie leaked to Customer');
  assert.equal((await call('verifyCaptainIdentity',{orderId,session:attempt.session},captain)).verified,true);
  for(const stage of ['before','after']){
    for(let side=0;side<4;side++){await upload(`orders/${orderId}/${captainId}/${stage}_${side}.jpg`,evidence,captain);await call('recordWashEvidence',{orderId,stage,side},captain);}
    if(stage==='before'){
      await call('updateWashProgress',{orderId,action:'start'},captain);assert.equal((await clientOrder(orderId,owner)).status.stringValue,'washing');
      await call('updateCaptainLocation',{orderId,latitude:17.3998,longitude:78.3546,accuracy:10},captain);
    }
  }
  const review=await call('checkWashPhotos',{orderId},captain);assert.equal(review.status,'unavailable','Local fixture must not call a live AI provider');
  await assert.rejects(call('updateWashProgress',{orderId,action:'finish'},captain));
  await call('updateWashProgress',{orderId,action:'finish',acknowledgePhotoIssues:true},captain);assert.equal((await clientOrder(orderId,owner)).status.stringValue,'photosReady');
  await call('approveWash',{orderId},owner);await call('rateWash',{orderId,stars:5,tags:[]},owner);
  assert.equal((await db.doc(`earnings/${orderId}`).get()).data().status,'approved');
  const document=await call('createBookingDocument',{orderId,kind:'receipt'},owner),pdf=await fetch(document.url);assert.equal(pdf.headers.get('content-type'),'application/pdf');assert.equal((await fetch(document.url)).status,403);
  console.log('PASS: authenticated booking, atomic Captain claim, real local face comparison/private capture, 8 evidence uploads, GPS, Customer wash states, labelled AI-outage acknowledgement, owner approval/rating/earnings and single-use receipt. Capture was simulated; no real merchant call, user or production data.');
}finally{await db.terminate();await deleteApp(app);}
