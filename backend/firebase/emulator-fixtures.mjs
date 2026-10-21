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
if(action==='seed') {
  await db.doc('config/operations').set(config);
  for(const [uid,phone,name] of [['qa-customer','+919000000001',''],['qa-captain','+919000000002','QA Captain']]){
    try {await auth.createUser({uid,phoneNumber:phone});}catch(e){if(e.code!=='auth/uid-already-exists'&&e.code!=='auth/phone-number-already-exists')throw e;}
    await db.doc(`users/${uid}`).set({name,phone,email:'',freeWashes:0,createdAt:Timestamp.now(),updatedAt:Timestamp.now()});
  }
  await db.doc('captains/qa-captain').set({name:'QA Captain',phone:'+919000000002',approved:true,kycStatus:'approved',online:false,societyIds:['soc_avatar'],paymentMode:'test',rating:0,ratingCount:0,completedWashes:0,activeJobCount:0,createdAt:Timestamp.now()});
  console.log('Local QA accounts ready: Customer 9000000001, Captain 9000000002. SMS codes come only from the Auth emulator.');
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
} else throw Error('Use seed, capture or codes.');
