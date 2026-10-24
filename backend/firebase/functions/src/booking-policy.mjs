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
  if (p?.kind !== 'wallet') return { kind: 'refund' };
  if (!Number.isSafeInteger(p.freeWashMinutes) || p.freeWashMinutes < 0 || p.freeWashMinutes > 60 ||
      !Number.isSafeInteger(p.lateCreditBps) || p.lateCreditBps < 0 || p.lateCreditBps > 10000) {
    throw new Error('Cancellation policy is not configured.');
  }
  return { kind: 'wallet', freeWashMinutes: p.freeWashMinutes, lateCreditBps: p.lateCreditBps };
}

export function cancellationBenefit(order, now) {
  const p = order.cancellationPolicy ?? { kind: 'refund' };
  if (p.kind !== 'wallet' || order.paymentStatus !== 'captured') return null;
  // An entirely wallet-funded booking restores its original entitlement; it
  // cannot manufacture another free wash or additional credit by cancellation.
  if (order.pricePaise === 0) return { kind: 'walletRestored', freeWashes: 0, creditPaise: 0 };
  const created = order.createdAt?.toMillis?.() ?? now;
  if (now - created <= p.freeWashMinutes * 60000) return { kind: 'freeWash', freeWashes: 1, creditPaise: 0 };
  return { kind: 'credit', freeWashes: 0, creditPaise: Math.round(order.pricePaise * p.lateCreditBps / 10000 / 100) * 100 };
}

export function worksWindow(captain, window) {
  return !captain.workingWindows?.length || captain.workingWindows.some(w => w.startHour <= window.startHour && w.endHour >= window.endHour);
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
