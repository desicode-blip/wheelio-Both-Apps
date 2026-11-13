// v2 (13 Nov 2026, Aman: "monthly plans must be active — build the complete journey").
// Written for Ajay's review; off until config/operations.monthlyPlans === true.
//
// How a monthly plan books and pays (AutoPay is not available yet, so it is one upfront
// payment for one cycle, no renewal):
//  1. createBooking gets `plan: {frequency, weekdays:[1..7], start:'YYYY-MM-DD'}`. The server
//     works out the visit dates exactly like the app (every chosen weekday from `start` up
//     to the same date next month), prices the cycle, and the order is visit 1 (`day` must
//     be the first visit). The customer pays the cycle price once, through the normal checkout.
//  2. When the payment is captured and visit 1 gets a slot, the price (and the gateway fee)
//     is split across the visits. Visit 1 keeps its share; every later visit becomes its own
//     order (status `scheduled`, paid by the same payment, `planId` = visit 1's id).
//  3. activatePlanVisits (every 5 minutes) moves a scheduled visit to `searching` about a day
//     ahead, when it reserves capacity and offers it to Captains like any booking. A visit
//     that never finds capacity is refunded as a service failure (its share only).
//  4. Each visit is cancelled, refunded, approved and paid to its Captain on its own, with
//     the existing rules, against its share (partial refunds on the one payment).
import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';

export class MonthlyPlanError extends Error {constructor(code,message){super(message);this.code=code;}}
const fail=(code,message)=>{throw new MonthlyPlanError(code,message);};
const hash=v=>createHash('sha256').update(v).digest('hex').slice(0,32);
const iso=d=>`${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`;
const parse=s=>{const [y,m,d]=s.split('-').map(Number);return new Date(Date.UTC(y,m-1,d));};
const LEVELS=['basic','premium','extraPremium'];

/** Same month as the app's nextMonth(): same day next month, clamped to its last day. */
export function nextMonth(day){
  const d=parse(day),last=new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+2,0)).getUTCDate();
  return iso(new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+1,Math.min(d.getUTCDate(),last))));
}

/** Every date in [start, nextMonth(start)) whose weekday (Mon=1 … Sun=7) was chosen. */
export function planVisits(start,weekdays){
  const out=[],end=nextMonth(start);
  for(let d=parse(start);iso(d)<end;d=new Date(d.getTime()+86400000)){
    const wd=d.getUTCDay()===0?7:d.getUTCDay();
    if(weekdays.includes(wd))out.push(iso(d));
  }
  return out;
}

// Aman's monthly tariff (rupees), as the app shows it: base + per-day × days a week,
// + tier and interior allowances per day. config.monthlyPlanPricing.{car,bike} overrides.
const DEFAULT_PRICING={car:{base:199,perDay:106,levelPerDay:72,interiorPerDay:80},bike:{base:99,perDay:66,levelPerDay:40,interiorPerDay:0}};

export function planPricePaise(config,kind,frequency,level,coverage){
  const p=config.monthlyPlanPricing?.[kind==='bike'?'bike':'car']??DEFAULT_PRICING[kind==='bike'?'bike':'car'];
  if(['base','perDay','levelPerDay','interiorPerDay'].some(k=>typeof p[k]!=='number'||!Number.isFinite(p[k])||p[k]<0))fail('failed-precondition','Monthly plans are not priced yet.');
  const rupees=p.base+p.perDay*frequency+p.levelPerDay*frequency*LEVELS.indexOf(level)+(coverage==='exteriorInterior'?p.interiorPerDay*frequency:0);
  return Math.round(rupees*100);
}

/**
 * Validates `data.plan` for createBooking. Returns null for a one-time booking, otherwise
 * {plan, pricePaise}. `type` is the vehicle type after wash-tier pricing.
 */
export function monthlyPlan(config,type,data,today){
  if(data.plan===undefined||data.plan===null)return null;
  if(config.monthlyPlans!==true)fail('failed-precondition','Monthly plans are not available yet.');
  const raw=data.plan;
  if(typeof raw!=='object'||Array.isArray(raw))fail('invalid-argument','Check your monthly plan.');
  const frequency=raw.frequency;
  if(!Number.isInteger(frequency)||frequency<1||frequency>7)fail('invalid-argument','Choose 1 to 7 days a week.');
  if(!Array.isArray(raw.weekdays)||raw.weekdays.length!==frequency||raw.weekdays.some(d=>!Number.isInteger(d)||d<1||d>7)||new Set(raw.weekdays).size!==frequency)
    fail('invalid-argument','Choose your wash days again.');
  if(!/^\d{4}-\d{2}-\d{2}$/.test(raw.start??'')||raw.start<today)fail('invalid-argument','Choose a plan start date from today.');
  if(parse(raw.start).getTime()-parse(today).getTime()>31*86400000)fail('invalid-argument','Start your plan within the next month.');
  // A plan is paid by one payment: no coupons, wallet credit or free washes on top.
  if(data.couponCode||data.useCredit===true||data.useFreeWash===true||(data.paymentChoice&&data.paymentChoice!=='razorpay'))
    fail('failed-precondition','Monthly plans are paid in full with Razorpay. Remove the coupon and try again.');
  const weekdays=[...raw.weekdays].sort((a,b)=>a-b),dates=planVisits(raw.start,weekdays);
  if(!dates.length)fail('invalid-argument','Choose your wash days again.');
  if(data.day!==dates[0])fail('invalid-argument','Your first plan visit changed. Review the plan again.');
  const level=data.serviceLevel??'basic',coverage=data.coverage??'exterior';
  const pricePaise=planPricePaise(config,type.kind,frequency,level,coverage);
  if(pricePaise<dates.length*100)fail('failed-precondition','Monthly plans are not priced yet.');
  return {pricePaise,plan:{frequency,weekdays,start:raw.start,end:nextMonth(raw.start),dates,totalVisits:dates.length,pricePaise}};
}

/** Splits `total` paise into `n` whole shares; the first share takes the remainder. */
export function shares(total,n){
  const each=Math.floor(total/n);
  return Array.from({length:n},(_,i)=>i===0?total-each*(n-1):each);
}

/**
 * At capture of a plan order whose first visit got a slot: visit 1's own price fields, and
 * the later visits' orders (refs + data) to create in the same transaction.
 *  - `earningsFor(visitOrder, feePaise)` returns the visit's Captain earnings fields.
 *  - `windowTimes(day, window)` gives the visit's slot.
 */
export function planVisitOrders(db,parentId,o,{paymentId,source,feePaise,earningsFor,windowTimes,now}){
  const plan=o.plan,n=plan.dates.length,price=shares(plan.pricePaise,n),fee=shares(feePaise??0,n);
  const visit=(i)=>{
    const base={...o,pricePaise:price[i],basePricePaise:price[i]};
    // Fixed Captain pay stays per visit; percentage policies follow the visit's share.
    return {...base,...earningsFor(base,fee[i])};
  };
  const first=visit(0);
  const firstFields={pricePaise:first.pricePaise,basePricePaise:first.basePricePaise,captainPayPaise:first.captainPayPaise,
    ...(first.gatewayFeePaise!==undefined?{gatewayFeePaise:first.gatewayFeePaise,platformFeePaise:first.platformFeePaise}:{}),
    planId:parentId,planVisit:1,planVisits:n,planPricePaise:plan.pricePaise};
  const windows=o.requestedWindows??[{startHour:o.startHour,endHour:o.endHour}];
  const {razorpayOrderId,nextPaymentCheckAt,checkoutLease,checkoutLeaseUntil,paymentExpiresAt,capacityCaptainId,bookedAt,...copy}=o;
  const later=plan.dates.slice(1).map((day,k)=>{
    const i=k+1,v=visit(i),id=hash(`${parentId}:visit:${i}`),w=windows[0],t=windowTimes(day,w),last=windowTimes(day,windows.at(-1));
    return [db.doc(`orders/${id}`),{
      ...copy,pricePaise:v.pricePaise,basePricePaise:v.basePricePaise,captainPayPaise:v.captainPayPaise,
      ...(v.gatewayFeePaise!==undefined?{gatewayFeePaise:v.gatewayFeePaise,platformFeePaise:v.platformFeePaise}:{}),
      ref:`WH-${id.slice(0,8).toUpperCase()}`,requestIdentity:`${o.requestIdentity}:visit:${i}`,
      day,startHour:w.startHour,endHour:w.endHour,slotStart:Timestamp.fromMillis(t.start),slotEnd:Timestamp.fromMillis(t.end),
      lastSlotEnd:Timestamp.fromMillis(last.end),retentionDueAt:Timestamp.fromMillis(last.end+90*86400000),slotKey:null,
      status:'scheduled',paymentStatus:'captured',paymentSource:source,razorpayPaymentId:paymentId??null,capacityReserved:false,captainId:null,
      walletReserved:false,walletReleased:false,creditUsedPaise:0,creditReservedLots:[],freeWashUsed:false,
      planId:parentId,planVisit:i+1,planVisits:n,planPricePaise:plan.pricePaise,
      evidence:{},createdAt:Timestamp.fromMillis(now),updatedAt:Timestamp.fromMillis(now),
    }];
  });
  return {firstFields,later};
}
