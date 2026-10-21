import { createHmac, timingSafeEqual } from 'node:crypto';

export function signatureMatches(message, signature, secret) {
  if (typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const expected = createHmac('sha256', secret).update(message).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

export class RazorpayPayments {
  constructor({ keyId, keySecret }) { this.keyId = keyId; this.keySecret = keySecret; }
  async request(path, method = 'GET', body, headers = {}) {
    const result = await fetch(`https://api.razorpay.com/v1${path}`, {
      method, headers: { Authorization: `Basic ${Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64')}`,
        'Content-Type': 'application/json', ...headers },
      body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(20000),
    });
    const data = await result.json();
    // Do not return provider payloads or credentials to callers/logs.
    if (!result.ok) throw new Error(`Payment provider request failed (${result.status}).`);
    return data;
  }
  createOrder({ amount, receipt, bookingId }) {
    return this.request('/orders', 'POST', { amount, currency: 'INR', receipt, notes: { wheelioBookingId: bookingId } });
  }
  payment(id) { return this.request(`/payments/${encodeURIComponent(id)}`); }
  orderPayments(id) { return this.request(`/orders/${encodeURIComponent(id)}/payments`); }
  fetchRefund(id) { return this.request(`/refunds/${encodeURIComponent(id)}`); }
  verify({ orderId, paymentId, signature }) { return signatureMatches(`${orderId}|${paymentId}`, signature, this.keySecret); }
  refund({ paymentId, amount, refundId }) {
    return this.request(`/payments/${encodeURIComponent(paymentId)}/refund`, 'POST',
      { amount, notes: { wheelioRefundId: refundId }, receipt: refundId }, { 'X-Refund-Idempotency': refundId });
  }
}
