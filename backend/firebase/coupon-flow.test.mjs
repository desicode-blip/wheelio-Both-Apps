import test,{before,beforeEach,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
import {approvedCouponPolicy} from './functions/src/coupon-policy.mjs';
import {couponId} from './functions/src/refund-coupons.mjs';
import {migrateLegacyValue} from './functions/src/coupon-migration.mjs';
import {capturedEarnings} from './functions/src/earning-policy.mjs';
let app,db,s,clock,provider,config,sequence,deleted;
const project='demo-wheelio-coupons',owner='customer',phone=uid=>({uid,token:{phone_number:'+919000000001'}});
const review=()=>({uid:'reviewer',token:{email:'reviewer@example.test',email_verified:true,auth_time:Math.floor(clock/1000),firebase:{sign_in_provider:'google.com'}}});
before(()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Local emulators required.');app=initializeApp({projectId:project},'coupon-flow-tests');db=getFirestore(app);});
after(()=>deleteApp(app));
beforeEach(async()=>{
 await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});
 clock=Date.parse('2026-11-10T07:00:00+05:30');sequence=0;deleted=[];
 const base=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
 config={...base,paymentMerchant:'washkrew',paymentBalanceMode:'refundCouponsV1',refundCouponsReady:true,walletTopupsEnabled:false,captainEarningsPolicy:'netGatewayPlusPlatformV1',platformFeeBps:300,cancellationPolicy:{...approvedCouponPolicy},vehicleTypes:base.vehicleTypes.map(v=>v.kind==='hatchback'?{...v,pricePaise:10000}:v)};
 provider={keyId:'rzp_test_fixture',payments:new Map(),async createOrder({amount}){return {id:'order_coupon_'+(++sequence),amount,currency:'INR'};},async payment(id){return this.payments.get(id);},async orderPayments(id){return {items:[...this.payments.values()].filter(p=>p.order_id===id)};},verify:()=>true};
 s=new WashKrewService({db,paymentProviders:{'washkrew:test':provider},now:()=>clock,evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100}),deletePrefix:async()=>{}},accounts:{deleteUser:async id=>deleted.push(id)}});
 await db.doc('config/operations').set(config);await db.doc('privateConfig/captainReviewers').set({emails:['reviewer@example.test']});
 await s.register(phone(owner),{role:'customer',name:'Customer fixture'});
 await s.register(phone('other'),{role:'customer',name:'Other fixture'});
 for(const uid of ['captain1','captain2']){await s.register(phone(uid),{role:'captain',name:'Captain fixture'});await db.doc('captains/'+uid).update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});}
});
function input(id,patch={}){return {requestId:id,plate:'TS09AB1234',vehicleKind:'hatchback',societyId:'soc_avatar',tower:'T3',floor:'B2',parking:'42',washKind:'wetOutside',day:'2026-11-10',startHour:8,endHour:10,paymentChoice:'razorpay',refundCouponPolicyVersion:1,acceptedCancellationPolicy:{...approvedCouponPolicy},...patch};}
async function paid(id,{fee=200,...patch}={}){const c=await s.checkout(phone(owner),{booking:input(id,patch)});const p={id:'pay_coupon_'+sequence,order_id:c.orderId,amount:c.amount,currency:'INR',status:'captured',method:'upi',fee,tax:Math.floor(fee*18/118),amount_refunded:0};provider.payments.set(p.id,p);await s.capturePayment(p,'test','washkrew');return {...c,payment:p};}
async function cancel(id){const q=(await s.getCancellationQuote(phone(owner),{orderId:id})).quote;await s.cancel(phone(owner),{orderId:id,confirmation:q.confirmation});return q;}
async function issue(id){const d=(await db.doc('refundRequests/'+id).get());await s.reviewRefundRequest(review(),{requestId:id,expectedVersion:`${d.updateTime.seconds}:${d.updateTime.nanoseconds}`,decision:'issue',note:'Verified paid funds and saved refund rule.',confirm:true});return (await db.doc('refundRequests/'+id).get()).data();}
async function fullWash(id){await s.claim(phone('captain1'),{orderId:id});clock=Date.parse('2026-11-10T08:00:00+05:30');await s.progress(phone('captain1'),{orderId:id,action:'arrived'});for(let side=0;side<4;side++)await s.evidenceUploaded(phone('captain1'),{orderId:id,stage:'before',side});await s.progress(phone('captain1'),{orderId:id,action:'start'});for(let side=0;side<4;side++)await s.evidenceUploaded(phone('captain1'),{orderId:id,stage:'after',side});await s.progress(phone('captain1'),{orderId:id,action:'finish'});}

test('paid cancellation reaches private review; coupon reuse plus shortfall funds real Captain earnings once',async()=>{
 const first=await paid('funding');const captured=(await db.doc('orders/'+first.bookingId).get()).data();assert.equal(captured.captainPayPaise,9500);assert.equal(captured.platformFeePaise,300);
 const quote=await cancel(first.bookingId);assert.equal(quote.couponPaise,9800);assert.equal(quote.gatewayFeePaise,200);assert.equal(quote.feePaise,0);assert.equal((await db.collection('refunds').get()).size,0);assert.equal((await db.doc('wallets/customer_test').get()).exists,false);
 await assert.rejects(s.listRefundRequests(phone(owner),{}),{code:'permission-denied'});
 const list=await s.listRefundRequests(review(),{});assert.equal(list.requests.length,1);
 const r=await issue(first.bookingId);await issue(first.bookingId);assert.equal((await db.collection('coupons').get()).size,1);
 await assert.rejects(s.previewCoupon(phone('other'),{code:r.couponCode,vehicleKind:'hatchback'}),{code:'not-found'});
 const preview=await s.previewCoupon(phone(owner),{code:r.couponCode,vehicleKind:'hatchback'});assert.equal(preview.appliedPaise,9800);assert.equal(preview.cashDuePaise,200);
 const second=await paid('coupon-new-wash',{fee:4,paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:9800,expectedAmountPaise:200});assert.equal(second.amount,200);
 await fullWash(second.bookingId);await s.approve(phone(owner),{orderId:second.bookingId});
 const earning=(await db.doc('earnings/'+second.bookingId).get()).data();assert.equal(earning.status,'approved');assert.equal(earning.amount,9696);
 assert.equal((await db.doc('coupons/'+r.couponId).get()).data().availablePaise,0);
 await assert.rejects(s.previewCoupon(phone(owner),{code:r.couponCode,vehicleKind:'hatchback'}),{code:'failed-precondition'});
});
test('first five minutes wins inside two hours; late and exact cutoff deduct gateway only once, never the success commission',async()=>{
 let b=await paid('near');clock+=300000;assert.equal((await cancel(b.bookingId)).couponPaise,9800);
 await db.doc('captains/captain1').update({lastSeenAt:Timestamp.fromMillis(clock)});await db.doc('captains/captain2').update({lastSeenAt:Timestamp.fromMillis(clock)});
 b=await paid('late',{startHour:12,endHour:14});clock+=300001;let q=await cancel(b.bookingId);assert.equal(q.couponPaise,4800);assert.equal(q.feePaise,5000);
 await db.doc('captains/captain1').update({lastSeenAt:Timestamp.fromMillis(clock)});await db.doc('captains/captain2').update({lastSeenAt:Timestamp.fromMillis(clock)});
 b=await paid('cutoff',{startHour:12,endHour:14});clock=Date.parse('2026-11-10T10:00:00+05:30');assert.equal((await s.getCancellationQuote(phone(owner),{orderId:b.bookingId})).quote.couponPaise,4800);
 clock++;q=await cancel(b.bookingId);assert.equal(q.couponPaise,0);assert.equal((await db.doc('refundRequests/'+b.bookingId).get()).data().status,'ineligible');
 await assert.rejects(issue(b.bookingId),{code:'failed-precondition'});
});
test('single-use cheaper wash needs exact forfeiture acknowledgement; captured value cannot be used a second time',async()=>{
 const first=await paid('zero-fee-funding',{fee:0});await cancel(first.bookingId);const r=await issue(first.bookingId);
 const preview=await s.previewCoupon(phone(owner),{code:r.couponCode,vehicleKind:'bike'});assert.equal(preview.appliedPaise,6900);assert.equal(preview.forfeitPaise,3100);
 const draft=input('forfeit',{vehicleKind:'bike',paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:6900,expectedAmountPaise:0});
 await assert.rejects(s.checkout(phone(owner),{booking:draft}),{code:'failed-precondition'});assert.equal((await db.doc('coupons/'+r.couponId).get()).data().availablePaise,10000);
 const c=await s.checkout(phone(owner),{booking:{...draft,acceptedCouponForfeitPaise:3100}});assert.equal(c.paid,true);assert.equal(sequence,1);
 const coupon=(await db.doc('coupons/'+r.couponId).get()).data();assert.equal(coupon.spentPaise,10000);assert.equal(coupon.availablePaise,0);
 const o=(await db.doc('orders/'+c.bookingId).get()).data();assert.equal(o.captainPayPaise,6693);assert.equal(o.couponForfeitPaise,3100);assert.equal(o.gatewayFeePaise,0);
 assert.equal((await cancel(c.bookingId)).couponPaise,6900);
});
test('unpaid coupon checkout restores all held value once, including unconsumed forfeiture, without extending expiry',async()=>{
 const first=await paid('abandon-funding');await cancel(first.bookingId);const r=await issue(first.bookingId),couponRef=db.doc('coupons/'+r.couponId),before=(await couponRef.get()).data();
 const c=await s.checkout(phone(owner),{booking:input('unpaid-coupon',{paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:9800,expectedAmountPaise:200})});
 assert.equal((await couponRef.get()).data().availablePaise,0);await s.abandonCheckout(phone(owner),c);await s.abandonCheckout(phone(owner),c);
 const restored=(await couponRef.get()).data();assert.equal(restored.availablePaise,9800);assert.equal(restored.reservedPaise,0);assert.equal(restored.expiresAt.toMillis(),before.expiresAt.toMillis());
});
test('lost capacity before coupon-only payment preserves the coupon and clears the pending checkout',async()=>{
 const first=await paid('capacity-funding',{fee:0});await cancel(first.bookingId);const r=await issue(first.bookingId);
 const b=await s.createBooking(phone(owner),input('capacity-coupon',{vehicleKind:'bike',paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:6900,expectedAmountPaise:0,acceptedCouponForfeitPaise:3100}));
 await db.doc('config/operations').update({bookingsEnabled:false});
 await assert.rejects(s.checkout(phone(owner),{bookingId:b.bookingId}),{code:'resource-exhausted'});
 assert.equal((await db.doc('coupons/'+r.couponId).get()).data().availablePaise,10000);
 assert.equal((await db.doc('customerState/'+owner).get()).data().pendingBookingId,null);
 assert.equal((await db.doc('refundRequests/'+b.bookingId).get()).exists,false);
 assert.equal((await db.doc('orders/'+b.bookingId).get()).data().paymentStatus,'unpaid');
});
test('prohibited funding releases reserved coupon and refunds only the gateway payment to source',async()=>{
 const first=await paid('card-funding');await cancel(first.bookingId);const r=await issue(first.bookingId);
 await db.doc('config/operations').update({paymentPolicy:'no-credit-card-checkout'});
 const c=await s.checkout(phone(owner),{booking:input('card-coupon',{paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:9800,expectedAmountPaise:200})});
 const payment={id:'pay_credit_coupon',order_id:c.orderId,amount:200,status:'captured',currency:'INR',method:'card',card:{type:'credit'}};
 await s.capturePayment(payment,'test','washkrew');
 assert.equal((await db.doc('coupons/'+r.couponId).get()).data().availablePaise,9800);
 assert.equal((await db.doc('orders/'+c.bookingId).get()).data().couponReleased,true);
 assert.equal((await db.doc('refunds/'+c.bookingId).get()).data().amount,200);
 assert.equal((await db.doc('refundRequests/'+c.bookingId).get()).exists,false);
});
test('late capture after abandoned coupon checkout refunds only new net cash; original coupon stays restored',async()=>{
 const first=await paid('late-funding',{fee:3100});await cancel(first.bookingId);const r=await issue(first.bookingId);assert.equal(r.amountPaise,6900);
 const c=await s.checkout(phone(owner),{booking:input('late-coupon',{paymentChoice:'coupon',couponCode:r.couponCode,expectedCouponPaise:6900,expectedAmountPaise:3100})});await s.abandonCheckout(phone(owner),c);
 const payment={id:'pay_after_abandon',order_id:c.orderId,amount:3100,fee:62,status:'captured',currency:'INR',method:'upi'};provider.payments.set(payment.id,payment);await s.capturePayment(payment,'test','washkrew');
 assert.equal((await db.doc('refundRequests/'+c.bookingId).get()).data().amountPaise,3038);assert.equal((await db.doc('coupons/'+r.couponId).get()).data().availablePaise,6900);
});
test('expired payment/service failure creates full net coupon request even though normal cancellation is outside grace',async()=>{
 const c=await s.checkout(phone(owner),{booking:input('expired-capture')});clock+=16*60000;
 const p={id:'pay_expired_coupon',order_id:c.orderId,amount:c.amount,fee:200,status:'captured',currency:'INR',method:'upi'};provider.payments.set(p.id,p);await s.capturePayment(p,'test','washkrew');
 const r=(await db.doc('refundRequests/'+c.bookingId).get()).data();assert.equal(r.amountPaise,9800);assert.equal(r.serviceFailure,true);assert.equal((await db.collection('jobOffers').get()).size,0);
});
test('human-upheld completed-wash problem creates a refund request and voids the held earning without issuing money automatically',async()=>{
 const b=await paid('reported');await fullWash(b.bookingId);await s.reportProblem(phone(owner),{orderId:b.bookingId,kind:'notClean',note:'Rear panel was not wiped',photoCount:1});
 const report=(await s.listWashReports(review(),{})).reports[0];await s.reviewWashReport(review(),{orderId:b.bookingId,expectedVersion:report.version,outcome:'upheld',note:'Verified visible dirt on the after-wash evidence.',evidenceReviewed:true});
 assert.equal((await db.doc('refundRequests/'+b.bookingId).get()).data().amountPaise,9800);assert.equal((await db.doc('earnings/'+b.bookingId).get()).data().status,'voided');assert.equal((await db.collection('coupons').get()).size,0);
});
test('coupon issue rejects stale/self/anonymous decisions and any original-method refund, and duplicate approved responses never mint twice',async()=>{
 const b=await paid('review-guards');await cancel(b.bookingId);const row=(await s.listRefundRequests(review(),{})).requests[0];const body={requestId:row.id,expectedVersion:row.version,decision:'issue',confirm:true,note:'Verified payment and cancellation terms.'};
 await assert.rejects(s.reviewRefundRequest(null,body),{code:'unauthenticated'});await assert.rejects(s.reviewRefundRequest({...review(),uid:owner},body),{code:'permission-denied'});
 await db.doc('refundRequests/'+row.id).update({note:'A newer review note'});await assert.rejects(s.reviewRefundRequest(review(),body),{code:'aborted'});
 provider.payments.get(b.payment.id).amount_refunded=1;await assert.rejects(issue(b.bookingId),{code:'failed-precondition'});provider.payments.get(b.payment.id).amount_refunded=0;
 await issue(b.bookingId);await issue(b.bookingId);assert.equal((await db.collection('coupons').get()).size,1);
});
test('owner price edits are versioned, validated and audited; existing booking/coupon snapshots retain their price',async()=>{
 const old=await paid('old-price');const a=await s.getVehiclePricing(review(),{});
 await s.updateVehiclePricing(review(),{expectedVersion:a.version,prices:[{kind:'hatchback',pricePaise:4000}],note:'Owner changed the hatchback launch price.'});
 assert.equal((await db.doc('orders/'+old.bookingId).get()).data().basePricePaise,10000);assert.equal((await db.doc('config/operations').get()).data().platformFeeBps,300);assert.equal((await db.collection('pricingReviews').get()).size,1);
 await assert.rejects(s.updateVehiclePricing(review(),{expectedVersion:a.version,prices:[{kind:'hatchback',pricePaise:100}],note:'Stale price edit'}),{code:'aborted'});
 const fresh=await s.getVehiclePricing(review(),{});await assert.rejects(s.updateVehiclePricing(phone(owner),{expectedVersion:fresh.version,prices:[{kind:'bike',pricePaise:100}],note:'Not a reviewer'}),{code:'permission-denied'});
 for(const amount of [0,-1,100.5,1000001])await assert.rejects(s.updateVehiclePricing(review(),{expectedVersion:fresh.version,prices:[{kind:'bike',pricePaise:amount}],note:'Invalid amount'}),{code:'invalid-argument'});
 const next=await paid('new-price',{fee:80});assert.equal(next.amount,4000);assert.equal((await db.doc('orders/'+next.bookingId).get()).data().captainPayPaise,3800);
});
test('legacy value conversion is atomic, keeps original expiry and cannot move test value into live funding',async()=>{
 const expires=clock+86400000;
 await db.doc('wallets/customer_test').set({customerId:owner,paymentMode:'test',creditLotVersion:1,creditPaise:15000,freeWashes:0,creditLots:[{amountPaise:10000,addedAt:clock-1000,expiresAt:expires},{amountPaise:5000,addedAt:clock-2000,expiresAt:clock-1}]});
 await Promise.all([migrateLegacyValue(s,owner,'test'),migrateLegacyValue(s,owner,'test')]);
 const coupons=await db.collection('coupons').get();assert.equal(coupons.size,1);assert.equal(coupons.docs[0].data().faceValuePaise,10000);assert.equal(coupons.docs[0].data().expiresAt.toMillis(),expires);
 assert.equal((await db.doc('wallets/customer_test').get()).data().creditPaise,0);assert.equal((await db.collection('couponMigrations').get()).size,1);
 await db.doc('config/operations').update({paymentMode:'live'});await assert.rejects(s.previewCoupon(phone(owner),{code:coupons.docs[0].data().code,vehicleKind:'bike'}),{code:'not-found'});
});
test('new wallet/top-up paths stay disabled and commission is actual gateway fee plus exactly 3% of wash value',async()=>{
 await assert.rejects(s.createWalletTopup(phone(owner),{requestId:'removed',amountPaise:100}),{code:'failed-precondition'});
 await assert.rejects(s.createBooking(phone(owner),input('wallet-removed',{useCredit:true,paymentChoice:'wallet'})),{code:'failed-precondition'});
 const c=capturedEarnings({captainEarningsPolicy:'netGatewayPlusPlatformV1',platformFeeBps:300,basePricePaise:10000,pricePaise:10000},{source:'razorpay',gatewayFeePaise:236});assert.equal(c.captainPayPaise,9464);assert.equal(c.platformFeePaise,300);
 assert.equal(capturedEarnings({captainEarningsPolicy:'netGatewayPlusPlatformV1',platformFeeBps:300,basePricePaise:10000,pricePaise:0},{source:'coupon',gatewayFeePaise:0}).captainPayPaise,9700);
});
test('Customer deletion preserves live prepaid value even without a historical top-up',async()=>{
 await db.doc('wallets/customer_live').set({customerId:owner,paymentMode:'live',creditPaise:9800,freeWashes:0});
 await assert.rejects(s.deleteAccount(phone(owner),{role:'customer',confirm:true}),{code:'failed-precondition'});
 assert.equal((await db.doc('wallets/customer_live').get()).data().creditPaise,9800);
 assert.deepEqual(deleted,[]);
});
