import {randomBytes} from 'node:crypto';
import {FieldValue,Timestamp} from 'firebase-admin/firestore';
import {walletCredits,creditExpiry} from './wallet-credits.mjs';
import {couponId} from './refund-coupons.mjs';
import {CouponError} from './coupon-ledger.mjs';

// Convert existing server-owned value, never create a test/promotion entitlement.
// Source grants, amounts and original expiry are retained in a private audit.
export async function migrateLegacyValue(s,uid,mode=null){
 const config=(await s.db.doc('config/operations').get()).data();
 if(config?.paymentBalanceMode!=='refundCouponsV1'||config.refundCouponsReady!==true)return {converted:0};
 mode??=config.paymentMode;
 if(!['test','live'].includes(mode))throw new CouponError('failed-precondition','The payment mode is not configured.');
 return s.db.runTransaction(async tx=>{
  const ref=s.walletRef(uid,mode),userRef=s.db.doc('users/'+uid),[snapshot,user]=await Promise.all([tx.get(ref),tx.get(userRef)]);
  const original=snapshot.data(),profile=user.data();
  if(!original||!profile||!profile.roles?.includes('customer')||profile.deletedRoles?.customer||profile.deletingRole==='customer'||profile.deletionStatus)return {converted:0};
  const value=walletCredits(original,s.now(),config.walletExpiryStartedAt?.toMillis?.()??s.now()),free=original.freeWashes??0;
  if(!Number.isSafeInteger(free)||free<0||value.creditLots.length+free>400)throw new CouponError('failed-precondition','Existing prepaid value needs an operations review before conversion.');
  if(value.creditPaise===0&&free===0)return {converted:0};
  const types=(config.vehicleTypes??[]).filter(v=>v.active!==false&&Number.isSafeInteger(v.pricePaise)&&v.pricePaise>0);
  const promotionValue=types.length?Math.max(...types.map(v=>v.pricePaise)):0;
  if(free&&!promotionValue)throw new CouponError('failed-precondition','Existing free washes need a valid service catalog before conversion.');
  const grants=[...value.creditLots.map(l=>({amountPaise:l.amountPaise,expiresAt:l.expiresAt,source:'legacyPrepaidValue'})),...Array.from({length:free},()=>({amountPaise:promotionValue,expiresAt:creditExpiry(s.now()),source:'legacyFreeWash'}))];
  const sequence=(original.couponMigrationSequence??0)+1,ids=[];
  for(const grant of grants){
   const hex=randomBytes(8).toString('hex').toUpperCase(),code=`WK-${hex.slice(0,8)}-${hex.slice(8)}`,id=couponId(code);ids.push(id);
   tx.create(s.db.doc('coupons/'+id),{code,customerId:uid,paymentMode:mode,status:'active',faceValuePaise:grant.amountPaise,availablePaise:grant.amountPaise,reservedPaise:0,spentPaise:0,expiredPaise:0,
    useRule:'singleUse',unusedRule:'forfeit',issuedAt:Timestamp.fromMillis(s.now()),expiresAt:Timestamp.fromMillis(grant.expiresAt),source:grant.source,sourceMigrationId:ref.id+'_'+sequence});
  }
  tx.create(s.db.doc('couponMigrations/'+ref.id+'_'+sequence),{customerId:uid,paymentMode:mode,sourceCreditPaise:value.creditPaise,sourceFreeWashes:free,sourceCreditLots:value.creditLots,couponIds:ids,createdAt:FieldValue.serverTimestamp()});
  tx.set(ref,{creditPaise:0,creditLots:[],creditLotVersion:1,freeWashes:0,nextExpiryAt:null,expiredCreditPaise:value.expiredCreditPaise,couponMigrationSequence:sequence,couponMigratedAt:FieldValue.serverTimestamp()},{merge:true});
  return {converted:ids.length,prepaidPaise:value.creditPaise,freeWashes:free};
 });
}

// Payment/booking confirmation has already committed. An unrelated legacy
// conversion issue must not turn a captured checkout into a false failure.
export async function migrateAfterCommit(s,uid,mode){
 try{return await migrateLegacyValue(s,uid,mode);}
 catch{
  await s.db.doc('couponMigrationIssues/'+uid+'_'+mode).set({customerId:uid,paymentMode:mode,status:'needsReview',updatedAt:FieldValue.serverTimestamp()},{merge:true}).catch(()=>{});
  return {needsReview:true};
 }
}
