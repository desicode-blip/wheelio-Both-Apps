import {createHash,randomUUID} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {PhotoCheckError} from './photo-checks.mjs';
export const photoFingerprint=o=>createHash('sha256').update(JSON.stringify([0,1,2,3].map(i=>{const e=o.evidence?.[`after_${i}`];return [e?.path,e?.generation,e?.uploadedAt?.toMillis?.()];}))).digest('hex');
const fail=(code,message)=>{throw new PhotoCheckError(code,message);};
export async function checkWashPhotos(service,auth,data){
  const uid=service.actor(auth);if(!/^[A-Za-z0-9_-]{1,100}$/.test(data.orderId??''))fail('invalid-argument','Open your assigned job.');
  const ref=service.db.doc(`orders/${data.orderId}`),cfg=(await service.db.doc('privateConfig/photoChecks').get()).data(),lease=randomUUID(),now=service.now();
  const selected=await service.db.runTransaction(async tx=>{
    const o=(await tx.get(ref)).data();if(o?.captainId!==uid||o.status!=='washing')fail('permission-denied','Only the assigned Captain can check wash photos.');
    if([0,1,2,3].some(i=>!o.evidence?.[`after_${i}`]))fail('failed-precondition','Upload all four after photos first.');
    const fingerprint=photoFingerprint(o),previous=o.photoReview;
    if(previous?.fingerprint===fingerprint&&previous.status!=='checking'&&(previous.status!=='unavailable'||now-(previous.checkedAt?.toMillis()??0)<30000))return {cached:previous};
    if(previous?.status==='checking'&&now-(previous.startedAt?.toMillis()??0)<120000)fail('failed-precondition','Your photos are being checked. Try again in a moment.');
    const recent=now-(previous?.windowStartedAt?.toMillis()??0)<1800000,attempts=recent?(previous?.attempts??0)+1:1;
    if(attempts>5)fail('resource-exhausted','Several photo checks have been requested. Review your photos and ask Help before retrying.');
    tx.update(ref,{photoReview:{fingerprint,status:'checking',lease,startedAt:Timestamp.fromMillis(now),attempts,windowStartedAt:recent?previous.windowStartedAt:Timestamp.fromMillis(now)}});return {o,fingerprint};
  });
  if(selected.cached)return {issues:selected.cached.issues??[],status:selected.cached.status};
  let issues=[],status='checked';
  try{
    if(!cfg?.enabled||!cfg.aiEnabled||cfg.paymentMode!==selected.o.paymentMode)throw Error('Review configuration pending');
    const photos=[];
    for(let i=0;i<4;i++){
      const evidence=selected.o.evidence[`after_${i}`],expected=`orders/${ref.id}/${uid}/after_${i}.jpg`;
      if(evidence.path!==expected)throw Error('Invalid photo reference');
      photos.push(await service.evidence.read(expected,evidence.generation));
    }
    issues=await service.photoChecks.reviewWash(photos);
  }catch{status='unavailable';issues=[{side:0,reason:'Automatic photo checking is unavailable. Review all four photos before sending them to the owner.'}];}
  await service.db.runTransaction(async tx=>{const o=(await tx.get(ref)).data();if(o?.captainId!==uid||o.status!=='washing'||o.photoReview?.lease!==lease||photoFingerprint(o)!==selected.fingerprint)fail('failed-precondition','The photos or booking changed. Check them again.');tx.update(ref,{'photoReview.status':status,'photoReview.issues':issues,'photoReview.checkedAt':Timestamp.fromMillis(service.now())});});
  return {issues,status};
}
