import {createHash} from 'node:crypto';
import {CouponError,normalizeCouponCode,couponValue,reserveCouponValue,completeCouponReservation} from './coupon-ledger.mjs';
const fail=(code,message)=>{throw new CouponError(code,message);};
export const couponId=code=>createHash('sha256').update(normalizeCouponCode(code)).digest('hex');
async function requireCustomer(s,auth){
 const uid=s.actor(auth),p=(await s.db.doc('users/'+uid).get()).data();
 if(!p||!p.roles?.includes('customer')||p.deletionStatus||p.deletedRoles?.customer||p.deletingRole==='customer')fail('permission-denied','Complete your Customer account before using coupons.');
 return uid;
}
function present(doc,now){
 const o=doc.data(),s=couponValue({...o,expiresAt:o.expiresAt?.toMillis?.()},now);
 return {id:doc.id,code:o.code,availablePaise:s.availablePaise,reservedPaise:s.reservedPaise,spentPaise:s.spentPaise,
  faceValuePaise:s.faceValuePaise,expiresAt:s.expiresAt,status:o.status==='active'?(s.expiresAt<=now?'expired':s.availablePaise>0?'available':s.reservedPaise>0?'reserved':'used'):o.status,
  issuedAt:o.issuedAt?.toMillis?.()??null,sourceRequestId:o.sourceRequestId??null};
}
export async function previewCoupon(s,auth,data){
 const uid=await requireCustomer(s,auth),code=normalizeCouponCode(data.code);
 const [doc,cfg]=await Promise.all([s.db.doc('coupons/'+couponId(code)).get(),s.db.doc('config/operations').get()]);
 const o=doc.data(),config=cfg.data();
 if(!o||o.customerId!==uid||o.paymentMode!==config?.paymentMode)fail('not-found','This coupon is unavailable for your account.');
 const type=config.vehicleTypes?.find(v=>v.kind===data.vehicleKind&&v.active!==false);
 if(!type||!Number.isSafeInteger(type.pricePaise)||type.pricePaise<100)fail('failed-precondition','Review the current wash price.');
 const value=reserveCouponValue({...o,expiresAt:o.expiresAt?.toMillis?.()},{now:s.now(),pricePaise:type.pricePaise});
 return {...present(doc,s.now()),appliedPaise:value.amountPaise,cashDuePaise:value.cashDuePaise,forfeitPaise:value.forfeitPaise,vehicleKind:type.kind,basePricePaise:type.pricePaise};
}

// Read first; the caller invokes write() only after every transaction read is
// complete. Booking creation and coupon reservation share one atomic commit.
export async function prepareCouponReservation(s,tx,{customerId,bookingId,code,pricePaise,paymentMode,expectedPaise,acceptedForfeitPaise}){
 const normalized=normalizeCouponCode(code),ref=s.db.doc('coupons/'+couponId(normalized)),snapshot=await tx.get(ref),o=snapshot.data();
 if(!o||o.customerId!==customerId||o.paymentMode!==paymentMode)fail('not-found','This coupon is unavailable for your account.');
 const reservationRef=s.db.doc('couponReservations/'+bookingId),existing=await tx.get(reservationRef);
 if(existing.exists)fail('failed-precondition','Reopen the original booking to continue its coupon reservation.');
 const value=reserveCouponValue({...o,expiresAt:o.expiresAt?.toMillis?.()},{now:s.now(),pricePaise});
 if(expectedPaise!==undefined&&expectedPaise!==value.amountPaise)fail('failed-precondition','The coupon value changed. Apply it again before paying.');
 if(value.forfeitPaise>0&&acceptedForfeitPaise!==value.forfeitPaise)fail('failed-precondition','Review and confirm the unused coupon value that will be lost before paying.');
 return {...value,couponId:ref.id,code:normalized,write(){
  tx.update(ref,{availablePaise:value.coupon.availablePaise,reservedPaise:value.coupon.reservedPaise,expiredPaise:value.coupon.expiredPaise});
  tx.create(reservationRef,{customerId,bookingId,couponId:ref.id,amountPaise:value.amountPaise,heldPaise:value.heldPaise,forfeitPaise:value.forfeitPaise,status:'reserved',expiresAt:o.expiresAt});
 }};
}

export async function prepareCompleteCoupon(s,tx,bookingId,order,{captured}){
 if(!(order.couponReservedPaise>0))return null;
 const ref=s.db.doc('couponReservations/'+bookingId),snapshot=await tx.get(ref),r=snapshot.data();
 if(!r||r.customerId!==order.customerId||r.couponId!==order.couponId||r.amountPaise!==order.couponReservedPaise)fail('failed-precondition','This coupon reservation needs support review.');
 if(r.status!=='reserved')return {released:r.status==='released',write(){}};
 const couponRef=s.db.doc('coupons/'+r.couponId),o=(await tx.get(couponRef)).data();
 if(!o||o.customerId!==order.customerId||o.paymentMode!==order.paymentMode||o.expiresAt?.toMillis?.()!==r.expiresAt?.toMillis?.())fail('failed-precondition','The coupon reservation could not be confirmed.');
 const next=completeCouponReservation({...o,expiresAt:o.expiresAt?.toMillis?.()},{now:s.now(),amountPaise:r.heldPaise??r.amountPaise,captured});
 return {released:!captured,write(){
  tx.update(couponRef,{availablePaise:next.availablePaise,reservedPaise:next.reservedPaise,spentPaise:next.spentPaise,expiredPaise:next.expiredPaise});
  tx.update(ref,{status:captured?'captured':'released'});
 }};
}
