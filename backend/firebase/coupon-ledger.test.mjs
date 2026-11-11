import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeCouponCode,couponValue,reserveCouponValue,completeCouponReservation} from './functions/src/coupon-ledger.mjs';
const coupon=()=>({customerId:'owner',status:'active',useRule:'singleUse',unusedRule:'forfeit',faceValuePaise:10000,availablePaise:10000,reservedPaise:0,spentPaise:0,expiresAt:2000});
test('private coupon reservation covers a wash or computes a Razorpay shortfall without minting value',()=>{
 const r=reserveCouponValue(coupon(),{now:1000,pricePaise:6900});
 assert.equal(r.amountPaise,6900);assert.equal(r.cashDuePaise,0);assert.equal(r.coupon.availablePaise,0);
 assert.throws(()=>reserveCouponValue(r.coupon,{now:1001,pricePaise:5000}));
 const spent=completeCouponReservation(r.coupon,{now:1001,amountPaise:r.heldPaise,captured:true});assert.equal(spent.spentPaise,10000);assert.equal(spent.availablePaise,0);assert.equal(spent.reservedPaise,0);
 assert.throws(()=>completeCouponReservation(spent,{now:1001,amountPaise:r.heldPaise,captured:true}));
 assert.throws(()=>reserveCouponValue({...coupon(),faceValuePaise:6850,availablePaise:6850},{now:1000,pricePaise:6900}),/gateway minimum/);
});
test('unpaid coupon restoration retains expiry and a corrupt or expired coupon never funds a new wash',()=>{
 const r=reserveCouponValue(coupon(),{now:1000,pricePaise:6900});
 assert.equal(completeCouponReservation(r.coupon,{now:1500,amountPaise:r.heldPaise,captured:false}).availablePaise,10000);
 const expired=completeCouponReservation(r.coupon,{now:2000,amountPaise:r.heldPaise,captured:false});assert.equal(expired.availablePaise,0);assert.equal(expired.expiredPaise,10000);assert.equal(expired.expiresAt,2000);
 assert.throws(()=>reserveCouponValue(coupon(),{now:2000,pricePaise:100}));assert.throws(()=>couponValue({...coupon(),availablePaise:10001},1000));
 assert.equal(normalizeCouponCode(' wk-aabbccdd-11223344 '),'WK-AABBCCDD-11223344');assert.throws(()=>normalizeCouponCode('../another-owner'));
});
test('single-use coupons never silently retain or discard unused value without an explicit rule',()=>{
 const c={...coupon(),unusedRule:undefined};
 assert.throws(()=>reserveCouponValue(c,{now:1000,pricePaise:6900}));
 assert.throws(()=>reserveCouponValue({...c,unusedRule:'minimumPrice'},{now:1000,pricePaise:6900}));
 const full=reserveCouponValue(coupon(),{now:1000,pricePaise:14900});assert.equal(full.amountPaise,10000);assert.equal(full.cashDuePaise,4900);assert.equal(full.coupon.availablePaise,0);
 const discarded=reserveCouponValue({...c,unusedRule:'forfeit'},{now:1000,pricePaise:6900});assert.equal(discarded.amountPaise,6900);assert.equal(discarded.heldPaise,10000);assert.equal(discarded.forfeitPaise,3100);assert.equal(discarded.coupon.availablePaise,0);
});
