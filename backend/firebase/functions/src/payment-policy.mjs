// Provider-derived funding only. Never trust the client's selected payment label.
export function acceptsFunding(payment,policy){
  if(!['no-credit-cards','no-credit-card-checkout'].includes(policy))return true; // Preserve historical obligations.
  if(payment.method==='card')return payment.card?.type==='debit';
  if(payment.method==='upi')return policy==='no-credit-card-checkout'||payment.upi?.payer_account_type==='bank_account';
  return payment.method==='netbanking'||(policy==='no-credit-card-checkout'&&payment.method==='wallet');
}
