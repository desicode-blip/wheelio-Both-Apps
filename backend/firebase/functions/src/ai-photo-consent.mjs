import {Timestamp} from 'firebase-admin/firestore';
export const AI_PHOTO_CONSENT_VERSION='vehicle-after-photos-toggle-v2';
export const LEGACY_AI_PHOTO_CONSENT_VERSION='vehicle-after-photos-v1';
export class AiPhotoConsentError extends Error {constructor(message,code='invalid-argument'){super(message);this.code=code;}}
export function photoAiChoice(input){
  if(input.aiPhotoConsent===undefined)return {allowed:false,version:AI_PHOTO_CONSENT_VERSION,state:'notGiven'};
  if(typeof input.aiPhotoConsent==='boolean'&&input.aiPhotoConsentVersion===LEGACY_AI_PHOTO_CONSENT_VERSION)return {allowed:false,version:AI_PHOTO_CONSENT_VERSION,state:'legacyClient'};
  if(typeof input.aiPhotoConsent!=='boolean'||input.aiPhotoConsentVersion!==AI_PHOTO_CONSENT_VERSION){
    throw new AiPhotoConsentError('Review the current optional Google AI photo permission.');
  }
  return {allowed:input.aiPhotoConsent,version:AI_PHOTO_CONSENT_VERSION,state:input.aiPhotoConsent?'allowed':'declined'};
}
export const customerAllowsPhotoAi=order=>order.aiPhotoConsent?.customer?.allowed===true&&order.aiPhotoConsent.customer.version===AI_PHOTO_CONSENT_VERSION;
export const photoAiRevision=order=>Number.isSafeInteger(order.aiPhotoConsent?.customer?.revision)?order.aiPhotoConsent.customer.revision:0;

export async function setBookingPhotoAi(service,auth,data){
  const uid=service.actor(auth);
  if(!/^[A-Za-z0-9_-]{1,100}$/.test(data.orderId??'')||typeof data.enabled!=='boolean'||data.policyVersion!==AI_PHOTO_CONSENT_VERSION||!Number.isSafeInteger(data.expectedRevision)||data.expectedRevision<0)throw new AiPhotoConsentError('Open the booking and use its current AI photo setting.');
  const ref=service.db.doc(`orders/${data.orderId}`);
  return service.db.runTransaction(async tx=>{
    const o=(await tx.get(ref)).data();
    if(o?.customerId!==uid)throw new AiPhotoConsentError('Only this booking’s Customer can change its AI setting.','permission-denied');
    if(o.paymentStatus!=='captured'||!['searching','onTheWay','washing'].includes(o.status))throw new AiPhotoConsentError('Change the AI setting after payment and before the Captain sends the wash photos.','failed-precondition');
    const revision=photoAiRevision(o),enabled=customerAllowsPhotoAi(o);
    if(enabled===data.enabled)return {enabled,revision,checkMayHaveStarted:!!o.photoReview?.aiSentAt};
    // Turning OFF is always safe, including an older device. A delayed/replayed
    // ON request must never override a newer OFF choice.
    if(data.enabled&&data.expectedRevision!==revision)throw new AiPhotoConsentError('The AI setting changed on another device. Refresh this booking and try again.','aborted');
    const customer={allowed:data.enabled,version:AI_PHOTO_CONSENT_VERSION,revision:revision+1,state:data.enabled?'allowed':'declined',recordedAt:Timestamp.fromMillis(service.now())};
    const patch={'aiPhotoConsent.customer':customer,photoReview:null};
    // Clearing the old lease invalidates in-flight/cached results. The Captain
    // still explicitly sends the four registered photos; no approval occurs here.
    tx.update(ref,patch);
    return {enabled:data.enabled,revision:customer.revision,checkMayHaveStarted:!!o.photoReview?.aiSentAt};
  });
}
