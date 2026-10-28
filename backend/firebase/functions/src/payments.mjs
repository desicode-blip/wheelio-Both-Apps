import { createHmac, timingSafeEqual } from 'node:crypto';

// Provider descriptions/payloads can contain payment or personal details.
// Persist only this bounded error category and HTTP status for operations.
export class PaymentProviderError extends Error {
  constructor(status, code) {
    super(`Payment provider request failed (${status}).`);
    this.name = 'PaymentProviderError';
    this.status = status;
    this.code = ['BAD_REQUEST_ERROR', 'SERVER_ERROR', 'GATEWAY_ERROR', 'AUTHENTICATION_ERROR', 'RATE_LIMIT_EXCEEDED'].includes(code) ? code : 'PROVIDER_ERROR';
  }
}

export function signatureMatches(message, signature, secret) {
  if (typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const expected = createHmac('sha256', secret).update(message).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

export class RazorpayPayments {
  constructor({ keyId, keySecret, fetchImpl = fetch }) { this.keyId = keyId; this.keySecret = keySecret; this.fetch = fetchImpl; }
  async request(path, method = 'GET', body, headers = {}) {
    let result;
    try { result = await this.fetch(`https://api.razorpay.com/v1${path}`, {
      method, headers: { Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
        'Content-Type': 'application/json', ...headers },
      body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(20000),
    }); } catch { throw new PaymentProviderError(0); }
    const data = await result.json().catch(() => null);
    // Do not return provider payloads or credentials to callers/logs.
    if (!result.ok || !data) throw new PaymentProviderError(result.ok ? 502 : result.status, data?.error?.code);
    return data;
  }
  createOrder({ amount, receipt, bookingId, checkoutConfigId }) {
    return this.request('/orders', 'POST', { amount, currency: 'INR', receipt, ...(checkoutConfigId?{checkout_config_id:checkoutConfigId}:{}), notes: { wheelioBookingId: bookingId } });
  }
  async payment(id) {
    const payment=await this.request(`/payments/${encodeURIComponent(id)}`);
    if(payment.method==='card'&&!payment.card?.type)payment.card=await this.request(`/payments/${encodeURIComponent(id)}/card`);
    return payment;
  }
  async orderPayments(id) {
    const result=await this.request(`/orders/${encodeURIComponent(id)}/payments`);
    if(Array.isArray(result.items))result.items=await Promise.all(result.items.map(p=>p.status==='captured'&&p.method==='card'&&!p.card?.type?this.payment(p.id):p));
    return result;
  }
  fetchRefund(id) { return this.request(`/refunds/${encodeURIComponent(id)}`); }
  async findRefund({ paymentId, refundId }) {
    // A process can die after Razorpay accepts a POST but before Firestore gets
    // the ID. Recover that refund before sending the same idempotent request.
    for (let skip = 0; skip < 1000; skip += 100) {
      const page = await this.request(`/payments/${encodeURIComponent(paymentId)}/refunds?count=100&skip=${skip}`);
      if (!Array.isArray(page.items)) throw new PaymentProviderError(502);
      const found = page.items.find(r => r.receipt === refundId || r.notes?.wheelioRefundId === refundId);
      if (found) return found;
      if (page.items.length < 100) return null;
    }
    throw new PaymentProviderError(502);
  }
  verify({ orderId, paymentId, signature }) { return signatureMatches(`${orderId}|${paymentId}`, signature, this.keySecret); }
  refund({ paymentId, amount, refundId }) {
    return this.request(`/payments/${encodeURIComponent(paymentId)}/refund`, 'POST',
      { amount, notes: { wheelioRefundId: refundId }, receipt: refundId }, { 'X-Refund-Idempotency': refundId });
  }
}
