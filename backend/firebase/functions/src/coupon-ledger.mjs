// Private, owner-bound service coupons. All amounts are integer paise. There is
// no wallet/top-up balance, client-issued value or cash withdrawal operation.
export class CouponError extends Error {
 constructor(code,message){super(message);this.code=code;}
}
const fail=(message)=>{throw new CouponError('failed-precondition',message);};
const money=n=>Number.isSafeInteger(n)&&n>=0;
export function normalizeCouponCode(value){
 if(typeof value!=='string')throw new CouponError('invalid-argument','Enter a valid coupon code.');
 const code=value.trim().toUpperCase().replaceAll(' ','');
 if(!/^WK-[A-F0-9]{8}-[A-F0-9]{8}$/.test(code))throw new CouponError('invalid-argument','Enter a valid coupon code.');
 return code;
}
export function couponValue(input,now){
 const {faceValuePaise,availablePaise,reservedPaise=0,spentPaise=0,expiredPaise=0}=input;
 if(![faceValuePaise,availablePaise,reservedPaise,spentPaise,expiredPaise].every(money)||faceValuePaise!==availablePaise+reservedPaise+spentPaise+expiredPaise||!Number.isSafeInteger(input.expiresAt))fail('This coupon needs support review.');
 const expired=input.expiresAt<=now?availablePaise:0;
 return {...input,availablePaise:availablePaise-expired,reservedPaise,spentPaise,expiredPaise:expiredPaise+expired};
}
export function reserveCouponValue(input,{now,pricePaise}){
 if(!money(pricePaise)||pricePaise<=0)fail('Review the wash price before applying a coupon.');
 const coupon=couponValue(input,now);
 if(coupon.status!=='active'||coupon.availablePaise<=0)fail('This coupon has no usable value or has expired.');
 if(coupon.useRule!=='singleUse'||coupon.unusedRule!=='forfeit')fail('This coupon needs support review.');
 const heldPaise=coupon.availablePaise,amountPaise=Math.min(pricePaise,heldPaise),cashDuePaise=pricePaise-amountPaise;
 if(cashDuePaise>0&&cashDuePaise<100)fail('This coupon leaves less than the ₹1 gateway minimum. Choose another wash; the coupon has not been used.');
 return {coupon:{...coupon,availablePaise:0,reservedPaise:coupon.reservedPaise+heldPaise},amountPaise,heldPaise,forfeitPaise:heldPaise-amountPaise,cashDuePaise};
}
export function completeCouponReservation(input,{now,amountPaise,captured}){
 const coupon=couponValue(input,now);
 if(!money(amountPaise)||amountPaise<=0||amountPaise>coupon.reservedPaise)fail('The coupon reservation needs support review.');
 return {...coupon,reservedPaise:coupon.reservedPaise-amountPaise,
  spentPaise:coupon.spentPaise+(captured?amountPaise:0),
  availablePaise:coupon.availablePaise+(!captured&&coupon.expiresAt>now?amountPaise:0),
  expiredPaise:coupon.expiredPaise+(!captured&&coupon.expiresAt<=now?amountPaise:0)};
}
