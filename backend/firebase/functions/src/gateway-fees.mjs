// Razorpay computes the method-specific fee and displays the total before the
// customer authorises payment. Never guess a merchant percentage in the app.
export const walletFeePolicy='customerAtTopupV1';
export function customerTopupFees() {
 return {label:'Payment gateway fee',message:'Gateway fee is added once. The order amount becomes usable wallet credit.',
  rules:['card','upi','netbanking','wallet'].map(method=>({method,fee:{payee:'customer',percentage_value:'100'}}))};
}
export function confirmsCustomerFees(config) {
 return customerTopupFees().rules.every(rule=>config?.rules?.some(r=>r.method===rule.method&&r.fee?.payee==='customer'&&r.fee?.percentage_value==='100'));
}
export function topupFunding(order,payment) {
 const dynamic=order.feePolicy===walletFeePolicy,credit=order.amountPaise,paid=payment.amount;
 if(!Number.isSafeInteger(paid)||paid<credit)return null;
 if(!dynamic)return paid===credit?{creditPaise:credit,paidPaise:paid}:null;
 // `fee` already includes GST. `tax` is its component, not a second fee.
 const fee=payment.fee;
 if(!Number.isSafeInteger(fee)||fee<0||paid-fee!==credit)return null;
 return {creditPaise:credit,paidPaise:paid,gatewayFeePaise:fee};
}
