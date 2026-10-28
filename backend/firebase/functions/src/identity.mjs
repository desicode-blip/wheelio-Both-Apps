import {randomUUID} from 'node:crypto';
import {Timestamp,FieldValue} from 'firebase-admin/firestore';
import {PhotoCheckError} from './photo-checks.mjs';
import {photoModeEnabled} from './photo-policy.mjs';
const fail=(code,message)=>{throw new PhotoCheckError(code,message);};
const orderId=value=>{if(!/^[A-Za-z0-9_-]{1,100}$/.test(value??''))fail('invalid-argument','Invalid booking.');return value;};
export async function beginIdentity(service,auth,data){
  const uid=service.actor(auth),oid=orderId(data.orderId),session=randomUUID(),ref=service.db.doc(`identityChecks/${oid}`),now=service.now();
  const cfg=(await service.db.doc('privateConfig/photoChecks').get()).data();
  return service.db.runTransaction(async tx=>{
    const [order,cap,previous]=await Promise.all([tx.get(service.db.doc(`orders/${oid}`)),tx.get(service.db.doc(`captains/${uid}`)),tx.get(ref)]),o=order.data(),p=previous.data();
    if(o?.captainId!==uid||!cap.data()?.approved||o.status!=='onTheWay'||!o.arrivedAt)fail('permission-denied','Arrive at your assigned vehicle before this check.');
    if(!photoModeEnabled(cfg,o.paymentMode))fail('failed-precondition','Identity checks need operations setup for this booking mode.');
    if(o.identityStatus==='verified')return {verified:true};
    const recent=p?.captainId===uid&&now-(p.windowStartAt?.toMillis()??0)<3600000;
    if(recent&&(p.attemptCount>=5||now-p.updatedAt.toMillis()<5000))fail('resource-exhausted','Please wait before another selfie attempt, or ask Help for a review.');
    const path=`identity/${uid}/${oid}/${session}.jpg`;
    tx.update(order.ref,{identityCaptureSession:session,identityCaptureExpiresAt:Timestamp.fromMillis(now+5*60000)});
    tx.set(ref,{orderId:oid,captainId:uid,session,path,status:'uploading',priorPaths:[...(p?.priorPaths??[]),...(p?.path?[p.path]:[])].slice(-128),attemptCount:recent?p.attemptCount+1:1,windowStartAt:recent?p.windowStartAt:Timestamp.fromMillis(now),updatedAt:Timestamp.fromMillis(now),expiresAt:Timestamp.fromMillis(now+24*3600000)});
    return {session,path};
  });
}
export async function verifyIdentity(service,auth,data){
  const uid=service.actor(auth),oid=orderId(data.orderId),ref=service.db.doc(`identityChecks/${oid}`),p=(await ref.get()).data(),orderRef=service.db.doc(`orders/${oid}`),o=(await orderRef.get()).data();
  const currentCapture=order=>order?.captainId===uid&&order.status==='onTheWay'&&order.identityCaptureSession===data.session&&(order.identityCaptureExpiresAt?.toMillis()??0)>service.now();
  if(!p||p.captainId!==uid||p.session!==data.session||p.status!=='uploading'||p.expiresAt.toMillis()<service.now()||!currentCapture(o))fail('permission-denied','Reopen the identity check for your assigned job.');
  if(!photoModeEnabled((await service.db.doc('privateConfig/photoChecks').get()).data(),o.paymentMode))fail('failed-precondition','Identity checks need operations setup for this booking mode.');
  const lease=randomUUID();
  await service.db.runTransaction(async tx=>{const [check,order]=await Promise.all([tx.get(ref),tx.get(orderRef)]);if(check.data()?.session!==p.session||check.data()?.status!=='uploading'||!currentCapture(order.data()))fail('failed-precondition','Reopen the current identity attempt before checking.');tx.update(ref,{status:'checking',lease});});
  const baseline=`kyc/${uid}/selfie.jpg`;
  const read=async path=>{const meta=await service.evidence.metadata(path);if(!meta||!/^image\/(jpeg|png|webp)$/.test(meta.contentType)||Number(meta.size)<=0||Number(meta.size)>8*1024*1024)fail('failed-precondition','A clear approved Captain photo and a fresh selfie are required.');return service.evidence.read(path,meta.generation);};
  let result;
  try{const [reference,capture]=await Promise.all([read(baseline),read(p.path)]);result=await service.photoChecks.compare(reference,capture);if(!['candidateMatch','review','retake'].includes(result?.status))fail('unavailable','The photo check did not return a result. Try again.');}
  catch(error){await service.db.runTransaction(async tx=>{const check=(await tx.get(ref)).data();if(check?.session===p.session&&check.lease===lease&&check.status==='checking')tx.update(ref,{status:'uploading'});});throw error;}
  if(!['candidateMatch','review','retake'].includes(result.status))fail('unavailable','The photo check did not return a result. Try again.');
  const verified=result.status==='candidateMatch';
  await service.db.runTransaction(async tx=>{
    const [current,order]=await Promise.all([tx.get(ref),tx.get(orderRef)]);
    if(current.data()?.session!==p.session||(current.data()?.status!=='checking'||current.data()?.lease!==lease)||order.data()?.captainId!==uid||order.data()?.status!=='onTheWay')fail('failed-precondition','This booking changed. Reopen the job.');
    tx.update(ref,{status:verified?'verified':result.status,model:result.model??'opencv-sface-2021dec',...(Number.isFinite(result.score)?{score:result.score}:{}),updatedAt:Timestamp.fromMillis(service.now())});
    tx.update(orderRef,{identityStatus:verified?'verified':result.status,identityCaptureSession:FieldValue.delete(),identityCaptureExpiresAt:FieldValue.delete(),updatedAt:FieldValue.serverTimestamp()});
  });
  if(result.status!=='review'){try{for(const path of [p.path,...(p.priorPaths??[])])await service.evidence.deletePrefix(path);}catch{/* Scheduled private cleanup retries retained captures. */}}
  return {verified,status:result.status,message:verified?'Check complete.':result.status==='retake'?'Show one clearly lit face, close to the camera.':'This photo needs an operations review. Ask Help; your account and earnings are unchanged.'};
}
export async function reviewIdentity(service,data){
  const oid=orderId(data.orderId);if(typeof data.accept!=='boolean'||typeof data.reason!=='string'||data.reason.trim().length<3||data.reason.length>500)fail('invalid-argument','Record the human review and reason.');
  const ref=service.db.doc(`identityChecks/${oid}`),orderRef=service.db.doc(`orders/${oid}`);
  await service.db.runTransaction(async tx=>{const [check,order]=await Promise.all([tx.get(ref),tx.get(orderRef)]),p=check.data(),o=order.data();if(p?.status!=='review'||o?.captainId!==p.captainId||o.status!=='onTheWay'||p.expiresAt.toMillis()<service.now())fail('failed-precondition','Review a current identity-check case first.');tx.update(ref,{status:data.accept?'manualAccepted':'retake',reviewReason:data.reason,reviewedAt:FieldValue.serverTimestamp()});tx.update(orderRef,{identityStatus:data.accept?'verified':'retake',updatedAt:FieldValue.serverTimestamp()});});return {ok:true};
}
