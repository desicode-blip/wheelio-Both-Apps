// v2 (13 Nov 2026): a monthly plan is paid once; each visit becomes its own paid order,
// is offered about a day ahead, and can be cancelled or refunded on its own share.
import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
import {planVisits,nextMonth,planPricePaise,shares} from './functions/src/monthly-plan.mjs';
import {readFile} from 'node:fs/promises';

let app,db,service,clock,provider,counter;
const auth=uid=>({uid,token:{phone_number:'+919876543210'}});
const customer=auth('customer'),base=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
const config={...base,captainEarningsPolicy:'netGatewayV1'};
const ist=s=>Date.parse(`${s}+05:30`);
// 1 Nov 2026 is a Sunday: a 1-day-a-week Sunday plan has 5 visits (1, 8, 15, 22, 29 Nov).
const plan={frequency:1,weekdays:[7],start:'2026-11-01'};
const input=(requestId,extra={})=>({requestId,plate:'TS09AB1234',societyId:'soc_avatar',vehicleKind:'hatchback',tower:'T3',floor:'B2',parking:'42',note:'',
  washKind:'wetOutside',day:'2026-11-01',startHour:8,endHour:10,windows:[{startHour:8,endHour:10}],acceptedCancellationPolicy:{kind:'refundThenCredit',refundMinutes:5,lateCreditBps:5000},...extra});

before(()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Run only through Firebase emulators:exec.');
  app=initializeApp({projectId:'demo-wheelio'},'monthly-plan-tests');db=getFirestore(app);
});
after(async()=>{await deleteApp(app);});
beforeEach(async()=>{
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-wheelio/databases/(default)/documents`,{method:'DELETE'});
  clock=ist('2026-11-01T07:00:00');counter=0;
  provider={keyId:'rzp_test_fake',payments:new Map(),refunds:[],async findRefund(){return null;},
    async createOrder({amount}){return {id:`order_${++counter}`,amount,currency:'INR'};},
    verify:({signature})=>signature==='valid',async payment(id){return this.payments.get(id);},async orderPayments(id){return {items:[...this.payments.values()].filter(p=>p.order_id===id)};},
    async refund({paymentId,amount,refundId}){this.refunds.push({paymentId,amount,refundId});return {id:`refund_${refundId}`,payment_id:paymentId,amount,status:'processed'};}};
  service=new WashKrewService({db,payments:provider,now:()=>clock,evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100})}});
  await db.doc('config/operations').set({...config,monthlyPlans:true});
  await service.register(customer,{role:'customer',name:'Test Customer'});
  for(const uid of ['captain1','captain2']){await service.register(auth(uid),{role:'captain',name:`Test ${uid}`});await db.doc(`captains/${uid}`).update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});}
});

async function payPlan(requestId='plan-1'){
  const b=await service.createBooking(customer,input(requestId,{plan,expectedAmountPaise:30500}));
  const checkout=await service.checkout(customer,b);
  const payment={id:`pay_${counter}`,order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured',fee:600};
  provider.payments.set(payment.id,payment);
  await service.capturePayment(payment);
  const visits=(await db.collection('orders').where('planId','==',b.bookingId).get()).docs.filter(d=>d.id!==b.bookingId).sort((a,b)=>a.data().planVisit-b.data().planVisit);
  return {b,checkout,payment,visits};
}

test('visit dates and price match the app',()=>{
  assert.deepEqual(planVisits('2026-11-01',[7]),['2026-11-01','2026-11-08','2026-11-15','2026-11-22','2026-11-29']);
  assert.equal(nextMonth('2026-01-31'),'2026-02-28'); // clamped like the app
  assert.equal(planVisits('2026-11-02',[1,3,5]).length,13); // real calendar weekdays, not 4 weeks
  assert.equal(planPricePaise({},'hatchback',3,'basic','exterior'),(199+106*3)*100); // ₹517
  assert.equal(planPricePaise({},'sedan',3,'premium','exteriorInterior'),(199+106*3+72*3+80*3)*100);
  assert.equal(planPricePaise({},'bike',2,'extraPremium','exterior'),(99+66*2+40*2*2)*100);
  assert.deepEqual(shares(30500,5),[6100,6100,6100,6100,6100]);
  assert.deepEqual(shares(1001,3),[335,333,333]);
});

test('plans are off until config.monthlyPlans, and need the first visit and Razorpay',async()=>{
  await db.doc('config/operations').set({...config,monthlyPlans:false});
  await assert.rejects(service.createBooking(customer,input('off',{plan})),/not available yet/);
  await db.doc('config/operations').set({...config,monthlyPlans:true});
  await assert.rejects(service.createBooking(customer,input('day',{plan,day:'2026-11-08'})),/first plan visit/);
  await assert.rejects(service.createBooking(customer,input('days',{plan:{...plan,weekdays:[6,7]}})),/wash days/);
  await assert.rejects(service.createBooking(customer,input('coupon',{plan,useCredit:true})),/paid in full/);
  await assert.rejects(service.createBooking(customer,input('price',{plan,expectedAmountPaise:29900})),/price or balance changed/);
  // Fixed Captain pay above a visit's share can't be sold as a plan.
  await db.doc('config/operations').set({...base,monthlyPlans:true});
  await assert.rejects(service.createBooking(customer,input('fixed',{plan})),/Pricing is not configured/);
});

test('one payment books the cycle: visit 1 searches, later visits wait as paid orders',async()=>{
  const {b,checkout,payment,visits}=await payPlan();
  assert.equal(checkout.amount,30500);
  const first=(await db.doc('orders/'+b.bookingId).get()).data();
  assert.equal(first.status,'searching');assert.equal(first.pricePaise,6100);assert.equal(first.planPricePaise,30500);
  assert.equal(first.planVisit,1);assert.equal(first.planVisits,5);assert.equal(first.captainPayPaise,6100-120); // share minus its fee share
  assert.equal(visits.length,4);
  assert.deepEqual(visits.map(v=>v.data().day),['2026-11-08','2026-11-15','2026-11-22','2026-11-29']);
  for(const v of visits){
    const o=v.data();
    assert.equal(o.status,'scheduled');assert.equal(o.paymentStatus,'captured');assert.equal(o.razorpayPaymentId,payment.id);
    assert.equal(o.pricePaise,6100);assert.equal(o.captainPayPaise,6100-120);assert.equal(o.capacityReserved,false);assert.equal(o.razorpayOrderId,undefined);
  }
  const offers=await db.collection('jobOffers').where('orderId','==',b.bookingId).get();
  assert.equal(offers.size,2);assert.equal(offers.docs[0].data().planVisits,5);
  // A replayed capture changes nothing.
  await service.capturePayment(payment);
  assert.equal((await db.collection('orders').where('planId','==',b.bookingId).get()).size,5); // visit 1 + 4
});

test('a later visit is offered about a day ahead, and can be cancelled on its own share',async()=>{
  const {visits}=await payPlan();
  const [second,third]=visits;
  assert.equal(await service.activatePlanVisit(second.id),'wait');
  clock=ist('2026-11-07T21:00:00');
  assert.equal(await service.activatePlanVisit(second.id),'searching');
  const o=(await second.ref.get()).data();
  assert.equal(o.status,'searching');assert.equal(o.capacityReserved,true);
  assert.equal((await db.collection('jobOffers').where('orderId','==',second.id).get()).size,2);
  // Cancel the third visit well ahead: its share follows the normal cancellation rules.
  const {quote}=await service.getCancellationQuote(customer,{orderId:third.id});
  await service.cancel(customer,{orderId:third.id,confirmation:quote?.confirmation});
  const cancelled=(await third.ref.get()).data(),refund=(await db.doc('refunds/'+third.id).get()).data();
  assert.equal(cancelled.status,'cancelled');
  assert.ok(refund.amount>0&&refund.amount<=6100);assert.equal(refund.paymentId,cancelled.razorpayPaymentId);
});

test('a visit that never finds a Captain slot is refunded its share',async()=>{
  const {visits}=await payPlan();
  const fourth=visits[2];
  for(const uid of ['captain1','captain2'])await db.doc(`captains/${uid}`).update({approved:false});
  clock=ist('2026-11-22T09:00:00');
  assert.equal(await service.activatePlanVisit(fourth.id),'wait');
  clock=ist('2026-11-22T10:30:00');
  assert.equal(await service.activatePlanVisit(fourth.id),'refunded');
  const o=(await fourth.ref.get()).data(),refund=(await db.doc('refunds/'+fourth.id).get()).data();
  assert.equal(o.status,'cancelled');assert.equal(o.cancellationReason,'slotExpired');
  assert.equal(refund.amount,6100);
});

test('team test bookings skip payment but reach Captains like real ones',async()=>{
  // Premium and plans are off for customers here; the test booker can still use them.
  await db.doc('config/operations').set({...config,monthlyPlans:false});
  await assert.rejects(service.createBooking(customer,input('t0',{testBooking:true,serviceLevel:'premium',coverage:'exterior'})),/WashKrew team/);
  await db.doc('privateConfig/testBookings').set({uids:['customer']});
  const b=await service.createBooking(customer,input('t1',{testBooking:true,serviceLevel:'premium',coverage:'exterior'}));
  assert.equal(b.amount,39200); // Aman's Premium price, shown but not charged
  const paid=await service.checkout(customer,b);
  assert.equal(paid.paid,true);assert.equal(counter,0); // no Razorpay order
  const o=(await db.doc('orders/'+b.bookingId).get()).data();
  assert.equal(o.status,'searching');assert.equal(o.paymentSource,'test');assert.equal(o.captainPayPaise,0);assert.equal(o.serviceLevel,'premium');
  const offers=await db.collection('jobOffers').where('orderId','==',b.bookingId).get();
  assert.equal(offers.size,2);assert.equal(offers.docs[0].data().testBooking,true);
  // Cancelling refunds nothing (nothing was paid).
  assert.equal((await service.getCancellationQuote(customer,{orderId:b.bookingId})).quote,null);
  await service.cancel(customer,{orderId:b.bookingId});
  assert.equal((await db.doc('orders/'+b.bookingId).get()).data().refundAmountPaise,0);
  assert.equal((await db.doc('refunds/'+b.bookingId).get()).exists,false);
  // A test monthly plan splits into visits the same way, still unpaid.
  const p=await service.createBooking(customer,input('t2',{testBooking:true,plan}));
  await service.checkout(customer,p);
  const visits=await db.collection('orders').where('planId','==',p.bookingId).get();
  assert.equal(visits.size,5);
  for(const v of visits.docs){assert.equal(v.data().captainPayPaise,0);assert.equal(v.data().testBooking,true);}
});
