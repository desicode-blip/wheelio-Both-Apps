import {test} from 'node:test';
import assert from 'node:assert/strict';
import {RazorpayPayments,PaymentProviderError} from './functions/src/payments.mjs';

test('server pins the merchant checkout configuration to its Razorpay order',async()=>{
 let body;const api=new RazorpayPayments({keyId:'rzp_test_fake',keySecret:'fake',fetchImpl:async(url,options)=>{body=JSON.parse(options.body);return Response.json({id:'order_1'});}});
 await api.createOrder({amount:14900,receipt:'booking',bookingId:'b1',checkoutConfigId:'config_no_credit'});
 assert.equal(body.checkout_config_id,'config_no_credit');assert.equal(body.amount,14900);
});
test('verification and order reconciliation fetch provider card funding types',async()=>{
 const paths=[];const api=new RazorpayPayments({keyId:'rzp_test_fake',keySecret:'fake',fetchImpl:async url=>{paths.push(url);return Response.json(url.endsWith('/card')?{type:'debit'}:url.includes('/orders/')?{items:[{id:'pay_1',method:'card',status:'captured'}]}:{id:'pay_1',method:'card',status:'captured'});}});
 assert.equal((await api.payment('pay_1')).card.type,'debit');
 assert.equal((await api.orderPayments('order_1')).items[0].card.type,'debit');
 assert.equal(paths.filter(p=>p.endsWith('/card')).length,2);
});

test('provider errors retain bounded diagnostics without exposing payloads or credentials',async()=>{
  const api=new RazorpayPayments({keyId:'rzp_test_fake',keySecret:'private-key',fetchImpl:async()=>new Response(JSON.stringify({error:{code:'BAD_REQUEST_ERROR',description:'private-key personal@example.com'}}),{status:400})});
  await assert.rejects(api.fetchRefund('rfnd_one'),error=>{
    assert.ok(error instanceof PaymentProviderError);assert.equal(error.status,400);assert.equal(error.code,'BAD_REQUEST_ERROR');
    assert.ok(!JSON.stringify(error).includes('private-key'));assert.ok(!String(error).includes('personal@'));return true;
  });
});

test('refund recovery searches pages for its receipt and never invents a matching refund',async()=>{
  const paths=[];const api=new RazorpayPayments({keyId:'rzp_test_fake',keySecret:'fake',fetchImpl:async(url)=>{
    paths.push(url);return Response.json({items:paths.length===1?Array.from({length:100},(_,i)=>({id:`other_${i}`,receipt:'other'})):[{id:'rfnd_found',notes:{wheelioRefundId:'wh_booking'}}]});
  }});
  assert.equal((await api.findRefund({paymentId:'pay_1',refundId:'wh_booking'})).id,'rfnd_found');assert.ok(paths[1].endsWith('skip=100'));
  api.fetch=async()=>Response.json({items:[]});assert.equal(await api.findRefund({paymentId:'pay_1',refundId:'wh_absent'}),null);
});

test('refund POST retains the full amount and identical idempotency body across retries',async()=>{
  const requests=[];const api=new RazorpayPayments({keyId:'rzp_test_fake',keySecret:'fake',fetchImpl:async(url,options)=>{requests.push({url,...options});return Response.json({id:'rfnd_1'});}});
  const input={paymentId:'pay_1',amount:14900,refundId:'wh_booking_reference'};await api.refund(input);await api.refund(input);
  assert.equal(requests[0].body,requests[1].body);assert.equal(JSON.parse(requests[0].body).amount,14900);
  assert.equal(requests[0].headers['X-Refund-Idempotency'],input.refundId);assert.equal(requests[1].headers['X-Refund-Idempotency'],input.refundId);
});
