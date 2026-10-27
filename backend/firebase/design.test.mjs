import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
import {readFile} from 'node:fs/promises';
import {removedAppAccess} from './functions/src/account-access.mjs';

let app,db,service,clock,provider,deletedUsers,deletedPrefixes;
const config=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
const auth=uid=>({uid,token:{phone_number:'+919876543210',auth_time:Math.floor(clock/1000)}});
before(()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Emulators only.');app=initializeApp({projectId:'demo-wheelio'},'design-tests');db=getFirestore(app);});
after(()=>deleteApp(app));
beforeEach(async()=>{
 await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-wheelio/databases/(default)/documents`,{method:'DELETE'});
 clock=Date.parse('2026-11-01T08:00:00+05:30');deletedUsers=[];deletedPrefixes=[];
 provider={keyId:'rzp_test_fake',payments:new Map(),createOrder:async({amount})=>({id:'order_design',amount,currency:'INR'}),payment:async id=>provider.payments.get(id)};
 service=new WashKrewService({db,payments:provider,now:()=>clock,accounts:{deleteUser:async uid=>deletedUsers.push(uid)},evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100}),deletePrefix:async p=>deletedPrefixes.push(p)}});
 await db.doc('config/operations').set(config);
 await service.register(auth('owner'),{role:'customer',name:'Owner'});
 await service.register(auth('captain'),{role:'captain',name:'Captain'});
 await db.doc('captains/captain').update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});
});
async function assigned(){
 const b=await service.createBooking(auth('owner'),{requestId:'design',plate:'TS09AB1234',societyId:'soc_avatar',vehicleKind:'hatchback',tower:'T3',floor:'B2',parking:'42',note:'',washKind:'wetOutside',day:'2026-11-01',startHour:8,endHour:10});
 const c=await service.checkout(auth('owner'),b),p={id:'pay_design',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'};provider.payments.set(p.id,p);await service.capturePayment(p);await service.claim(auth('captain'),{orderId:b.bookingId});return {orderId:b.bookingId};
}
async function finished(){
 const d=await assigned();await service.progress(auth('captain'),{...d,action:'arrived'});
 for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain'),{...d,stage:'before',side});
 await service.progress(auth('captain'),{...d,action:'start'});
 for(let side=0;side<4;side++)await service.evidenceUploaded(auth('captain'),{...d,stage:'after',side});
 await service.progress(auth('captain'),{...d,action:'finish'});return d;
}
test('designed vehicle-help answers reach the assigned captain; other accounts cannot answer',async()=>{
 const d=await assigned();await service.vehicleHelp(auth('captain'),{...d,action:'request',value:'empty'});
 await assert.rejects(service.vehicleHelp(auth('stranger'),{...d,action:'answer',value:'outside'}),{code:'permission-denied'});
 await service.vehicleHelp(auth('owner'),{...d,action:'answer',value:'other_floor'});
 assert.equal((await db.doc(`orders/${d.orderId}`).get()).data().vehicleHelp.answer,'other_floor');
});
test('automatic approval waits for the server review deadline and settles earnings exactly once',async()=>{
 const d=await finished(),o=(await db.doc(`orders/${d.orderId}`).get()).data();
 assert.equal(o.autoApproveAt.toDate().toISOString(),'2026-11-01T18:29:00.000Z');
 await assert.rejects(service.approve(null,d,{automatic:true}),{code:'failed-precondition'});
 await assert.rejects(service.approve(auth('stranger'),{...d,automatic:true}),{code:'permission-denied'});
 clock=o.autoApproveAt.toMillis();await service.approve(null,d,{automatic:true});await service.approve(null,d,{automatic:true});
 assert.equal((await db.doc(`orders/${d.orderId}`).get()).data().approvalSource,'automatic');
 assert.equal((await db.doc('captains/captain').get()).data().completedWashes,1);
 assert.equal((await db.doc(`earnings/${d.orderId}`).get()).data().status,'approved');
 await service.rate(auth('owner'),{...d,stars:4,tags:['Spotless','Polite']});
 assert.deepEqual((await db.doc(`orders/${d.orderId}`).get()).data().ratingTags,['Spotless','Polite']);
});
test('problem evidence is stored with the report and damage is prioritized without inventing a decision',async()=>{
 const d=await finished();await service.reportProblem(auth('owner'),{...d,kind:'damage',note:'Photo evidence',photoCount:2});
 const o=(await db.doc(`orders/${d.orderId}`).get()).data();assert.equal(o.dispute.outcome,'damagePriority');assert.equal(o.dispute.photos.length,2);
 assert.equal((await db.doc(`earnings/${d.orderId}`).get()).data().status,'onHold');
 await assert.rejects(service.approve(null,d,{automatic:true}),{code:'failed-precondition'});
});
test('inbox read/unread/delete persists, batches are atomic and private',async()=>{
 await db.doc('notifications/owned').set({recipientId:'owner',role:'customer',read:false});await db.doc('notifications/other').set({recipientId:'stranger',read:false});
 await assert.rejects(service.readNotification(auth('owner'),{notificationIds:['owned','other']}),{code:'permission-denied'});
 assert.equal((await db.doc('notifications/owned').get()).data().read,false);
 await service.readNotification(auth('owner'),{notificationId:'owned'});assert.equal((await db.doc('notifications/owned').get()).data().read,true);
 await service.readNotification(auth('owner'),{notificationId:'owned',action:'unread'});assert.equal((await db.doc('notifications/owned').get()).data().read,false);
 await service.readNotification(auth('owner'),{notificationId:'owned',action:'delete'});assert.ok((await db.doc('notifications/owned').get()).data().deletedAt);
});
test('notification preferences are stored per app and security category cannot be disabled',async()=>{
 const p={role:'customer',enabled:true,soundOn:false,quietHours:true,mutedUntil:clock+3600000,offCategories:['offers']};
 await service.notificationPreferences(auth('owner'),p);await service.notificationPreferences(auth('owner'),{...p,role:'captain',offCategories:['level']});
 const d=(await db.doc('users/owner').get()).data();assert.deepEqual(d.notificationPreferences.customer.offCategories,['offers']);assert.deepEqual(d.notificationPreferences.captain.offCategories,['level']);
 await assert.rejects(service.notificationPreferences(auth('owner'),{...p,offCategories:['account']}),{code:'invalid-argument'});
});
test('phone sync uses only the authenticated verified claim and preserves ownership',async()=>{
 const changed={...auth('captain'),token:{phone_number:'+919000000001'}};await service.syncVerifiedPhone(changed,{phone:'+919999999999'});
 assert.equal((await db.doc('users/captain').get()).data().phone,'+919000000001');assert.equal((await db.doc('captains/captain').get()).data().phone,'+919000000001');
});
test('UPI onboarding no longer asks for bank photos and payout changes need recent verification',async()=>{
 await service.register(auth('applicant'),{role:'captain',name:'Applicant'});
 await service.captainPayout(auth('applicant'),{method:'upi',upi:'applicant@bank'});await service.submitCaptainApplication(auth('applicant'),{societyIds:['soc_avatar']});
 assert.equal((await db.doc('captains/applicant').get()).data().kycStatus,'underReview');
 await assert.rejects(service.captainPayout({...auth('captain'),token:{...auth('captain').token,auth_time:0}},{method:'upi',upi:'new@bank'}),{code:'failed-precondition'});
 await service.captainPayout(auth('captain'),{method:'upi',upi:'new@bank'});assert.equal((await db.doc('captains/captain').get()).data().payout.status,'pendingVerification');
});
test('deletion refuses open jobs and removes the account without affecting the other party',async()=>{
 const d=await assigned();await assert.rejects(service.deleteAccount(auth('owner'),{confirm:true}),{code:'failed-precondition'});assert.deepEqual(deletedUsers,[]);
 await service.cancel(auth('owner'),d);
 await db.doc('documentDownloads/unused-link').set({customerId:'owner'});await db.doc('supportState/owner').set({lastRequestAt:Timestamp.fromMillis(clock)});
 await db.doc('payoutRecords/old-transfer').set({captainId:'owner',amount:11600});
 await service.deleteAccount(auth('owner'),{confirm:true});
 const o=(await db.doc(`orders/${d.orderId}`).get()).data();assert.equal(o.customerId,null);assert.equal(o.captainId,'captain');assert.equal(o.plate,'');
 assert.equal((await db.doc('users/owner').get()).data().deletionStatus,'completed');assert.deepEqual(deletedUsers,['owner']);assert.ok(deletedPrefixes.includes('profiles/owner/'));
 assert.equal((await db.doc('documentDownloads/unused-link').get()).exists,false);assert.equal((await db.doc('supportState/owner').get()).exists,false);
 const payout=(await db.doc('payoutRecords/old-transfer').get()).data();assert.equal(payout.captainId,null);assert.equal(payout.amount,11600);
});
test('private document links are owner-scoped, short-lived and single-use',async()=>{
 const d=await finished();
 await assert.rejects(service.createDocument(auth('stranger'),{...d,kind:'receipt'}),{code:'permission-denied'});
 const link=await service.createDocument(auth('owner'),{...d,kind:'receipt'}),token=new URL(link.url).searchParams.get('token');
 assert.equal((await service.consumeDocument(token)).order.customerId,'owner');
 await assert.rejects(service.consumeDocument(token),{code:'permission-denied'});
 clock+=3000;const expired=await service.createDocument(auth('owner'),{...d,kind:'receipt'});clock+=600001;
 await assert.rejects(service.consumeDocument(new URL(expired.url).searchParams.get('token')),{code:'permission-denied'});
});

test('Customer deletion preserves the same phone Captain, its active work, private files and notifications',async()=>{
 await service.register(auth('captain'),{role:'customer'});
 const job=await assigned();
 await db.doc('notifications/customer-role').set({recipientId:'captain',role:'customer'});
 await db.doc('notifications/captain-role').set({recipientId:'captain',role:'captain'});
 await db.doc('users/captain').update({captainPhotoPath:'profiles/captain/captain.jpg',customerPhotoPath:'profiles/captain/customer.jpg'});
 const result=await service.deleteAccount(auth('captain'),{confirm:true,role:'customer'});
 assert.equal(result.identityDeleted,false);assert.deepEqual(deletedUsers,[]);
 assert.equal((await db.doc(`orders/${job.orderId}`).get()).data().captainId,'captain');
 assert.equal((await db.doc('captains/captain').get()).data().approved,true);
 assert.equal((await db.doc('notifications/captain-role').get()).exists,true);
 assert.equal((await db.doc('notifications/customer-role').get()).exists,false);
 const profile=(await db.doc('users/captain').get()).data();
 assert.deepEqual(profile.roles,['captain']);assert.equal(profile.captainPhotoPath,'profiles/captain/captain.jpg');
 assert.ok(profile.deletedRoles.customer);assert.ok(!deletedPrefixes.includes('kyc/captain/'));
 assert.equal(removedAppAccess(profile,'createBooking'),true);assert.equal(removedAppAccess(profile,'progress'),false);
 await assert.rejects(service.register({...auth('captain'),token:{...auth('captain').token,auth_time:0}},{role:'customer'}),{code:'failed-precondition'});
 await service.register(auth('captain'),{role:'customer'});
 assert.equal((await db.doc('users/captain').get()).data().deletedRoles?.customer,undefined);
});

test('Captain deletion keeps Customer bookings and wallet and requires recent SMS verification',async()=>{
 await service.register(auth('owner'),{role:'captain'});
 const job=await assigned();
 await db.doc('wallets/owner_test').set({customerId:'owner',creditPaise:1500});
 await assert.rejects(service.deleteAccount({...auth('owner'),token:{...auth('owner').token,auth_time:0}},{confirm:true,role:'captain'}),{code:'failed-precondition'});
 await service.deleteAccount(auth('owner'),{confirm:true,role:'captain'});
 assert.deepEqual(deletedUsers,[]);assert.equal((await db.doc('captains/owner').get()).exists,false);
 assert.equal((await db.doc(`orders/${job.orderId}`).get()).data().customerId,'owner');
 assert.equal((await db.doc('wallets/owner_test').get()).data().creditPaise,1500);
 const profile=(await db.doc('users/owner').get()).data();assert.deepEqual(profile.roles,['customer']);
 assert.equal(removedAppAccess(profile,'captainPreferences'),true);assert.equal(removedAppAccess(profile,'createBooking'),false);
});

test('missing uploaded identity returns a clear precondition instead of a generic application error',async()=>{
 service.evidence.metadata=async()=>null;
 await service.register(auth('applicant'),{role:'captain',name:'Applicant'});
 await service.captainPayout(auth('applicant'),{method:'upi',upi:'applicant@bank'});
 await assert.rejects(service.submitCaptainApplication(auth('applicant'),{societyIds:['soc_avatar']}),{code:'failed-precondition',message:'Upload your identity and selfie.'});
 assert.equal((await db.doc('captains/applicant').get()).data().kycStatus,'notSubmitted');
});
test('human dispute decisions queue only the actual cash refund and award an explicit bonus once',async()=>{
 const d=await finished();await service.reportProblem(auth('owner'),{...d,kind:'notClean',note:'Please review',photoCount:1});
 const decision={...d,outcome:'upheld',note:'The after photo confirms the missed area.',bonusFreeWashes:2};
 await service.resolveDispute(decision);await service.resolveDispute(decision);
 const o=(await db.doc(`orders/${d.orderId}`).get()).data();assert.equal(o.status,'disputeUpheld');assert.equal(o.dispute.creditsAwarded,2);
 assert.equal((await db.doc('wallets/owner_test').get()).data().freeWashes,2);
 assert.equal((await db.doc(`refunds/${d.orderId}`).get()).data().amount,14900);
 assert.equal((await db.doc(`earnings/${d.orderId}`).get()).data().status,'voided');
});
test('payout records require approved unpaid earnings and never record a transfer twice',async()=>{
 const d=await finished();await service.approve(auth('owner'),d);
 const payout={captainId:'captain',paymentMode:'test',reference:'VERIFIED-TEST-UTR',earningIds:[d.orderId],verifiedTransfer:true};
 await assert.rejects(service.recordPayout({...payout,verifiedTransfer:false}),{code:'invalid-argument'});
 await service.recordPayout(payout);await service.recordPayout(payout);
 const c=(await db.doc('captains/captain').get()).data();assert.equal(c.payouts.length,1);assert.equal(c.payouts[0].amount,11600);
 await assert.rejects(service.recordPayout({...payout,reference:'ANOTHER-REFERENCE'}),{code:'failed-precondition'});
});
test('saved area preferences filter offers on the server and cannot expand approved societies',async()=>{
 const windows=[{startHour:6,endHour:10}];
 await assert.rejects(service.captainPreferences(auth('captain'),{workingWindows:windows,areaPreference:{mode:'societies',societyIds:['soc_avali']}}),{code:'permission-denied'});
 await service.captainPreferences(auth('captain'),{workingWindows:windows,areaPreference:{mode:'place',place:'Another area'}});
 assert.ok((await service.availability(auth('owner'),{societyId:'soc_avatar',day:'2026-11-01'})).slots.every(s=>!s.available));
 await service.register(auth('eligible'),{role:'captain',name:'Eligible'});
 await db.doc('captains/eligible').update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});
 const b=await service.createBooking(auth('owner'),{requestId:'filtered',plate:'TS09AB1234',societyId:'soc_avatar',vehicleKind:'hatchback',floor:'B2',washKind:'wetOutside',day:'2026-11-01',startHour:8,endHour:10});
 const c=await service.checkout(auth('owner'),b);await service.capturePayment({id:'pay_filter',order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured'});
 assert.deepEqual((await db.collection('jobOffers').get()).docs.map(d=>d.data().captainId),['eligible']);
});

test('late windows are checked before midnight and no-show cancellation restores the full payment',async()=>{
 const d=await assigned();clock=Date.parse('2026-11-01T10:01:00+05:30');
 await service.checkBookingDeadline(d.orderId);
 const late=(await db.doc(`orders/${d.orderId}`).get()).data();assert.equal(late.status,'onTheWay');assert.equal(late.noShowChecking,true);assert.equal(late.runningLateMinutes,1);
 clock=Date.parse('2026-11-01T23:59:00+05:30');await service.checkBookingDeadline(d.orderId);await service.checkBookingDeadline(d.orderId);
 const o=(await db.doc(`orders/${d.orderId}`).get()).data();assert.equal(o.status,'cancelled');assert.equal(o.cancellationReason,'slotExpired');
 assert.equal((await db.doc(`refunds/${d.orderId}`).get()).data().amount,14900);
});
test('lost progress and problem callbacks may retry without duplicate events or losing the report',async()=>{
 const d=await finished();const ref=db.collection(`orders/${d.orderId}/events`),n=(await ref.get()).size;
 await service.progress(auth('captain'),{...d,action:'finish'});assert.equal((await ref.get()).size,n);
 const report={...d,kind:'notClean',note:'Please review',photoCount:1};await service.reportProblem(auth('owner'),report);await service.reportProblem(auth('owner'),report);
 assert.equal((await ref.where('type','==','problemReported').get()).size,1);
 await assert.rejects(service.reportProblem(auth('stranger'),report),{code:'permission-denied'});
});
test('location matching uses configured boundaries and preferences can be drafted without granting approval',async()=>{
 const cfg={...config,societies:config.societies.map(s=>({...s,location:{latitude:17.42,longitude:78.34},serviceRadiusMetres:100}))};await db.doc('config/operations').set(cfg);
 assert.equal((await service.serviceLocation(null,{latitude:17.42,longitude:78.34})).societyId,'soc_avatar');
 assert.equal((await service.serviceLocation(null,{latitude:17.45,longitude:78.34})).societyId,null);
 await assert.rejects(service.serviceLocation(null,{latitude:999,longitude:0}),{code:'invalid-argument'});
 await db.doc('captains/captain').update({approved:false});await service.captainPreferences(auth('captain'),{workingWindows:[{startHour:6,endHour:10}],areaPreference:{mode:'all'}});
 await assert.rejects(service.captainOnline(auth('captain'),{online:true}),{code:'permission-denied'});
});
