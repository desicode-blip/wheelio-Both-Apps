import { createHash, randomUUID } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { PaymentProviderError } from './payments.mjs';

export class ServiceError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (code, message) => { throw new ServiceError(code, message); };
const text = (value, min, max, label) => {
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) fail('invalid-argument', `Check ${label}.`);
  return value.trim();
};
const stamp = () => FieldValue.serverTimestamp();
const active = ['searching', 'onTheWay', 'washing', 'photosReady', 'disputed'];
const id = (value, label = 'reference') => text(value, 1, 100, label).match(/^[A-Za-z0-9_-]+$/)?.[0] || fail('invalid-argument', `Invalid ${label}.`);
const dateMillis = value => value?.toMillis?.() ?? (typeof value === 'number' ? value : 0);
const hash = value => createHash('sha256').update(value).digest('hex').slice(0, 32);

export class WashKrewService {
  constructor({ db, payments, evidence, now = () => Date.now() }) { Object.assign(this, { db, payments, evidence, now }); }
  actor(auth) {
    if (!auth?.uid) fail('unauthenticated', 'Log in to continue.');
    if (!/^\+91[6-9]\d{9}$/.test(auth.token?.phone_number ?? '')) fail('permission-denied', 'Verify your mobile number before continuing.');
    return auth.uid;
  }
  async config() {
    const s = await this.db.doc('config/operations').get();
    return s.exists ? s.data() : { bookingsEnabled: false, societies: [], vehicleTypes: [], slotWindows: [] };
  }
  async availability(_auth,data) {
    const societyId=id(data.societyId,'society');
    if(!/^\d{4}-\d{2}-\d{2}$/.test(data.day??''))fail('invalid-argument','Choose a date.');
    const cfg=await this.config();
    if(!cfg.societies?.some(s=>s.id===societyId&&s.active))return {slots:[]};
    const day=Date.parse(`${data.day}T00:00:00+05:30`);
    if(!Number.isFinite(day)||day<this.now()-86400000||day>this.now()+60*86400000)fail('invalid-argument','Choose a date within 60 days.');
    const captains=await this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',societyId).get();
    const count=captains.docs.filter(c=>c.id!==_auth?.uid&&c.data().paymentMode===cfg.paymentMode).length;
    const capacity=Math.min(count,Number.isInteger(cfg.capacityPerSlot)?cfg.capacityPerSlot:count);
    const slots=await Promise.all((cfg.slotWindows??[]).map(async w=>{
      const ref=this.db.doc(`slotCapacity/${hash(`${societyId}:${data.day}:${w.startHour}`)}`),reserved=(await ref.get()).data()?.reserved??0;
      return {...w,available:!!cfg.bookingsEnabled&&reserved<capacity&&day+w.endHour*3600000>this.now()};
    }));
    return {slots};
  }
  async register(auth, data) {
    const uid = this.actor(auth), role = data.role;
    if (!['customer', 'captain'].includes(role)) fail('invalid-argument', 'Invalid account type.');
    const name = text(data.name ?? '', 0, 80, 'your name');
    const ref = this.db.doc(`users/${uid}`), captainRef = this.db.doc(`captains/${uid}`);
    await this.db.runTransaction(async tx => {
      const [profile, captain, config] = await Promise.all([tx.get(ref), role === 'captain' ? tx.get(captainRef) : Promise.resolve(null), tx.get(this.db.doc('config/operations'))]);
      if (role === 'captain' && !captain.exists && (name || profile.data()?.name || '').length < 2) fail('invalid-argument', 'Enter your name.');
      const values = { phone: auth.token.phone_number, updatedAt: stamp() };
      if (name) values.name = name;
      if (!profile.exists) tx.set(ref, { ...values, name, email: auth.token.email ?? '', freeWashes: 0, createdAt: stamp() });
      else tx.update(ref, values);
      if (role === 'captain' && !captain.exists) tx.set(captainRef, {
        name: name || profile.data()?.name, phone: auth.token.phone_number, approved: false, kycStatus: 'notSubmitted', online: false,
        societyIds: [], rating: 0, ratingCount: 0, completedWashes: 0, activeJobCount: 0,
        paymentMode: config.data()?.paymentMode ?? 'test',
        createdAt: stamp(), updatedAt: stamp(),
      });
    });
    return { uid };
  }
  async createBooking(auth, data) {
    const uid = this.actor(auth), requestId = id(data.requestId, 'booking request');
    const bookingId = hash(`${uid}:${requestId}`), ref = this.db.doc(`orders/${bookingId}`);
    const plate = text(data.plate, 6, 15, 'vehicle number').toUpperCase().replaceAll(' ', '');
    if (!/^[A-Z0-9]{6,12}$/.test(plate)) fail('invalid-argument', 'Check the vehicle number.');
    const societyId = id(data.societyId, 'society'), vehicleKind = id(data.vehicleKind, 'vehicle type');
    const tower = text(data.tower ?? '', 0, 100, 'tower'), floor = text(data.floor, 1, 30, 'parking floor');
    const parking = text(data.parking ?? '', 0, 80, 'parking slot'), note = text(data.note ?? '', 0, 500, 'notes');
    if (!['dryDusting', 'wetOutside'].includes(data.washKind)) fail('invalid-argument', 'Choose an available wash.');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(data.day ?? '')) fail('invalid-argument', 'Choose a date.');
    const result = await this.db.runTransaction(async tx => {
      const [existing, cfg, profile] = await Promise.all([tx.get(ref), tx.get(this.db.doc('config/operations')), tx.get(this.db.doc(`users/${uid}`))]);
      if (existing.exists) {
        const old = existing.data();
        if (old.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
        return { bookingId, status: old.status, amount: old.pricePaise };
      }
      const config = cfg.data();
      if (!config?.bookingsEnabled) fail('failed-precondition', 'Bookings are not open yet. Please try again once service starts.');
      if (!profile.exists || !profile.data().name) fail('failed-precondition', 'Save your name first.');
      const type = config.vehicleTypes?.find(v => v.kind === vehicleKind && v.active !== false);
      const society = config.societies?.find(s => s.id === societyId && s.active === true);
      if (!type || !society) fail('failed-precondition', 'This vehicle or society is not currently available.');
      if (!Number.isSafeInteger(type.pricePaise) || type.pricePaise < 100 || !Number.isSafeInteger(type.captainPayPaise)
        || type.captainPayPaise < 0 || type.captainPayPaise > type.pricePaise) fail('failed-precondition', 'Pricing is not configured.');
      const window = config.slotWindows?.find(w => w.startHour === data.startHour && w.endHour === data.endHour);
      if (!window) fail('invalid-argument', 'Choose an available time window.');
      const start = Date.parse(`${data.day}T${String(window.startHour).padStart(2, '0')}:00:00+05:30`);
      const end = Date.parse(`${data.day}T${String(window.endHour).padStart(2, '0')}:00:00+05:30`);
      if (!Number.isFinite(start) || end <= this.now() || start > this.now() + 60 * 86400000) fail('invalid-argument', 'Choose a future slot within 60 days.');
      const outstanding = await tx.get(this.db.doc(`customerState/${uid}`));
      if (outstanding.data()?.pendingBookingId) {
        const previous = await tx.get(this.db.doc(`orders/${outstanding.data().pendingBookingId}`));
        if (previous.exists && previous.data().status === 'pendingPayment' && dateMillis(previous.data().paymentExpiresAt) > this.now())
          fail('already-exists', 'Finish or cancel your pending payment before starting another booking.');
      }
      const slotKey = hash(`${societyId}:${data.day}:${window.startHour}`);
      const slot = await tx.get(this.db.doc(`slotCapacity/${slotKey}`));
      const captains = await tx.get(this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',societyId));
      const available = captains.docs.filter(c => c.id !== uid && c.data().paymentMode === config.paymentMode).length;
      const capacity = Math.min(available, Number.isInteger(config.capacityPerSlot) ? config.capacityPerSlot : available);
      if ((slot.data()?.reserved ?? 0) >= capacity) fail('resource-exhausted', 'No captain capacity is available in that time window. Choose another time.');
      tx.set(ref, {
        customerId: uid, customerFirstName: profile.data().name.split(' ')[0], captainId: null,
        ref: `WH-${bookingId.slice(0, 8).toUpperCase()}`, status: 'pendingPayment', paymentStatus: 'unpaid',
        vehicleKind, vehicleName: type.name, plate, societyId, societyName: society.name, area: society.area, city: society.city ?? 'Hyderabad',
        tower, floor, parking, note, washKind: data.washKind, day: data.day, startHour: window.startHour, endHour: window.endHour,
        slotStart: Timestamp.fromMillis(start), slotEnd: Timestamp.fromMillis(end), slotKey,
        pricePaise: type.pricePaise, captainPayPaise: type.captainPayPaise, currency: 'INR', paymentMode: config.paymentMode,
        paymentExpiresAt: Timestamp.fromMillis(this.now() + 15 * 60000), capacityReserved: false,
        evidence: {}, createdAt: stamp(), updatedAt: stamp(),
      });
      tx.set(this.db.doc(`customerState/${uid}`), { pendingBookingId: bookingId }, { merge: true });
      return { bookingId, status: 'pendingPayment', amount: type.pricePaise };
    });
    return result;
  }
  async checkout(auth, data) {
    const uid = this.actor(auth), bookingId = id(data.bookingId), ref = this.db.doc(`orders/${bookingId}`);
    const lease = randomUUID();
    const order = await this.db.runTransaction(async tx => {
      const s = await tx.get(ref), o = s.data();
      if (!o || o.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
      if (o.paymentStatus === 'captured') return o;
      if (o.status !== 'pendingPayment' || dateMillis(o.paymentExpiresAt) <= this.now()) fail('failed-precondition', 'This payment window expired. Create a new booking.');
      if (o.razorpayOrderId) return o;
      if (dateMillis(o.checkoutLeaseUntil) > this.now()) fail('aborted', 'Checkout is being prepared. Please try again shortly.');
      tx.update(ref, { checkoutLease: lease, checkoutLeaseUntil: Timestamp.fromMillis(this.now()+30000), updatedAt: stamp() });
      return o;
    });
    if (order.paymentStatus === 'captured') return { bookingId, paid: true };
    if ((this.payments.keyId.startsWith('rzp_live_') ? 'live' : 'test') !== order.paymentMode) fail('failed-precondition', 'Payment configuration changed. Please create a new booking.');
    let providerId = order.razorpayOrderId;
    if (!providerId) {
      const created = await this.payments.createOrder({ amount: order.pricePaise, receipt: order.ref, bookingId });
      if (!created.id || created.amount !== order.pricePaise || created.currency !== 'INR') fail('internal', 'Checkout could not be prepared.');
      await this.db.runTransaction(async tx => {
        const latest = (await tx.get(ref)).data();
        if (latest.checkoutLease !== lease || latest.status !== 'pendingPayment') fail('aborted', 'Booking changed while preparing payment.');
        tx.update(ref, { razorpayOrderId: created.id, nextPaymentCheckAt: Timestamp.fromMillis(this.now()+120000), checkoutLeaseUntil: Timestamp.fromMillis(0), updatedAt: stamp() });
        tx.set(this.db.doc(`paymentOrders/${created.id}`), { bookingId });
      });
      providerId = created.id;
    }
    return { bookingId, keyId: this.payments.keyId, orderId: providerId, amount: order.pricePaise, currency: 'INR', name: 'WashKrew', testMode: order.paymentMode === 'test' };
  }
  async verifyPayment(auth, data) {
    const uid = this.actor(auth), bookingId = id(data.bookingId), order = (await this.db.doc(`orders/${bookingId}`).get()).data();
    if (!order || order.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
    const paymentId = id(data.paymentId, 'payment');
    if (data.orderId !== order.razorpayOrderId || !this.payments.verify({ orderId: order.razorpayOrderId, paymentId, signature: data.signature }))
      fail('permission-denied', 'Payment verification failed.');
    const payment = await this.payments.payment(paymentId);
    await this.capturePayment(payment);
    const latest = (await this.db.doc(`orders/${bookingId}`).get()).data();
    return { bookingId, status: latest.status, paymentStatus: latest.paymentStatus };
  }
  async reconcilePayment(bookingId) {
    const ref=this.db.doc(`orders/${id(bookingId)}`),o=(await ref.get()).data();
    if(!o?.razorpayOrderId||o.paymentStatus==='captured')return;
    const result=await this.payments.orderPayments(o.razorpayOrderId);
    for(const p of result.items??[])if(p.status==='captured')await this.capturePayment(p);
    // Reconcile lost browser callbacks/webhooks without creating payments.
    // Stop polling after two days; signed webhooks and owner checks still work.
    const fresh=(await ref.get()).data();
    await ref.update({nextPaymentCheckAt:fresh.paymentStatus==='captured'||this.now()-dateMillis(o.createdAt)>2*86400000?FieldValue.delete():Timestamp.fromMillis(this.now()+300000)});
  }
  async checkPayment(auth, data) {
    const uid = this.actor(auth), bookingId = id(data.bookingId), order = (await this.db.doc(`orders/${bookingId}`).get()).data();
    if (!order || order.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
    if (order.razorpayOrderId && order.paymentStatus !== 'captured') {
      const payments = await this.payments.orderPayments(order.razorpayOrderId);
      for (const payment of payments.items ?? []) if (payment.status === 'captured') await this.capturePayment(payment);
    }
    if (order.status === 'cancelled' && order.paymentStatus === 'captured') {
      // Customer checks can fetch an existing refund, never bypass POST retry
      // backoff or create a second refund from repeated button presses.
      try { await this.processRefund(bookingId, { checkStatus: true }); }
      catch (error) { if (!(error instanceof PaymentProviderError)) throw error; }
    }
    const latest = (await this.db.doc(`orders/${bookingId}`).get()).data();
    return { bookingId, status: latest.status, paymentStatus: latest.paymentStatus, refundStatus: latest.refundStatus ?? 'none' };
  }
  async captureWebhookPayment(paymentId) {
    const payment = await this.payments.payment(id(paymentId));
    // The merchant is shared with Trustkeyper. A signed merchant event alone
    // does not make its order a WashKrew booking; acknowledge unrelated events.
    if (!payment?.order_id || !(await this.db.doc(`paymentOrders/${id(payment.order_id)}`).get()).exists) return { ignored: true };
    await this.capturePayment(payment);
    return { ignored: false };
  }
  async capturePayment(payment) {
    if (payment.status !== 'captured') return;
    const mapping = (await this.db.doc(`paymentOrders/${id(payment.order_id)}`).get()).data();
    if (!mapping) fail('not-found', 'Unknown payment order.');
    const ref = this.db.doc(`orders/${mapping.bookingId}`);
    await this.db.runTransaction(async tx => {
      const [s, cfg] = await Promise.all([tx.get(ref), tx.get(this.db.doc('config/operations'))]);
      const o = s.data();
      if (!o || payment.order_id !== o.razorpayOrderId || payment.amount !== o.pricePaise || payment.currency !== o.currency)
        fail('permission-denied', 'Payment amount or order does not match.');
      if (o.paymentStatus === 'captured') {
        if (o.razorpayPaymentId !== payment.id) fail('already-exists', 'This booking already has a captured payment.');
        return;
      }
      const capacity = await tx.get(this.db.doc(`slotCapacity/${o.slotKey}`));
      const cfgData = cfg.data();
      const captains = await tx.get(this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',o.societyId));
      const available = captains.docs.filter(c => c.id !== o.customerId && c.data().paymentMode === o.paymentMode).length;
      const capacityLimit = Math.min(available, Number.isInteger(cfgData?.capacityPerSlot) ? cfgData.capacityPerSlot : available);
      const canReserve = o.status === 'pendingPayment' && dateMillis(o.paymentExpiresAt) > this.now() && dateMillis(o.slotEnd) > this.now() && cfgData?.bookingsEnabled
        && (capacity.data()?.reserved ?? 0) < capacityLimit;
      tx.update(ref, { paymentStatus: 'captured', razorpayPaymentId: payment.id, nextPaymentCheckAt:FieldValue.delete(),
        status: canReserve ? 'searching' : 'cancelled', capacityReserved: !!canReserve,
        ...(canReserve ? {} : { cancellationReason: 'slotUnavailable', refundStatus: 'queued' }), updatedAt: stamp() });
      tx.set(this.db.doc(`payments/${mapping.bookingId}`), { customerId: o.customerId, paymentId: payment.id, amount: payment.amount, currency: 'INR', status: 'captured', updatedAt: stamp() });
      tx.set(this.db.doc(`customerState/${o.customerId}`), { pendingBookingId: null }, { merge: true });
      if (canReserve) tx.set(capacity.ref, { reserved: (capacity.data()?.reserved ?? 0) + 1 }, { merge: true });
      else tx.set(this.db.doc(`refunds/${mapping.bookingId}`), { bookingId: mapping.bookingId, customerId: o.customerId, paymentId: payment.id, amount: o.pricePaise, status: 'queued', createdAt: stamp() });
      this.event(tx, ref, 'paymentCaptured', { status: canReserve ? 'searching' : 'cancelled' });
    });
    await this.dispatch(mapping.bookingId);
  }
  event(tx, ref, type, details = {}) {
    tx.create(ref.collection('events').doc(), { type, ...details, createdAt: stamp() });
  }
  async dispatch(bookingId) {
    const ref = this.db.doc(`orders/${id(bookingId)}`), o = (await ref.get()).data();
    if (!o || o.status !== 'searching' || o.paymentStatus !== 'captured' || dateMillis(o.slotEnd) <= this.now()) return;
    const cfg = await this.config();
    const seconds = Number.isInteger(cfg.offerTtlSeconds) && cfg.offerTtlSeconds >= 30 ? cfg.offerTtlSeconds : 60;
    const captains = await this.db.collection('captains').where('approved', '==', true).where('online', '==', true).where('societyIds', 'array-contains', o.societyId).limit(50).get();
    await Promise.all(captains.docs.filter(c=>c.id!==o.customerId && c.data().paymentMode === o.paymentMode && this.now()-dateMillis(c.data().lastSeenAt)<120000).map(c=>this.db.runTransaction(async tx=>{
      const offerRef = this.db.doc(`jobOffers/${hash(`${bookingId}:${c.id}`)}`);
      const [booking, captain, prior] = await Promise.all([tx.get(ref), tx.get(c.ref), tx.get(offerRef)]);
      if (booking.data()?.status !== 'searching' || !captain.data()?.approved || !captain.data()?.online) return;
      if (prior.exists && ['rejected','accepted','withdrawn'].includes(prior.data().status)) return;
      if (prior.exists && dateMillis(prior.data().expiresAt) > this.now()) return;
      // Coarse offer only. Vehicle identity, owner's note and exact parking are
      // available exclusively to the captain who wins the claim transaction.
      tx.set(offerRef, { orderId: bookingId, captainId: c.id, societyId: o.societyId, societyName: o.societyName, area: o.area,
        vehicleKind: o.vehicleKind, vehicleName: o.vehicleName, washKind: o.washKind, captainPayPaise: o.captainPayPaise,
        slotStart: o.slotStart, slotEnd: o.slotEnd, status: 'pending', expiresAt: Timestamp.fromMillis(this.now()+seconds*1000), createdAt: stamp() });
    })));
  }
  async captainOnline(auth, data) {
    const uid = this.actor(auth);
    if (typeof data.online !== 'boolean') fail('invalid-argument', 'Choose online or offline.');
    const ref = this.db.doc(`captains/${uid}`);
    await this.db.runTransaction(async tx=>{
      const c = (await tx.get(ref)).data();
      if (!c?.approved) fail('permission-denied', 'Your captain account must be approved before going online.');
      if (data.online && !c.societyIds?.length) fail('failed-precondition', 'Choose at least one approved society.');
      tx.update(ref, { online: data.online, lastSeenAt: stamp(), updatedAt: stamp() });
    });
    if (data.online) {
      const c = (await ref.get()).data();
      for (const societyId of c.societyIds) {
        const jobs = await this.db.collection('orders').where('status','==','searching').where('societyId','==',societyId).limit(30).get();
        for (const j of jobs.docs) await this.dispatch(j.id);
      }
    }
    return { online: data.online };
  }
  async submitCaptainApplication(auth, data) {
    const uid = this.actor(auth), cfg = await this.config();
    const societyIds = [...new Set(data.societyIds ?? [])];
    if (!societyIds.length || societyIds.length > 10 || societyIds.some(s => !cfg.societies?.some(c => c.id === s && c.active))) fail('invalid-argument', 'Choose available societies.');
    const upi = text(data.upi, 3, 100, 'payout UPI');
    if (!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$/.test(upi)) fail('invalid-argument', 'Check your UPI ID.');
    for (const kind of ['aadhaar', 'selfie', 'bank']) {
      const meta = await this.evidence.metadata(`kyc/${uid}/${kind}.jpg`);
      if (!meta || !/^image\/(jpeg|png|webp)$/.test(meta.contentType) || Number(meta.size) > 8 * 1024 * 1024) fail('failed-precondition', 'Upload your identity, selfie and bank proof.');
    }
    await this.db.runTransaction(async tx => {
      const ref = this.db.doc(`captains/${uid}`), c = (await tx.get(ref)).data();
      if (!c || c.approved || !['notSubmitted','changesRequested'].includes(c.kycStatus)) fail('failed-precondition', 'Your application is already under review.');
      tx.update(ref, { requestedSocietyIds: societyIds, upi, kycStatus: 'underReview', submittedAt: stamp(), updatedAt: stamp() });
    });
    return { status: 'underReview' };
  }
  async claim(auth, data) {
    const uid = this.actor(auth), orderId = id(data.orderId), ref = this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const [booking, captain, offer, offers] = await Promise.all([tx.get(ref),tx.get(this.db.doc(`captains/${uid}`)),
        tx.get(this.db.doc(`jobOffers/${hash(`${orderId}:${uid}`)}`)), tx.get(this.db.collection('jobOffers').where('orderId','==',orderId))]);
      const o = booking.data(), c = captain.data(), f = offer.data();
      if (!c?.approved || !c.online || this.now()-dateMillis(c.lastSeenAt)>=120000 || !c.societyIds.includes(o?.societyId) || c.paymentMode !== o?.paymentMode) fail('permission-denied', 'You are not available for this society.');
      if (!o || o.customerId === uid || o.status !== 'searching' || o.paymentStatus !== 'captured') fail('failed-precondition', 'This job is no longer available.');
      if (!f || f.status !== 'pending' || dateMillis(f.expiresAt) <= this.now()) fail('deadline-exceeded', 'This offer expired.');
      const assigned = await tx.get(this.db.collection('orders').where('captainId','==',uid).where('status','in',['onTheWay','washing','photosReady']));
      if (assigned.docs.some(d => dateMillis(d.data().slotStart)<dateMillis(o.slotEnd) && dateMillis(d.data().slotEnd)>dateMillis(o.slotStart)))
        fail('failed-precondition','You already have a job in this time window.');
      tx.update(ref, { captainId: uid, captain: { id: uid, name: c.name.split(' ')[0], rating: c.rating ?? 0, washes: c.completedWashes ?? 0 }, status:'onTheWay', assignedAt:stamp(),updatedAt:stamp() });
      tx.update(captain.ref,{activeJobCount:(c.activeJobCount??0)+1,updatedAt:stamp()});
      for (const f of offers.docs) tx.update(f.ref,{status:f.data().captainId===uid?'accepted':'withdrawn',updatedAt:stamp()});
      this.event(tx,ref,'captainAssigned',{captainId:uid,status:'onTheWay'});
    });
    return { orderId, status:'onTheWay' };
  }
  async reject(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`jobOffers/${hash(`${orderId}:${uid}`)}`);
    await this.db.runTransaction(async tx=>{const s=await tx.get(ref);if(s.data()?.captainId!==uid)fail('permission-denied','This offer is not yours.');
      if(s.data().status==='pending')tx.update(ref,{status:'rejected',updatedAt:stamp()});});
    return {ok:true};
  }
  async progress(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`), action=data.action;
    const before=(await ref.get()).data();
    if(!before||before.captainId!==uid)fail('permission-denied','This job is not yours.');
    if(['start','finish'].includes(action)) {
      const stage=action==='start'?'before':'after';
      for(let side=0;side<4;side++) {
        const evidence=before.evidence?.[`${stage}_${side}`];
        if(!evidence||!await this.evidence.exists(evidence.path))fail('failed-precondition',`Upload all four ${stage} photos first.`);
      }
    }
    await this.db.runTransaction(async tx=>{
      const s=await tx.get(ref),o=s.data();
      if(o.captainId!==uid)fail('permission-denied','This job is not yours.');
      let update={updatedAt:stamp()};
      if(action==='arrived'&&o.status==='onTheWay')update.arrivedAt=stamp();
      else if(action==='start'&&o.status==='onTheWay'&&o.arrivedAt)update={...update,status:'washing',startedAt:stamp()};
      else if(action==='finish'&&o.status==='washing')update={...update,status:'photosReady',finishedAt:stamp()};
      else if(action==='noteHeard'&&active.includes(o.status))update.noteHeard=true;
      else fail('failed-precondition','This action is not available at the current wash stage.');
      tx.update(ref,update); this.event(tx,ref,action,{status:update.status??o.status,captainId:uid});
      if(action==='finish')tx.set(this.db.doc(`earnings/${orderId}`),{captainId:uid,orderId,amount:o.captainPayPaise,status:'awaitingApproval',createdAt:stamp(),updatedAt:stamp()});
    });
    return {ok:true};
  }
  async evidenceUploaded(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),stage=data.stage,side=data.side;
    if(!['before','after'].includes(stage)||!Number.isInteger(side)||side<0||side>3)fail('invalid-argument','Invalid photo angle.');
    const path=`orders/${orderId}/${uid}/${stage}_${side}.jpg`;
    const metadata=await this.evidence.metadata(path);
    if(!metadata||!/^image\/(jpeg|png|webp)$/.test(metadata.contentType)||Number(metadata.size)>8*1024*1024)fail('invalid-argument','Upload an image smaller than 8 MB.');
    const ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(ref)).data();
      if(o?.captainId!==uid||(stage==='before'?o.status!=='onTheWay':o.status!=='washing'))fail('permission-denied','Photos cannot be changed at this wash stage.');
      tx.update(ref,{[`evidence.${stage}_${side}`]:{path,uploadedAt:stamp()},updatedAt:stamp()});
    });
    return {path};
  }
  async customerPhoto(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),angle=data.angle;
    if(!['front','back','left','right'].includes(angle))fail('invalid-argument','Invalid photo angle.');
    const path=`orders/${orderId}/customer/${angle}.jpg`,meta=await this.evidence.metadata(path);
    if(!meta||!/^image\/(jpeg|png|webp)$/.test(meta.contentType)||Number(meta.size)>8*1024*1024)fail('invalid-argument','Choose a photo smaller than 8 MB.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),o=(await tx.get(ref)).data();
      if(o?.customerId!==uid||o.status!=='pendingPayment')fail('permission-denied','These vehicle photos are locked.');
      tx.update(ref,{[`customerPhotos.${angle}`]:path,updatedAt:stamp()});
    });return {path};
  }
  async location(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId);
    if(!Number.isFinite(data.latitude)||!Number.isFinite(data.longitude)||Math.abs(data.latitude)>90||Math.abs(data.longitude)>180)
      fail('invalid-argument','Invalid location.');
    const ref=this.db.doc(`orders/${orderId}/tracking/current`);
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(this.db.doc(`orders/${orderId}`))).data(),prior=await tx.get(ref);
      if(o?.captainId!==uid||!['onTheWay','washing'].includes(o.status))fail('permission-denied','Location sharing is only available during your assigned job.');
      if(this.now()-dateMillis(prior.data()?.updatedAt)<5000)return;
      tx.set(ref,{latitude:data.latitude,longitude:data.longitude,accuracy:Number.isFinite(data.accuracy)?Math.max(0,data.accuracy):null,updatedAt:stamp()});
    });
    return {ok:true};
  }
  async approve(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const s=await tx.get(ref),o=s.data();
      if(!o||o.customerId!==uid)fail('permission-denied','This booking is not yours.');
      if(o.status==='approved')return;
      if(o.status!=='photosReady')fail('failed-precondition','The wash is not ready for approval.');
      const c=await tx.get(this.db.doc(`captains/${o.captainId}`));
      tx.update(ref,{status:'approved',approvedAt:stamp(),updatedAt:stamp()});
      tx.update(c.ref,{completedWashes:(c.data()?.completedWashes??0)+1,activeJobCount:Math.max(0,(c.data()?.activeJobCount??1)-1),updatedAt:stamp()});
      tx.set(this.db.doc(`earnings/${orderId}`),{captainId:o.captainId,orderId,amount:o.captainPayPaise,status:'approved',updatedAt:stamp()},{merge:true});
      this.event(tx,ref,'customerApproved',{status:'approved'});
    });
    return {ok:true};
  }
  async rate(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId);
    if(!Number.isInteger(data.stars)||data.stars<1||data.stars>5)fail('invalid-argument','Choose 1 to 5 stars.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),s=await tx.get(ref),o=s.data();
      if(!o||o.customerId!==uid||o.status!=='approved')fail('permission-denied','Only the customer can rate an approved wash.');
      if(o.rating)fail('already-exists','This wash has already been rated.');
      const c=await tx.get(this.db.doc(`captains/${o.captainId}`)),count=c.data().ratingCount??0,sum=c.data().ratingSum??0;
      tx.update(ref,{rating:data.stars,updatedAt:stamp()});tx.update(c.ref,{ratingCount:count+1,ratingSum:sum+data.stars,rating:(sum+data.stars)/(count+1),updatedAt:stamp()});
    });
    return {ok:true};
  }
  async cancel(auth,data,{expired = false} = {}) {
    const uid=expired?auth.uid:this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const [s,cfg]=await Promise.all([tx.get(ref),tx.get(this.db.doc('config/operations'))]),o=s.data();
      if(!o||o.customerId!==uid)fail('permission-denied','This booking is not yours.');
      if(o.status==='cancelled')return;
      if(expired && (dateMillis(o.slotEnd)>this.now() || o.arrivedAt))return;
      if(!['pendingPayment','searching','onTheWay'].includes(o.status))fail('failed-precondition','Contact support to cancel a wash that has started.');
      const fee=!expired&&o.status==='onTheWay'?cfg.data()?.cancellationFeePaise:0;
      if(!Number.isSafeInteger(fee)||fee<0||fee>o.pricePaise)fail('failed-precondition','Cancellation terms are not configured. Contact support.');
      const slot=o.capacityReserved?await tx.get(this.db.doc(`slotCapacity/${o.slotKey}`)):null;
      const captain=o.captainId?await tx.get(this.db.doc(`captains/${o.captainId}`)):null;
      const offers=await tx.get(this.db.collection('jobOffers').where('orderId','==',orderId));
      tx.update(ref,{status:'cancelled',cancelledAt:stamp(),capacityReserved:false,refundStatus:o.paymentStatus==='captured'?'queued':'none',refundAmountPaise:o.paymentStatus==='captured'?o.pricePaise-fee:0,updatedAt:stamp()});
      if(slot)tx.set(slot.ref,{reserved:Math.max(0,(slot.data()?.reserved??1)-1)},{merge:true});
      if(captain?.exists)tx.update(captain.ref,{activeJobCount:Math.max(0,(captain.data().activeJobCount??1)-1),updatedAt:stamp()});
      for(const offer of offers.docs)tx.update(offer.ref,{status:'withdrawn',updatedAt:stamp()});
      if(o.paymentStatus==='captured')tx.set(this.db.doc(`refunds/${orderId}`),{bookingId:orderId,customerId:uid,paymentId:o.razorpayPaymentId,amount:o.pricePaise-fee,status:'queued',createdAt:stamp()});
      this.event(tx,ref,'customerCancelled',{status:'cancelled'});
    });
    return {ok:true};
  }
  async reportProblem(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),kind=id(data.kind),note=text(data.note??'',0,1000,'problem description');
    if(!['notClean','damage','wrongVehicle','noShow'].includes(kind))fail('invalid-argument','Choose a problem.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),o=(await tx.get(ref)).data();
      if(!o||o.customerId!==uid||!['photosReady','approved'].includes(o.status))fail('permission-denied','A problem cannot be opened for this booking.');
      tx.update(ref,{status:'disputed',dispute:{kind,note,outcome:'underReview',createdAt:Timestamp.fromMillis(this.now())},updatedAt:stamp()});
      tx.set(this.db.doc(`supportTickets/${orderId}`),{customerId:uid,orderId,captainId:o.captainId,kind,note,status:'open',createdAt:stamp()});
      tx.set(this.db.doc(`earnings/${orderId}`),{status:'onHold',updatedAt:stamp()},{merge:true});
      this.event(tx,ref,'problemReported',{status:'disputed'});
    });
    return {ok:true};
  }
  async applyRefund(bookingId, refund, lease) {
    const ref=this.db.doc(`refunds/${id(bookingId)}`);
    if (!refund?.id || !['pending','processed','failed'].includes(refund.status)) fail('internal','Refund verification failed.');
    await this.db.runTransaction(async tx=>{
      const current=(await tx.get(ref)).data();
      if (!current || refund.payment_id !== current.paymentId || refund.amount !== current.amount
        || (current.providerRefundId && current.providerRefundId !== refund.id)) fail('internal','Refund verification failed.');
      // A verified webhook may finish while an older worker is still running.
      if (current.status === 'processed' || (lease && current.lease !== lease)) return;
      const status=refund.status==='processed'?'processed':refund.status==='failed'?'needsReview':'submitted';
      tx.update(ref,{status,providerRefundId:refund.id,leaseUntil:Timestamp.fromMillis(0),
        lastErrorCode:FieldValue.delete(),lastErrorStatus:FieldValue.delete(),
        nextAttemptAt:status==='submitted'?Timestamp.fromMillis(this.now()+300000):FieldValue.delete(),updatedAt:stamp()});
      tx.update(this.db.doc(`orders/${bookingId}`),{refundStatus:status==='needsReview'?'delayed':status,
        refundIssue:status==='needsReview'?'providerFailed':FieldValue.delete(),
        refundAmountPaise:current.amount,providerRefundId:refund.id,updatedAt:stamp()});
    });
  }
  async processRefund(bookingId, { checkStatus = false } = {}) {
    const ref=this.db.doc(`refunds/${id(bookingId)}`),lease=randomUUID();
    const data=await this.db.runTransaction(async tx=>{
      const s=await tx.get(ref),r=s.data();if(!r||r.status==='processed')return null;
      if (r.status==='needsReview' || (checkStatus && !r.providerRefundId)) return null;
      if(dateMillis(r.leaseUntil)>this.now())return null;
      if (!checkStatus && dateMillis(r.nextAttemptAt)>this.now()) return null;
      const attempts=(r.attempts??0)+1;
      tx.update(ref,{status:'processing',attempts,lease,leaseUntil:Timestamp.fromMillis(this.now()+60000),updatedAt:stamp()});return {...r,attempts};
    });
    if(!data)return;
    if(data.amount===0){await this.db.runTransaction(async tx=>{const r=(await tx.get(ref)).data();if(r.lease!==lease||r.status==='processed')return;
      tx.update(ref,{status:'processed',leaseUntil:Timestamp.fromMillis(0),nextAttemptAt:FieldValue.delete(),updatedAt:stamp()});
      tx.update(this.db.doc(`orders/${bookingId}`),{refundStatus:'processed',refundIssue:FieldValue.delete(),refundAmountPaise:0,updatedAt:stamp()});});return;}
    try {
      const request={paymentId:data.paymentId,amount:data.amount,refundId:`wh_${bookingId}`};
      const refund=data.providerRefundId ? await this.payments.fetchRefund(data.providerRefundId)
        : await this.payments.findRefund(request) ?? await this.payments.refund(request);
      await this.applyRefund(bookingId,refund,lease);
    } catch(error) {
      const rejected=error instanceof PaymentProviderError && error.status>=400 && error.status<500 && ![409,429].includes(error.status);
      const invalid=error instanceof ServiceError;
      const delay=Math.min(3600000,300000*2**Math.min(data.attempts-1,4));
      await this.db.runTransaction(async tx=>{
        const current=(await tx.get(ref)).data();if(current.lease!==lease||current.status==='processed')return;
        tx.update(ref,{status:invalid?'needsReview':'retry',leaseUntil:Timestamp.fromMillis(0),
          nextAttemptAt:invalid?FieldValue.delete():Timestamp.fromMillis(this.now()+delay),
          lastErrorCode:error instanceof PaymentProviderError?error.code:invalid?'VERIFICATION_FAILED':'PROVIDER_ERROR',
          lastErrorStatus:error instanceof PaymentProviderError?error.status:0,updatedAt:stamp()});
        tx.update(this.db.doc(`orders/${bookingId}`),{refundStatus:'delayed',
          refundIssue:invalid?'verificationFailed':rejected?'providerRejected':'providerUnavailable',updatedAt:stamp()});
      });
      throw error;
    }
  }
}
