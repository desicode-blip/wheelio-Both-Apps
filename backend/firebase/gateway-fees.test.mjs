import {test} from 'node:test';
import assert from 'node:assert/strict';
import {customerTopupFees,confirmsCustomerFees,topupFunding} from './functions/src/gateway-fees.mjs';
import {checkoutIdentity} from './functions/src/checkout-identity.mjs';
test('top-up passes the full actual gateway fee once; GST is not deducted twice',()=>{
 const order={amountPaise:10000,feePolicy:'customerAtTopupV1'};
 assert.deepEqual(topupFunding(order,{amount:10200,fee:200,tax:31}),{creditPaise:10000,paidPaise:10200,gatewayFeePaise:200});
 for(const p of [{amount:10000,fee:200},{amount:10200},{amount:10201,fee:200},{amount:10200,fee:-1}])assert.equal(topupFunding(order,p),null);
 assert.deepEqual(topupFunding(order,{amount:10000,fee:0}),{creditPaise:10000,paidPaise:10000,gatewayFeePaise:0});
 assert.deepEqual(topupFunding({amountPaise:10000},{amount:10000,fee:200}),{creditPaise:10000,paidPaise:10000});
 assert.equal(confirmsCustomerFees(customerTopupFees()),true);assert.equal(confirmsCustomerFees({}),false);
});
test('checkout identity is stable on retries and cannot reuse another vehicle, payment choice or amount',()=>{
 const input={plate:'ts 09 ab 1234',societyId:'one',day:'2026-11-12',startHour:8,endHour:10,useCredit:false,expectedAmountPaise:6900};
 const key=checkoutIdentity(input);
 assert.equal(checkoutIdentity({...input,plate:'TS09AB1234',requestId:'different',pricePaise:0}),key);
 for(const patch of [{plate:'TS09AB5678'},{useCredit:true},{expectedAmountPaise:0},{paymentChoice:'wallet'},{startHour:10},{vehiclePosition:{latitude:1,longitude:2}}])assert.notEqual(checkoutIdentity({...input,...patch}),key);
});
