import test from 'node:test';
import assert from 'node:assert/strict';
import {couponPolicy,couponRefundAmount} from './functions/src/coupon-policy.mjs';
// These are isolated formula fixtures, not an owner decision or live config.
const policy={kind:'couponByTime',creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,earlyFeeRule:'gatewayOnly',lateFeeRule:'percentThenFee',useRule:'singleUse',unusedRule:'forfeit'};
const stamp=n=>({toMillis:()=>n});
const order=()=>({paymentStatus:'captured',pricePaise:10000,gatewayFeePaise:200,cancellationPolicy:policy,bookedAt:stamp(0),slotStart:stamp(8*3600000)});
test('coupon formula cannot activate missing owner choices; each requested deduction choice is exact',()=>{
 assert.throws(()=>couponPolicy({kind:'couponByTime'}));
 assert.equal(couponRefundAmount(order(),300000).couponPaise,9800);
 assert.throws(()=>couponRefundAmount({...order(),cancellationPolicy:{...policy,earlyFeeRule:'policyPlusGateway'}},300000));
 assert.equal(couponRefundAmount(order(),300001).couponPaise,4800);
 assert.equal(couponRefundAmount({...order(),cancellationPolicy:{...policy,lateFeeRule:'percentThenFee'}},300001).couponPaise,4800);
});
test('five-minute grace wins near the wash; exact two-hour cutoff qualifies, service failure ignores time',()=>{
 const close={...order(),slotStart:stamp(3600000)};
 assert.equal(couponRefundAmount(close,300000).couponPaise,9800);assert.equal(couponRefundAmount(close,300001).couponPaise,0);
 assert.equal(couponRefundAmount(order(),6*3600000).couponPaise,4800);assert.equal(couponRefundAmount(order(),6*3600000+1).couponPaise,0);
 assert.equal(couponRefundAmount(order(),9*3600000,{serviceFailure:true}).couponPaise,9800);
 assert.throws(()=>couponRefundAmount({...order(),gatewayFeePaise:null},1000));
 const funded={...order(),pricePaise:10000,couponReservedPaise:5000};
 assert.equal(couponRefundAmount(funded,1000).couponPaise,14800);
 assert.equal(couponRefundAmount({...funded,couponReleased:true},1000,{serviceFailure:true}).couponPaise,9800);
});
