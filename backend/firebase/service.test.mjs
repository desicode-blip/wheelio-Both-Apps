import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
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
  service=new WashKrewService({db,payments:provider,now:()=>clock,evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100})}});
  await db.doc('config/operations').set(config);
  await service.register(customer,{role:'customer',name:'Test Customer'});
  for(const uid of ['captain1','captain2']) {await service.register(auth(uid),{role:'captain',name:`Test ${uid}`});await db.doc(`captains/${uid}`).update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});}
});
async function paid(requestId='request-1') {
  const booking=await service.createBooking(customer,input(requestId));const checkout=await service.checkout(customer,booking);
  const payment={id:`pay_${counter}`,order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'};provider.payments.set(payment.id,payment);
  await service.capturePayment(payment);return {...booking,payment};
}
test('route ETA uses actual shared location, throttles refresh and rejects stale assignment results',async()=>{
  const ref=db.doc('orders/route-test');await ref.set({captainId:'captain1',status:'onTheWay',societyId:'soc_avatar',vehiclePosition:{latitude:17.4,longitude:78.35}});
  let calls=0;service.maps={arrival:async()=>{calls++;return {seconds:180,distanceMetres:1300};}};
  const location={orderId:ref.id,latitude:17.41,longitude:78.36};
  await assert.rejects(service.location(customer,location),{code:'permission-denied'});
  await service.location(auth('captain1'),location);assert.equal((await ref.get()).data().arrivalEstimateAt.toMillis(),clock+180000);
  clock+=15000;await service.location(auth('captain1'),location);assert.equal(calls,1);
  clock+=90000;service.maps={arrival:async()=>{await ref.update({status:'washing'});return {seconds:900,distanceMetres:9000};}};
  await service.location(auth('captain1'),location);assert.equal((await ref.get()).data().arrivalDistanceMetres,1300);
});
test('route provider outages retain private GPS and clear ETA instead of inventing one',async()=>{
  const ref=db.doc('orders/route-fail');await ref.set({captainId:'captain1',status:'onTheWay',societyId:'soc_avatar',vehiclePosition:{latitude:17.4,longitude:78.35}});
  service.maps={arrival:async()=>{throw Error('unavailable');}};
  await service.location(auth('captain1'),{orderId:ref.id,latitude:17.41,longitude:78.36});
  assert.equal((await ref.get()).data().arrivalStatus,'unavailable');assert.equal((await ref.get()).data().arrivalEstimateAt,undefined);
  assert.equal((await ref.collection('tracking').doc('current').get()).data().latitude,17.41);
});
test('server training rejects skipping, survives reopening and grades the current quiz',async()=>{
  const training={version:'approved-v1',required:true,videos:[0,1,2].map(()=>({url:'https://example.test/approved.mp4',seconds:20}))};
  await db.doc('config/operations').update({training});
  const captain=auth('captain1');
  await assert.rejects(service.submitQuiz(captain,{version:'wash-safety-1',answers:[0,0,1,0,0]}),{code:'failed-precondition'});
  let session=await service.startTraining(captain,{index:0});
  assert.equal((await service.trainingHeartbeat(captain,{index:0,session:session.session,positionSeconds:20})).completed,false);
  session=await service.startTraining(captain,{index:0});assert.equal(session.watchedSeconds,0);
  for(let index=0;index<3;index++){
    const s=await service.startTraining(captain,{index});
    clock+=10000;assert.equal((await service.trainingHeartbeat(captain,{index,session:s.session,positionSeconds:10})).completed,false);
    clock+=10000;assert.equal((await service.trainingHeartbeat(captain,{index,session:s.session,positionSeconds:20})).completed,true);
  }
  assert.deepEqual(await service.submitQuiz(captain,{version:'wash-safety-1',answers:[0,0,1,0,0]}),{score:5,passed:true});
  await db.doc('config/operations').update({'training.version':'approved-v2'});
  await assert.rejects(service.submitQuiz(captain,{version:'wash-safety-1',answers:[0,0,1,0,0]}),{code:'failed-precondition'});
});
test('unpublished training never reports completion and owner work restrictions cannot be bypassed',async()=>{
  await assert.rejects(service.startTraining(auth('captain1'),{index:0}),{code:'failed-precondition'});
  await service.setCaptainPolicy({captainId:'captain1',workStatus:'blocked',jobLimit:2,levelDay:1,reason:'Manual test review'});
  await assert.rejects(service.captainOnline(auth('captain1'),{online:true}),{code:'failed-precondition'});
  const available=await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'});assert.equal(available.slots.some(s=>s.available),true);
  await service.setCaptainPolicy({captainId:'captain2',workStatus:'refresher',jobLimit:2,levelDay:1,reason:'Manual test review'});
  assert.equal((await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'})).slots.some(s=>s.available),false);
  await service.scheduleIntro({captainId:'captain1',at:new Date(clock+3600000).toISOString()});
  assert.match((await db.doc('captains/captain1').get()).data().introCallLabel,/IST/);
});
test('per-job face checking is assignment-bound, server-verified and uncertain matches require human review',async()=>{
  const ref=db.doc('orders/identity-test');await ref.set({captainId:'captain1',customerId:'customer',status:'onTheWay',arrivedAt:Timestamp.fromMillis(clock),slotStart:Timestamp.fromMillis(clock-1000),paymentMode:'test',evidence:Object.fromEntries([0,1,2,3].map(i=>[`before_${i}`,{path:`orders/identity-test/captain1/before_${i}.jpg`}]))});
  await db.doc('privateConfig/photoChecks').set({enabled:true,paymentMode:'test'});
  const removed=[];service.evidence.read=async()=>Buffer.from('private-fixture');service.evidence.deletePrefix=async p=>removed.push(p);service.photoChecks={compare:async()=>({status:'review',score:.1,model:'local-test-stub'})};
  await assert.rejects(service.beginIdentity(customer,{orderId:ref.id}),{code:'permission-denied'});
  await assert.rejects(service.progress(auth('captain1'),{orderId:ref.id,action:'start'}),{code:'failed-precondition'});
  const attempt=await service.beginIdentity(auth('captain1'),{orderId:ref.id});
  await assert.rejects(service.verifyIdentity(auth('captain2'),{orderId:ref.id,session:attempt.session}),{code:'permission-denied'});
  assert.equal((await service.verifyIdentity(auth('captain1'),{orderId:ref.id,session:attempt.session})).verified,false);
  await assert.rejects(service.progress(auth('captain1'),{orderId:ref.id,action:'start'}),{code:'failed-precondition'});
  await service.reviewIdentity({orderId:ref.id,accept:true,reason:'Human fixture review'});
  await service.progress(auth('captain1'),{orderId:ref.id,action:'start'});assert.equal((await ref.get()).data().status,'washing');
  clock+=24*3600000+1;await service.cleanupIdentityChecks();assert.equal((await db.doc(`identityChecks/${ref.id}`).get()).exists,false);assert.ok(removed.includes(attempt.path));
});
test('photo review binds the current evidence, requires warning acknowledgement and never approves the wash',async()=>{
  const ref=db.doc('orders/photo-review');await ref.set({captainId:'captain1',customerId:'customer',status:'washing',paymentMode:'test',slotStart:Timestamp.fromMillis(clock-1000),captainPayPaise:11600,evidence:Object.fromEntries([0,1,2,3].map(i=>[`after_${i}`,{path:`orders/photo-review/captain1/after_${i}.jpg`,uploadedAt:Timestamp.fromMillis(clock)}]))});
  await db.doc('privateConfig/photoChecks').set({enabled:true,aiEnabled:true,paymentMode:'test'});
  service.evidence.read=async()=>Buffer.from('fixture');let calls=0;service.photoChecks={reviewWash:async()=>{calls++;return [{side:2,reason:'Visible dust; review the left side.'}];}};
  await assert.rejects(service.checkWashPhotos(customer,{orderId:ref.id}),{code:'permission-denied'});
  assert.equal((await service.checkWashPhotos(auth('captain1'),{orderId:ref.id})).issues[0].side,2);
  await service.checkWashPhotos(auth('captain1'),{orderId:ref.id});assert.equal(calls,1);
  await assert.rejects(service.progress(auth('captain1'),{orderId:ref.id,action:'finish'}),{code:'failed-precondition'});
  await service.progress(auth('captain1'),{orderId:ref.id,action:'finish',acknowledgePhotoIssues:true});
  assert.equal((await ref.get()).data().status,'photosReady');assert.equal((await db.doc(`earnings/${ref.id}`).get()).data().status,'awaitingApproval');
});
test('photo-review outages are labelled honestly and can retry without retaking unchanged evidence',async()=>{
  const ref=db.doc('orders/review-outage');await ref.set({captainId:'captain1',status:'washing',paymentMode:'test',evidence:Object.fromEntries([0,1,2,3].map(i=>[`after_${i}`,{path:`orders/review-outage/captain1/after_${i}.jpg`,uploadedAt:Timestamp.fromMillis(clock)}]))});
  await db.doc('privateConfig/photoChecks').set({enabled:true,aiEnabled:true,paymentMode:'test'});service.evidence.read=async()=>Buffer.from('fixture');
  service.photoChecks={reviewWash:async()=>{throw Error('Provider offline');}};
  assert.equal((await service.checkWashPhotos(auth('captain1'),{orderId:ref.id})).status,'unavailable');
  clock+=31000;service.photoChecks={reviewWash:async()=>[]};
  assert.deepEqual(await service.checkWashPhotos(auth('captain1'),{orderId:ref.id}),{issues:[],status:'checked'});
});
test('evidence registration checks decoded quality and cannot use an overwritten image generation',async()=>{
  const ref=db.doc('orders/quality-proof');await ref.set({captainId:'captain1',status:'onTheWay',arrivedAt:Timestamp.fromMillis(clock),slotStart:Timestamp.fromMillis(clock-1000),paymentMode:'test',identityStatus:'verified'});
  await db.doc('privateConfig/photoChecks').set({enabled:true,paymentMode:'test'});let checks=0;
  service.evidence.metadata=async()=>({contentType:'image/jpeg',size:100,generation:'1'});service.evidence.read=async()=>Buffer.from('local fixture');
  service.photoChecks={quality:async()=>{checks++;return {issue:'tooDark'};}};
  await assert.rejects(service.evidenceUploaded(customer,{orderId:ref.id,stage:'before',side:0}),{code:'permission-denied'});assert.equal(checks,0);
  await assert.rejects(service.evidenceUploaded(auth('captain1'),{orderId:ref.id,stage:'before',side:0}),{code:'failed-precondition'});
  assert.equal((await ref.get()).data().evidence,undefined);
  service.photoChecks.quality=async()=>({issue:null});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{orderId:ref.id,stage:'before',side});
  service.evidence.metadata=async()=>({contentType:'image/jpeg',size:100,generation:'2'});
  await assert.rejects(service.progress(auth('captain1'),{orderId:ref.id,action:'start'}),{code:'failed-precondition'});
});
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

test('shared-merchant webhooks ignore unrelated payments and still verify WashKrew captures',async()=>{
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
  await assert.rejects(service.progress(auth('captain1'),{...d,action:'arrived'}),{code:'failed-precondition'});
  clock=Date.parse('2026-11-01T08:00:00+05:30');
  await assert.rejects(service.progress(auth('captain2'),{...d,action:'arrived'}),{code:'permission-denied'});
  await assert.rejects(service.progress(auth('captain1'),{...d,action:'start'}),{code:'failed-precondition'});
  await service.progress(auth('captain1'),{...d,action:'arrived'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...d,stage:'before',side});
  await service.progress(auth('captain1'),{...d,action:'start'});
  await assert.rejects(service.progress(auth('captain1'),{...d,action:'finish'}),{code:'failed-precondition'});
  for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain1'),{...d,stage:'after',side});
  await service.progress(auth('captain1'),{...d,action:'finish'});
  assert.equal((await db.doc(`earnings/${b.bookingId}`).get()).data().status,'awaitingApproval');
  assert.equal((await db.doc(`earnings/${b.bookingId}`).get()).data().paymentMode,'test');
  await assert.rejects(service.approve(auth('captain1'),d),{code:'permission-denied'});
  await service.approve(customer,d);await service.approve(customer,d);
  assert.equal((await db.doc(`earnings/${b.bookingId}`).get()).data().paymentMode,'test');
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

test('historical test callbacks and refunds keep their original credentials after live cutover',async()=>{
  const b=await service.createBooking(customer,input()),c=await service.checkout(customer,b);
  provider.payments.set('pay_before_cutover',{id:'pay_before_cutover',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
  const live={keyId:'rzp_live_fake',async orderPayments(){assert.fail('Test reconciliation used live keys');},async refund(){assert.fail('Test refund used live keys');}};
  service.paymentProviders={test:provider,live};service.payments=live;
  await db.doc('config/operations').update({paymentMode:'live'});
  await service.reconcilePayment(b.bookingId);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().status,'searching');
  await service.cancel(customer,{orderId:b.bookingId});
  await service.processRefund(b.bookingId);
  assert.equal(provider.refundCalls,1);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'processed');
});

test('a test reservation cannot consume live capacity and historical test slot keys stay valid',async()=>{
  await db.doc('config/operations').update({capacityPerSlot:1});
  const b=await paid(),old=(await db.doc(`orders/${b.bookingId}`).get()).data();
  assert.equal((await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'})).slots.find(s=>s.startHour===8).available,false);
  const {createHash}=await import('node:crypto');
  assert.equal(old.slotKey,createHash('sha256').update('soc_avatar:2026-11-01:8').digest('hex').slice(0,32));
  const live={...provider,keyId:'rzp_live_fake',payments:new Map()};
  service.paymentProviders={test:provider,live};service.payments=live;
  await db.doc('captains/captain2').update({paymentMode:'live'});
  await db.doc('config/operations').update({paymentMode:'live'});
  assert.equal((await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'})).slots.find(s=>s.startHour===8).available,true);
  const next=await service.createBooking(customer,input('live-request')),checkout=await service.checkout(customer,next);
  assert.equal(checkout.keyId,'rzp_live_fake');assert.equal(checkout.testMode,false);
  const capture={id:'pay_live',order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'};
  live.payments.set(capture.id,capture);
  await service.captureWebhookPayment(capture.id,'live',checkout.orderId);
  const current=(await db.doc(`orders/${next.bookingId}`).get()).data();
  assert.notEqual(current.slotKey,old.slotKey);
  for(const key of [old.slotKey,current.slotKey])assert.equal((await db.doc(`slotCapacity/${key}`).get()).data().reserved,1);
  const offers=(await db.collection('jobOffers').where('orderId','==',next.bookingId).get()).docs;
  assert.equal(offers.length,1);assert.equal(offers[0].data().paymentMode,'live');assert.equal(offers[0].data().captainId,'captain2');
  await assert.rejects(service.claim(auth('captain1'),{orderId:next.bookingId}),{code:'permission-denied'});
  await service.cancel(customer,{orderId:b.bookingId});
  assert.equal((await db.doc(`slotCapacity/${current.slotKey}`).get()).data().reserved,1);
});

test('wrong-mode captures and unconfigured live checkout cannot use test keys',async()=>{
  const b=await service.createBooking(customer,input()),c=await service.checkout(customer,b);
  const capture={id:'pay_wrong_mode',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'};
  await assert.rejects(service.capturePayment(capture,'live'),{code:'permission-denied'});
  provider.payments.set(capture.id,capture);
  await assert.rejects(service.captureWebhookPayment(capture.id,'live',c.orderId),{code:'permission-denied'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().paymentStatus,'unpaid');
  assert.throws(()=>service.getPayments('live'),{code:'failed-precondition'});
  await service.cancel(customer,{orderId:b.bookingId});
  await db.doc('config/operations').update({paymentMode:'live'});
  await db.doc('captains/captain1').update({paymentMode:'live'});
  const liveBooking=await service.createBooking(customer,input('missing-live-keys'));
  await assert.rejects(service.checkout(customer,liveBooking),{code:'failed-precondition'});
  assert.equal(counter,1);
});

test('unrelated shared-merchant live events need no provider access',async()=>{
  assert.deepEqual(await service.captureWebhookPayment('pay_other_live','live','order_other_live'),{ignored:true});
  assert.deepEqual(await service.refundWebhook({id:'rfnd_other_live'},'live'),{ignored:true});
  assert.equal((await db.collection('orders').get()).size,0);
});

test('refund webhooks reject the wrong environment and verify through the archived test provider',async()=>{
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});
  provider.refund=async({paymentId,amount})=>({id:'rfnd_mode',payment_id:paymentId,amount,status:'pending'});
  await service.processRefund(b.bookingId);
  const result={id:'rfnd_mode',payment_id:b.payment.id,amount:14900,status:'processed'};
  provider.fetchRefund=async()=>result;
  const live={keyId:'rzp_live_fake',async fetchRefund(){assert.fail('Test refund webhook used live keys');}};
  service.paymentProviders={test:provider,live};service.payments=live;
  await assert.rejects(service.refundWebhook(result,'live'),{code:'permission-denied'});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'submitted');
  assert.deepEqual(await service.refundWebhook(result,'test'),{ignored:false});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().refundStatus,'processed');
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
  clock=Date.parse('2026-11-01T08:00:00+05:30');
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


test('wallet reservation is atomic, free checkout uses no provider order, and cancellation restores once',async()=>{
  await db.doc('wallets/customer_test').set({customerId:'customer',paymentMode:'test',freeWashes:1,creditPaise:0});
  const b=await service.createBooking(customer,{...input(),useFreeWash:true,expectedAmountPaise:0});
  assert.equal(b.amount,0);
  assert.equal((await db.doc('wallets/customer_test').get()).data().freeWashes,0);
  const checkout=await service.checkout(customer,b);assert.equal(checkout.paid,true);assert.equal(counter,0);
  await service.checkout(customer,b);
  await service.cancel(customer,{orderId:b.bookingId});await service.cancel(customer,{orderId:b.bookingId});
  assert.equal((await db.doc('wallets/customer_test').get()).data().freeWashes,1);
  assert.equal((await db.doc(`refunds/${b.bookingId}`).get()).exists,false);
});
test('payment expiry restores reserved credit; late capture refunds only cash without restoring twice',async()=>{
  await db.doc('wallets/customer_test').set({customerId:'customer',paymentMode:'test',freeWashes:0,creditPaise:7500});
  const b=await service.createBooking(customer,{...input(),useCredit:true,expectedAmountPaise:7400});
  const checkout=await service.checkout(customer,b);
  assert.equal(checkout.amount,7400);
  clock+=16*60000;
  await service.cancel({uid:'customer'},{orderId:b.bookingId},{paymentExpired:true});
  assert.equal((await db.doc('wallets/customer_test').get()).data().creditPaise,7500);
  await service.capturePayment({id:'pay_late',order_id:checkout.orderId,amount:7400,currency:'INR',status:'captured'});
  assert.equal((await db.doc('wallets/customer_test').get()).data().creditPaise,7500);
  assert.equal((await db.doc(`refunds/${b.bookingId}`).get()).data().amount,7400);
});
test('wallet cancellation snapshots grant early free wash or late credit only once and never cross modes',async()=>{
  await db.doc('config/operations').update({cancellationPolicy:{kind:'wallet',freeWashMinutes:15,lateCreditBps:5000}});
  const b=await paid();await service.cancel(customer,{orderId:b.bookingId});await service.cancel(customer,{orderId:b.bookingId});
  assert.equal((await db.doc('wallets/customer_test').get()).data().freeWashes,1);
  const b2=await paid('second');clock+=16*60000;
  await service.cancel(customer,{orderId:b2.bookingId});
  assert.equal((await db.doc('wallets/customer_test').get()).data().creditPaise,7500);
  assert.equal((await db.doc('wallets/customer_live').get()).exists,false);
  assert.equal((await db.collection('refunds').get()).size,0);
});
test('multiple windows choose capacity, expire into the next window and respect captain hours',async()=>{
  for(const uid of ['captain1','captain2'])await service.captainPreferences(auth(uid),{workingWindows:[{startHour:10,endHour:14}]});
  await assert.rejects(service.createBooking(customer,input()),{code:'resource-exhausted'});
  const b=await service.createBooking(customer,{...input(),windows:[{startHour:8,endHour:10},{startHour:10,endHour:12},{startHour:12,endHour:14}]});
  const checkout=await service.checkout(customer,b);
  await service.capturePayment({id:'pay_windows',order_id:checkout.orderId,amount:14900,currency:'INR',status:'captured'});
  let o=(await db.doc(`orders/${b.bookingId}`).get()).data();assert.equal(o.startHour,10);
  clock=Date.parse('2026-11-01T12:01:00+05:30');await service.dispatch(b.bookingId);
  o=(await db.doc(`orders/${b.bookingId}`).get()).data();assert.equal(o.startHour,12);
  assert.equal((await db.doc(`slotCapacity/${o.slotKey}`).get()).data().reserved,1);
});

test('all nine selected 4 AM–10 PM windows survive booking, capture and Captain offers',async()=>{
  const b=await service.createBooking(customer,{...input('all-day-nine'),day:'2026-11-02',windows:config.slotWindows,anyTime:true});
  const checkout=await service.checkout(customer,b);
  await service.capturePayment({id:'pay_all_day_nine',order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'});
  const o=(await db.doc(`orders/${b.bookingId}`).get()).data();
  assert.equal(o.anyTime,true);assert.deepEqual(o.requestedWindows,config.slotWindows);
  assert.equal(o.startHour,4);assert.equal(o.status,'searching');
  const offers=await db.collection('jobOffers').where('orderId','==',b.bookingId).get();
  assert.equal(offers.size,2);
  for(const offer of offers.docs){assert.equal(offer.data().anyTime,true);assert.deepEqual(offer.data().requestedWindows,config.slotWindows);}
});

test('exact half-hour preferences persist and match early/late booking, payment, offers and claim',async()=>{
  clock=Date.parse('2026-11-01T03:30:00+05:30');
  const slots=[{startMinute:240,endMinute:300},{startMinute:1230,endMinute:1320}];
  await service.captainPreferences(auth('captain1'),{workingSlots:slots,areaPreference:{mode:'all'}});
  await db.doc('captains/captain2').update({approved:false});
  assert.deepEqual((await db.doc('captains/captain1').get()).data().workingSlots,slots);
  const available=await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'});
  assert.deepEqual(available.slots.filter(s=>s.available).map(s=>s.startHour),[4,20]);
  clock=Date.parse('2026-11-01T05:30:00+05:30');
  assert.deepEqual((await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'})).slots.filter(s=>s.available).map(s=>s.startHour),[20]);
  clock=Date.parse('2026-11-01T03:30:00+05:30');
  const b=await service.createBooking(customer,{...input('late-exact'),startHour:20,endHour:22});
  const checkout=await service.checkout(customer,b);
  await db.doc('captains/captain1').update({lastSeenAt:Timestamp.fromMillis(clock)});
  await service.capturePayment({id:'pay_exact',order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'});
  const offers=await db.collection('jobOffers').where('orderId','==',b.bookingId).get();
  assert.deepEqual(offers.docs.map(d=>d.data().captainId),['captain1']);
  await service.claim(auth('captain1'),{orderId:b.bookingId});
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().captainId,'captain1');
});

test('under-review work preferences save without granting capacity or online eligibility',async()=>{
  for(const uid of ['captain1','captain2'])await db.doc(`captains/${uid}`).update({approved:false,online:false});
  await service.captainPreferences(auth('captain1'),{workingSlots:[{startMinute:540,endMinute:600}],areaPreference:{mode:'all'}});
  const slots=await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'});
  assert.ok(slots.slots.every(s=>!s.available));
  await assert.rejects(service.captainOnline(auth('captain1'),{online:true}),{code:'permission-denied'});
  await db.doc('captains/captain1').update({approved:true});
  assert.deepEqual((await service.availability(customer,{societyId:'soc_avatar',day:'2026-11-01'})).slots.filter(s=>s.available).map(s=>s.startHour),[8]);
});

test('work periods validate half-hour bounds, breaks and legacy edits without broadening exact hours',async()=>{
  for(const workingSlots of [[{startMinute:239,endMinute:300}],[{startMinute:240,endMinute:270}],[{startMinute:270,endMinute:1330}],[{startMinute:541,endMinute:630}],Array(5).fill({startMinute:240,endMinute:300})]){
    await assert.rejects(service.captainPreferences(auth('captain1'),{workingSlots}),{code:'invalid-argument'});
  }
  await service.captainPreferences(auth('captain1'),{workingSlots:[{startMinute:780,endMinute:1140},{startMinute:540,endMinute:600}]});
  assert.deepEqual((await db.doc('captains/captain1').get()).data().workingSlots,[{startMinute:540,endMinute:600},{startMinute:780,endMinute:1140}]);
  await service.captainPreferences(auth('captain1'),{workingSlots:[]});
  assert.deepEqual((await db.doc('captains/captain1').get()).data().workingSlots,[]);
  await service.captainPreferences(auth('captain1'),{workingWindows:[{startHour:6,endHour:10}]});
  assert.equal((await db.doc('captains/captain1').get()).data().workingSlots,undefined);
});
test('typed addresses need a served society or operator mapping and cannot forge approval',async()=>{
  const a={name:'My Home Avatar',area:'Narsingi',city:'Hyderabad',pincode:'500089'};
  const ok=await service.checkAddress(customer,a);assert.equal(ok.served,true);
  const b=await service.createBooking(customer,{...input(),addressKey:ok.addressKey});assert.equal(b.amount,14900);
  await service.cancel(customer,{orderId:b.bookingId});
  assert.equal((await service.checkAddress(customer,{...a,name:'Unserved building'})).served,false);
  await assert.rejects(service.createBooking(customer,{...input('forged'),addressKey:'forged'}),{code:'failed-precondition'});
});

test('recorded notes are owner-only, bounded, and locked after payment',async()=>{
  const b=await service.createBooking(customer,input());
  service.evidence.metadata=async()=>({contentType:'audio/mp4',size:1000});
  const d={orderId:b.bookingId,kind:'note_audio',seconds:12};
  await assert.rejects(service.customerMedia(auth('stranger'),d),{code:'permission-denied'});
  await service.customerMedia(customer,d);
  assert.equal((await db.doc(`orders/${b.bookingId}`).get()).data().customerMedia.note_audio.seconds,12);
  await assert.rejects(service.customerMedia(customer,{...d,seconds:100}),{code:'invalid-argument'});
  service.evidence.metadata=async()=>({contentType:'text/html',size:100});
  await assert.rejects(service.customerMedia(customer,d),{code:'invalid-argument'});
  service.evidence.metadata=async()=>({contentType:'audio/mp4',size:100});
  const c=await service.checkout(customer,b);
  await service.capturePayment({id:'pay_media',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
  await assert.rejects(service.customerMedia(customer,d),{code:'permission-denied'});
});
test('support requests are authenticated, idempotent and rate limited',async()=>{
  const data={requestId:'help-one',kind:'accountDeletion',note:'Please review my account deletion request.'};
  await assert.rejects(service.supportRequest(null,data),{code:'unauthenticated'});
  const r=await service.supportRequest(customer,data);await service.supportRequest(customer,data);
  assert.equal((await db.doc(`supportTickets/${r.requestId}`).get()).data().status,'open');
  await assert.rejects(service.supportRequest(customer,{...data,requestId:'help-two'}),{code:'resource-exhausted'});
});

test('push registration honors owner preferences, token removal and private inbox acknowledgements',async()=>{
 const token='test-token-long-enough-for-registration';
 await assert.rejects(service.registerPushToken(customer,{token,role:'customer'}),{code:'permission-denied'});
 await service.setPushPreference(customer,{role:'customer',enabled:true});
 await service.registerPushToken(customer,{token,role:'customer'});
 await service.removePushToken(auth('stranger'),{token});assert.equal((await db.collection('deviceTokens').get()).size,1);
 await service.setPushPreference(customer,{role:'customer',enabled:false});assert.equal((await db.collection('deviceTokens').get()).size,0);
 await db.doc('notifications/notice').set({recipientId:'customer',read:false});
 await assert.rejects(service.readNotification(auth('stranger'),{notificationId:'notice'}),{code:'permission-denied'});
 await service.readNotification(customer,{notificationId:'notice'});assert.equal((await db.doc('notifications/notice').get()).data().read,true);
});

test('revoked manual service mappings cannot be reused for a new booking',async()=>{
 const a={name:'Mapped building',area:'Area',city:'Hyderabad',pincode:'500089'};
 await service.checkAddress(customer,a);
 const req=(await db.collection('addressRequests').get()).docs[0].data();
 await db.doc(`serviceAddresses/${req.addressKey}`).set({approved:true,societyId:'soc_avatar'});
 const approved=await service.checkAddress(customer,a);assert.equal(approved.served,true);
 await db.doc(`serviceAddresses/${req.addressKey}`).update({approved:false});
 await assert.rejects(service.createBooking(customer,{...input(),addressKey:req.addressKey}),{code:'failed-precondition'});
});
