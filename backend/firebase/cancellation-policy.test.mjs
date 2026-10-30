import test from 'node:test';
import assert from 'node:assert/strict';
import {cancellationPolicy,cancellationBenefit,walletPrice} from './functions/src/booking-policy.mjs';
const start=Date.parse('2026-11-01T07:00:00+05:30');
const policy={kind:'refundThenCredit',refundMinutes:5,lateCreditBps:5000};
const order=(changes={})=>({pricePaise:14900,creditUsedPaise:0,paymentStatus:'captured',cancellationPolicy:policy,createdAt:{toMillis:()=>start-600000},bookedAt:{toMillis:()=>start},...changes});

test('five-minute policy refunds cash through the inclusive boundary from booking confirmation',()=>{
 assert.deepEqual(cancellationPolicy({cancellationPolicy:policy}),policy);
 assert.deepEqual(cancellationBenefit(order(),start+300000),{kind:'refund',freeWashes:0,creditPaise:0,cashRefundPaise:14900,feePaise:0,restoreReserved:false});
 assert.equal(cancellationBenefit(order(),start+300001).creditPaise,7450);
 assert.equal(cancellationBenefit(order(),start+300001).feePaise,7450);
});
test('mixed and wallet-only late cancellations split total paid value without restoring used credit twice',()=>{
 for(const [cash,credit] of [[10000,5000],[0,15000],[15000,0]]){
  const early=cancellationBenefit(order({pricePaise:cash,creditUsedPaise:credit}),start);
  assert.equal(early.cashRefundPaise,cash);assert.equal(early.creditPaise,credit);
  const late=cancellationBenefit(order({pricePaise:cash,creditUsedPaise:credit}),start+300001);
  assert.equal(late.creditPaise,7500);assert.equal(late.feePaise,7500);assert.equal(late.cashRefundPaise,0);assert.equal(late.restoreReserved,false);
 }
 const odd=cancellationBenefit(order({pricePaise:14901}),start+300001);
 assert.equal(odd.creditPaise+odd.feePaise,14901);
});
test('legacy policies and unpaid/free entitlements keep their previous obligations',()=>{
 assert.equal(cancellationBenefit(order({paymentStatus:'unpaid'}),start),null);
 assert.equal(cancellationBenefit(order({cancellationPolicy:{kind:'refund'}}),start),null);
 const legacy=order({cancellationPolicy:{kind:'wallet',freeWashMinutes:15,lateCreditBps:5000}});
 assert.equal(cancellationBenefit(legacy,start).kind,'freeWash');
 assert.equal(cancellationBenefit(legacy,start+16*60000).creditPaise,7500);
 const free=cancellationBenefit(order({pricePaise:0,freeWashUsed:true}),start+300001);
 assert.equal(free.kind,'walletRestored');assert.equal(free.creditPaise,0);assert.equal(free.feePaise,0);
 assert.throws(()=>cancellationPolicy({cancellationPolicy:{...policy,refundMinutes:-1}}));
 assert.throws(()=>cancellationPolicy({cancellationPolicy:{...policy,lateCreditBps:10001}}));
});
test('wallet usage preserves paise and the Razorpay minimum without consuming unused remainder',()=>{
 assert.deepEqual(walletPrice(14900,{creditPaise:7450},{useCredit:true}),{pricePaise:7450,creditUsedPaise:7450,freeWashUsed:false});
 assert.deepEqual(walletPrice(14900,{creditPaise:14850},{useCredit:true}),{pricePaise:100,creditUsedPaise:14800,freeWashUsed:false});
 assert.equal(walletPrice(14900,{creditPaise:20000},{useCredit:true}).pricePaise,0);
});
