import {createHash,randomUUID} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {PhotoCheckError} from './photo-checks.mjs';
import {photoModeEnabled} from './photo-policy.mjs';
import {photoAiChoice,customerAllowsPhotoAi,photoAiRevision,AI_PHOTO_CONSENT_VERSION,LEGACY_AI_PHOTO_CONSENT_VERSION} from './ai-photo-consent.mjs';
export const photoFingerprint=o=>createHash('sha256').update(JSON.stringify([0,1,2,3].map(i=>{const e=o.evidence?.[`after_${i}`];return [e?.path,e?.generation,e?.uploadedAt?.toMillis?.()];}))).digest('hex');
const fail=(code,message)=>{throw new PhotoCheckError(code,message);};
class SettingChanged extends Error {}
export async function checkWashPhotos(service,auth,data){
  const uid=service.actor(auth);if(!/^[A-Za-z0-9_-]{1,100}$/.test(data.orderId??''))fail('invalid-argument','Open your assigned job.');
  const protocol=data.requiredConsentPolicyVersion===AI_PHOTO_CONSENT_VERSION?AI_PHOTO_CONSENT_VERSION:LEGACY_AI_PHOTO_CONSENT_VERSION;
  const reply=review=>({issues:review?.issues??[],status:review?.status??'notChecked',consentPolicyVersion:protocol});
  const ref=service.db.doc(`orders/${data.orderId}`),cfg=(await service.db.doc('privateConfig/photoChecks').get()).data(),lease=randomUUID(),now=service.now();
  const selected=await service.db.runTransaction(async tx=>{
    const o=(await tx.get(ref)).data();if(o?.captainId!==uid)fail('permission-denied','Only the assigned Captain can check wash photos.');
    if(['photosReady','approved','disputed','disputeUpheld'].includes(o.status))return {cached:o.photoReview??{status:'manualReview',issues:[]}};
    if(o.status!=='washing')fail('permission-denied','Only the assigned Captain can check wash photos.');
    if([0,1,2,3].some(i=>!o.evidence?.[`after_${i}`]))fail('failed-precondition','Upload all four after photos first.');
    const fingerprint=photoFingerprint(o),previous=o.photoReview,revision=photoAiRevision(o);
    const same=previous?.fingerprint===fingerprint&&previous?.customerRevision===revision;
    if(data.statusOnly)return {cached:same?previous:{status:'notChecked',issues:[]}};
    const choice=photoAiChoice(data),captainConsent={...choice,recordedAt:Timestamp.fromMillis(now)};
    if(!choice.allowed||!customerAllowsPhotoAi(o)){
      const review={fingerprint,status:'manualReview',issues:[],customerRevision:revision,checkedAt:Timestamp.fromMillis(now),reason:!customerAllowsPhotoAi(o)?'customerPermissionNotGranted':'captainPermissionNotGranted'};
      tx.update(ref,{photoReview:review,'aiPhotoConsent.captain':captainConsent});return {cached:review};
    }
    if(same&&previous.status==='checking'&&now-(previous.startedAt?.toMillis()??0)<120000)fail('failed-precondition','Your photos are being checked. Try again in a moment.');
    if(same&&!['checking','manualReview'].includes(previous.status)&&(previous.status!=='unavailable'||now-(previous.checkedAt?.toMillis()??0)<30000))return {cached:previous};
    const rate=o.photoAiRate??previous,recent=now-(rate?.windowStartedAt?.toMillis()??0)<1800000,attempts=recent?(rate?.attempts??0)+1:1;
    if(attempts>5)fail('resource-exhausted','Several photo checks have been requested. Review your photos and ask Help before retrying.');
    const windowStartedAt=recent?rate.windowStartedAt:Timestamp.fromMillis(now);
    tx.update(ref,{'aiPhotoConsent.captain':captainConsent,photoAiRate:{attempts,windowStartedAt},photoReview:{fingerprint,customerRevision:revision,status:'checking',lease,startedAt:Timestamp.fromMillis(now),attempts,windowStartedAt}});
    return {o,fingerprint,revision};
  });
  if(selected.cached)return reply(selected.cached);
  const authorize=async(markSent=false)=>service.db.runTransaction(async tx=>{
    const o=(await tx.get(ref)).data();
    if(o?.captainId!==uid||o.status!=='washing'||!customerAllowsPhotoAi(o)||photoAiRevision(o)!==selected.revision||o.photoReview?.lease!==lease||photoFingerprint(o)!==selected.fingerprint)throw new SettingChanged();
    if(markSent&&!o.photoReview.aiSentAt)tx.update(ref,{'photoReview.aiSentAt':Timestamp.fromMillis(service.now())});
  });
  let issues=[],status='checked';
  try{
    if(!photoModeEnabled(cfg,selected.o.paymentMode)||!cfg.aiEnabled)throw Error('Review configuration pending');
    await authorize();
    const photos=await Promise.all([0,1,2,3].map(async i=>{
      const evidence=selected.o.evidence[`after_${i}`],expected=`orders/${ref.id}/${uid}/after_${i}.jpg`;
      if(evidence.path!==expected)throw Error('Invalid photo reference');return service.evidence.read(expected,evidence.generation);
    }));
    await authorize();issues=await service.photoChecks.reviewWash(photos,{authorize});
  }catch(error){
    status=error instanceof SettingChanged?'settingsChanged':'unavailable';
    if(status==='unavailable')issues=[{side:0,reason:'Automatic photo checking is unavailable. Review all four photos before sending them to the owner.'}];
  }
  const review=await service.db.runTransaction(async tx=>{
    const o=(await tx.get(ref)).data();
    if(o?.captainId!==uid)fail('permission-denied','This job is not yours.');
    if(['photosReady','approved','disputed','disputeUpheld'].includes(o.status))return o.photoReview??{status:'manualReview',issues:[]};
    if(o.status!=='washing'||photoFingerprint(o)!==selected.fingerprint)return {status:'settingsChanged',issues:[]};
    if(!customerAllowsPhotoAi(o)){
      const manual={fingerprint:selected.fingerprint,status:'manualReview',issues:[],customerRevision:photoAiRevision(o),checkedAt:Timestamp.fromMillis(service.now()),reason:'customerTurnedAiOff'};tx.update(ref,{photoReview:manual});return manual;
    }
    if(o.photoReview?.lease!==lease||photoAiRevision(o)!==selected.revision)return {status:'settingsChanged',issues:[]};
    tx.update(ref,{'photoReview.status':status,'photoReview.issues':issues,'photoReview.checkedAt':Timestamp.fromMillis(service.now())});return {status,issues};
  });
  return reply(review);
}
