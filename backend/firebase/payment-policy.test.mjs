import {test} from 'node:test';
import assert from 'node:assert/strict';
import {acceptsFunding} from './functions/src/payment-policy.mjs';
test('no-credit-card policy accepts bank UPI, debit cards and netbanking',()=>{
 for(const p of [{method:'upi',upi:{payer_account_type:'bank_account'}},{method:'card',card:{type:'debit'}},{method:'netbanking'}])assert.equal(acceptsFunding(p,'no-credit-cards'),true);
});
test('credit cards, credit-funded UPI and unverifiable funding are rejected',()=>{
 for(const p of [{method:'card',card:{type:'credit'}},{method:'upi',upi:{payer_account_type:'credit_card'}},{method:'upi',upi:{payer_account_type:'credit_line'}},{method:'upi'},{method:'card'},{method:'card',card:{type:'unknown'}},{method:'emi'},{method:'paylater'},{method:'wallet'}])assert.equal(acceptsFunding(p,'no-credit-cards'),false);
});
test('historical payment records retain their original funding policy',()=>{
 assert.equal(acceptsFunding({method:'card',card:{type:'credit'}},null),true);
});
test('owner checkout-only ban retains UPI funding while blocking credit-card checkout',()=>{
 assert.equal(acceptsFunding({method:'upi',upi:{payer_account_type:'credit_card'}},'no-credit-card-checkout'),true);
 assert.equal(acceptsFunding({method:'upi'},'no-credit-card-checkout'),true);
 assert.equal(acceptsFunding({method:'card',card:{type:'debit'}},'no-credit-card-checkout'),true);
 assert.equal(acceptsFunding({method:'card',card:{type:'credit'}},'no-credit-card-checkout'),false);
 assert.equal(acceptsFunding({method:'card'},'no-credit-card-checkout'),false);
});
