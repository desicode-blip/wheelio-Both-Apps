import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getAuth } from 'firebase-admin/auth';
import { ZipFile } from 'yazl';
import { receiptPdf, evidenceFiles } from './documents.mjs';
import { createHash } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { orderNotices, pushDelivery } from './notifications.mjs';
import { getStorage } from 'firebase-admin/storage';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';
import { RazorpayPayments, signatureMatches } from './payments.mjs';
import { WashKrewService, ServiceError } from './service.mjs';

initializeApp();
// These controllers mostly wait for Firestore, Storage and Razorpay. Fractional
// CPU keeps the web rollout within the new project's regional CPU quota.
setGlobalOptions({ region: 'asia-south1', maxInstances: 5, minInstances: 0, memory: '256MiB', cpu: 'gcf_gen1', concurrency: 1, timeoutSeconds: 60 });
const keyId = defineSecret('RAZORPAY_KEY_ID'), keySecret = defineSecret('RAZORPAY_KEY_SECRET'), webhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');
const testKeyId=defineSecret('RAZORPAY_TEST_KEY_ID'),testKeySecret=defineSecret('RAZORPAY_TEST_KEY_SECRET');
const liveWebhookSecret=defineSecret('RAZORPAY_LIVE_WEBHOOK_SECRET');
const paymentSecrets=[keyId,keySecret,testKeyId,testKeySecret];
const db = getFirestore();
function service(withPayment = false) {
  const current=withPayment?new RazorpayPayments({keyId:keyId.value(),keySecret:keySecret.value()}):null;
  const test=withPayment?new RazorpayPayments({keyId:testKeyId.value(),keySecret:testKeySecret.value()}):null;
  return new WashKrewService({ db, payments:current, paymentProviders:withPayment?{test,live:current}:undefined,
    evidence: {
      async exists(path) { const [exists] = await getStorage().bucket().file(path).exists(); return exists; },
      async metadata(path) { const [metadata] = await getStorage().bucket().file(path).getMetadata(); return metadata; },
      async deletePrefix(prefix) { await getStorage().bucket().deleteFiles({prefix}); },
    },
    accounts:{deleteUser:uid=>getAuth().deleteUser(uid)},
  });
}
const cors = ['https://wheelio-apps.web.app', 'https://wheelio-apps.firebaseapp.com', /^http:\/\/(localhost|127\.0\.0\.1):\d+$/];
function callable(method, payment = false) {
  // Domain-restricted sharing forbids allUsers IAM bindings. The owner-only
  // configure-api-access operation enables the HTTP gateway after deployment;
  // Firebase ID tokens and service authorization below remain mandatory.
  return onCall({ cors, invoker: 'private', ...(payment ? { secrets: paymentSecrets } : {}) }, async request => {
    try {
      if(request.auth?.uid&&method!=='deleteAccount'&&(await db.doc(`users/${request.auth.uid}`).get()).data()?.deletionStatus)throw new ServiceError('permission-denied','This account is being deleted.');
      return await service(payment)[method](request.auth, request.data ?? {});
    }
    catch (error) {
      if (error instanceof ServiceError) throw new HttpsError(error.code, error.message);
      logger.error('WashKrew operation failed', { operation: method, code: error.code ?? 'internal' });
      throw new HttpsError('internal', 'This action could not be completed. Please try again.');
    }
  });
}
export const registerAccount = callable('register');
export const getAvailability = callable('availability');
export const checkServiceAddress = callable('checkAddress');
export const createBooking = callable('createBooking');
export const createCheckout = callable('checkout', true);
export const verifyPayment = callable('verifyPayment', true);
export const checkPayment = callable('checkPayment', true);
export const setCaptainOnline = callable('captainOnline');
export const setCaptainPreferences = callable('captainPreferences');
export const setCaptainPosition = callable('captainPosition');
export const matchServiceLocation = callable('serviceLocation');
export const submitCaptainApplication = callable('submitCaptainApplication');
export const saveCaptainPayout = callable('captainPayout');
export const claimJob = callable('claim');
export const rejectJob = callable('reject');
export const updateWashProgress = callable('progress');
export const recordWashEvidence = callable('evidenceUploaded');
export const recordCustomerPhoto = callable('customerPhoto');
export const recordCustomerMedia = callable('customerMedia');
export const updateCaptainLocation = callable('location');
export const approveWash = callable('approve');
export const rateWash = callable('rate');
export const cancelBooking = callable('cancel');
export const reportWashProblem = callable('reportProblem');
export const recordCaptainDisputeResponse = callable('captainDisputeResponse');
export const createSupportRequest = callable('supportRequest');
export const registerPushToken = callable('registerPushToken');
export const setPushPreference = callable('setPushPreference');
export const removePushToken = callable('removePushToken');
export const readNotification = callable('readNotification');
export const saveNotificationPreferences = callable('notificationPreferences');
export const updateVehicleHelp = callable('vehicleHelp');
export const saveProfilePhoto = callable('profilePhoto');
export const saveCustomerPlace = callable('savePlace');
export const syncVerifiedPhone = callable('syncVerifiedPhone');
export const deleteOwnAccount = callable('deleteAccount');
export const createBookingDocument = callable('createDocument');
export const downloadBookingDocument = onRequest({invoker:'private',cors:false,timeoutSeconds:120},async(request,response)=>{
  response.set('Cache-Control','private, no-store');response.set('X-Content-Type-Options','nosniff');response.set('Referrer-Policy','no-referrer');
  if(request.method!=='GET'){response.status(405).send('GET required');return;}
  try{
    const {download,order}=await service().consumeDocument(request.query.token);
    const safeRef=String(order.ref??download.orderId).replace(/[^A-Za-z0-9_-]/g,'');
    if(download.kind==='receipt'){
      response.set('Content-Type','application/pdf');response.set('Content-Disposition',`attachment; filename="WashKrew-${safeRef}-receipt.pdf"`);response.send(await receiptPdf(order));return;
    }
    const files=evidenceFiles(download.orderId,order),bucket=getStorage().bucket();
    for(const f of files)if(!(await bucket.file(f.path).exists())[0])throw new ServiceError('failed-precondition','An evidence image is not available. Contact support.');
    const [events,tracking]=await Promise.all([db.collection(`orders/${download.orderId}/events`).orderBy('createdAt').get(),db.doc(`orders/${download.orderId}/tracking/current`).get()]);
    const zip=new ZipFile();
    zip.on('error',()=>response.destroy());response.on('close',()=>{if(!response.writableFinished)zip.outputStream.destroy();});
    zip.addBuffer(Buffer.from(JSON.stringify({booking:order,events:events.docs.map(d=>d.data()),foregroundLocation:tracking.data()??null,callLogAvailable:false},null,2)),'booking-record.json');
    zip.addBuffer(await receiptPdf(order),'receipt.pdf');
    for(const f of files)zip.addReadStreamLazy(f.name,{compress:false},cb=>cb(null,bucket.file(f.path).createReadStream()));
    response.set('Content-Type','application/zip');response.set('Content-Disposition',`attachment; filename="WashKrew-${safeRef}-evidence.zip"`);
    await new Promise((resolve,reject)=>{response.once('finish',resolve);response.once('error',reject);response.once('close',resolve);zip.outputStream.once('error',reject);zip.outputStream.pipe(response);zip.end();});
  }catch(error){if(response.headersSent){response.destroy();return;}response.status(error instanceof ServiceError?403:500).send(error instanceof ServiceError?error.message:'Download unavailable. Open the booking and try again.');}
});

function paymentWebhook(mode, signatureSecret) {
  return onRequest({ secrets: [...paymentSecrets, signatureSecret], invoker: 'private', cors: false }, async (request, response) => {
    if (request.method !== 'POST') { response.status(405).send('POST required'); return; }
    if (!signatureMatches(request.rawBody, request.get('x-razorpay-signature'), signatureSecret.value())) { response.status(401).send('Invalid signature'); return; }
    const event = request.body;
    try {
      if (event.event === 'payment.captured' || event.event === 'order.paid') {
        const paymentId = event.payload?.payment?.entity?.id;
        if (!paymentId) { response.status(400).send('Missing payment'); return; }
        // A callback alone cannot prove capture. The service fetches the payment
        // with the matching mode's keys and verifies the server-owned booking.
        await service(true).captureWebhookPayment(paymentId, mode, event.payload?.payment?.entity?.order_id ?? null);
      } else if (event.event === 'refund.processed') {
        const refund = event.payload?.refund?.entity;
        if (!refund?.id) { response.status(400).send('Missing refund'); return; }
        await service(true).refundWebhook(refund, mode);
      }
      response.status(200).send('OK');
    } catch (error) { logger.error('Payment webhook failed', { code: error.code ?? 'internal', event: event.event }); response.status(500).send('Retry later'); }
  });
}
export const razorpayWebhook=paymentWebhook('test',webhookSecret);
export const razorpayLiveWebhook=paymentWebhook('live',liveWebhookSecret);

export const dispatchPaidBooking = onDocumentUpdated('orders/{orderId}', async event => {
  if (event.data.after.data().status === 'searching') await service().dispatch(event.params.orderId);
});
export const refundCancelledBooking = onDocumentCreated({ document: 'refunds/{orderId}', secrets: paymentSecrets, retry: true },
  event => service(true).processRefund(event.params.orderId));

export const maintainBookings = onSchedule({ schedule: 'every 5 minutes', timeoutSeconds:300, secrets: paymentSecrets }, async () => {
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
    if (doc.data().paymentExpiresAt.toMillis() < now)
      await backend.cancel({uid:doc.data().customerId},{orderId:doc.id},{paymentExpired:true});
  }
  const stalled = await db.collection('orders').where('status', 'in', ['searching', 'onTheWay']).limit(200).get();
  for (const doc of stalled.docs) if ((doc.data().status==='searching' ? doc.data().lastSlotEnd??doc.data().slotEnd : doc.data().slotEnd).toMillis() < now) {
    const o = doc.data();
    try { await backend.checkBookingDeadline(doc.id); }
    catch(error) { if (!(error instanceof ServiceError)) throw error; }
  }
  const review = await db.collection('orders').where('status','==','photosReady').limit(200).get();
  for(const doc of review.docs)if(doc.data().autoApproveAt?.toMillis()<=now){
    try{await backend.approve(null,{orderId:doc.id},{automatic:true});}
    catch(error){if(!(error instanceof ServiceError))throw error;}
  }
});


async function saveNotice(key,notice) {
  const ref=db.doc(`notifications/${createHash('sha256').update(key).digest('hex').slice(0,32)}`);
  await db.runTransaction(async tx=>{if((await tx.get(ref)).exists)return;tx.create(ref,{...notice,read:false,createdAt:FieldValue.serverTimestamp()});});
}
export const notifyBookingUpdate = onDocumentUpdated('orders/{orderId}',async event=>{
  for(const notice of orderNotices(event.data.before.data(),event.data.after.data()))
    await saveNotice(`${event.id}:${notice.recipientId}:${notice.role}:${notice.kind}`,{...notice,orderId:event.params.orderId});
});
export const notifyJobOffer = onDocumentCreated('jobOffers/{offerId}',async event=>{
  const o=event.data.data();
  if(o.status!=='pending'||o.expiresAt.toMillis()<=Date.now())return;
  await saveNotice(event.id,{recipientId:o.captainId,role:'captain',kind:'offer',orderId:o.orderId,offerExpiresAt:o.expiresAt,title:'New wash offer',body:'Open WashKrew Captain to review this offer before it expires.'});
});
export const sendInboxPush = onDocumentCreated({document:'notifications/{notificationId}',retry:true},async event=>{
  const notice=event.data.data();
  if(notice.offerExpiresAt?.toMillis()<=Date.now())return;
  const profile=(await db.doc(`users/${notice.recipientId}`).get()).data()??{};
  const preference=profile.notificationPreferences?.[notice.role];
  const delivery=pushDelivery(notice,preference,Date.now(),profile[`${notice.role}PushEnabled`]);
  if(!delivery.send)return;
  const devices=await db.collection('deviceTokens').where('uid','==',notice.recipientId).get();
  const eligible=devices.docs.filter(d=>d.data().role===notice.role).slice(0,50);
  if(!eligible.length)return;
  try {
    const result=await getMessaging().sendEachForMulticast({tokens:eligible.map(d=>d.data().token),notification:{title:notice.title,body:notice.body},data:{orderId:notice.orderId??'',role:notice.role},apns:{payload:{aps:delivery.sound?{sound:'default'}:{}}}});
    for(let i=0;i<result.responses.length;i++)if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(result.responses[i].error?.code))await eligible[i].ref.delete();
  }catch(error){logger.error('Push delivery failed; inbox entry retained',{code:error.code??'messaging'});throw error;}
});
