import {CouponError} from './coupon-ledger.mjs';
const fail=message=>{throw new CouponError('failed-precondition',message);};
const millis=value=>value?.toMillis?.();
const money=n=>Number.isSafeInteger(n)&&n>=0;
export const approvedCouponPolicy=Object.freeze({kind:'couponByTime',creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,earlyFeeRule:'gatewayOnly',lateFeeRule:'percentThenFee',useRule:'singleUse',unusedRule:'forfeit'});

// Explicit owner-selected rules are required. Missing choices never activate
// an assumed refund amount in production.
export function couponPolicy(input){
 if(input?.kind!=='couponByTime'||input.creditMinutes!==5||input.cutoffMinutes!==120||input.lateCreditBps!==5000||
  input.earlyFeeRule!=='gatewayOnly'||input.lateFeeRule!=='percentThenFee'||
  input.useRule!=='singleUse'||input.unusedRule!=='forfeit')fail('The refund-coupon policy is not configured.');
 return {kind:'couponByTime',creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,earlyFeeRule:input.earlyFeeRule,lateFeeRule:input.lateFeeRule,useRule:'singleUse',unusedRule:input.unusedRule};
}
export function couponRefundAmount(order,now,{serviceFailure=false}={}){
 const p=couponPolicy(order.cancellationPolicy);
 if(order.paymentStatus!=='captured')return {kind:'couponRequest',phase:'unpaid',couponPaise:0,paidValuePaise:0,gatewayFeePaise:0,cancellationFeePaise:0};
 const cash=order.pricePaise,coupon=order.couponReleased?0:order.couponReservedPaise??0,fee=order.gatewayFeePaise??(cash===0?0:null);
 if(![cash,coupon,fee].every(money)||fee>cash||!money(cash+coupon))fail('The gateway fee or funding is still being verified. Please check again.');
 const total=cash+coupon,net=total-fee;
 let returned,phase;
 if(serviceFailure){returned=net;phase='serviceFailure';}
 else{
  const confirmed=millis(order.bookedAt),start=millis(order.slotStart);
  if(!Number.isFinite(confirmed)||!Number.isFinite(start)||!Number.isFinite(now)||now<confirmed)fail('The cancellation timing could not be verified.');
  if(now-confirmed<=p.creditMinutes*60000){phase='grace';returned=net;}
  else if(now<=start-p.cutoffMinutes*60000){phase='partial';returned=Math.max(0,Math.floor(total*p.lateCreditBps/10000)-fee);}
  else{phase='noCoupon';returned=0;}
 }
 return {kind:'couponRequest',phase,couponPaise:returned,paidValuePaise:total,gatewayFeePaise:fee,cancellationFeePaise:net-returned};
}
