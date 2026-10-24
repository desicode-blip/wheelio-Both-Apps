import {test} from 'node:test';
import assert from 'node:assert/strict';
import {orderNotices} from './functions/src/notifications.mjs';
test('order notifications are role-scoped, coarse and explicitly identify test bookings',()=>{
 const before={status:'onTheWay'};
 const after={customerId:'owner',captainId:'captain',status:'cancelled',paymentMode:'test',plate:'PRIVATE',phone:'PRIVATE',note:'PRIVATE',societyName:'PRIVATE'};
 const notices=orderNotices(before,after);
 assert.deepEqual(notices.map(n=>[n.recipientId,n.role]),[['owner','customer'],['captain','captain']]);
 assert.equal(notices.every(n=>n.title.startsWith('Test · ')),true);
 assert.equal(JSON.stringify(notices).includes('PRIVATE'),false);
 assert.equal(orderNotices(after,after).length,0);
});
