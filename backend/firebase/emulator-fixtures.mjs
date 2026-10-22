// Disposable browser QA data. This file refuses production and non-loopback hosts.
import {readFile} from 'node:fs/promises';
import {initializeApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {getAuth} from './functions/node_modules/firebase-admin/lib/esm/auth/index.js';
import {WheelioService} from './functions/src/service.mjs';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('Both local emulator hosts must be set. Never run against production.');
initializeApp({projectId:'demo-wheelio'});const db=getFirestore(),auth=getAuth();
const config=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
const action=process.argv[2]??'seed';
if(action==='seed'||action==='seed-ready') {
  await db.doc('config/operations').set(config);
  for(const [uid,phone,name] of [['qa-customer','+919000000001',''],['qa-captain','+919000000002','QA Captain']]){
    try {await auth.createUser({uid,phoneNumber:phone});}catch(e){if(e.code!=='auth/uid-already-exists'&&e.code!=='auth/phone-number-already-exists')throw e;}
    await db.doc(`users/${uid}`).set({name,phone,email:'',freeWashes:0,createdAt:Timestamp.now(),updatedAt:Timestamp.now()});
  }
  await db.doc('captains/qa-captain').set({name:'QA Captain',phone:'+919000000002',approved:false,kycStatus:'notSubmitted',online:false,societyIds:[],paymentMode:'test',rating:0,ratingCount:0,completedWashes:0,activeJobCount:0,createdAt:Timestamp.now()});
  if(action==='seed-ready') {
    await db.doc('users/qa-customer').update({name:'QA Customer'});
    await db.doc('captains/qa-captain').update({approved:true,kycStatus:'approved',societyIds:['soc_avatar']});
    console.log('Booking-only replay: the disposable local Captain fixture is approved. This does not represent a real KYC review.');
  }
  console.log('Local QA accounts ready: Customer 9000000001, Captain 9000000002. SMS codes come only from the Auth emulator.');
} else if(action==='approve') {
  const ref=db.doc('captains/qa-captain'),captain=(await ref.get()).data();
  if(captain?.kycStatus!=='underReview'||!captain.requestedSocietyIds?.includes('soc_avatar'))throw Error('Submit the local QA application first.');
  await ref.update({approved:true,kycStatus:'approved',societyIds:['soc_avatar'],online:false,updatedAt:Timestamp.now()});
  console.log('Approved the disposable emulator Captain application only.');
} else if(action==='status') {
  const orders=await db.collection('orders').where('customerId','==','qa-customer').get();
  for(const doc of orders.docs){const o=doc.data();console.log({bookingId:doc.id,status:o.status,paymentStatus:o.paymentStatus,captainId:o.captainId,evidenceCount:Object.keys(o.evidence??{}).length,rating:o.rating??null,refundStatus:o.refundStatus??null});}
  const earnings=await db.collection('earnings').where('captainId','==','qa-captain').get();
  for(const doc of earnings.docs)console.log({earning:doc.id,status:doc.data().status,amount:doc.data().amount});
} else if(action==='location') {
  const jobs=await db.collection('orders').where('captainId','==','qa-captain').where('status','in',['onTheWay','washing']).get();
  if(jobs.size!==1)throw Error('Expected one active disposable QA wash.');
  const service=new WheelioService({db,payments:null,evidence:null});
  const second=process.argv[3]==='second';
  await service.location({uid:'qa-captain',token:{phone_number:'+919000000002'}},{orderId:jobs.docs[0].id,latitude:second?17.386:17.385,longitude:second?78.4877:78.4867,accuracy:10});
  console.log(`Sent ${second?'second':'first'} synthetic Hyderabad location through the real service to the local emulator only.`);
} else if(action==='capture') {
  const pending=await db.collection('orders').where('customerId','==','qa-customer').where('status','==','pendingPayment').get();
  const service=new WheelioService({db,payments:{keyId:'rzp_test_local_qa',async createOrder({amount,bookingId}){return {id:`order_qa_${bookingId}`,amount,currency:'INR'};}},evidence:null});
  for(const doc of pending.docs) {
    const checkout=await service.checkout({uid:'qa-customer',token:{phone_number:'+919000000001'}},{bookingId:doc.id});
    await service.capturePayment({id:`pay_qa_${doc.id}`,order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'});
  }
  console.log(`Simulated provider capture for ${pending.size} local QA booking(s). No external payment provider was contacted.`);
} else if(action==='codes') {
  const r=await fetch('http://127.0.0.1:9099/emulator/v1/projects/demo-wheelio/verificationCodes');
  const data=await r.json();console.log((data.verificationCodes??[]).filter(c=>['+919000000001','+919000000002'].includes(c.phoneNumber)).map(c=>({phone:c.phoneNumber,code:c.code})));
} else throw Error('Use seed, seed-ready (booking-only replay), approve, status, location [second], capture or codes.');
