import { createHash, randomUUID, randomBytes } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { PaymentProviderError } from './payments.mjs';
import {acceptsFunding} from './payment-policy.mjs';
import { validPosition, metresBetween, areaFits } from './geography.mjs';
import {startTraining,trainingHeartbeat,submitQuiz,trainingConfig} from './training.mjs';
import {beginIdentity,verifyIdentity,reviewIdentity} from './identity.mjs';
import {checkWashPhotos,photoFingerprint} from './wash-photo-review.mjs';
import {photoModeEnabled} from './photo-policy.mjs';
import {listCaptainApplications,getCaptainApplication,reviewCaptainApplication,captainReviewEvidence} from './captain-review.mjs';
import { walletPrice, cancellationPolicy, cancellationBenefit, worksWindow, normalizeWorkingSlots, windowTimes, normalizedAddress } from './booking-policy.mjs';

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
const canTakeJobs=c=>c?.approved&&!['blocked','refresher'].includes(c.workStatus);
const id = (value, label = 'reference') => text(value, 1, 100, label).match(/^[A-Za-z0-9_-]+$/)?.[0] || fail('invalid-argument', `Invalid ${label}.`);
const dateMillis = value => value?.toMillis?.() ?? (typeof value === 'number' ? value : 0);
const hash = value => createHash('sha256').update(value).digest('hex').slice(0, 32);
// Preserve historical test slot keys; live capacity uses a separate namespace.
const capacityKey=(society,day,hour,mode)=>hash(`${mode==='live'?'live:':''}${society}:${day}:${hour}`);

export class WashKrewService {
  constructor({ db, payments, paymentProviders, evidence, accounts, maps, photoChecks, now = () => Date.now() }) { Object.assign(this, { db, payments, paymentProviders, evidence, accounts, maps, photoChecks, now }); }
  getPayments(mode,merchant='trustkeyper') {
    merchant=merchant??'trustkeyper';
    if(!['trustkeyper','washkrew'].includes(merchant))fail('failed-precondition','This booking merchant is not configured. Contact support.');
    const provider=merchant==='trustkeyper'?(this.paymentProviders?.[mode]??this.payments):this.paymentProviders?.[`washkrew:${mode}`];
    const actual=provider?.keyId?.startsWith('rzp_live_')?'live':provider?.keyId?.startsWith('rzp_test_')?'test':null;
    if(!['test','live'].includes(mode)||actual!==mode)fail('failed-precondition','Payments are not configured for this booking. Contact support.');
    return provider;
  }
  actor(auth) {
    if (!auth?.uid) fail('unauthenticated', 'Log in to continue.');
    if (!/^\+91[6-9]\d{9}$/.test(auth.token?.phone_number ?? '')) fail('permission-denied', 'Verify your mobile number before continuing.');
    return auth.uid;
  }
  async config() {
    const s = await this.db.doc('config/operations').get();
    return s.exists ? s.data() : { bookingsEnabled: false, societies: [], vehicleTypes: [], slotWindows: [] };
  }
  worksWindow(captain, window, day = window.day) {
    const elapsed = (this.now() - Date.parse(`${day}T00:00:00+05:30`)) / 60000;
    return worksWindow(captain, window, elapsed);
  }
  startTraining(auth,data){return startTraining(this,auth,data);}
  listCaptainApplications(auth,data){return listCaptainApplications(this,auth,data);}
  getCaptainApplication(auth,data){return getCaptainApplication(this,auth,data);}
  reviewCaptainApplication(auth,data){return reviewCaptainApplication(this,auth,data);}
  captainReviewEvidence(auth,data){return captainReviewEvidence(this,auth,data);}
  trainingHeartbeat(auth,data){return trainingHeartbeat(this,auth,data);}
  submitQuiz(auth,data){return submitQuiz(this,auth,data);}
  checkWashPhotos(auth,data){return checkWashPhotos(this,auth,data);}
  beginIdentity(auth,data){return beginIdentity(this,auth,data);}
  verifyIdentity(auth,data){return verifyIdentity(this,auth,data);}
  reviewIdentity(data){return reviewIdentity(this,data);}
  async cleanupIdentityChecks(){
    const expired=await this.db.collection('identityChecks').where('expiresAt','<=',Timestamp.fromMillis(this.now())).limit(100).get();
    for(const doc of expired.docs){const p=doc.data();for(const path of [p.path,...(p.priorPaths??[])])if(typeof path==='string'&&new RegExp(`^identity/[A-Za-z0-9_-]+/${doc.id}/[a-f0-9-]{36}\\.jpg$`).test(path))await this.evidence.deletePrefix(path);await doc.ref.delete();}
  }
  // Not exported as app callables: these require the owner's IAM-operated CLI.
  async scheduleIntro(data){
    const uid=id(data.captainId),at=Date.parse(data.at),ref=this.db.doc(`captains/${uid}`);
    if(!Number.isFinite(at)||at<this.now()||at>this.now()+90*86400000)fail('invalid-argument','Choose the agreed upcoming introduction time.');
    const label=new Intl.DateTimeFormat('en-IN',{timeZone:'Asia/Kolkata',day:'numeric',month:'short',hour:'numeric',minute:'2-digit'}).format(at)+' IST';
    await this.db.runTransaction(async tx=>{
      if(!(await tx.get(ref)).exists)fail('not-found','Captain not found.');
      tx.update(ref,{introCallAt:Timestamp.fromMillis(at),introCallLabel:label,updatedAt:stamp()});
      tx.set(this.db.doc(`notifications/${hash(`${uid}:intro:${at}`)}`),{recipientId:uid,role:'captain',kind:'introScheduled',title:'Introduction call confirmed',body:label,read:false,createdAt:stamp()});
    });return {ok:true};
  }
  async setCaptainPolicy(data){
    const uid=id(data.captainId),reason=text(data.reason,3,500,'review reason');
    if(!['active','probation','refresher','blocked'].includes(data.workStatus)||!Number.isInteger(data.jobLimit)||data.jobLimit<1||data.jobLimit>50||!Number.isInteger(data.levelDay)||data.levelDay<1||data.levelDay>3)fail('invalid-argument','Choose a reviewed work status, daily job limit and level day (1–3).');
    const ref=this.db.doc(`captains/${uid}`),reviewId=randomUUID();
    await this.db.runTransaction(async tx=>{
      const c=(await tx.get(ref)).data();if(!c?.approved)fail('failed-precondition','Review and approve the real Captain first.');
      tx.update(ref,{workStatus:data.workStatus,jobLimit:data.jobLimit,levelDay:data.levelDay,workStatusReason:reason,...(['blocked','refresher'].includes(data.workStatus)?{online:false}:{}),updatedAt:stamp()});
      tx.create(ref.collection('reviews').doc(reviewId),{...data,createdAt:stamp()});
      tx.create(this.db.collection('notifications').doc(),{recipientId:uid,role:'captain',kind:data.workStatus==='active'?'levelUp':data.workStatus==='blocked'?'blocked':'probation',title:data.workStatus==='active'?'Work limits updated':data.workStatus==='blocked'?'You can’t take new jobs':'Captain review update',body:reason,read:false,createdAt:stamp()});
    });return {ok:true};
  }
  walletRef(uid, mode) { return this.db.doc(`wallets/${uid}_${mode}`); }
  async checkAddress(auth, data) {
    const uid = this.actor(auth), cfg = await this.config();
    const address = {
      name: text(data.name, 2, 120, 'building name'), area: text(data.area, 2, 120, 'area'),
      city: text(data.city, 2, 80, 'city'), pincode: text(data.pincode, 6, 6, 'pincode'),
    };
    if (!/^[1-9]\d{5}$/.test(address.pincode)) fail('invalid-argument', 'Check the pincode.');
    const key = hash(normalizedAddress(address));
    const canonical = cfg.societies?.find(s => s.active && s.name.trim().toLowerCase() === address.name.toLowerCase() &&
      s.pincode === address.pincode && (s.city ?? 'Hyderabad').toLowerCase() === address.city.toLowerCase());
    const reviewed = (await this.db.doc(`serviceAddresses/${key}`).get()).data();
    const society = canonical ?? cfg.societies?.find(s => s.active && s.id === reviewed?.societyId && reviewed.approved === true);
    const requestRef = this.db.doc(`addressRequests/${hash(`${uid}:${key}`)}`);
    await requestRef.set({ customerId: uid, address, addressKey: key, status: society ? 'approved' : 'underReview',
      ...(society ? { societyId: society.id } : {}), updatedAt: stamp() }, { merge: true });
    return society ? { served: true, society: { ...society, addressName: address.name, addressArea: address.area, addressCity: address.city, addressPincode: address.pincode }, addressKey: key }
      : { served: false, requestId: requestRef.id, status: 'underReview' };
  }
  async availability(_auth,data) {
    const societyId=id(data.societyId,'society');
    if(!/^\d{4}-\d{2}-\d{2}$/.test(data.day??''))fail('invalid-argument','Choose a date.');
    const cfg=await this.config();
    if(!cfg.societies?.some(s=>s.id===societyId&&s.active))return {slots:[]};
    const day=Date.parse(`${data.day}T00:00:00+05:30`);
    if(!Number.isFinite(day)||day<this.now()-86400000||day>this.now()+60*86400000)fail('invalid-argument','Choose a date within 60 days.');
    const captains=await this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',societyId).get();
    const slots=await Promise.all((cfg.slotWindows??[]).map(async w=>{
      const count=captains.docs.filter(c=>canTakeJobs(c.data())&&c.id!==_auth?.uid&&c.data().paymentMode===cfg.paymentMode&&this.worksWindow(c.data(),w,data.day)&&areaFits(c.data(),{societyId,area:cfg.societies.find(s=>s.id===societyId)?.area},cfg.societies)).length;
      const capacity=Math.min(count,Number.isInteger(cfg.capacityPerSlot)?cfg.capacityPerSlot:count);
      const ref=this.db.doc(`slotCapacity/${capacityKey(societyId,data.day,w.startHour,cfg.paymentMode)}`),reserved=(await ref.get()).data()?.reserved??0;
      return {...w,available:!!cfg.bookingsEnabled&&reserved<capacity&&day+w.endHour*3600000>this.now()};
    }));
    return {slots, multipleWindows: true};
  }
  async register(auth, data) {
    const uid = this.actor(auth), role = data.role;
    if (!['customer', 'captain'].includes(role)) fail('invalid-argument', 'Invalid account type.');
    const name = text(data.name ?? '', 0, 80, 'your name');
    const ref = this.db.doc(`users/${uid}`), captainRef = this.db.doc(`captains/${uid}`);
    await this.db.runTransaction(async tx => {
      const [profile, captain, config] = await Promise.all([tx.get(ref), tx.get(captainRef), tx.get(this.db.doc('config/operations'))]);
      if(profile.data()?.deletionStatus||profile.data()?.deletingRole)fail('failed-precondition','Account deletion must finish before registering again.');
      if(profile.data()?.deletedRoles?.[role]&&(!Number.isFinite(auth.token.auth_time)||this.now()/1000-auth.token.auth_time>300))fail('failed-precondition','Log in with a fresh SMS code to create this app account again.');
      if (role === 'captain' && !captain.exists && (name || profile.data()?.name || '').length < 2) fail('invalid-argument', 'Enter your name.');
      const roles=profile.data()?.roles??(profile.exists?['customer',...(captain.exists?['captain']:[])]:[]);
      const values = { phone: auth.token.phone_number, roles:[...new Set([...roles,role])], updatedAt: stamp() };
      if (name) values.name = name;
      if (!profile.exists) tx.set(ref, { ...values, name, email: auth.token.email ?? '', freeWashes: 0, createdAt: stamp() });
      else tx.update(ref, {...values,[`deletedRoles.${role}`]:FieldValue.delete()});
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
      if(config?.paymentMode==='live'&&config.paymentMerchant!=='washkrew')fail('failed-precondition','New live bookings require the separate WashKrew merchant.');
      if(config?.paymentMerchant&&!['washkrew','trustkeyper'].includes(config.paymentMerchant))fail('failed-precondition','The booking merchant is not configured.');
      if(profile.data()?.deletionStatus)fail('permission-denied','This account is being deleted.');
      if(profile.data()?.deletedRoles?.customer||profile.data()?.deletingRole==='customer')fail('permission-denied','Log in with a fresh SMS code to create your Customer account again.');
      if (!config?.bookingsEnabled) fail('failed-precondition', 'Bookings are not open yet. Please try again once service starts.');
      if (!profile.exists || !profile.data().name) fail('failed-precondition', 'Save your name first.');
      const type = config.vehicleTypes?.find(v => v.kind === vehicleKind && v.active !== false);
      const society = config.societies?.find(s => s.id === societyId && s.active === true);
      if (!type || !society) fail('failed-precondition', 'This vehicle or society is not currently available.');
      if (!Number.isSafeInteger(type.pricePaise) || type.pricePaise < 100 || !Number.isSafeInteger(type.captainPayPaise)
        || type.captainPayPaise < 0 || type.captainPayPaise > type.pricePaise) fail('failed-precondition', 'Pricing is not configured.');
      const requested = data.windows ?? [{ startHour: data.startHour, endHour: data.endHour }];
      if (!Array.isArray(requested) || !requested.length || requested.length > 12 ||
          (data.anyTime !== undefined && typeof data.anyTime !== 'boolean')) fail('invalid-argument', 'Choose available time windows.');
      const windows = requested.map(w => {
        const found = config.slotWindows?.find(x => x.startHour === w?.startHour && x.endHour === w?.endHour);
        if (!found) fail('invalid-argument', 'Choose available time windows.');
        const times = windowTimes(data.day, found);
        if (!Number.isFinite(times.start) || times.end <= this.now() || times.start > this.now() + 60 * 86400000) fail('invalid-argument', 'Choose a future slot within 60 days.');
        return { startHour: found.startHour, endHour: found.endHour };
      }).sort((a,b) => a.startHour-b.startHour);
      if (new Set(windows.map(w=>w.startHour)).size !== windows.length) fail('invalid-argument', 'Choose each time window once.');
      const outstanding = await tx.get(this.db.doc(`customerState/${uid}`));
      if (outstanding.data()?.pendingBookingId) {
        const previous = await tx.get(this.db.doc(`orders/${outstanding.data().pendingBookingId}`));
        if (previous.exists && previous.data().status === 'pendingPayment' && dateMillis(previous.data().paymentExpiresAt) > this.now())
          fail('already-exists', 'Finish or cancel your pending payment before starting another booking.');
      }
      const captains = await tx.get(this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',societyId));
      const slots = await Promise.all(windows.map(w => tx.get(this.db.doc(`slotCapacity/${capacityKey(societyId,data.day,w.startHour,config.paymentMode)}`))));
      const availableIndex = windows.findIndex((w,i) => {
        const available = captains.docs.filter(c => canTakeJobs(c.data())&&c.id !== uid && c.data().paymentMode === config.paymentMode && this.worksWindow(c.data(), w,data.day)&&areaFits(c.data(),{societyId,area:society.area},config.societies)).length;
        return (slots[i].data()?.reserved ?? 0) < Math.min(available, Number.isInteger(config.capacityPerSlot) ? config.capacityPerSlot : available);
      });
      if (availableIndex < 0) fail('resource-exhausted', 'No captain capacity is available in those time windows. Choose another time.');
      const window = windows[availableIndex], {start,end} = windowTimes(data.day, window);
      const slotKey = slots[availableIndex].id;
      if (!['test','live'].includes(config.paymentMode)) fail('failed-precondition', 'Payment mode is not configured.');
      const walletRef = this.walletRef(uid, config.paymentMode), wallet = (await tx.get(walletRef)).data();
      if (data.useFreeWash && !(wallet?.freeWashes > 0)) fail('failed-precondition', 'Your free-wash balance changed. Review this booking again.');
      const pricing = walletPrice(type.pricePaise, wallet, {useFreeWash:data.useFreeWash===true,useCredit:data.useCredit===true});
      if (data.expectedAmountPaise !== undefined && data.expectedAmountPaise !== pricing.pricePaise) fail('failed-precondition', 'Your price or balance changed. Review this booking again.');
      let address = null;
      if (data.addressKey) {
        const request = (await tx.get(this.db.doc(`addressRequests/${hash(`${uid}:${id(data.addressKey)}`)}`))).data();
        if (request?.status !== 'approved' || request.societyId !== societyId) fail('failed-precondition', 'This address is awaiting service approval.');
        const mapping=(await tx.get(this.db.doc(`serviceAddresses/${data.addressKey}`))).data();
        const canonical=society.name.trim().toLowerCase()===request.address.name.trim().toLowerCase()&&society.pincode===request.address.pincode&&(society.city??'Hyderabad').toLowerCase()===request.address.city.toLowerCase();
        if(!canonical&&!(mapping?.approved===true&&mapping.societyId===societyId))fail('failed-precondition','This address is no longer served. Check availability again.');
        address = request.address;
      }
      const policy = cancellationPolicy(config);
      tx.set(ref, {
        customerId: uid, customerFirstName: profile.data().name.split(' ')[0], captainId: null,
        ref: `WH-${bookingId.slice(0, 8).toUpperCase()}`, status: 'pendingPayment', paymentStatus: 'unpaid',
        vehicleKind, vehicleName: type.name, plate, societyId, societyName: address?.name ?? society.name, area: address?.area ?? society.area, city: address?.city ?? society.city ?? 'Hyderabad',
        pincode: address?.pincode ?? society.pincode ?? '', manualAddress: !!address, addressKey: address ? data.addressKey : null,
        tower, floor, parking, note, washKind: data.washKind, day: data.day, startHour: window.startHour, endHour: window.endHour,
        vehiclePosition: validPosition(data.vehiclePosition) ? {latitude:data.vehiclePosition.latitude,longitude:data.vehiclePosition.longitude} : null,
        slotStart: Timestamp.fromMillis(start), slotEnd: Timestamp.fromMillis(end), slotKey,
        requestedWindows: windows, anyTime: data.anyTime === true,
        lastSlotEnd: Timestamp.fromMillis(windowTimes(data.day, windows.at(-1)).end),
        ...pricing, basePricePaise: type.pricePaise, cancellationPolicy: policy,
        walletReserved: pricing.freeWashUsed || pricing.creditUsedPaise > 0, walletReleased: false,
        captainPayPaise: type.captainPayPaise, currency: 'INR', paymentMode: config.paymentMode, paymentMerchant:config.paymentMerchant??'trustkeyper',
        paymentPolicy:config.paymentPolicy??null,checkoutConfigId:config.checkoutConfigId??null,
        paymentExpiresAt: Timestamp.fromMillis(this.now() + 15 * 60000), capacityReserved: false,
        evidence: {}, createdAt: Timestamp.fromMillis(this.now()), updatedAt: stamp(),
      });
      if (pricing.freeWashUsed || pricing.creditUsedPaise > 0) tx.set(walletRef, {
        customerId:uid, paymentMode:config.paymentMode,
        freeWashes: Math.max(0,(wallet?.freeWashes??0)-(pricing.freeWashUsed?1:0)),
        creditPaise: Math.max(0,(wallet?.creditPaise??0)-pricing.creditUsedPaise), updatedAt:stamp(),
      }, {merge:true});
      tx.set(this.db.doc(`customerState/${uid}`), { pendingBookingId: bookingId }, { merge: true });
      return { bookingId, status: 'pendingPayment', amount: pricing.pricePaise };
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
    if (order.pricePaise === 0) {
      await this.db.runTransaction(async tx => {
        const [fresh,cfg] = await Promise.all([tx.get(ref),tx.get(this.db.doc('config/operations'))]);
        const latest = fresh.data();
        if (latest.paymentStatus === 'captured') return;
        if (latest.customerId !== uid || latest.status !== 'pendingPayment' || latest.pricePaise !== 0 || !latest.walletReserved || dateMillis(latest.paymentExpiresAt)<=this.now()) fail('failed-precondition','Review or reopen this booking.');
        await this.settleBooking(tx,ref,latest,cfg.data(),null,'wallet');
      });
      await this.dispatch(bookingId);
      return {bookingId,paid:true};
    }
    if(order.paymentMode==='live'&&(order.paymentMerchant??'trustkeyper')!=='washkrew')fail('failed-precondition','New checkout on the historical shared live merchant is disabled. Contact support.');
    const payments=this.getPayments(order.paymentMode,order.paymentMerchant);
    let providerId = order.razorpayOrderId;
    if (!providerId) {
      const created = await payments.createOrder({ amount: order.pricePaise, receipt: order.ref, bookingId,checkoutConfigId:order.checkoutConfigId });
      if (!created.id || created.amount !== order.pricePaise || created.currency !== 'INR') fail('internal', 'Checkout could not be prepared.');
      await this.db.runTransaction(async tx => {
        const latest = (await tx.get(ref)).data();
        if (latest.checkoutLease !== lease || latest.status !== 'pendingPayment') fail('aborted', 'Booking changed while preparing payment.');
        tx.update(ref, { razorpayOrderId: created.id, nextPaymentCheckAt: Timestamp.fromMillis(this.now()+120000), checkoutLeaseUntil: Timestamp.fromMillis(0), updatedAt: stamp() });
        tx.set(this.db.doc(`paymentOrders/${created.id}`), { bookingId, paymentMode:order.paymentMode,paymentMerchant:order.paymentMerchant??'trustkeyper' });
      });
      providerId = created.id;
    }
    return { bookingId, keyId: payments.keyId, orderId: providerId, amount: order.pricePaise, currency: 'INR', name: 'WashKrew', testMode: order.paymentMode === 'test',checkoutConfigId:order.checkoutConfigId??null };
  }
  async verifyPayment(auth, data) {
    const uid = this.actor(auth), bookingId = id(data.bookingId), order = (await this.db.doc(`orders/${bookingId}`).get()).data();
    if (!order || order.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
    const paymentId = id(data.paymentId, 'payment'),payments=this.getPayments(order.paymentMode,order.paymentMerchant);
    if (data.orderId !== order.razorpayOrderId || !payments.verify({ orderId: order.razorpayOrderId, paymentId, signature: data.signature }))
      fail('permission-denied', 'Payment verification failed.');
    const payment = await payments.payment(paymentId);
    await this.capturePayment(payment,order.paymentMode,order.paymentMerchant);
    const latest = (await this.db.doc(`orders/${bookingId}`).get()).data();
    return { bookingId, status: latest.status, paymentStatus: latest.paymentStatus };
  }
  async reconcilePayment(bookingId) {
    const ref=this.db.doc(`orders/${id(bookingId)}`),o=(await ref.get()).data();
    if(!o?.razorpayOrderId||o.paymentStatus==='captured')return;
    const result=await this.getPayments(o.paymentMode,o.paymentMerchant).orderPayments(o.razorpayOrderId);
    for(const p of result.items??[])if(p.status==='captured')await this.capturePayment(p,o.paymentMode,o.paymentMerchant);
    // Reconcile lost browser callbacks/webhooks without creating payments.
    // Stop polling after two days; signed webhooks and owner checks still work.
    const fresh=(await ref.get()).data();
    await ref.update({nextPaymentCheckAt:fresh.paymentStatus==='captured'||this.now()-dateMillis(o.createdAt)>2*86400000?FieldValue.delete():Timestamp.fromMillis(this.now()+300000)});
  }
  async checkPayment(auth, data) {
    const uid = this.actor(auth), bookingId = id(data.bookingId), order = (await this.db.doc(`orders/${bookingId}`).get()).data();
    if (!order || order.customerId !== uid) fail('permission-denied', 'This booking is not yours.');
    if (order.razorpayOrderId && order.paymentStatus !== 'captured') {
      const payments = await this.getPayments(order.paymentMode,order.paymentMerchant).orderPayments(order.razorpayOrderId);
      for (const payment of payments.items ?? []) if (payment.status === 'captured') await this.capturePayment(payment,order.paymentMode,order.paymentMerchant);
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
  async captureWebhookPayment(paymentId,mode='test',hintOrderId=null,merchant='trustkeyper') {
    // A signed hint can rule out unrelated merchant traffic before an API call;
    // it never proves payment. Known orders are fetched and verified below.
    if(hintOrderId) {
      const mapping=(await this.db.doc(`paymentOrders/${id(hintOrderId)}`).get()).data();
      if(!mapping)return {ignored:true};
      if(mapping.paymentMode && mapping.paymentMode!==mode)fail('permission-denied','Payment mode does not match.');
      if((mapping.paymentMerchant??'trustkeyper')!==merchant)fail('permission-denied','Payment merchant does not match.');
    }
    const payment = await this.getPayments(mode,merchant).payment(id(paymentId));
    // The merchant is shared with Trustkeyper. A signed merchant event alone
    // does not make its order a WashKrew booking; acknowledge unrelated events.
    if (!payment?.order_id || !(await this.db.doc(`paymentOrders/${id(payment.order_id)}`).get()).exists) return { ignored: true };
    await this.capturePayment(payment,mode,merchant);
    return { ignored: false };
  }
  async refundWebhook(refund,mode='test',merchant='trustkeyper') {
    const pending=await this.db.collection('refunds').where('providerRefundId','==',id(refund.id,'refund')).limit(1).get();
    if(pending.empty)return {ignored:true};
    const record=pending.docs[0],expected=record.data();
    const order=(await this.db.doc(`orders/${record.id}`).get()).data();
    if(order?.paymentMode!==mode || (order?.paymentMerchant??'trustkeyper')!==merchant || refund.payment_id!==expected.paymentId || refund.amount!==expected.amount)
      fail('permission-denied','Refund does not match this booking.');
    await this.applyRefund(record.id,await this.getPayments(mode,merchant).fetchRefund(refund.id));
    return {ignored:false};
  }
  async capturePayment(payment,mode='test',merchant='trustkeyper') {
    merchant=merchant??'trustkeyper';
    if (payment.status !== 'captured') return;
    const mapping = (await this.db.doc(`paymentOrders/${id(payment.order_id)}`).get()).data();
    if (!mapping) fail('not-found', 'Unknown payment order.');
    if((mapping.paymentMerchant??'trustkeyper')!==merchant)fail('permission-denied','Payment merchant does not match.');
    const ref = this.db.doc(`orders/${mapping.bookingId}`);
    await this.db.runTransaction(async tx => {
      const [s, cfg] = await Promise.all([tx.get(ref), tx.get(this.db.doc('config/operations'))]);
      const o = s.data();
      if (!o || o.paymentMode!==mode || (o.paymentMerchant??'trustkeyper')!==merchant || payment.order_id !== o.razorpayOrderId || payment.amount !== o.pricePaise || payment.currency !== o.currency)
        fail('permission-denied', 'Payment amount or order does not match.');
      if (o.paymentStatus === 'captured') {
        if (o.razorpayPaymentId !== payment.id) fail('already-exists', 'This booking already has a captured payment.');
        return;
      }
      await this.settleBooking(tx, ref, o, cfg.data(), payment.id,'razorpay',acceptsFunding(payment,o.paymentPolicy)?null:'paymentMethodNotAllowed');
    });
    await this.dispatch(mapping.bookingId);
  }
  async settleBooking(tx, ref, o, cfg, paymentId, source = 'razorpay',rejectionReason=null) {
    const windows = o.requestedWindows ?? [{startHour:o.startHour,endHour:o.endHour}];
    const [slots,captains,wallet] = await Promise.all([
      Promise.all(windows.map(w=>tx.get(this.db.doc(`slotCapacity/${capacityKey(o.societyId,o.day,w.startHour,o.paymentMode)}`)))),
      tx.get(this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',o.societyId)),
      tx.get(this.walletRef(o.customerId,o.paymentMode)),
    ]);
    const selected = windows.findIndex((w,i)=>{
      const count=captains.docs.filter(c=>canTakeJobs(c.data())&&c.id!==o.customerId&&c.data().paymentMode===o.paymentMode&&this.worksWindow(c.data(),w,o.day)&&areaFits(c.data(),o,cfg.societies)).length;
      return windowTimes(o.day,w).end>this.now() && (slots[i].data()?.reserved??0)<Math.min(count,Number.isInteger(cfg?.capacityPerSlot)?cfg.capacityPerSlot:count);
    });
    const canReserve=!rejectionReason&&o.status==='pendingPayment'&&dateMillis(o.paymentExpiresAt)>this.now()&&cfg?.bookingsEnabled===true&&selected>=0;
    const selection=canReserve?windows[selected]:null;
    const cashRefund=!canReserve&&o.pricePaise>0;
    tx.update(ref,{paymentStatus:'captured',paymentSource:source,...(paymentId?{razorpayPaymentId:paymentId}:{}),nextPaymentCheckAt:FieldValue.delete(),
      status:canReserve?'searching':'cancelled',capacityReserved:canReserve,
      ...(canReserve?{...selection,slotKey:slots[selected].id,slotStart:Timestamp.fromMillis(windowTimes(o.day,selection).start),slotEnd:Timestamp.fromMillis(windowTimes(o.day,selection).end)}:
        {cancellationReason:rejectionReason??'slotUnavailable',refundStatus:cashRefund?'queued':'none',walletReleased:!!o.walletReserved}),updatedAt:stamp()});
    tx.set(this.db.doc(`payments/${ref.id}`),{customerId:o.customerId,paymentId:paymentId??null,source,amount:o.pricePaise,currency:'INR',status:'captured',updatedAt:stamp()});
    tx.set(this.db.doc(`customerState/${o.customerId}`),{pendingBookingId:null},{merge:true});
    if(canReserve)tx.set(slots[selected].ref,{reserved:(slots[selected].data()?.reserved??0)+1},{merge:true});
    else {
      this.restoreWallet(tx,wallet,o);
      if(cashRefund)tx.set(this.db.doc(`refunds/${ref.id}`),{bookingId:ref.id,customerId:o.customerId,paymentId,amount:o.pricePaise,paymentMode:o.paymentMode,paymentMerchant:o.paymentMerchant??'trustkeyper',status:'queued',createdAt:stamp()});
    }
    this.event(tx,ref,'paymentCaptured',{status:canReserve?'searching':'cancelled'});
  }
  restoreWallet(tx, wallet, order, benefit = null) {
    const restore=order.walletReserved&&!order.walletReleased;
    const free=(restore&&order.freeWashUsed?1:0)+(benefit?.freeWashes??0);
    const credit=(restore?(order.creditUsedPaise??0):0)+(benefit?.creditPaise??0);
    if(free||credit)tx.set(wallet.ref,{customerId:order.customerId,paymentMode:order.paymentMode,
      freeWashes:(wallet.data()?.freeWashes??0)+free,creditPaise:(wallet.data()?.creditPaise??0)+credit,updatedAt:stamp()},{merge:true});
  }
  event(tx, ref, type, details = {}) {
    tx.create(ref.collection('events').doc(), { type, ...details, createdAt: stamp() });
  }
  async dispatch(bookingId) {
    const ref = this.db.doc(`orders/${id(bookingId)}`);
    await this.advanceWindow(ref);
    const o = (await ref.get()).data();
    if (!o || o.status !== 'searching' || o.paymentStatus !== 'captured' || dateMillis(o.slotEnd) <= this.now()) return;
    const cfg = await this.config();
    const seconds = Number.isInteger(cfg.offerTtlSeconds) && cfg.offerTtlSeconds >= 30 ? cfg.offerTtlSeconds : 60;
    const captains = await this.db.collection('captains').where('approved', '==', true).where('online', '==', true).where('societyIds', 'array-contains', o.societyId).limit(50).get();
    await Promise.all(captains.docs.filter(c=>c.id!==o.customerId && c.data().paymentMode === o.paymentMode && this.worksWindow(c.data(),o) && areaFits(c.data(),o,cfg.societies) && this.now()-dateMillis(c.data().lastSeenAt)<120000).map(c=>this.db.runTransaction(async tx=>{
      const offerRef = this.db.doc(`jobOffers/${hash(`${bookingId}:${c.id}`)}`);
      const [booking, captain, prior] = await Promise.all([tx.get(ref), tx.get(c.ref), tx.get(offerRef)]);
      if (booking.data()?.status !== 'searching' || booking.data().slotKey!==o.slotKey || !canTakeJobs(captain.data()) || !captain.data()?.online || !this.worksWindow(captain.data(),o) || !areaFits(captain.data(),o,cfg.societies)) return;
      if (prior.exists && ['rejected','accepted','withdrawn'].includes(prior.data().status)) return;
      if (prior.exists && dateMillis(prior.data().expiresAt) > this.now()) return;
      // Coarse offer only. Vehicle identity, owner's note and exact parking are
      // available exclusively to the captain who wins the claim transaction.
      tx.set(offerRef, { orderId: bookingId, captainId: c.id, societyId: o.societyId, societyName: o.societyName, area: o.area,
        vehicleKind: o.vehicleKind, vehicleName: o.vehicleName, washKind: o.washKind, captainPayPaise: o.captainPayPaise,
        distanceMetres:metresBetween(captain.data().position,cfg.societies?.find(s=>s.id===o.societyId)?.location),
        paymentMode:o.paymentMode, slotStart: o.slotStart, slotEnd: o.slotEnd, requestedWindows:o.requestedWindows??[], anyTime:o.anyTime===true, status: 'pending', expiresAt: Timestamp.fromMillis(this.now()+seconds*1000), createdAt: stamp() });
    })));
  }
  async advanceWindow(ref) {
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(ref)).data();
      if(o?.status!=='searching'||dateMillis(o.slotEnd)>this.now()||!o.requestedWindows?.length)return;
      const windows=o.requestedWindows.filter(w=>windowTimes(o.day,w).end>this.now());
      if(!windows.length)return;
      const [cfg,captains,old,slots,offers]=await Promise.all([
        tx.get(this.db.doc('config/operations')),
        tx.get(this.db.collection('captains').where('approved','==',true).where('societyIds','array-contains',o.societyId)),
        tx.get(this.db.doc(`slotCapacity/${o.slotKey}`)),
        Promise.all(windows.map(w=>tx.get(this.db.doc(`slotCapacity/${capacityKey(o.societyId,o.day,w.startHour,o.paymentMode)}`)))),
        tx.get(this.db.collection('jobOffers').where('orderId','==',ref.id)),
      ]);
      const i=windows.findIndex((w,i)=>{
        const count=captains.docs.filter(c=>canTakeJobs(c.data())&&c.id!==o.customerId&&c.data().paymentMode===o.paymentMode&&this.worksWindow(c.data(),w,o.day)&&areaFits(c.data(),o,cfg.data()?.societies)).length;
        return (slots[i].data()?.reserved??0)<Math.min(count,cfg.data()?.capacityPerSlot??count);
      });
      if(i<0)return;
      const w=windows[i],times=windowTimes(o.day,w);
      tx.update(ref,{...w,slotKey:slots[i].id,slotStart:Timestamp.fromMillis(times.start),slotEnd:Timestamp.fromMillis(times.end),updatedAt:stamp()});
      if(o.capacityReserved)tx.set(old.ref,{reserved:Math.max(0,(old.data()?.reserved??1)-1)},{merge:true});
      tx.set(slots[i].ref,{reserved:(slots[i].data()?.reserved??0)+1},{merge:true});
      for(const f of offers.docs)tx.delete(f.ref);
      this.event(tx,ref,'windowUpdated');
    });
  }
  async captainPreferences(auth,data) {
    const uid=this.actor(auth), windows=data.workingWindows,cfg=await this.config();
    const exact = Object.hasOwn(data,'workingSlots'), slots = exact ? normalizeWorkingSlots(data.workingSlots) : null;
    if(exact ? slots === null : (!Array.isArray(windows)||!windows.length||windows.length>3||windows.some(w=>![[6,10],[10,14],[14,18]].some(([a,b])=>w?.startHour===a&&w?.endHour===b))||new Set(windows.map(w=>w.startHour)).size!==windows.length))
      fail('invalid-argument','Choose your working hours.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`captains/${uid}`),c=(await tx.get(ref)).data();
      if(!c||c.deletionStatus)fail('permission-denied','Complete your Captain account first.');
      const preference=data.areaPreference;
      if(preference!==undefined){
        if(!['all','radius','societies','place'].includes(preference?.mode))fail('invalid-argument','Choose an area preference.');
        const allowed=c.approved?c.societyIds??[]:(cfg.societies??[]).filter(s=>s.active).map(s=>s.id);
        if(preference.mode==='societies'&&(!Array.isArray(preference.societyIds)||!preference.societyIds.length||preference.societyIds.length>10||preference.societyIds.some(v=>!allowed.includes(v))))fail('permission-denied','Choose available societies within your approval.');
        if(preference.mode==='radius'&&(!Number.isFinite(preference.radiusKm)||preference.radiusKm<1||preference.radiusKm>50||!validPosition(c.position)))fail('failed-precondition','Allow location access before choosing a distance filter.');
        if(preference.mode==='place')text(preference.place,2,100,'area');
      }
      const compatibilityWindows = exact ? [[6,10],[10,14],[14,18]].filter(([a,b])=>!slots.length||slots.some(s=>s.startMinute<b*60&&s.endMinute>a*60)).map(([startHour,endHour])=>({startHour,endHour})) : windows.map(w=>({startHour:w.startHour,endHour:w.endHour}));
      tx.update(ref,{workingSlots:exact?slots:FieldValue.delete(),workingWindows:compatibilityWindows,...(preference?{areaPreference:{mode:preference.mode,...(preference.mode==='societies'?{societyIds:[...new Set(preference.societyIds)]}:preference.mode==='radius'?{radiusKm:preference.radiusKm}:preference.mode==='place'?{place:preference.place.trim()}:{})}}:{}),updatedAt:stamp()});
    });
    return {ok:true};
  }
  async captainOnline(auth, data) {
    const uid = this.actor(auth);
    if (typeof data.online !== 'boolean') fail('invalid-argument', 'Choose online or offline.');
    const ref = this.db.doc(`captains/${uid}`);
    await this.db.runTransaction(async tx=>{
      const c = (await tx.get(ref)).data();
      if (!c?.approved) fail('permission-denied', 'Your captain account must be approved before going online.');
      if(data.online&&!canTakeJobs(c))fail('failed-precondition','New jobs are paused pending the operations review. Open Help to ask for a review.');
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
  async captainPosition(auth,data){
    const uid=this.actor(auth);if(!validPosition(data))fail('invalid-argument','Invalid location.');
    const ref=this.db.doc(`captains/${uid}`);if(!(await ref.get()).exists)fail('permission-denied','Complete your Captain account first.');
    const {societyId}=await this.serviceLocation(null,data);
    await ref.update({position:{latitude:data.latitude,longitude:data.longitude,updatedAt:Timestamp.fromMillis(this.now())},locationSocietyId:societyId,updatedAt:stamp()});return {ok:true};
  }
  async serviceLocation(_auth,data){
    if(!validPosition(data))fail('invalid-argument','Invalid location.');
    const cfg=await this.config();
    const candidates=(cfg.societies??[]).filter(s=>s.active&&validPosition(s.location)&&Number.isFinite(s.serviceRadiusMetres)&&s.serviceRadiusMetres>0).map(s=>({societyId:s.id,distanceMetres:metresBetween(data,s.location),radius:s.serviceRadiusMetres})).filter(s=>s.distanceMetres<=s.radius).sort((a,b)=>a.distanceMetres-b.distanceMetres);
    if(candidates.length)return {societyId:candidates[0].societyId};
    if(data.suggest===true){const suggestion=(cfg.societies??[]).find(s=>s.active&&validPosition(s.mapViewport?.low)&&validPosition(s.mapViewport?.high)&&data.latitude>=s.mapViewport.low.latitude&&data.latitude<=s.mapViewport.high.latitude&&data.longitude>=s.mapViewport.low.longitude&&data.longitude<=s.mapViewport.high.longitude);if(suggestion)return {societyId:suggestion.id,matchKind:'mapSuggestion'};}
    return {societyId:null};
  }
  async captainPayout(auth,data) {
    const uid=this.actor(auth),method=data.method;
    if(!['upi','bank'].includes(method))fail('invalid-argument','Choose UPI or bank account.');
    let payout;
    if(method==='upi'){
      const upi=text(data.upi,3,100,'payout UPI');
      if(!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$/.test(upi))fail('invalid-argument','Check your UPI ID.');
      payout={method,upi};
    }else{
      const accountNumber=text(data.accountNumber,9,18,'bank account').replaceAll(' ','');
      if(!/^\d{9,18}$/.test(accountNumber))fail('invalid-argument','Check your account number.');
      payout={method,accountNumber};
    }
    const ref=this.db.doc(`captains/${uid}`);
    await this.db.runTransaction(async tx=>{
      const c=(await tx.get(ref)).data();
      if(!c)fail('failed-precondition','Complete your Captain account first.');
      if(c.approved&&(!Number.isFinite(auth.token.auth_time)||this.now()/1000-auth.token.auth_time>300))fail('failed-precondition','Verify the code sent to your current mobile number before changing payouts.');
      tx.update(ref,{payout:{...payout,status:'pendingVerification'},upi:method==='upi'?payout.upi:'',updatedAt:stamp()});
      if(c.approved)tx.set(this.db.doc(`notifications/${hash(`${uid}:payout:${JSON.stringify(payout)}`)}`),{recipientId:uid,role:'captain',kind:'upiChanged',category:'money',title:'Payout details updated',body:'Your new payout details are saved for verification.',read:false,createdAt:stamp()});
    });return {ok:true,status:'pendingVerification'};
  }
  async submitCaptainApplication(auth, data) {
    const uid = this.actor(auth), cfg = await this.config();
    const societyIds = [...new Set(data.societyIds ?? [])];
    if (!societyIds.length || societyIds.length > 10 || societyIds.some(s => !cfg.societies?.some(c => c.id === s && c.active))) fail('invalid-argument', 'Choose available societies.');
    const current=(await this.db.doc(`captains/${uid}`).get()).data();
    const payout=current?.payout??{method:'upi',upi:text(data.upi,3,100,'payout UPI'),status:'pendingVerification'};
    if(payout.method==='upi'&&!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$/.test(payout.upi))fail('invalid-argument','Check your UPI ID.');
    for (const kind of ['aadhaar', 'selfie']) {
      const meta = await this.evidence.metadata(`kyc/${uid}/${kind}.jpg`);
      if (!meta || !/^image\/(jpeg|png|webp)$/.test(meta.contentType) || Number(meta.size) <= 0 || Number(meta.size) > 8 * 1024 * 1024) fail('failed-precondition', 'Upload your identity and selfie.');
    }
    await this.db.runTransaction(async tx => {
      const ref = this.db.doc(`captains/${uid}`), c = (await tx.get(ref)).data();
      if (!c || c.approved || !['notSubmitted','changesRequested'].includes(c.kycStatus)) fail('failed-precondition', 'Your application is already under review.');
      if(cfg.training?.required){const t=trainingConfig(cfg);if(c.trainingVersion!==t.version||!c.trainingCompletedAt||!c.quizPassedAt)fail('failed-precondition','Finish the approved training videos and quiz first.');}
      tx.update(ref, { requestedSocietyIds: societyIds, payout, upi:payout.method==='upi'?payout.upi:'', paymentMode:cfg.paymentMode,kycStatus: 'underReview', submittedAt: stamp(), updatedAt: stamp() });
    });
    return { status: 'underReview' };
  }
  async claim(auth, data) {
    const uid = this.actor(auth), orderId = id(data.orderId), ref = this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const [booking, captain, offer, offers] = await Promise.all([tx.get(ref),tx.get(this.db.doc(`captains/${uid}`)),
        tx.get(this.db.doc(`jobOffers/${hash(`${orderId}:${uid}`)}`)), tx.get(this.db.collection('jobOffers').where('orderId','==',orderId))]);
      const o = booking.data(), c = captain.data(), f = offer.data();
      if (!canTakeJobs(c) || !c.online || this.now()-dateMillis(c.lastSeenAt)>=120000 || !c.societyIds.includes(o?.societyId) || c.paymentMode !== o?.paymentMode) fail('permission-denied', 'You are not available for this society.');
      if (!o || o.customerId === uid || o.status !== 'searching' || o.paymentStatus !== 'captured') fail('failed-precondition', 'This job is no longer available.');
      if (!f || f.status !== 'pending' || dateMillis(f.expiresAt) <= this.now()) fail('deadline-exceeded', 'This offer expired.');
      if (dateMillis(o.slotEnd)<=this.now() || !this.worksWindow(c,o) || dateMillis(f.slotStart)!==dateMillis(o.slotStart)) fail('failed-precondition','This time window is no longer available.');
      const assigned = await tx.get(this.db.collection('orders').where('captainId','==',uid).where('status','in',['onTheWay','washing','photosReady']));
      const cfg=(await tx.get(this.db.doc('config/operations'))).data();
      if(!areaFits(c,o,cfg?.societies))fail('failed-precondition','This job is outside your saved area preference.');
      if(Number.isInteger(c.jobLimit)&&c.jobLimit>0){const today=await tx.get(this.db.collection('orders').where('captainId','==',uid).where('day','==',o.day));if(today.docs.filter(d=>d.data().status!=='cancelled').length>=c.jobLimit)fail('failed-precondition','Your configured daily job limit is reached.');}
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
    const before=(await ref.get()).data(),identitySettings=['start','finish'].includes(action)?(await this.db.doc('privateConfig/photoChecks').get()).data():null;
    if(!before||before.captainId!==uid)fail('permission-denied','This job is not yours.');
    const completed=o=>(action==='arrived'&&o.arrivedAt&&active.includes(o.status))||(action==='noteHeard'&&o.noteHeard&&active.includes(o.status))||(action==='start'&&['washing','photosReady','approved','disputed'].includes(o.status))||(action==='finish'&&['photosReady','approved','disputed'].includes(o.status));
    if(completed(before))return {ok:true};
    if(identitySettings?.enabled&&!photoModeEnabled(identitySettings,before.paymentMode))fail('failed-precondition','Photo checks need operations setup for this booking mode.');
    if(['arrived','start','finish'].includes(action)&&dateMillis(before.slotStart)>this.now())fail('failed-precondition','This booking window has not opened yet.');
    if(['start','finish'].includes(action)) {
      const stage=action==='start'?'before':'after';
      for(let side=0;side<4;side++) {
        const evidence=before.evidence?.[`${stage}_${side}`];
        if(!evidence||!await this.evidence.exists(evidence.path))fail('failed-precondition',`Upload all four ${stage} photos first.`);
        if(evidence.generation&&(await this.evidence.metadata(evidence.path))?.generation!==evidence.generation)fail('failed-precondition','A photo changed after registration. Upload and check it again.');
      }
    }
    await this.db.runTransaction(async tx=>{
      const s=await tx.get(ref),o=s.data();
      if(o.captainId!==uid)fail('permission-denied','This job is not yours.');
      if(completed(o))return;
      if(['arrived','start','finish'].includes(action)&&dateMillis(o.slotStart)>this.now())fail('failed-precondition','This booking window has not opened yet.');
      let update={updatedAt:stamp()};
      if(action==='arrived'&&o.status==='onTheWay')update.arrivedAt=stamp();
      else if(action==='start'&&o.status==='onTheWay'&&o.arrivedAt){
        if(photoModeEnabled(identitySettings,o.paymentMode)&&o.identityStatus!=='verified')fail('failed-precondition','Complete the Captain identity check before starting. Help can request a human review.');
        if((o.customerMedia?.note_audio||o.customerMedia?.note_video)&&!o.noteHeard)fail('failed-precondition','Listen to the owner note before starting.');
        update={...update,status:'washing',startedAt:stamp()};
      }
      else if(action==='finish'&&o.status==='washing'){
        if(identitySettings?.aiEnabled&&photoModeEnabled(identitySettings,o.paymentMode)){
          if(!o.photoReview||o.photoReview.status==='checking'||o.photoReview.fingerprint!==photoFingerprint(o))fail('failed-precondition','Check the current after photos before sending.');
          if((o.photoReview.issues?.length||o.photoReview.status!=='checked')&&data.acknowledgePhotoIssues!==true)fail('failed-precondition','Review the photo warnings before sending.');
        }
        update={...update,status:'photosReady',finishedAt:stamp(),photoIssuesAcknowledged:data.acknowledgePhotoIssues===true,autoApproveAt:Timestamp.fromMillis(Math.floor((this.now()+19800000)/86400000+1)*86400000-19800000-60000)};
      }
      else if(action==='noteHeard'&&active.includes(o.status))update.noteHeard=true;
      else fail('failed-precondition','This action is not available at the current wash stage.');
      tx.update(ref,update); this.event(tx,ref,action,{status:update.status??o.status,captainId:uid});
      if(action==='finish')tx.set(this.db.doc(`earnings/${orderId}`),{captainId:uid,orderId,paymentMode:o.paymentMode,amount:o.captainPayPaise,status:'awaitingApproval',createdAt:stamp(),updatedAt:stamp()});
    });
    return {ok:true};
  }
  async evidenceUploaded(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),stage=data.stage,side=data.side;
    if(!['before','after'].includes(stage)||!Number.isInteger(side)||side<0||side>3)fail('invalid-argument','Invalid photo angle.');
    const path=`orders/${orderId}/${uid}/${stage}_${side}.jpg`;
    const ref=this.db.doc(`orders/${orderId}`),order=(await ref.get()).data();
    if(order?.captainId!==uid||(stage==='before'?order.status!=='onTheWay':order.status!=='washing'))fail('permission-denied','Photos cannot be changed at this wash stage.');
    const metadata=await this.evidence.metadata(path);
    if(!metadata||!/^image\/(jpeg|png|webp)$/.test(metadata.contentType)||Number(metadata.size)<=0||Number(metadata.size)>8*1024*1024)fail('invalid-argument','Upload an image smaller than 8 MB.');
    const checks=(await this.db.doc('privateConfig/photoChecks').get()).data();
    if(checks?.enabled&&!photoModeEnabled(checks,order.paymentMode))fail('failed-precondition','Photo checks need operations setup for this booking mode.');
    if(photoModeEnabled(checks,order.paymentMode)){
      const result=await this.photoChecks.quality(await this.evidence.read(path,metadata.generation));
      if(!result||!Object.hasOwn(result,'issue'))fail('unavailable','Photo checking did not return a result. Try again.');
      if(result.issue)fail('failed-precondition',result.issue==='tooDark'?'This photo is too dark. Add light and take it again.':'This photo is too small, unreadable or obscured. Take it again.');
    }
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(ref)).data();
      if(o?.captainId!==uid||(stage==='before'?o.status!=='onTheWay':o.status!=='washing'))fail('permission-denied','Photos cannot be changed at this wash stage.');
      tx.update(ref,{[`evidence.${stage}_${side}`]:{path,...(metadata.generation?{generation:metadata.generation}:{}),uploadedAt:stamp()},updatedAt:stamp()});
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
  async customerMedia(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),kind=data.kind,seconds=data.seconds;
    if(!['vehicle','note_audio','note_video'].includes(kind)||!Number.isInteger(seconds)||seconds<1||seconds>30)fail('invalid-argument','Choose a recording of up to 30 seconds.');
    const path=`orders/${orderId}/customer/${kind}`,meta=await this.evidence.metadata(path);
    const allowed=kind==='note_audio'?['audio/mp4','audio/aac']:['video/mp4','video/quicktime'];
    if(!meta||!allowed.includes(meta.contentType)||Number(meta.size)<=0||Number(meta.size)>20*1024*1024)fail('invalid-argument','Upload a supported recording smaller than 20 MB.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),o=(await tx.get(ref)).data();
      if(o?.customerId!==uid||o.status!=='pendingPayment')fail('permission-denied','These recordings are locked.');
      const media={...(o.customerMedia??{})};
      if(kind==='note_audio')delete media.note_video;
      if(kind==='note_video')delete media.note_audio;
      media[kind]={path,contentType:meta.contentType,seconds};
      tx.update(ref,{customerMedia:media,updatedAt:stamp()});
    });
    return {path};
  }
  async location(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId);
    if(!Number.isFinite(data.latitude)||!Number.isFinite(data.longitude)||Math.abs(data.latitude)>90||Math.abs(data.longitude)>180)
      fail('invalid-argument','Invalid location.');
    const ref=this.db.doc(`orders/${orderId}/tracking/current`),orderRef=this.db.doc(`orders/${orderId}`),cfg=await this.config(),attempt=randomUUID();
    const destination=await this.db.runTransaction(async tx=>{
      const o=(await tx.get(orderRef)).data(),prior=await tx.get(ref);
      if(o?.captainId!==uid||!['onTheWay','washing'].includes(o.status))fail('permission-denied','Location sharing is only available during your assigned job.');
      if(this.now()-dateMillis(prior.data()?.updatedAt)<5000)return;
      tx.set(ref,{latitude:data.latitude,longitude:data.longitude,accuracy:Number.isFinite(data.accuracy)?Math.max(0,data.accuracy):null,updatedAt:stamp()});
      const target=o.vehiclePosition??cfg.societies?.find(s=>s.id===o.societyId)?.location;
      if(this.maps&&o.status==='onTheWay'&&validPosition(target)&&this.now()-dateMillis(o.arrivalAttemptAt)>=90000){
        tx.update(orderRef,{arrivalAttemptAt:Timestamp.fromMillis(this.now()),arrivalAttempt:attempt});
        return target;
      }
    });
    if(destination){
      try{
        const route=await this.maps.arrival({latitude:data.latitude,longitude:data.longitude},destination);
        if(!Number.isSafeInteger(route.seconds)||route.seconds<0||route.seconds>86400)throw Error('Invalid route');
        await this.db.runTransaction(async tx=>{
          const o=(await tx.get(orderRef)).data();
          if(o?.captainId!==uid||o.status!=='onTheWay'||o.arrivedAt||o.arrivalAttempt!==attempt)return;
          tx.update(orderRef,{arrivalEstimateAt:Timestamp.fromMillis(this.now()+route.seconds*1000),arrivalUpdatedAt:Timestamp.fromMillis(this.now()),arrivalDistanceMetres:route.distanceMetres,arrivalStatus:'available'});
        });
      }catch{
        // GPS sharing must still work during a Routes outage. Never substitute a made-up ETA.
        await this.db.runTransaction(async tx=>{const o=(await tx.get(orderRef)).data();if(o?.arrivalAttempt===attempt&&o.status==='onTheWay')tx.update(orderRef,{arrivalStatus:'unavailable',arrivalEstimateAt:FieldValue.delete()});});
      }
    }
    return {ok:true};
  }
  async approve(auth,data,{automatic=false}={}) {
    const uid=automatic?null:this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const s=await tx.get(ref),o=s.data();
      if(!o||(!automatic&&o.customerId!==uid))fail('permission-denied','This booking is not yours.');
      if(o.status==='approved')return;
      if(o.status!=='photosReady')fail('failed-precondition','The wash is not ready for approval.');
      if(automatic&&(!o.autoApproveAt||dateMillis(o.autoApproveAt)>this.now()))fail('failed-precondition','The review window has not ended.');
      const c=await tx.get(this.db.doc(`captains/${o.captainId}`));
      tx.update(ref,{status:'approved',approvalSource:automatic?'automatic':'customer',approvedAt:stamp(),updatedAt:stamp()});
      tx.update(c.ref,{completedWashes:(c.data()?.completedWashes??0)+1,activeJobCount:Math.max(0,(c.data()?.activeJobCount??1)-1),updatedAt:stamp()});
      tx.set(this.db.doc(`earnings/${orderId}`),{captainId:o.captainId,orderId,paymentMode:o.paymentMode,amount:o.captainPayPaise,status:'approved',updatedAt:stamp()},{merge:true});
      this.event(tx,ref,automatic?'autoApproved':'customerApproved',{status:'approved'});
    });
    return {ok:true};
  }
  async rate(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId);
    if(!Number.isInteger(data.stars)||data.stars<1||data.stars>5)fail('invalid-argument','Choose 1 to 5 stars.');
    const tags=data.tags??[];
    if(!Array.isArray(tags)||tags.length>5||new Set(tags).size!==tags.length||tags.some(t=>!['Spotless','On time','Polite','Missed a spot','Late'].includes(t)))fail('invalid-argument','Choose the available rating tags.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),s=await tx.get(ref),o=s.data();
      if(!o||o.customerId!==uid||o.status!=='approved')fail('permission-denied','Only the customer can rate an approved wash.');
      if(o.rating)fail('already-exists','This wash has already been rated.');
      const c=await tx.get(this.db.doc(`captains/${o.captainId}`)),count=c.data().ratingCount??0,sum=c.data().ratingSum??0;
      tx.update(ref,{rating:data.stars,ratingTags:tags,updatedAt:stamp()});tx.update(c.ref,{ratingCount:count+1,ratingSum:sum+data.stars,rating:(sum+data.stars)/(count+1),updatedAt:stamp()});
    });
    return {ok:true};
  }
  async cancel(auth,data,{expired = false, paymentExpired = false} = {}) {
    const uid=expired||paymentExpired?auth.uid:this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const [s,cfg]=await Promise.all([tx.get(ref),tx.get(this.db.doc('config/operations'))]),o=s.data();
      if(!o||o.customerId!==uid)fail('permission-denied','This booking is not yours.');
      if(o.status==='cancelled')return;
      if(paymentExpired && (o.status!=='pendingPayment'||dateMillis(o.paymentExpiresAt)>this.now()))return;
      if(expired && (dateMillis(o.slotEnd)>this.now() || o.arrivedAt))return;
      if(!['pendingPayment','searching','onTheWay'].includes(o.status))fail('failed-precondition','Contact support to cancel a wash that has started.');
      const benefit=!expired&&!paymentExpired?cancellationBenefit(o,this.now()):null;
      const fee=!benefit&&!expired&&o.status==='onTheWay'?cfg.data()?.cancellationFeePaise:0;
      if(!Number.isSafeInteger(fee)||fee<0||fee>o.pricePaise)fail('failed-precondition','Cancellation terms are not configured. Contact support.');
      const slot=o.capacityReserved?await tx.get(this.db.doc(`slotCapacity/${o.slotKey}`)):null;
      const captain=o.captainId?await tx.get(this.db.doc(`captains/${o.captainId}`)):null;
      const offers=await tx.get(this.db.collection('jobOffers').where('orderId','==',orderId));
      const wallet=await tx.get(this.walletRef(uid,o.paymentMode));
      const refund=o.paymentStatus==='captured'&&!benefit&&o.pricePaise>0;
      tx.update(ref,{status:'cancelled',cancelledAt:stamp(),capacityReserved:false,walletReleased:!!o.walletReserved,
        ...(benefit?{cancellationBenefit:benefit}:{}),cancellationReason:paymentExpired?'paymentExpired':expired?'slotExpired':'customerCancelled',
        refundStatus:refund?'queued':'none',refundAmountPaise:refund?o.pricePaise-fee:0,updatedAt:stamp()});
      this.restoreWallet(tx,wallet,o,benefit);
      if(slot)tx.set(slot.ref,{reserved:Math.max(0,(slot.data()?.reserved??1)-1)},{merge:true});
      if(captain?.exists)tx.update(captain.ref,{activeJobCount:Math.max(0,(captain.data().activeJobCount??1)-1),updatedAt:stamp()});
      for(const offer of offers.docs)tx.update(offer.ref,{status:'withdrawn',updatedAt:stamp()});
      if(refund)tx.set(this.db.doc(`refunds/${orderId}`),{bookingId:orderId,customerId:uid,paymentId:o.razorpayPaymentId,amount:o.pricePaise-fee,paymentMode:o.paymentMode,paymentMerchant:o.paymentMerchant??'trustkeyper',status:'queued',createdAt:stamp()});
      this.event(tx,ref,'customerCancelled',{status:'cancelled'});
    });
    return {ok:true};
  }
  async reportProblem(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),kind=id(data.kind),note=text(data.note??'',0,1000,'problem description');
    if(!['notClean','damage','wrongVehicle','noShow'].includes(kind))fail('invalid-argument','Choose a problem.');
    const photoCount=data.photoCount??0,photos=[];
    if(!Number.isInteger(photoCount)||photoCount<0||photoCount>3)fail('invalid-argument','Add up to three problem photos.');
    const prior=(await this.db.doc(`orders/${orderId}`).get()).data();
    if(!prior||prior.customerId!==uid)fail('permission-denied','This booking is not yours.');
    const sameReport=o=>o.dispute?.kind===kind&&o.dispute.note===note&&(o.dispute.photos??[]).length===photoCount;
    if(sameReport(prior))return {ok:true};
    for(let i=0;i<photoCount;i++){
      const path=`orders/${orderId}/problems/${uid}_${i}.jpg`,meta=await this.evidence.metadata(path);
      if(!meta||!/^image\/(jpeg|png|webp)$/.test(meta.contentType)||Number(meta.size)<=0||Number(meta.size)>8*1024*1024)fail('invalid-argument','Upload each problem photo before sending the report.');
      photos.push(path);
    }
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),o=(await tx.get(ref)).data();
      if(o?.customerId===uid&&sameReport(o))return;
      if(!o||o.customerId!==uid||!['photosReady','approved'].includes(o.status))fail('permission-denied','A problem cannot be opened for this booking.');
      tx.update(ref,{status:'disputed',dispute:{kind,note,photos,outcome:kind==='damage'?'damagePriority':'underReview',createdAt:Timestamp.fromMillis(this.now())},updatedAt:stamp()});
      tx.set(this.db.doc(`supportTickets/${orderId}`),{customerId:uid,orderId,captainId:o.captainId,kind,note,photos,priority:kind==='damage'?'damage':'normal',status:'open',createdAt:stamp()});
      tx.set(this.db.doc(`earnings/${orderId}`),{status:'onHold',updatedAt:stamp()},{merge:true});
      this.event(tx,ref,'problemReported',{status:'disputed'});
    });
    return {ok:true};
  }
  async supportRequest(auth,data) {
    const uid=this.actor(auth),requestId=id(data.requestId),kind=data.kind,note=text(data.note,5,1000,'your message');
    if(!['booking','payment','phoneChange','accountDeletion','other'].includes(kind))fail('invalid-argument','Choose a support topic.');
    const ref=this.db.doc(`supportTickets/${hash(`${uid}:${requestId}`)}`),state=this.db.doc(`supportState/${uid}`);
    await this.db.runTransaction(async tx=>{
      const [old,rate]=await Promise.all([tx.get(ref),tx.get(state)]);
      if(old.exists)return;
      if(dateMillis(rate.data()?.lastRequestAt)>this.now()-60000)fail('resource-exhausted','Your previous request is saved. Wait one minute before sending another.');
      tx.set(ref,{customerId:uid,kind,note,status:'open',createdAt:stamp(),updatedAt:stamp()});
      tx.set(state,{lastRequestAt:Timestamp.fromMillis(this.now())});
    });
    return {requestId:ref.id,status:'open'};
  }
  async registerPushToken(auth,data) {
    const uid=this.actor(auth),token=text(data.token,20,4096,'notification registration'),role=data.role;
    if(!['customer','captain'].includes(role))fail('invalid-argument','Invalid app.');
    await this.db.runTransaction(async tx=>{
      const profile=(await tx.get(this.db.doc(`users/${uid}`))).data();
      if(profile?.[`${role}PushEnabled`]!==true)fail('permission-denied','Enable notifications first.');
      tx.set(this.db.doc(`deviceTokens/${hash(token)}`),{uid,token,role,updatedAt:stamp()});
    });
    return {ok:true};
  }
  async setPushPreference(auth,data) {
    const uid=this.actor(auth),{role,enabled}=data;
    if(!['customer','captain'].includes(role)||typeof enabled!=='boolean')fail('invalid-argument','Choose a notification preference.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`users/${uid}`),profile=await tx.get(ref);
      const devices=enabled?null:await tx.get(this.db.collection('deviceTokens').where('uid','==',uid));
      if(!profile.exists)fail('failed-precondition','Complete your account first.');
      tx.update(ref,{[`${role}PushEnabled`]:enabled,updatedAt:stamp()});
      for(const d of devices?.docs??[])if(d.data().role===role)tx.delete(d.ref);
    });
    return {ok:true};
  }
  async removePushToken(auth,data) {
    const uid=this.actor(auth),token=text(data.token,20,4096,'notification registration'),ref=this.db.doc(`deviceTokens/${hash(token)}`);
    await this.db.runTransaction(async tx=>{const s=await tx.get(ref);if(s.data()?.uid===uid)tx.delete(ref);});
    return {ok:true};
  }
  async readNotification(auth,data) {
    const uid=this.actor(auth),action=data.action??'read',ids=data.notificationIds??[data.notificationId];
    if(!['read','unread','delete'].includes(action)||!Array.isArray(ids)||ids.length<1||ids.length>100)fail('invalid-argument','Choose up to 100 notifications.');
    const refs=[...new Set(ids.map(v=>id(v)))].map(v=>this.db.doc(`notifications/${v}`));
    await this.db.runTransaction(async tx=>{
      const docs=await Promise.all(refs.map(r=>tx.get(r)));
      if(docs.some(s=>s.data()?.recipientId!==uid))fail('permission-denied','This update is not yours.');
      for(const doc of docs)tx.update(doc.ref,action==='delete'?{deletedAt:stamp(),read:true}:{read:action==='read'});
    });
    return {ok:true};
  }
  async notificationPreferences(auth,data) {
    const uid=this.actor(auth),{role,enabled,soundOn,quietHours,mutedUntil,offCategories}=data;
    const categories=role==='captain'?['jobs','money','level','account']:['bookings','payments','offers','account'];
    if(!['captain','customer'].includes(role)||[enabled,soundOn,quietHours].some(v=>typeof v!=='boolean')||!Array.isArray(offCategories)||offCategories.length>3||offCategories.some(v=>!categories.includes(v)||v==='account')||new Set(offCategories).size!==offCategories.length||!(mutedUntil===null||(Number.isInteger(mutedUntil)&&mutedUntil>=0&&mutedUntil<=this.now()+31*86400000)))fail('invalid-argument','Check your notification settings.');
    const ref=this.db.doc(`users/${uid}`);
    await this.db.runTransaction(async tx=>{
      if(!(await tx.get(ref)).exists)fail('failed-precondition','Complete your account first.');
      tx.update(ref,{[`notificationPreferences.${role}`]:{enabled,soundOn,quietHours,mutedUntil,offCategories},[`${role}PushEnabled`]:enabled,updatedAt:stamp()});
    });
    return {ok:true};
  }
  // These two operations are deliberately not exported as client callables.
  // operator.cjs authenticates the project owner through Google IAM.
  async checkBookingDeadline(orderId){
    const ref=this.db.doc(`orders/${id(orderId)}`),o=(await ref.get()).data();
    if(!o)return;
    if(o.status==='photosReady'&&o.autoApproveAt&&dateMillis(o.autoApproveAt)<=this.now())return this.approve(null,{orderId},{automatic:true});
    if(o.status==='searching'&&dateMillis(o.lastSlotEnd??o.slotEnd)<=this.now())return this.cancel({uid:o.customerId},{orderId},{expired:true});
    if(o.status!=='onTheWay'||dateMillis(o.slotEnd)>this.now())return;
    const deadline=Math.floor((dateMillis(o.slotEnd)+19800000)/86400000+1)*86400000-19800000-60000;
    if(this.now()>=deadline)return this.cancel({uid:o.customerId},{orderId},{expired:true});
    await this.db.runTransaction(async tx=>{
      const fresh=(await tx.get(ref)).data();
      if(fresh?.status!=='onTheWay')return;
      tx.update(ref,{noShowChecking:true,runningLateMinutes:Math.max(1,Math.ceil((this.now()-dateMillis(fresh.slotEnd))/60000)),noShowCancelAt:Timestamp.fromMillis(deadline),updatedAt:stamp()});
      if(!fresh.noShowChecking)this.event(tx,ref,'washStatusCheck');
    });
  }
  async resolveDispute(data) {
    const orderId=id(data.orderId),outcome=data.outcome,note=text(data.note,5,1000,'review decision'),bonus=data.bonusFreeWashes??0;
    if(!['upheld','rejected','damagePriority'].includes(outcome)||!Number.isInteger(bonus)||bonus<0||bonus>10||(outcome!=='upheld'&&bonus))fail('invalid-argument','Choose an explicit review decision and bonus.');
    const ref=this.db.doc(`orders/${orderId}`);
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(ref)).data();
      if(!o?.dispute)fail('failed-precondition','This booking has no problem report.');
      if(o.dispute.outcome===outcome&&['upheld','rejected'].includes(outcome))return;
      if(o.status!=='disputed'||!['underReview','damagePriority'].includes(o.dispute.outcome))fail('failed-precondition','This report is already resolved.');
      const [captain,wallet,refund]=await Promise.all([tx.get(this.db.doc(`captains/${o.captainId}`)),tx.get(this.walletRef(o.customerId,o.paymentMode)),tx.get(this.db.doc(`refunds/${orderId}`))]);
      const restore=outcome==='upheld'&&o.walletReserved&&!o.walletReleased;
      const free=(wallet.data()?.freeWashes??0)+(restore&&o.freeWashUsed?1:0)+bonus;
      const credit=(wallet.data()?.creditPaise??0)+(restore?o.creditUsedPaise??0:0);
      tx.update(ref,{status:outcome==='upheld'?'disputeUpheld':outcome==='rejected'?'approved':'disputed',dispute:{...o.dispute,outcome,decisionNote:note,creditsAwarded:bonus,decidedAt:stamp()},...(outcome==='upheld'?{refundStatus:o.pricePaise>0?'queued':'none',refundAmountPaise:o.pricePaise,walletReleased:!!o.walletReserved}:{}),updatedAt:stamp()});
      tx.set(this.db.doc(`supportTickets/${orderId}`),{status:outcome==='damagePriority'?'open':'resolved',decision:outcome,decisionNote:note,updatedAt:stamp()},{merge:true});
      if(outcome!=='damagePriority'){
        tx.set(this.db.doc(`earnings/${orderId}`),{status:outcome==='upheld'?'voided':'approved',updatedAt:stamp()},{merge:true});
        if(captain.exists&&!o.approvedAt)tx.update(captain.ref,{activeJobCount:Math.max(0,(captain.data().activeJobCount??1)-1),...(outcome==='rejected'?{completedWashes:(captain.data().completedWashes??0)+1}:{}),updatedAt:stamp()});
      }
      if(outcome==='upheld'){
        if(restore||bonus)tx.set(wallet.ref,{customerId:o.customerId,paymentMode:o.paymentMode,freeWashes:free,creditPaise:credit,updatedAt:stamp()},{merge:true});
        if(o.pricePaise>0&&!refund.exists)tx.set(refund.ref,{bookingId:orderId,customerId:o.customerId,paymentId:o.razorpayPaymentId,amount:o.pricePaise,paymentMode:o.paymentMode,paymentMerchant:o.paymentMerchant??'trustkeyper',status:'queued',createdAt:stamp()});
      }
      this.event(tx,ref,'disputeReviewed',{outcome});
    });return {ok:true};
  }
  async recordPayout(data) {
    const captainId=id(data.captainId),mode=data.paymentMode,reference=text(data.reference,6,100,'verified transfer reference'),ids=data.earningIds;
    if(data.verifiedTransfer!==true||!['test','live'].includes(mode)||!Array.isArray(ids)||!ids.length||ids.length>100||new Set(ids).size!==ids.length)fail('invalid-argument','Confirm a completed transfer and its exact earnings.');
    const payoutId=hash(`${mode}:${reference}`),ref=this.db.doc(`captains/${captainId}`),payoutRef=this.db.doc(`payoutRecords/${payoutId}`);
    await this.db.runTransaction(async tx=>{
      const c=(await tx.get(ref)).data(),earnings=await Promise.all(ids.map(e=>tx.get(this.db.doc(`earnings/${id(e)}`))));
      const recorded=(await tx.get(payoutRef)).data();
      if(!c)fail('failed-precondition','Captain not found.');
      if(recorded){if(recorded.captainId!==captainId||JSON.stringify(recorded.earningIds)!==JSON.stringify(ids))fail('already-exists','This transfer reference is already recorded.');return;}
      if(earnings.some(e=>!e.exists||e.data().captainId!==captainId||e.data().paymentMode!==mode||e.data().status!=='approved'||e.data().payoutId))fail('failed-precondition','Only approved, unpaid earnings in the selected payment mode can be recorded.');
      const amount=earnings.reduce((n,e)=>n+e.data().amount,0);
      if(!Number.isSafeInteger(amount)||amount<=0)fail('failed-precondition','No positive payable amount.');
      const payout={id:payoutId,paymentMode:mode,amount,earningIds:ids,reference,destination:c.payout?.method==='bank'?`Bank ending ${c.payout.accountNumber.slice(-4)}`:c.upi??'',paidAt:Timestamp.fromMillis(this.now()),status:'paid',adjustmentPaise:0};
      tx.update(ref,{payouts:[payout,...(c.payouts??[])].slice(0,100),updatedAt:stamp()});
      tx.create(payoutRef,{...payout,captainId,createdAt:stamp()});
      for(const e of earnings)tx.update(e.ref,{payoutId,paidAt:stamp(),updatedAt:stamp()});
      tx.set(this.db.doc(`notifications/${hash(`payout:${payoutId}:${captainId}`)}`),{recipientId:captainId,role:'captain',kind:'payoutSent',payoutId,amount,category:'money',title:'Payout recorded',body:'Open Money to view the completed transfer and reference.',read:false,createdAt:stamp()});
    });return {ok:true,payoutId};
  }
  async captainDisputeResponse(auth,data){
    const uid=this.actor(auth),orderId=id(data.orderId),seconds=data.seconds,path=`orders/${orderId}/dispute_response/${uid}.m4a`;
    const o=(await this.db.doc(`orders/${orderId}`).get()).data();
    if(o?.captainId!==uid||o.status!=='disputed')fail('permission-denied','Only the assigned captain can respond to an open report.');
    if(!Number.isInteger(seconds)||seconds<1||seconds>30)fail('invalid-argument','Record a response of up to 30 seconds.');
    const meta=await this.evidence.metadata(path);
    if(!meta||!['audio/mp4','audio/aac'].includes(meta.contentType)||Number(meta.size)<=0||Number(meta.size)>20*1024*1024)fail('invalid-argument','Upload the voice response first.');
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`orders/${orderId}`),fresh=(await tx.get(ref)).data();
      if(fresh?.captainId!==uid||fresh.status!=='disputed')fail('failed-precondition','This report has already moved on.');
      tx.update(ref,{'dispute.captainResponse':{path,seconds,contentType:meta.contentType,createdAt:stamp()},updatedAt:stamp()});
    });return {ok:true};
  }
  async createDocument(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),kind=data.kind;
    if(!['receipt','evidence'].includes(kind))fail('invalid-argument','Choose a booking document.');
    const ref=this.db.doc(`orders/${orderId}`),profileRef=this.db.doc(`users/${uid}`),token=randomBytes(32).toString('hex');
    await this.db.runTransaction(async tx=>{
      const [snapshot,profile]=await Promise.all([tx.get(ref),tx.get(profileRef)]),o=snapshot.data();
      if(!o||o.customerId!==uid)fail('permission-denied','This booking is not yours.');
      if(kind==='receipt'&&o.paymentStatus!=='captured')fail('failed-precondition','A verified payment is needed for a receipt.');
      if(kind==='evidence'&&!o.dispute)fail('failed-precondition','Open your problem report to download its evidence.');
      if(dateMillis(profile.data()?.lastDocumentAt)>this.now()-2000)fail('resource-exhausted','Wait a moment before downloading another document.');
      tx.set(this.db.doc(`documentDownloads/${hash(token)}`),{customerId:uid,orderId,kind,expiresAt:Timestamp.fromMillis(this.now()+600000),createdAt:stamp()});
      tx.update(profileRef,{lastDocumentAt:Timestamp.fromMillis(this.now())});
    });
    const base=process.env.FUNCTIONS_EMULATOR==='true'?'http://127.0.0.1:5001/demo-wheelio/asia-south1/':'https://asia-south1-wheelio-apps.cloudfunctions.net/';
    return {url:`${base}downloadBookingDocument?token=${token}`};
  }
  async consumeDocument(token) {
    if(typeof token!=='string'||!/^[a-f0-9]{64}$/.test(token))fail('permission-denied','This download link is invalid.');
    const ref=this.db.doc(`documentDownloads/${hash(token)}`);
    return this.db.runTransaction(async tx=>{
      const download=(await tx.get(ref)).data();
      if(!download||download.usedAt||dateMillis(download.expiresAt)<=this.now())fail('permission-denied','Open the booking and request a fresh download link.');
      const o=(await tx.get(this.db.doc(`orders/${download.orderId}`))).data();
      if(!o||o.customerId!==download.customerId)fail('permission-denied','This booking is no longer available.');
      tx.update(ref,{usedAt:stamp()});return {download,order:o};
    });
  }
  async deleteAccount(auth,data) {
    const uid=this.actor(auth),role=data.role??'customer';
    if(!['customer','captain'].includes(role))fail('invalid-argument','Choose the app account to delete.');
    if(data.confirm!==true)fail('invalid-argument','Confirm account deletion first.');
    if(!Number.isFinite(auth.token.auth_time)||this.now()/1000-auth.token.auth_time>300||auth.token.auth_time>this.now()/1000+60)fail('failed-precondition','For your security, sign out and log in again before deleting your account.');
    if(!this.accounts?.deleteUser||!this.evidence.deletePrefix)fail('failed-precondition','Account deletion is temporarily unavailable. Please try again.');
    const userRef=this.db.doc(`users/${uid}`),captainRef=this.db.doc(`captains/${uid}`);
    const remainingRoles=await this.db.runTransaction(async tx=>{
      const [customerJobs,captainJobs,profile,captain]=await Promise.all([
        tx.get(this.db.collection('orders').where('customerId','==',uid)),tx.get(this.db.collection('orders').where('captainId','==',uid)),tx.get(userRef),tx.get(captainRef),
      ]);
      if((role==='customer'?customerJobs:captainJobs).docs.some(d=>['pendingPayment','searching','onTheWay','washing','photosReady','disputed'].includes(d.data().status)))fail('failed-precondition','Finish or cancel your open bookings and resolve reports before deleting your account.');
      if(!profile.exists)fail('failed-precondition','This account is not available.');
      if(profile.data().deletingRole&&profile.data().deletingRole!==role)fail('failed-precondition','Wait for the other app account deletion to finish.');
      const roles=profile.data().roles??['customer',...(captain.exists?['captain']:[])];
      const remaining=roles.filter(r=>r!==role);
      tx.update(userRef,{deletingRole:role,...(!remaining.length?{deletionStatus:'pending'}:{}),updatedAt:stamp()});
      if(role==='captain'&&captain.exists)tx.update(captainRef,{approved:false,online:false,deletionStatus:'pending',updatedAt:stamp()});
      return remaining;
    });
    const commit=async docs=>{for(let i=0;i<docs.length;i+=400){const batch=this.db.batch();for(const [ref,value] of docs.slice(i,i+400))value===null?batch.delete(ref):batch.update(ref,value);await batch.commit();}};
    // Keep other parties' accounting/evidence usable while removing this user's
    // ownership and personal booking details. No client chooses the target UID.
    for(const [field,patch] of [
      ['customerId',{customerId:null,customerFirstName:'Former customer',plate:'',tower:'',floor:'',parking:'',note:'',customerPhotos:{},customerMedia:{},customerDeletedAt:stamp()}],
      ['captainId',{captainId:null,captain:{id:'deleted',name:'Former captain',rating:0,washes:0},captainDeletedAt:stamp()}],
    ]){
      if(remainingRoles.length&&field!==(role==='customer'?'customerId':'captainId'))continue;
      const docs=await this.db.collection('orders').where(field,'==',uid).get();
      if(field==='customerId')for(const d of docs.docs){await this.evidence.deletePrefix(`orders/${d.id}/customer/`);await this.evidence.deletePrefix(`orders/${d.id}/problems/`);}
      await commit(docs.docs.map(d=>[d.ref,patch]));
    }
    for(const [collection,field,remove] of [['payments','customerId',false],['refunds','customerId',false],['earnings','captainId',false],['payoutRecords','captainId',false],['supportTickets','customerId',false],['notifications','recipientId',true],['deviceTokens','uid',true],['addressRequests','customerId',true],['documentDownloads','customerId',true]]){
      const docs=await this.db.collection(collection).where(field,'==',uid).get();
      const selected=docs.docs.filter(d=>!remainingRoles.length||(['notifications','deviceTokens','supportTickets'].includes(collection)?(d.data().role??'customer')===role:field===(role==='customer'?'customerId':'captainId')));
      await commit(selected.map(d=>[d.ref,remove?null:{[field]:null,...(collection==='supportTickets'?{note:''}:{}),accountDeletedAt:stamp()}]));
    }
    await this.evidence.deletePrefix(`profiles/${uid}/${role}.jpg`);
    if(role==='captain'){
      for(const prefix of [`kyc/${uid}/`,`identity/${uid}/`])await this.evidence.deletePrefix(prefix);
      const identityChecks=await this.db.collection('identityChecks').where('captainId','==',uid).get();await commit(identityChecks.docs.map(d=>[d.ref,null]));
      await this.db.recursiveDelete(captainRef);
      const offers=await this.db.collection('jobOffers').where('captainId','==',uid).get();await commit(offers.docs.map(d=>[d.ref,null]));
    }else await commit([[this.walletRef(uid,'test'),null],[this.walletRef(uid,'live'),null],[this.db.doc(`customerState/${uid}`),null]]);
    if(remainingRoles.length){
      await userRef.update({roles:remainingRoles,[`deletedRoles.${role}`]:stamp(),deletingRole:FieldValue.delete(),[`${role}PhotoPath`]:FieldValue.delete(),[`${role}PushEnabled`]:false,[`notificationPreferences.${role}`]:FieldValue.delete(),...(role==='customer'?{savedPlaces:FieldValue.delete(),freeWashes:FieldValue.delete()}:{}),updatedAt:stamp()});
      return {ok:true,deleted:true,role,identityDeleted:false};
    }
    await this.evidence.deletePrefix(`profiles/${uid}/`);
    await commit([[this.db.doc(`supportState/${uid}`),null]]);
    try{await this.accounts.deleteUser(uid);}catch(e){if(e.code!=='auth/user-not-found')throw e;}
    await userRef.set({deletionStatus:'completed',deletedAt:stamp(),updatedAt:stamp()});
    return {ok:true,deleted:true,role,identityDeleted:true};
  }
  async syncVerifiedPhone(auth) {
    const uid=this.actor(auth),phone=auth.token.phone_number;
    await this.db.runTransaction(async tx=>{
      const ref=this.db.doc(`users/${uid}`),captainRef=this.db.doc(`captains/${uid}`),[profile,captain]=await Promise.all([tx.get(ref),tx.get(captainRef)]);
      if(!profile.exists)fail('failed-precondition','Complete your account first.');
      if(profile.data().phone===phone)return;
      tx.update(ref,{phone,updatedAt:stamp()});
      if(captain.exists)tx.update(captainRef,{phone,updatedAt:stamp()});
      for(const role of ['customer',...(captain.exists?['captain']:[])])tx.set(this.db.doc(`notifications/${hash(`${uid}:phone:${phone}:${role}`)}`),{recipientId:uid,role,kind:'phoneChanged',category:'account',title:'Phone number changed',body:'Your verified mobile number was updated.',read:false,createdAt:stamp()});
    });return {ok:true,phone};
  }
  async profilePhoto(auth,data) {
    const uid=this.actor(auth),role=data.role;
    if(!['customer','captain'].includes(role)||typeof data.remove!=='boolean')fail('invalid-argument','Choose your app profile.');
    const path=`profiles/${uid}/${role}.jpg`;
    if(!data.remove){
      const meta=await this.evidence.metadata(path);
      if(!meta||!/^image\/(jpeg|png|webp)$/.test(meta.contentType)||Number(meta.size)<=0||Number(meta.size)>8*1024*1024)fail('invalid-argument','Choose a profile photo smaller than 8 MB.');
    }
    await this.db.doc(`users/${uid}`).update({[`${role}PhotoPath`]:data.remove?null:path,updatedAt:stamp()});
    return {path:data.remove?null:path};
  }
  async savePlace(auth,data) {
    const uid=this.actor(auth),cfg=await this.config(),society=cfg.societies?.find(s=>s.id===data.societyId&&s.active);
    if(!society)fail('failed-precondition','Choose a served society.');
    const place={societyId:society.id,societyName:society.name,area:society.area??'',city:society.city??'',pincode:society.pincode??'',tower:text(data.tower??'',0,100,'tower'),floor:text(data.floor??'',0,50,'floor'),parking:text(data.parking??'',0,50,'parking'),vehiclePosition:validPosition(data.vehiclePosition)?{latitude:data.vehiclePosition.latitude,longitude:data.vehiclePosition.longitude}:null};
    place.id=hash(`${place.societyId}:${place.tower}:${place.floor}:${place.parking}`);
    const ref=this.db.doc(`users/${uid}`);
    await this.db.runTransaction(async tx=>{
      const profile=(await tx.get(ref)).data();
      if(!profile)fail('failed-precondition','Complete your account first.');
      tx.update(ref,{savedPlaces:[place,...(profile.savedPlaces??[]).filter(p=>p.id!==place.id)].slice(0,20),updatedAt:stamp()});
    });return {place};
  }
  async vehicleHelp(auth,data) {
    const uid=this.actor(auth),orderId=id(data.orderId),ref=this.db.doc(`orders/${orderId}`),{action,value}=data;
    if(!['request','answer'].includes(action)||!(action==='request'?['empty','differentVehicle','floor']:['other_floor','outside','not_here']).includes(value))fail('invalid-argument','Choose one of the displayed answers.');
    if(action==='answer'&&value==='not_here')return this.cancel(auth,{orderId});
    await this.db.runTransaction(async tx=>{
      const o=(await tx.get(ref)).data();
      if(!o||o.status!=='onTheWay'||(action==='request'?o.captainId:o.customerId)!==uid)fail('permission-denied','This action is not available for this booking.');
      if(action==='answer'&&o.vehicleHelp?.status!=='waiting')fail('failed-precondition','Your captain has no open vehicle request.');
      const help=action==='request'?{status:'waiting',reason:value,requestedAt:Timestamp.fromMillis(this.now())}:{...o.vehicleHelp,status:'answered',answer:value,answeredAt:Timestamp.fromMillis(this.now())};
      tx.update(ref,{vehicleHelp:help,updatedAt:stamp()});
      this.event(tx,ref,action==='request'?'vehicleHelpRequested':'vehicleHelpAnswered',{answer:value});
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
      const order=(await this.db.doc(`orders/${bookingId}`).get()).data();
      const payments=this.getPayments(order?.paymentMode??data.paymentMode??'test',order?.paymentMerchant??data.paymentMerchant);
      const request={paymentId:data.paymentId,amount:data.amount,refundId:`wh_${bookingId}`};
      const refund=data.providerRefundId ? await payments.fetchRefund(data.providerRefundId)
        : await payments.findRefund(request) ?? await payments.refund(request);
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
