// v2 (13 Nov 2026): vehicle details, care routine and exact windows reach the order and
// the Captain's offer; the AI vehicle check stays off until config.vehicleAi.
import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
import {vehicleProfile,careRoutine,minuteWindows,cleanIdentification} from './functions/src/vehicle-care.mjs';
import {readFile} from 'node:fs/promises';

let app,db,service,clock,provider,counter,ai;
const auth=uid=>({uid,token:{phone_number:'+919876543210'}});
const customer=auth('customer'),config=JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url)));
const aiChoice={aiPhotoConsent:true,aiPhotoConsentVersion:'vehicle-after-photos-toggle-v2',requiredConsentPolicyVersion:'vehicle-after-photos-toggle-v2'};
const input=(requestId='request-1')=>({...aiChoice,requestId,plate:'TS09AB1234',societyId:'soc_avatar',vehicleKind:'hatchback',tower:'T3',floor:'B2',parking:'42',note:'Near ramp',washKind:'wetOutside',day:'2026-11-01',startHour:8,endHour:10,pricePaise:1,acceptedCancellationPolicy:{kind:'refundThenCredit',refundMinutes:5,lateCreditBps:5000}});
const jpeg=Buffer.from([0xff,0xd8,0xff,0xe0,1,2,3,4]).toString('base64');

before(()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Run only through Firebase emulators:exec.');
  app=initializeApp({projectId:'demo-wheelio'},'vehicle-care-tests');db=getFirestore(app);
});
after(async()=>{await deleteApp(app);});
beforeEach(async()=>{
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-wheelio/databases/(default)/documents`,{method:'DELETE'});
  clock=Date.parse('2026-11-01T07:00:00+05:30');counter=0;
  provider={keyId:'rzp_test_fake',payments:new Map(),async findRefund(){return null;},
    async createOrder({amount}){return {id:`order_${++counter}`,amount,currency:'INR'};},
    verify:({signature})=>signature==='valid',async payment(id){return this.payments.get(id);},async orderPayments(id){return {items:[...this.payments.values()].filter(p=>p.order_id===id)};},
    async refund({paymentId,amount,refundId}){return {id:`refund_${refundId}`,payment_id:paymentId,amount,status:'processed'};}};
  ai={calls:0,answer:{make:'Hyundai',model:'Creta',color:'White',finish:'glossy',confidence:0.92},async identify(images,kind){this.calls++;this.kind=kind;this.count=images.length;return this.answer;}};
  service=new WashKrewService({db,payments:provider,vehicleAi:ai,now:()=>clock,evidence:{exists:async()=>true,metadata:async()=>({contentType:'image/jpeg',size:100})}});
  await db.doc('config/operations').set(config);
  await service.register(customer,{role:'customer',name:'Test Customer'});
  for(const uid of ['captain1','captain2']){await service.register(auth(uid),{role:'captain',name:`Test ${uid}`});await db.doc(`captains/${uid}`).update({approved:true,online:true,societyIds:['soc_avatar'],lastSeenAt:Timestamp.fromMillis(clock)});}
});

test('vehicle profile, care routine and minute windows are cleaned and validated',()=>{
  assert.equal(vehicleProfile(undefined),null);
  assert.deepEqual(vehicleProfile({make:' Hyundai ',model:'Creta\n',color:'White',finish:'matte',seats:'leather',source:'ai',extra:'x'}),{make:'Hyundai',model:'Creta',color:'White',finish:'matte',seats:'leather',source:'ai'});
  assert.equal(vehicleProfile({finish:'shiny'}),null); // nothing usable
  assert.throws(()=>vehicleProfile('Hyundai'));
  assert.deepEqual(careRoutine([{title:'Matte-safe wash',detail:'No wax.'}]),[{title:'Matte-safe wash',detail:'No wax.'}]);
  assert.throws(()=>careRoutine([{title:'a'},{title:'b'},{title:'c'},{title:'d'}]));
  assert.throws(()=>careRoutine([{detail:'no title'}]));
  const server=[{startHour:8,endHour:10},{startHour:18,endHour:22}];
  assert.deepEqual(minuteWindows([{startMinute:1140,endMinute:1260},{startMinute:495,endMinute:600}],server),[{startMinute:495,endMinute:600},{startMinute:1140,endMinute:1260}]);
  assert.throws(()=>minuteWindows([{startMinute:495,endMinute:540}],server)); // under 1 hour
  assert.deepEqual(minuteWindows([{startMinute:420,endMinute:1380}],server),[{startMinute:420,endMinute:1380}]); // covers booked windows
  assert.throws(()=>minuteWindows([{startMinute:620,endMinute:1000}],server)); // overlaps none of the booked windows
  assert.throws(()=>minuteWindows([{startMinute:1320,endMinute:1440}],[{startHour:22,endHour:24}])); // after 11 PM
  assert.throws(()=>minuteWindows([{startMinute:480,endMinute:600},{startMinute:540,endMinute:600}],server)); // overlap
  assert.equal(cleanIdentification({make:'',model:''}),null);
  assert.deepEqual(cleanIdentification({make:'Royal Enfield',model:'Classic 350',color:'Black',finish:'satin',confidence:3}),{make:'Royal Enfield',model:'Classic 350',color:'Black',finish:'unknown',confidence:1});
});

test('createBooking stores the details and every Captain offer carries them',async()=>{
  const care={vehicleProfile:{make:'Hyundai',model:'Creta',color:'White',finish:'matte',seats:'leather',source:'ai'},
    careRoutine:[{title:'Matte-safe wash',detail:'Mild shampoo, no wax or polish.'}],minuteWindows:[{startMinute:495,endMinute:600}]};
  const b=await service.createBooking(customer,{...input('care-1'),...care});
  const order=(await db.doc('orders/'+b.bookingId).get()).data();
  assert.deepEqual(order.vehicleProfile,care.vehicleProfile);assert.deepEqual(order.careRoutine,care.careRoutine);assert.deepEqual(order.minuteWindows,care.minuteWindows);
  const checkout=await service.checkout(customer,b);
  const payment={id:`pay_${counter}`,order_id:checkout.orderId,amount:checkout.amount,currency:'INR',status:'captured'};provider.payments.set(payment.id,payment);
  await service.capturePayment(payment);
  const offers=await db.collection('jobOffers').where('orderId','==',b.bookingId).get();
  assert.equal(offers.size,2);
  for(const d of offers.docs){assert.deepEqual(d.data().vehicleProfile,care.vehicleProfile);assert.deepEqual(d.data().careRoutine,care.careRoutine);assert.deepEqual(d.data().minuteWindows,care.minuteWindows);}
});

test('bookings without the new fields are unchanged; bad fields are refused',async()=>{
  await assert.rejects(service.createBooking(customer,{...input('bad'),minuteWindows:[{startMinute:1080,endMinute:1200}]}),/inside the available windows/);
  await assert.rejects(service.createBooking(customer,{...input('bad2'),careRoutine:'wash gently'}),/care routine/);
  const b=await service.createBooking(customer,input('plain'));
  const order=(await db.doc('orders/'+b.bookingId).get()).data();
  assert.equal(order.vehicleProfile,undefined);assert.equal(order.careRoutine,undefined);assert.equal(order.minuteWindows,undefined);
});

test('identifyVehicle is off until config.vehicleAi, then validates photos and rate-limits',async()=>{
  await assert.rejects(service.identifyVehicle(customer,{vehicleKind:'sedan',images:[jpeg]}),/not available yet/);
  assert.equal(ai.calls,0);
  await db.doc('config/operations').update({vehicleAi:true});
  assert.deepEqual(await service.identifyVehicle(customer,{vehicleKind:'sedan',images:[jpeg,jpeg]}),{make:'Hyundai',model:'Creta',color:'White',finish:'glossy',confidence:0.92});
  assert.equal(ai.kind,'sedan');assert.equal(ai.count,2);
  await assert.rejects(service.identifyVehicle(customer,{vehicleKind:'truck',images:[jpeg]}),/vehicle type/);
  await assert.rejects(service.identifyVehicle(customer,{vehicleKind:'sedan',images:[Buffer.from('not an image').toString('base64')]}),/JPEG or PNG/);
  await assert.rejects(service.identifyVehicle(customer,{vehicleKind:'sedan',images:[jpeg,jpeg,jpeg]}),/one or two photos/);
  ai.answer={make:'',model:''};
  assert.deepEqual(await service.identifyVehicle(customer,{vehicleKind:'bike',images:[jpeg]}),{make:'',model:'',color:'',finish:'unknown',confidence:0});
  for(let i=0;i<8;i++)await service.identifyVehicle(customer,{vehicleKind:'bike',images:[jpeg]});
  await assert.rejects(service.identifyVehicle(customer,{vehicleKind:'bike',images:[jpeg]}),/Too many photo checks/);
  clock+=3600000;
  await service.identifyVehicle(customer,{vehicleKind:'bike',images:[jpeg]}); // a new hour
});

test('Premium and interior are priced from config.washPrices once washTiers is on',async()=>{
  const premium={...input('tier-1'),serviceLevel:'premium',coverage:'exterior'};
  await assert.rejects(service.createBooking(customer,premium),/not available yet/);
  const kind=input().vehicleKind;
  await db.doc('config/operations').update({washTiers:true,washPrices:{[kind]:{premium:{exterior:392,exteriorInterior:472}}}});
  const b=await service.createBooking(customer,premium);
  const order=(await db.doc('orders/'+b.bookingId).get()).data();
  assert.equal(order.basePricePaise,39200);assert.equal(order.serviceLevel,'premium');assert.equal(order.coverage,'exterior');
  await service.abandonCheckout(customer,{bookingId:b.bookingId});
  await assert.rejects(service.createBooking(customer,{...input('tier-2'),serviceLevel:'premium',coverage:'exteriorInterior'}),/available wash/); // washKind must say inside
  const inside=await service.createBooking(customer,{...input('tier-3'),serviceLevel:'premium',coverage:'exteriorInterior',washKind:'wetOutsideDryInside'});
  const o2=(await db.doc('orders/'+inside.bookingId).get()).data();
  assert.equal(o2.basePricePaise,47200);assert.equal(o2.washKind,'wetOutsideDryInside');
  await service.abandonCheckout(customer,{bookingId:inside.bookingId});
  await assert.rejects(service.createBooking(customer,{...input('tier-4'),serviceLevel:'extraPremium',coverage:'exterior'}),/not priced yet/);
  const basic=await service.createBooking(customer,input('tier-5')); // Basic exterior unchanged
  assert.equal((await db.doc('orders/'+basic.bookingId).get()).data().serviceLevel,undefined);
});
