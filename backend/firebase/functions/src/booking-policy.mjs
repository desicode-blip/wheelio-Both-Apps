// Server-only booking arithmetic, in integer paise. Existing orders retain
// their original cancellation policy when an operator changes the catalog.
export function walletPrice(basePrice, wallet, { useFreeWash = false, useCredit = false } = {}) {
  const free = Number.isSafeInteger(wallet?.freeWashes) ? Math.max(0, wallet.freeWashes) : 0;
  const balance = Number.isSafeInteger(wallet?.creditPaise) ? Math.max(0, wallet.creditPaise) : 0;
  if (useFreeWash && free > 0) return { pricePaise: 0, freeWashUsed: true, creditUsedPaise: 0 };
  let used = useCredit ? Math.min(balance, basePrice) : 0;
  // Razorpay's minimum amount is INR 1. Keep unused credit in the wallet.
  if (basePrice - used > 0 && basePrice - used < 100) used = Math.max(0, basePrice - 100);
  return { pricePaise: basePrice - used, freeWashUsed: false, creditUsedPaise: used };
}

export function cancellationPolicy(config) {
  const p = config?.cancellationPolicy;
  if (p?.kind === 'refundThenCredit') {
    if (!Number.isSafeInteger(p.refundMinutes) || p.refundMinutes < 0 || p.refundMinutes > 60 ||
        !Number.isSafeInteger(p.lateCreditBps) || p.lateCreditBps < 0 || p.lateCreditBps > 10000) {
      throw new Error('Cancellation policy is not configured.');
    }
    return {kind:'refundThenCredit',refundMinutes:p.refundMinutes,lateCreditBps:p.lateCreditBps};
  }
  if (p?.kind !== 'wallet') return { kind: 'refund' };
  if (!Number.isSafeInteger(p.freeWashMinutes) || p.freeWashMinutes < 0 || p.freeWashMinutes > 60 ||
      !Number.isSafeInteger(p.lateCreditBps) || p.lateCreditBps < 0 || p.lateCreditBps > 10000) {
    throw new Error('Cancellation policy is not configured.');
  }
  return { kind: 'wallet', freeWashMinutes: p.freeWashMinutes, lateCreditBps: p.lateCreditBps };
}

export function cancellationBenefit(order, now) {
  const p = order.cancellationPolicy ?? { kind: 'refund' };
  if (p.kind === 'refundThenCredit' && order.paymentStatus === 'captured') {
    // Existing promotional free-wash entitlements are restored, never converted
    // into spendable money or multiplied by cancelling a free booking.
    if (order.freeWashUsed) return {kind:'walletRestored',freeWashes:0,creditPaise:0,cashRefundPaise:0,feePaise:0};
    const cash=order.pricePaise,credit=order.creditUsedPaise??0,total=cash+credit;
    const start=(order.bookedAt??order.createdAt)?.toMillis?.()??now;
    if(now-start<=p.refundMinutes*60000) return {kind:'refund',freeWashes:0,creditPaise:credit,cashRefundPaise:cash,feePaise:0,restoreReserved:false};
    const returned=Math.floor(total*p.lateCreditBps/10000);
    return {kind:'credit',freeWashes:0,creditPaise:returned,cashRefundPaise:0,feePaise:total-returned,restoreReserved:false};
  }
  if (p.kind !== 'wallet' || order.paymentStatus !== 'captured') return null;
  // An entirely wallet-funded booking restores its original entitlement; it
  // cannot manufacture another free wash or additional credit by cancellation.
  if (order.pricePaise === 0) return { kind: 'walletRestored', freeWashes: 0, creditPaise: 0 };
  const created = order.createdAt?.toMillis?.() ?? now;
  if (now - created <= p.freeWashMinutes * 60000) return { kind: 'freeWash', freeWashes: 1, creditPaise: 0 };
  return { kind: 'credit', freeWashes: 0, creditPaise: Math.round(order.pricePaise * p.lateCreditBps / 10000 / 100) * 100 };
}

export function worksWindow(captain, window, notBeforeMinute = window.startHour * 60) {
  const start = Math.max(window.startHour * 60, notBeforeMinute);
  if (start >= window.endHour * 60) return false;
  // Exact preferences are minutes from midnight. A window may ring when it
  // overlaps a work period; the Captain still chooses whether to accept it.
  if (Array.isArray(captain.workingSlots)) return !captain.workingSlots.length ||
    captain.workingSlots.some(s => s.startMinute < window.endHour * 60 && s.endMinute > start);
  return !captain.workingWindows?.length || captain.workingWindows.some(w => w.startHour <= window.startHour && w.endHour >= window.endHour);
}

export function normalizeWorkingSlots(slots) {
  if (!Array.isArray(slots) || slots.length > 4 || slots.some(s =>
    !Number.isInteger(s?.startMinute) || !Number.isInteger(s?.endMinute) ||
    s.startMinute < 240 || s.endMinute > 1320 || s.endMinute - s.startMinute < 60 ||
    s.startMinute % 30 || s.endMinute % 30)) return null;
  const out = [];
  for (const s of [...slots].sort((a,b) => a.startMinute - b.startMinute)) {
    const last = out.at(-1);
    if (last && s.startMinute <= last.endMinute) last.endMinute = Math.max(last.endMinute, s.endMinute);
    else out.push({startMinute:s.startMinute,endMinute:s.endMinute});
  }
  return out;
}

export function windowTimes(day, window) {
  return {
    start: Date.parse(`${day}T${String(window.startHour).padStart(2, '0')}:00:00+05:30`),
    end: Date.parse(`${day}T${String(window.endHour).padStart(2, '0')}:00:00+05:30`),
  };
}

export function normalizedAddress(address) {
  return [address.name, address.area, address.city, address.pincode]
    .map(v => String(v ?? '').trim().toLowerCase().replace(/\s+/g, ' ')).join('|');
}
