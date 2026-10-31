import {test} from 'node:test';
import assert from 'node:assert/strict';
import {orderNotices,pushDelivery} from './functions/src/notifications.mjs';
test('order notifications are role-scoped and private, using the designed wording',()=>{
 const before={status:'onTheWay'};
 const after={customerId:'owner',captainId:'captain',status:'cancelled',paymentMode:'test',plate:'PRIVATE',phone:'PRIVATE',note:'PRIVATE',societyName:'PRIVATE'};
 const notices=orderNotices(before,after);
 assert.deepEqual(notices.map(n=>[n.recipientId,n.role]),[['owner','customer'],['captain','captain']]);
 assert.equal(notices.every(n=>n.title==='Booking cancelled'),true);
 assert.equal(JSON.stringify(notices).includes('PRIVATE'),false);
 assert.equal(orderNotices(after,after).length,0);
});
test('push respects persisted mute/category preferences and Hyderabad quiet hours',()=>{
 const notice={role:'customer',kind:'photosReady'};
 const night=Date.parse('2026-11-01T22:00:00+05:30'),morning=Date.parse('2026-11-02T07:00:00+05:30');
 assert.deepEqual(pushDelivery(notice,{enabled:false},night,true),{send:false,sound:false});
 assert.deepEqual(pushDelivery(notice,{mutedUntil:morning},night,true),{send:false,sound:false});
 assert.deepEqual(pushDelivery(notice,{offCategories:['bookings']},night,true),{send:false,sound:false});
 assert.deepEqual(pushDelivery(notice,{quietHours:true},night,true),{send:true,sound:false});
 assert.deepEqual(pushDelivery(notice,{quietHours:true},morning,true),{send:true,sound:true});
 assert.deepEqual(pushDelivery({role:'captain',kind:'offer'},{quietHours:true,mutedUntil:morning,soundOn:false},night,true),{send:true,sound:true});
 assert.deepEqual(pushDelivery({role:'captain',kind:'offer'},null,night,false),{send:false,sound:false});
});

test('wallet cancellations describe wallet outcome without a fictional bank refund',()=>{
 const before={status:'searching'},after={status:'cancelled',customerId:'owner',captainId:'captain',cancellationPolicy:{kind:'walletByTime'},cancellationBenefit:{kind:'credit',phase:'noCredit'}};
 const notices=orderNotices(before,after);
 assert.match(notices.find(n=>n.role==='customer').body,/wallet credit/);
 assert.doesNotMatch(notices.find(n=>n.role==='customer').body,/refund/);
 assert.equal(notices.find(n=>n.role==='captain').title,'Booking cancelled');
});
