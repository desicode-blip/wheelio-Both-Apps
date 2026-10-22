import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';
import { RazorpayPayments, signatureMatches } from './payments.mjs';
import { WheelioService, ServiceError } from './service.mjs';

initializeApp();
// These controllers mostly wait for Firestore, Storage and Razorpay. Fractional
// CPU keeps the web rollout within the new project's regional CPU quota.
setGlobalOptions({ region: 'asia-south1', maxInstances: 5, minInstances: 0, memory: '256MiB', cpu: 'gcf_gen1', concurrency: 1, timeoutSeconds: 60 });
const keyId = defineSecret('RAZORPAY_KEY_ID'), keySecret = defineSecret('RAZORPAY_KEY_SECRET'), webhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');
const db = getFirestore();
function service(withPayment = false) {
  return new WheelioService({ db,
    payments: withPayment ? new RazorpayPayments({ keyId: keyId.value(), keySecret: keySecret.value() }) : null,
    evidence: {
      async exists(path) { const [exists] = await getStorage().bucket().file(path).exists(); return exists; },
      async metadata(path) { const [metadata] = await getStorage().bucket().file(path).getMetadata(); return metadata; },
    },
  });
}
const cors = ['https://wheelio-apps.web.app', 'https://wheelio-apps.firebaseapp.com', /^http:\/\/(localhost|127\.0\.0\.1):\d+$/];
function callable(method, payment = false) {
  // Domain-restricted sharing forbids allUsers IAM bindings. The owner-only
  // configure-api-access operation enables the HTTP gateway after deployment;
  // Firebase ID tokens and service authorization below remain mandatory.
  return onCall({ cors, invoker: 'private', ...(payment ? { secrets: [keyId, keySecret] } : {}) }, async request => {
    try { return await service(payment)[method](request.auth, request.data ?? {}); }
    catch (error) {
      if (error instanceof ServiceError) throw new HttpsError(error.code, error.message);
      logger.error('Wheelio operation failed', { operation: method, code: error.code ?? 'internal' });
      throw new HttpsError('internal', 'This action could not be completed. Please try again.');
    }
  });
}
export const registerAccount = callable('register');
export const getAvailability = callable('availability');
export const createBooking = callable('createBooking');
export const createCheckout = callable('checkout', true);
export const verifyPayment = callable('verifyPayment', true);
export const checkPayment = callable('checkPayment', true);
export const setCaptainOnline = callable('captainOnline');
export const submitCaptainApplication = callable('submitCaptainApplication');
export const claimJob = callable('claim');
export const rejectJob = callable('reject');
export const updateWashProgress = callable('progress');
export const recordWashEvidence = callable('evidenceUploaded');
export const recordCustomerPhoto = callable('customerPhoto');
export const updateCaptainLocation = callable('location');
export const approveWash = callable('approve');
export const rateWash = callable('rate');
export const cancelBooking = callable('cancel');
export const reportWashProblem = callable('reportProblem');

export const razorpayWebhook = onRequest({ secrets: [keyId, keySecret, webhookSecret], invoker: 'private', cors: false }, async (request, response) => {
  if (request.method !== 'POST') { response.status(405).send('POST required'); return; }
  if (!signatureMatches(request.rawBody, request.get('x-razorpay-signature'), webhookSecret.value())) { response.status(401).send('Invalid signature'); return; }
  const event = request.body;
  try {
    if (event.event === 'payment.captured' || event.event === 'order.paid') {
      const paymentId = event.payload?.payment?.entity?.id;
      if (!paymentId) { response.status(400).send('Missing payment'); return; }
      // Fetch the payment independently; never treat a browser callback or
      // an unsigned/deserialized event field as proof of capture.
      const backend = service(true);
      await backend.captureWebhookPayment(paymentId);
    } else if (event.event === 'refund.processed') {
      const refund = event.payload?.refund?.entity;
      if (!refund?.id) { response.status(400).send('Missing refund'); return; }
      const pending = await db.collection('refunds').where('providerRefundId', '==', refund.id).limit(1).get();
      if (!pending.empty) {
        const r = pending.docs[0];
        if (refund.payment_id !== r.data().paymentId || refund.amount !== r.data().amount) { response.status(400).send('Refund mismatch'); return; }
        const backend = service(true);
        await backend.applyRefund(r.id, await backend.payments.fetchRefund(refund.id));
      }
    }
    response.status(200).send('OK');
  } catch (error) { logger.error('Payment webhook failed', { code: error.code ?? 'internal', event: event.event }); response.status(500).send('Retry later'); }
});

export const dispatchPaidBooking = onDocumentUpdated('orders/{orderId}', async event => {
  if (event.data.after.data().status === 'searching') await service().dispatch(event.params.orderId);
});
export const refundCancelledBooking = onDocumentCreated({ document: 'refunds/{orderId}', secrets: [keyId, keySecret], retry: true },
  event => service(true).processRefund(event.params.orderId));

export const maintainBookings = onSchedule({ schedule: 'every 5 minutes', timeoutSeconds:300, secrets: [keyId, keySecret] }, async () => {
  const backend = service(true), now = Date.now();
  const due=await db.collection('orders').where('nextPaymentCheckAt','<=',new Date(now)).orderBy('nextPaymentCheckAt').limit(20).get();
  for(const doc of due.docs) {
    try { await backend.reconcilePayment(doc.id); }
    catch(error) { logger.error('Scheduled payment reconciliation failed',{bookingId:doc.id,code:error.code??'provider'}); }
  }
  const searching = await db.collection('orders').where('status', '==', 'searching').limit(200).get();
  for (const doc of searching.docs) {
    try { await backend.dispatch(doc.id); }
    catch (error) { logger.error('Scheduled dispatch failed', { bookingId: doc.id, code: error.code ?? 'internal' }); }
  }
  const retries = await db.collection('refunds').where('status', 'in', ['queued', 'retry', 'processing', 'submitted']).limit(50).get();
  for (const doc of retries.docs) {
    // A provider outage for one refund must not block other refunds or expiry.
    try { await backend.processRefund(doc.id); }
    catch (error) { logger.error('Scheduled refund failed', { bookingId: doc.id, code: error.code ?? 'provider' }); }
  }
  const pending = await db.collection('orders').where('status', '==', 'pendingPayment').limit(200).get();
  for (const doc of pending.docs) {
    if (doc.data().paymentExpiresAt.toMillis() < now) await db.runTransaction(async tx => {
      const fresh = await tx.get(doc.ref);
      if (fresh.data().status === 'pendingPayment') tx.update(doc.ref, { status: 'cancelled', cancellationReason: 'paymentExpired' });
    });
  }
  const stalled = await db.collection('orders').where('status', 'in', ['searching', 'onTheWay']).limit(200).get();
  for (const doc of stalled.docs) if (doc.data().slotEnd.toMillis() < now) {
    const o = doc.data();
    try { await backend.cancel({uid:o.customerId},{orderId:doc.id},{expired:true}); }
    catch(error) { if (!(error instanceof ServiceError)) throw error; }
  }
});
