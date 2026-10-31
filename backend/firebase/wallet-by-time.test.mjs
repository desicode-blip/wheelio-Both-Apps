import test from 'node:test';
import assert from 'node:assert/strict';
import {cancellationPolicy,cancellationBenefit,serviceFailureBenefit} from './functions/src/booking-policy.mjs';
const booked=Date.parse('2026-11-01T07:00:00+05:30'),wash=booked+5*3600000;
const policy={kind:'walletByTime',creditMinutes:5,cutoffMinutes:120,lateCreditBps:5000,serviceFailure:'wallet'};
const ts=millis=>({toMillis:()=>millis});
const order=(patch={})=>({pricePaise:14900,creditUsedPaise:0,paymentStatus:'captured',bookedAt:ts(booked),slotStart:ts(wash),cancellationPolicy:policy,...patch});

test('wallet policy gives inclusive five-minute grace even for a near-term wash',()=>{
 assert.deepEqual(cancellationPolicy({cancellationPolicy:policy}),policy);
 for(const start of [wash,booked+30*60000,booked-60000]){
  const benefit=cancellationBenefit(order({slotStart:ts(start)}),booked+300000);
  assert.equal(benefit.phase,'fullCredit');assert.equal(benefit.creditPaise,14900);assert.equal(benefit.cashRefundPaise,0);assert.equal(benefit.feePaise,0);
 }
 assert.equal(cancellationBenefit(order({slotStart:ts(booked+60000)}),booked+300001).phase,'noCredit');
});
test('half credit includes the exact two-hour deadline; one millisecond later returns zero',()=>{
 const atCutoff=wash-120*60000;
 assert.equal(cancellationBenefit(order(),atCutoff).creditPaise,7450);
 const none=cancellationBenefit(order(),atCutoff+1);
 assert.equal(none.phase,'noCredit');assert.equal(none.creditPaise,0);assert.equal(none.feePaise,14900);
 assert.equal(cancellationBenefit(order(),booked+300001).phase,'partialCredit');
});
test('cash, mixed and entirely wallet-funded cancellations return total value once in paise',()=>{
 for(const [cash,used] of [[15000,0],[10000,5000],[0,15000]]){
  const o=order({pricePaise:cash,creditUsedPaise:used});
  for(const [time,returned]of[[booked,15000],[booked+300001,7500],[wash-60000,0]]){
   const benefit=cancellationBenefit(o,time);assert.equal(benefit.creditPaise,returned);assert.equal(benefit.feePaise,15000-returned);assert.equal(benefit.cashRefundPaise,0);assert.equal(benefit.restoreReserved,false);
  }
 }
 const odd=cancellationBenefit(order({pricePaise:14901}),booked+300001);
 assert.equal(odd.creditPaise,7450);assert.equal(odd.feePaise,7451);
});
test('cutoff follows the actual server-confirmed window, missing timing fails closed, invalid policy cannot activate',()=>{
 assert.equal(cancellationBenefit(order({slotStart:ts(wash+5*3600000)}),wash-60000).phase,'partialCredit');
 assert.throws(()=>cancellationBenefit(order({bookedAt:null}),booked));
 assert.throws(()=>cancellationBenefit(order({slotStart:null}),booked));
 for(const patch of [{creditMinutes:-1},{cutoffMinutes:1441},{lateCreditBps:10001},{serviceFailure:'cash'}])assert.throws(()=>cancellationPolicy({cancellationPolicy:{...policy,...patch}}));
 assert.equal(cancellationBenefit(order({paymentStatus:'unpaid'}),booked),null);
});
test('service failures ignore the customer cutoff and never re-return already restored wallet credit',()=>{
 const o=order({pricePaise:10000,creditUsedPaise:5000});
 assert.equal(serviceFailureBenefit(o).creditPaise,15000);
 assert.equal(serviceFailureBenefit({...o,walletReleased:true}).creditPaise,10000);
 assert.equal(serviceFailureBenefit({...o,cancellationPolicy:{kind:'refundThenCredit'}}),null);
 assert.equal(serviceFailureBenefit({...o,paymentStatus:'unpaid'}),null);
 assert.equal(serviceFailureBenefit(order({freeWashUsed:true,pricePaise:0})).kind,'walletRestored');
});
