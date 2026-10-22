import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WheelioService} from './functions/src/service.mjs';
import {signatureMatches,PaymentProviderError} from './functions/src/payments.mjs';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';

let app,db,service,clock,provider,counter;
const auth=uid=>({uid,token:{phone_number:'+919876543210'}});
const customer=auth('customer'), config=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
const input=(requestId='request-1')=>({requestId,plate:'TS09AB1234',societyId:'soc_avatar',vehicleKind:'hatchback',tower:'T3',floor:'B2',parking:'42',note:'Near ramp',washKind:'wetOutside',day:'2026-11-01',startHour:8,endHour:10,pricePaise:1});
before(()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Run only through Firebase emulators:exec.');
  app=initializeApp({projectId:'demo-wheelio'},'service-tests');db=getFirestore(app);
});
after(async()=>{await deleteApp(app);});
beforeEach(async()=>{
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-wheelio/databases/(default)/documents`,{method:'DELETE'});
  clock=Date.parse('2026-11-01T07:00:00+05:30');counter=0;
  provider={keyId:'rzp_test_fake',refundCalls:0,payments:new Map(),
    async findRefund(){return null;},
    async createOrder({amount}){return {id:`order_${++counter}`,amount,currency:'INR'};},
    verify:({signature})=>signature==='valid',async payment(id){return this.payments.get(id);},async orderPayments(id){return {items:[...this.payments.values()].filter(p=>p.order_id===id)};},
    async refund({paymentId,amount,refundId}){this.refundCalls++;return {id:`refund_${refundId}`,payment_id:paymentId,amount,status:'processed'};},
  };
  service=new WheelioService({db,payments:provider,now:()=>clock,evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100})}});
  await db.doc('config/operations').set(config);
  await service.register(customer,{role:'customer',name:'Test Customer'});
  for(const uid of ['captain1','captain2']) {await service.register(auth(uid),{role:'captain',name:`Test ${uid}`});await db.doc(`captains/${uid}`).update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});}
});
async function paid(requestId='request-1') {
  const booking=await service.createBooking(customer,input(requestId));const checkout=await service.checkout(customer,booking);
  const payment={id:`pay_${counter}`,order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'};provider.payments.set(payment.id,payment);
  await service.capturePayment(payment);return {...booking,payment};
}
test('phone verification and server pricing cannot be bypassed',async()=>{
  await assert.rejects(service.createBooking({uid:'customer',token:{}},input()),{code:'permission-denied'});
  const b=await service.createBooking(customer,input());assert.equal(b.amount,14900);
  assert.equal((await service.createBooking(customer,input())).bookingId,b.bookingId);
  await assert.rejects(service.checkout(auth('stranger'),b),{code:'permission-denied'});
});
test('unsigned callbacks, mismatched amounts and uncaptured authorizations cannot create a paid booking',async()=>{
  const b=await service.createBooking(customer,input());const checkout=await service.checkout(customer,b);
  await assert.rejects(service.verifyPayment(customer,{...b,orderId:checkout.orderId,paymentId:'pay_bad',signature:'bad'}),{code:'permission-denied'});
  await assert.rejects(service.capturePayment({id:'pay_bad',order_id:checkout.orderId,amount:1,currency:'INR',status:'captured'}),{code:'permission-denied'});
  await service.capturePayment({id:'pay_pending',order_id:checkout.orderId,status:'authorized'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().status,'pendingPayment');
});
test('only one captain wins simultaneous claims; another customer cannot claim or read exact details from offers',async()=>{
  const b=await paid();
  const offer=(await db.collection('jobOffers').get()).docs[0].data();assert.equal(offer.plate,undefined);assert.equal(offer.note,undefined);assert.equal(offer.parking,undefined);
  const results=await Promise.allSettled(['captain1','captain2'].map(uid=>service.claim(auth(uid),{orderId:b.bookingId})));
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  const o=(await db.doc(`orders/${b.bookingId}`).get()).data();assert.equal(o.status,'onTheWay');assert.ok(['captain1','captain2'].includes(o.captainId));
});

test('shared-merchant webhooks ignore unrelated payments and still verify Wheelio captures',async()=>{
  provider.payments.set('pay_trustkeyper',{id:'pay_trustkeyper',order_id:'order_other_app',amount:50000,currency:'INR',status:'captured'});
  provider.payments.set('pay_without_order',{id:'pay_without_order',amount:50000,currency:'INR',status:'captured'});
  assert.deepEqual(await service.captureWebhookPayment('pay_trustkeyper'),{ignored:true});
  assert.deepEqual(await service.captureWebhookPayment('pay_without_order'),{ignored:true});
  assert.equal((await db.collection('orders').get()).size,0);
  const b=await service.createBooking(customer,input()),c=await service.checkout(customer,b);
  provider.payments.set('pay_owned',{id:'pay_owned',order_id:c.orderId,amount:1,currency:'INR',status:'captured'});
  await assert.rejects(service.captureWebhookPayment('pay_owned'),{code:'permission-denied'});
  provider.payments.get('pay_owned').amount=c.amount;
  assert.deepEqual(await service.captureWebhookPayment('pay_owned'),{ignored:false});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().paymentStatus,'captured');
});
test('expiry, offline and overlapping assignments are enforced by the server',async()=>{
  const b=await paid();clock+=61000;await assert.rejects(service.claim(auth('captain1'),{orderId:b.bookingId}),{code:'deadline-exceeded'});
  await service.dispatch(b.bookingId);await db.doc('captains/captain1').update({online:false});await assert.rejects(service.claim(auth('captain1'),{orderId:b.bookingId}),{code:'permission-denied'});
  await service.claim(auth('captain2'),{orderId:b.bookingId});const b2=await paid('request-2');
  await assert.rejects(service.claim(auth('captain2'),{orderId:b2.bookingId}),{code:'failed-precondition'});
});
test('wash lifecycle requires assigned captain, arrival and four uploaded photos per stage; customer alone approves',async()=>{
  const b=await paid(),d={orderId:b.bookingId};await service.claim(auth('captain1'),d);
  await assert.rejects(service.progress(auth('captain2'),{...d,action:'arrived'}),{code:'permission-denied'});
  await assert.rejects(service.progress(auth('captain1'),{...d,action:'start'}),{code:'failed-precondition'});
  await service.progress(auth('captain1'),{...d,action:'arrived'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...d,stage:'before',side});
  await service.progress(auth('captain1'),{...d,action:'start'});
  await assert.rejects(service.progress(auth('captain1'),{...d,action:'finish'}),{code:'failed-precondition'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...d,stage:'after',side});
  await service.progress(auth('captain1'),{...d,action:'finish'});
  assert.equal((await db.doc(`earnings/${b.bookingId}`).get()).data().status,'awaitingApproval');
  await assert.rejects(service.approve(auth('captain1'),d),{code:'permission-denied'});
  await service.approve(customer,d);await service.approve(customer,d);
  assert.equal((await db.doc('captains/captain1').get()).data().completedWashes,1);
  await service.rate(customer,{...d,stars:5});await assert.rejects(service.rate(customer,{...d,stars:1}),{code:'already-exists'});
});
test('replayed capture and cancellation produce one refund and release capacity',async()=>{
  const b=await paid();await service.capturePayment(b.payment);
  const ref=db.doc(`orders/${b.bookingId}`),slot=(await ref.get()).data().slotKey;
  assert.equal((await db.doc(`slotCapacity/${slot}`).get()).data().reserved,1);
  await service.cancel(customer,{orderId:b.bookingId});await service.cancel(customer,{orderId:b.bookingId});
  await Promise.all([service.processRefund(b.bookingId),service.processRefund(b.bookingId)]);
  assert.equal(provider.refundCalls,1);assert.equal((await ref.get()).data().refundStatus,'processed');
  assert.equal((await db.doc(`slotCapacity/${slot}`).get()).data().reserved,0);
});

test('a rejected refund stays fully due, backs off and retries with the same idempotency key',async()=>{
  const b=await paid(),requests=[];await service.cancel(customer,{orderId:b.bookingId});
  provider.refund=async request=>{requests.push(request);throw new PaymentProviderError(400,'BAD_REQUEST_ERROR');};
  await assert.rejects(service.processRefund(b.bookingId),{status:400});
  let r=(await db.doc(`refunds/${b.bookingId}`).get()).data();
  assert.equal(r.status,'retry');assert.equal(r.amount,14900);assert.equal(r.lastErrorCode,'BAD_REQUEST_ERROR');
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'delayed');
  await service.processRefund(b.bookingId);await service.checkPayment(customer,b);
  await assert.rejects(service.checkPayment(auth('stranger'),b),{code:'permission-denied'});
  assert.equal(requests.length,1);
  clock=r.nextAttemptAt.toMillis()+1;
  provider.refund=async request=>{requests.push(request);return{id:'rfnd_recovered',payment_id:request.paymentId,amount:request.amount,status:'processed'};};
  await service.processRefund(b.bookingId);assert.deepEqual(requests[0],requests[1]);
  r=(await db.doc(`refunds/${b.bookingId}`).get()).data();assert.equal(r.status,'processed');assert.equal(r.lastErrorCode,undefined);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundIssue,undefined);
});

test('a refund accepted before a lost response is found instead of creating another refund',async()=>{
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});
  provider.findRefund=async({paymentId,refundId})=>({id:'rfnd_existing',payment_id:paymentId,amount:14900,status:'processed',receipt:refundId});
  await service.processRefund(b.bookingId);assert.equal(provider.refundCalls,0);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().providerRefundId,'rfnd_existing');
});

test('customer status checks reconcile an existing pending refund without issuing a second POST',async()=>{
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});
  provider.refund=async({paymentId,amount})=>{provider.refundCalls++;return{id:'rfnd_pending',payment_id:paymentId,amount,status:'pending'};};
  await service.processRefund(b.bookingId);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'submitted');
  provider.fetchRefund=async()=>({id:'rfnd_pending',payment_id:b.payment.id,amount:14900,status:'processed'});
  const result=await service.checkPayment(customer,b);assert.equal(result.refundStatus,'processed');assert.equal(provider.refundCalls,1);
});

test('late worker errors or pending results cannot downgrade a verified processed refund',async()=>{
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});
  let release,entered;const started=new Promise(resolve=>entered=resolve);
  provider.refund=async()=>{entered();await new Promise(resolve=>release=resolve);throw new PaymentProviderError(503);};
  const work=service.processRefund(b.bookingId);const rejected=assert.rejects(work,{status:503});await started;
  const result={id:'rfnd_webhook',payment_id:b.payment.id,amount:14900,status:'processed'};
  await service.applyRefund(b.bookingId,result);release();await rejected;
  await service.applyRefund(b.bookingId,{...result,status:'pending'});
  assert.equal((await db.doc(`refunds/${b.bookingId}`).get()).data().status,'processed');
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'processed');
});

test('failed or mismatched provider refunds need review and are never marked sent or recreated',async()=>{
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});
  provider.findRefund=async()=>({id:'rfnd_failed',payment_id:b.payment.id,amount:14900,status:'failed'});
  await service.processRefund(b.bookingId);await service.processRefund(b.bookingId);
  assert.equal(provider.refundCalls,0);assert.equal((await db.doc(`refunds/${b.bookingId}`).get()).data().status,'needsReview');
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundIssue,'providerFailed');
  await assert.rejects(service.applyRefund(b.bookingId,{id:'rfnd_wrong',payment_id:b.payment.id,amount:1,status:'processed'}),{code:'internal'});
});
test('payments captured after cancellation are refunded and never dispatched',async()=>{
  const b=await service.createBooking(customer,input());const c=await service.checkout(customer,b);await service.cancel(customer,{orderId:b.bookingId});
  await service.capturePayment({id:'pay_late',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().status,'cancelled');assert.equal((await db.collection('jobOffers').get()).size,0);
  await service.processRefund(b.bookingId);assert.equal(provider.refundCalls,1);
});
test('a captain cannot self-approve KYC or receive work without approval; mode isolation holds',async()=>{
  await service.register(auth('newcaptain'),{role:'captain',name:'New Captain'});
  await service.submitCaptainApplication(auth('newcaptain'),{societyIds:['soc_avatar'],upi:'test@upi'});
  assert.equal((await db.doc('captains/newcaptain').get()).data().approved,false);
  await assert.rejects(service.captainOnline(auth('newcaptain'),{online:true}),{code:'permission-denied'});
  await db.doc('captains/captain1').update({paymentMode:'live'});await db.doc('captains/captain2').update({approved:false});
  await assert.rejects(service.createBooking(customer,input()),{code:'resource-exhausted'});
});
test('availability reports actual capacity and expired checkout captures refund instead of dispatching',async()=>{
  let slots=await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'});assert.equal(slots.slots.find(s=>s.startHour===8).available,true);
  const b=await service.createBooking(customer,input());const c=await service.checkout(customer,b);clock+=16*60000;
  await service.capturePayment({id:'pay_expired',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().status,'cancelled');
  await db.doc('captains/captain1').update({approved:false});await db.doc('captains/captain2').update({approved:false});
  slots=await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'});assert.ok(slots.slots.every(s=>!s.available));
});
test('scheduled reconciliation recovers a lost checkout callback',async()=>{
  const b=await service.createBooking(customer,input());const c=await service.checkout(customer,b);
  provider.payments.set('pay_recover',{id:'pay_recover',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
  await service.reconcilePayment(b.bookingId);await service.reconcilePayment(b.bookingId);
  const o=(await db.doc(`orders/${b.bookingId}`).get()).data();assert.equal(o.status,'searching');assert.equal(o.nextPaymentCheckAt,undefined);
});
test('live location belongs to the assigned active captain and throttles rapid updates',async()=>{
  const b=await paid(),data={orderId:b.bookingId,latitude:17.385,longitude:78.4867,accuracy:12};
  await assert.rejects(service.location(auth('captain1'),data),{code:'permission-denied'});
  await service.claim(auth('captain1'),data);
  await assert.rejects(service.location(auth('captain2'),data),{code:'permission-denied'});
  await assert.rejects(service.location(auth('captain1'),{...data,latitude:91}),{code:'invalid-argument'});
  await service.location(auth('captain1'),data);
  const ref=db.doc(`orders/${b.bookingId}/tracking/current`),first=(await ref.get()).data();
  clock=first.updatedAt.toMillis()+1000;
  await service.location(auth('captain1'),{...data,latitude:17.386});
  assert.equal((await ref.get()).data().latitude,data.latitude);
  clock+=5000;
  await service.location(auth('captain1'),{...data,latitude:17.387});
  assert.equal((await ref.get()).data().latitude,17.387);
  await service.cancel(customer,{orderId:b.bookingId});
  await assert.rejects(service.location(auth('captain1'),data),{code:'permission-denied'});
});

test('assigned cancellation withdraws offers, releases the captain and prevents starting work',async()=>{
  const b=await paid(),data={orderId:b.bookingId};
  await service.claim(auth('captain1'),data);
  await service.cancel(customer,data);
  assert.equal((await db.doc('captains/captain1').get()).data().activeJobCount,0);
  assert.ok((await db.collection('jobOffers').where('orderId','==',b.bookingId).get()).docs.every(d=>d.data().status==='withdrawn'));
  await assert.rejects(service.progress(auth('captain1'),{...data,action:'arrived'}),{code:'failed-precondition'});
  await service.processRefund(b.bookingId);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'processed');
});

test('customer problems hold earnings and cannot be opened or approved by the captain',async()=>{
  const b=await paid(),data={orderId:b.bookingId};
  await service.claim(auth('captain1'),data);
  await service.progress(auth('captain1'),{...data,action:'arrived'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...data,stage:'before',side});
  await service.progress(auth('captain1'),{...data,action:'start'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...data,stage:'after',side});
  await service.progress(auth('captain1'),{...data,action:'finish'});
  await assert.rejects(service.reportProblem(auth('captain1'),{...data,kind:'notClean',note:'Test'}),{code:'permission-denied'});
  await service.reportProblem(customer,{...data,kind:'notClean',note:'Missed the rear window'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().status,'disputed');
  assert.equal((await db.doc(`earnings/${b.bookingId}`).get()).data().status,'onHold');
  assert.equal((await db.doc(`supportTickets/${b.bookingId}`).get()).data().customerId,'customer');
  await assert.rejects(service.approve(customer,data),{code:'failed-precondition'});
});

test('HMAC signatures are checked against original bytes and malformed signatures are rejected',()=>{
  const raw=Buffer.from('{"event":"payment.captured"}'),sig=createHmac('sha256','test-secret').update(raw).digest('hex');
  assert.equal(signatureMatches(raw,sig,'test-secret'),true);assert.equal(signatureMatches(Buffer.from('changed'),sig,'test-secret'),false);
  for(const bad of [null,'','0','z'.repeat(64),'f'.repeat(64)])assert.equal(signatureMatches(raw,bad,'test-secret'),false);
});
