// Integer-paise credit lots. The wallet document is the transaction lock; no
// client can create, extend or spend a lot independently of the balance.
export function creditExpiry(at) {
  const d=new Date(at),month=d.getUTCMonth();
  d.setUTCFullYear(d.getUTCFullYear()+1);
  if(d.getUTCMonth()!==month)d.setUTCDate(0); // 29 February -> 28 February.
  return d.getTime();
}
export function walletCredits(input={},now=Date.now(),legacyStart=now) {
  const balance=input.creditPaise??0;
  if(!Number.isSafeInteger(balance)||balance<0)throw Error('Wallet balance needs support review.');
  let lots=input.creditLots;
  if(input.creditLotVersion!==1)lots=balance?[{amountPaise:balance,addedAt:legacyStart,expiresAt:creditExpiry(legacyStart)}]:[];
  if(!Array.isArray(lots)||lots.some(l=>!Number.isSafeInteger(l.amountPaise)||l.amountPaise<=0||!Number.isSafeInteger(l.addedAt)||!Number.isSafeInteger(l.expiresAt)||l.expiresAt<=l.addedAt)||lots.reduce((n,l)=>n+l.amountPaise,0)!==balance)throw Error('Wallet credits need support review.');
  const expired=lots.filter(l=>l.expiresAt<=now).reduce((n,l)=>n+l.amountPaise,0);
  lots=lots.filter(l=>l.expiresAt>now).map(l=>({...l})).sort((a,b)=>a.expiresAt-b.expiresAt||a.addedAt-b.addedAt);
  return {creditLotVersion:1,creditLots:lots,creditPaise:balance-expired,expiredCreditPaise:(input.expiredCreditPaise??0)+expired,nextExpiryAt:lots[0]?.expiresAt??null};
}
export function changeCredits(input,{now,legacyStart=now,addPaise=0,spendPaise=0,restoreLots=[]}) {
  const state=walletCredits(input,now,legacyStart),spent=[];
  if(!Number.isSafeInteger(addPaise)||addPaise<0||!Number.isSafeInteger(spendPaise)||spendPaise<0||spendPaise>state.creditPaise||!Number.isSafeInteger(state.creditPaise+addPaise))throw Error('Wallet amount needs support review.');
  let need=spendPaise;
  for(const lot of state.creditLots){const n=Math.min(need,lot.amountPaise);if(n)spent.push({...lot,amountPaise:n});lot.amountPaise-=n;need-=n;}
  state.creditLots=state.creditLots.filter(l=>l.amountPaise);
  for(const lot of restoreLots){
    if(!Number.isSafeInteger(lot.amountPaise)||lot.amountPaise<=0||!Number.isSafeInteger(lot.addedAt)||!Number.isSafeInteger(lot.expiresAt))throw Error('Reserved wallet credits need support review.');
    if(lot.expiresAt>now)state.creditLots.push({...lot});else state.expiredCreditPaise+=lot.amountPaise;
  }
  if(addPaise)state.creditLots.push({amountPaise:addPaise,addedAt:now,expiresAt:creditExpiry(now)});
  // Coalesce only identical grant/expiry timestamps; spending never extends life.
  const merged=new Map();for(const l of state.creditLots){const key=l.addedAt+':'+l.expiresAt;const old=merged.get(key);if(old)old.amountPaise+=l.amountPaise;else merged.set(key,l);}
  state.creditLots=[...merged.values()].sort((a,b)=>a.expiresAt-b.expiresAt||a.addedAt-b.addedAt);
  state.creditPaise=state.creditLots.reduce((n,l)=>n+l.amountPaise,0);
  state.nextExpiryAt=state.creditLots[0]?.expiresAt??null;
  return {state,spent};
}
