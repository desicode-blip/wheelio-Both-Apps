import {randomBytes,createHash} from 'node:crypto';
import {FieldValue,Timestamp,FieldPath} from 'firebase-admin/firestore';
import {requireCaptainReviewer} from './captain-review.mjs';
import {couponRefundAmount} from './coupon-policy.mjs';
import {CouponError} from './coupon-ledger.mjs';
import {couponId} from './refund-coupons.mjs';
import {creditExpiry} from './wallet-credits.mjs';
const fail=(code,message)=>{throw new CouponError(code,message);};
const version=s=>`${s.updateTime.seconds}:${s.updateTime.nanoseconds}`;
const refId=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,100}$/.test(v)?v:fail('invalid-argument','Choose a refund request.');
const hash=v=>createHash('sha256').update(v).digest('hex');

export async function prepareRefundRequest(s,tx,orderId,order,benefit,{at=s.now(),serviceFailure=false,reason='customerCancellation'}={}){
 if(!benefit||!['couponRequest','credit'].includes(benefit.kind)||order.paymentStatus!=='captured')return null;
 const ref=s.db.doc('refundRequests/'+orderId),old=await tx.get(ref);
 if(old.exists)return {write(){},id:ref.id};
 const modern=benefit.kind==='couponRequest',amount=modern?benefit.couponPaise:benefit.creditPaise;
 if(!Number.isSafeInteger(amount)||amount<0)fail('failed-precondition','The refund amount needs support review.');
 const record={customerId:order.customerId,captainId:order.captainId??null,orderId,bookingRef:order.ref,paymentMode:order.paymentMode,paymentMerchant:order.paymentMerchant??'trustkeyper',
  amountPaise:amount,paidValuePaise:modern?benefit.paidValuePaise:order.pricePaise+(order.walletReleased?0:order.creditUsedPaise??0),
  gatewayFeePaise:modern?benefit.gatewayFeePaise:order.gatewayFeePaise??null,
  calculation:modern?'couponByTime':'savedHistoricalEntitlement',phase:benefit.phase??'historical',reason,serviceFailure,
  status:amount>0?'pending':'ineligible',requestedAt:Timestamp.fromMillis(at),createdAt:Timestamp.fromMillis(s.now()),updatedAt:FieldValue.serverTimestamp()};
 return {id:ref.id,write(){tx.create(ref,record);tx.update(s.db.doc('orders/'+orderId),{refundRequestId:ref.id,refundRequestStatus:record.status,refundCouponAmountPaise:amount});}};
}

export async function listRefundRequests(s,auth,data){
 await requireCaptainReviewer(s,auth);
 const status=data.status??'pending';
 if(!['pending','ineligible','issued','declined','all'].includes(status))fail('invalid-argument','Choose a refund status.');
 let query=s.db.collection('refundRequests');if(status!=='all')query=query.where('status','==',status);
 query=query.orderBy('createdAt','desc').orderBy(FieldPath.documentId(),'desc').limit(30);
 if(data.cursor){if(!Number.isSafeInteger(data.cursor.at)||!data.cursor.id)fail('invalid-argument','Refresh refund requests.');query=query.startAfter(Timestamp.fromMillis(data.cursor.at),refId(data.cursor.id));}
 const rows=await query.get();
 return {requests:rows.docs.map(d=>{const r=d.data();return {id:d.id,version:version(d),bookingRef:r.bookingRef,paymentMode:r.paymentMode,status:r.status,phase:r.phase,reason:r.reason,amountPaise:r.amountPaise,paidValuePaise:r.paidValuePaise,gatewayFeePaise:r.gatewayFeePaise,calculation:r.calculation,createdAt:r.createdAt.toMillis(),note:r.note??'',couponCode:r.couponCode??null};}),
  nextCursor:rows.size===30?{at:rows.docs.at(-1).data().createdAt.toMillis(),id:rows.docs.at(-1).id}:null};
}

export async function reviewRefundRequest(s,auth,data){
 const reviewer=await requireCaptainReviewer(s,auth,{fresh:true}),id=refId(data.requestId),note=typeof data.note==='string'?data.note.trim():'';
 if(!['issue','decline'].includes(data.decision)||note.length<5||note.length>1000||typeof data.expectedVersion!=='string'||data.confirm!==true)fail('invalid-argument','Confirm the refund decision and add a clear review note.');
 const requestRef=s.db.doc('refundRequests/'+id),initial=(await requestRef.get()).data();
 if(!initial)fail('not-found','This refund request is unavailable.');
 if([initial.customerId,initial.captainId].includes(reviewer.uid))fail('permission-denied','Another authorised reviewer must decide this refund.');
 if(!initial.customerId)fail('failed-precondition','The Customer account is unavailable for a coupon.');
 const orderRef=s.db.doc('orders/'+refId(initial.orderId)),original=(await orderRef.get()).data();
 if(data.decision==='issue'&&initial.status!=='issued'&&(original?.pricePaise??0)>0){
  const p=await s.getPayments(original.paymentMode,original.paymentMerchant).payment(original.razorpayPaymentId);
  if(p?.status!=='captured'||p.id!==original.razorpayPaymentId||p.order_id!==original.razorpayOrderId||p.amount!==original.pricePaise||p.currency!=='INR'||(p.amount_refunded??0)>0)fail('failed-precondition','The original payment is not available to back a coupon. Review any bank refund first.');
 }
 const bytes=randomBytes(8).toString('hex').toUpperCase(),code=`WK-${bytes.slice(0,8)}-${bytes.slice(8)}`,couponRef=s.db.doc('coupons/'+couponId(code));
 const result=await s.db.runTransaction(async tx=>{
  const [snapshot,orderSnapshot,bankRefund,profile]=await Promise.all([tx.get(requestRef),tx.get(orderRef),tx.get(s.db.doc('refunds/'+initial.orderId)),tx.get(s.db.doc('users/'+initial.customerId))]);
  const r=snapshot.data(),o=orderSnapshot.data();
  if(r?.status==='issued'&&data.decision==='issue')return {ok:true,couponId:r.couponId,alreadyIssued:true};
  if(r?.status==='declined'&&data.decision==='decline')return {ok:true};
  const customer=profile.data();
  if(!customer||!customer.roles?.includes('customer')||customer.deletionStatus||customer.deletingRole==='customer'||customer.deletedRoles?.customer)fail('failed-precondition','The Customer account is unavailable for a coupon. Review the account before deciding.');
  if(!r||!o||r.customerId!==o.customerId||!r.customerId||![ 'cancelled','disputeUpheld'].includes(o.status)||o.paymentStatus!=='captured'||bankRefund.exists||!['none',undefined].includes(o.refundStatus))fail('failed-precondition','The booking or its refund needs a manual financial review.');
  if(data.expectedVersion!==version(snapshot)||!['pending','ineligible'].includes(r.status))fail('aborted','This refund request changed. Refresh before deciding.');
  if(r.calculation==='couponByTime'&&couponRefundAmount(o,r.requestedAt.toMillis(),{serviceFailure:r.serviceFailure}).couponPaise!==r.amountPaise)fail('failed-precondition','The refund calculation changed. Review the booking before issuing a coupon.');
  if(data.decision==='issue'&&(!Number.isSafeInteger(r.amountPaise)||r.amountPaise<=0))fail('failed-precondition','There is no eligible value to issue as a coupon.');
  const next=data.decision==='issue'?'issued':'declined';
  if(next==='issued')tx.create(couponRef,{code,customerId:r.customerId,paymentMode:r.paymentMode,status:'active',faceValuePaise:r.amountPaise,availablePaise:r.amountPaise,reservedPaise:0,spentPaise:0,expiredPaise:0,
   useRule:'singleUse',unusedRule:'forfeit',issuedAt:Timestamp.fromMillis(s.now()),expiresAt:Timestamp.fromMillis(creditExpiry(s.now())),source:'refundRequest',sourceRequestId:id,sourceOrderId:r.orderId});
  tx.update(requestRef,{status:next,note,reviewer,reviewedAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp(),...(next==='issued'?{couponId:couponRef.id,couponCode:code}:{})});
  tx.update(orderRef,{refundRequestStatus:next,refundDecisionNote:note,...(next==='issued'?{refundCouponId:couponRef.id}:{}),updatedAt:FieldValue.serverTimestamp()});
  tx.create(requestRef.collection('reviews').doc(),{decision:data.decision,note,reviewer,createdAt:FieldValue.serverTimestamp()});
  tx.set(s.db.doc('notifications/'+hash('refund-coupon:'+id+':'+next)),{recipientId:r.customerId,role:'customer',orderId:r.orderId,category:'payments',kind:'refundCoupon',title:next==='issued'?'Your refund coupon is ready':'Refund request reviewed',body:next==='issued'?'Open Coupons to view your private, single-use coupon.':note,read:false,createdAt:FieldValue.serverTimestamp()});
  return {ok:true,...(next==='issued'?{couponId:couponRef.id}:{})};
 });
 return result;
}
