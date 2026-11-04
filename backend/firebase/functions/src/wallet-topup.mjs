import {changeCredits,creditExpiry} from './wallet-credits.mjs';
import {createHash,randomUUID} from 'node:crypto';
import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {acceptsFunding} from './payment-policy.mjs';

export class WalletTopupError extends Error{constructor(code,message){super(message);this.code=code;}}
const fail=(code,message)=>{throw new WalletTopupError(code,message);};
const stamp=()=>FieldValue.serverTimestamp();
const refId=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,100}$/.test(v)?v:fail('invalid-argument','Invalid wallet payment reference.');
const millis=v=>v?.toMillis?.()??0;
const topupRef=(s,value)=>s.db.doc('walletTopups/'+refId(value));
const status=(id,o)=>({topupId:id,amountPaise:o.amountPaise,status:o.status,paymentStatus:o.paymentStatus,refundStatus:o.refundStatus??'none'});

export async function createWalletTopup(s,auth,data){
 const uid=s.actor(auth),requestId=refId(data.requestId),amount=data.amountPaise;
 if(!Number.isSafeInteger(amount)||amount<100||amount>1000000)fail('invalid-argument','Choose an amount from ₹1 to ₹10,000.');
 const id='wt_'+createHash('sha256').update(`${uid}:${requestId}`).digest('hex').slice(0,32),ref=topupRef(s,id),lease=randomUUID();
 const order=await s.db.runTransaction(async tx=>{
  const [old,cfg,profile,state]=await Promise.all([tx.get(ref),tx.get(s.db.doc('config/operations')),tx.get(s.db.doc('users/'+uid)),tx.get(s.db.doc('customerState/'+uid))]);
  const config=cfg.data(),user=profile.data();
  if(!user?.name||user.roles&&!user.roles.includes('customer')||user.deletionStatus||user.deletedRoles?.customer||user.deletingRole==='customer')fail('failed-precondition','Complete your Customer account first.');
  if(!['live','test'].includes(config?.paymentMode)||config.paymentMode==='live'&&config.paymentMerchant!=='washkrew')fail('failed-precondition','Wallet payments are not configured.');
  if(old.exists){
   const o=old.data();if(o.customerId!==uid||o.amountPaise!==amount)fail('failed-precondition','Reopen the original wallet payment before retrying.');
   if(o.paymentStatus==='captured'||o.razorpayOrderId)return o;
   if(millis(o.checkoutLeaseUntil)>s.now())fail('aborted','Your wallet payment is being prepared. Please wait.');
   tx.update(ref,{checkoutLease:lease,checkoutLeaseUntil:Timestamp.fromMillis(s.now()+30000)});return o;
  }
  if(state.data()?.pendingTopupId){
   const pending=await tx.get(topupRef(s,state.data().pendingTopupId));
   if(pending.exists&&pending.data().paymentStatus!=='captured'&&millis(pending.data().paymentExpiresAt)>s.now())fail('already-exists','Check your pending wallet payment before adding more money.');
  }
  const o={customerId:uid,requestId,amountPaise:amount,currency:'INR',paymentMode:config.paymentMode,paymentMerchant:config.paymentMerchant??'trustkeyper',paymentPolicy:'no-credit-card-checkout',status:'pending',paymentStatus:'unpaid',createdAt:Timestamp.fromMillis(s.now()),paymentExpiresAt:Timestamp.fromMillis(s.now()+15*60000),checkoutLease:lease,checkoutLeaseUntil:Timestamp.fromMillis(s.now()+30000)};
  tx.create(ref,o);tx.set(s.db.doc('customerState/'+uid),{pendingTopupId:id},{merge:true});return o;
 });
 if(order.paymentStatus==='captured')return {...status(id,order),paid:true};
 if(millis(order.paymentExpiresAt)<=s.now())fail('failed-precondition','This wallet payment expired. Check its status before starting another.');
 const provider=s.getPayments(order.paymentMode,order.paymentMerchant);
 let providerId=order.razorpayOrderId;
 if(!providerId){
  let created;
  try{created=await provider.createOrder({amount:order.amountPaise,receipt:id,bookingId:id});}
  catch(e){await s.db.runTransaction(async tx=>{const latest=(await tx.get(ref)).data();if(latest?.checkoutLease===lease)tx.update(ref,{checkoutLeaseUntil:Timestamp.fromMillis(0)});});throw e;}
  if(!created.id?.startsWith('order_')||created.amount!==order.amountPaise||created.currency!=='INR')fail('internal','Wallet payment could not be prepared.');
  await s.db.runTransaction(async tx=>{
   const latest=(await tx.get(ref)).data();if(latest.checkoutLease!==lease||latest.razorpayOrderId)fail('aborted','Reopen your wallet payment.');
   tx.update(ref,{razorpayOrderId:created.id,checkoutLeaseUntil:Timestamp.fromMillis(0),nextPaymentCheckAt:Timestamp.fromMillis(s.now()+120000),updatedAt:stamp()});
   tx.create(s.db.doc('paymentOrders/'+created.id),{kind:'walletTopup',topupId:id,customerId:uid,paymentMode:order.paymentMode,paymentMerchant:order.paymentMerchant});
  });providerId=created.id;
 }
 return {topupId:id,purpose:'walletTopup',keyId:provider.keyId,orderId:providerId,amount:order.amountPaise,currency:'INR',testMode:order.paymentMode==='test'};
}

export async function captureWalletTopup(s,payment,mapping,mode,merchant){
 const ref=topupRef(s,mapping.topupId);
 await s.db.runTransaction(async tx=>{
  const snapshot=await tx.get(ref),o=snapshot.data();
  if(!o||o.paymentMode!==mode||o.paymentMerchant!==merchant||payment.order_id!==o.razorpayOrderId||payment.amount!==o.amountPaise||payment.currency!=='INR')fail('permission-denied','Wallet payment does not match.');
  if(o.paymentStatus==='captured'){if(o.razorpayPaymentId!==payment.id)fail('already-exists','This wallet payment is already confirmed.');return;}
  const [wallet,profile,state]=await Promise.all([tx.get(s.walletRef(o.customerId,mode)),tx.get(s.db.doc('users/'+o.customerId)),tx.get(s.db.doc('customerState/'+o.customerId))]);
  const user=profile.data(),allowed=acceptsFunding(payment,o.paymentPolicy)&&!!user&&!user.deletionStatus&&!user.deletedRoles?.customer&&user.deletingRole!=='customer';
  const old=wallet.data()?.creditPaise??0;
  if(allowed&&(!Number.isSafeInteger(old)||old<0||!Number.isSafeInteger(old+o.amountPaise)))fail('failed-precondition','Wallet balance needs support review.');
  tx.update(ref,{paymentStatus:'captured',razorpayPaymentId:payment.id,status:allowed?'credited':'refundPending',refundStatus:allowed?'none':'queued',creditedPaise:allowed?o.amountPaise:0,...(allowed?{creditExpiresAt:Timestamp.fromMillis(creditExpiry(s.now()))}:{}),capturedAt:Timestamp.fromMillis(s.now()),nextPaymentCheckAt:FieldValue.delete(),updatedAt:stamp()});
  if(allowed)tx.set(wallet.ref,{customerId:o.customerId,paymentMode:mode,...changeCredits(wallet.data(),{now:s.now(),addPaise:o.amountPaise}).state,updatedAt:stamp()},{merge:true});
  else tx.create(s.db.doc('refunds/'+mapping.topupId),{topupId:mapping.topupId,customerId:o.customerId,paymentId:payment.id,amount:o.amountPaise,paymentMode:mode,paymentMerchant:merchant,status:'queued',createdAt:stamp()});
  tx.create(s.db.doc('payments/'+mapping.topupId),{customerId:o.customerId,source:'walletTopup',paymentId:payment.id,amount:o.amountPaise,currency:'INR',status:'captured',updatedAt:stamp()});
  if(state.data()?.pendingTopupId===mapping.topupId)tx.set(state.ref,{pendingTopupId:null},{merge:true});
 });
}

export async function checkWalletTopup(s,auth,data,{verify=false,reconcile=false}={}){
 const uid=reconcile?null:s.actor(auth),id=refId(data.topupId),ref=topupRef(s,id),o=(await ref.get()).data();
 if(!o||!reconcile&&o.customerId!==uid)fail('permission-denied','This wallet payment is not yours.');
 const provider=s.getPayments(o.paymentMode,o.paymentMerchant);
 if(verify){
  const paymentId=refId(data.paymentId);
  if(data.orderId!==o.razorpayOrderId||!provider.verify({orderId:o.razorpayOrderId,paymentId,signature:data.signature}))fail('permission-denied','Wallet payment verification failed.');
  await s.capturePayment(await provider.payment(paymentId),o.paymentMode,o.paymentMerchant);
 }else if(o.razorpayOrderId&&o.paymentStatus!=='captured'){
  const result=await provider.orderPayments(o.razorpayOrderId);
  for(const payment of result.items??[])if(payment.status==='captured')await s.capturePayment(payment,o.paymentMode,o.paymentMerchant);
 }
 const latest=(await ref.get()).data();
 if(reconcile&&latest.paymentStatus!=='captured')await ref.update({nextPaymentCheckAt:s.now()-millis(o.createdAt)>2*86400000?FieldValue.delete():Timestamp.fromMillis(s.now()+300000)});
 return status(id,latest);
}
