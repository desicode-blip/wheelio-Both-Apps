import {CouponError} from './coupon-ledger.mjs';
export const earningsPolicy='netGatewayPlusPlatformV1';
export function platformCommission(pricePaise,bps){
 if(!Number.isSafeInteger(pricePaise)||pricePaise<0||!Number.isSafeInteger(bps)||bps<0||bps>10000)throw new CouponError('failed-precondition','The wash commission needs configuration review.');
 return Number((BigInt(pricePaise)*BigInt(bps)+5000n)/10000n);
}
export function capturedEarnings(order,{source,gatewayFeePaise}){
 if(!['netGatewayV1',earningsPolicy].includes(order.captainEarningsPolicy)||order.freeWashUsed)return {};
 const fee=source==='razorpay'?gatewayFeePaise:0,base=order.basePricePaise;
 if(!Number.isSafeInteger(base)||base<0)throw new CouponError('failed-precondition','The wash value needs support review.');
 if(!Number.isSafeInteger(fee)||fee<0||fee>(order.pricePaise??0))throw new CouponError('failed-precondition','The gateway is still confirming its fee. Check the payment again.');
 const commission=order.captainEarningsPolicy===earningsPolicy?platformCommission(base,order.platformFeeBps):0;
 if(base<fee+commission)throw new CouponError('failed-precondition','The wash fees exceed its value. Contact support.');
 return {captainPayPaise:base-fee-commission,gatewayFeePaise:fee,platformFeePaise:commission};
}
