import {randomUUID} from 'node:crypto';
import {FieldValue,FieldPath} from 'firebase-admin/firestore';

export class CaptainReviewError extends Error {
  constructor(code,message){super(message);this.code=code;}
}
const fail=(code,message)=>{throw new CaptainReviewError(code,message);};
const stamp=()=>FieldValue.serverTimestamp();
const kinds=['aadhaar','selfie','bank'];
const uid=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,128}$/.test(value)?value:fail('invalid-argument','Choose a Captain application.');
const millis=value=>value?.toMillis?.()??null;
const version=s=>s.updateTime?`${s.updateTime.seconds}:${s.updateTime.nanoseconds}`:'';
const validImage=m=>m&&/^image\/(jpeg|png|webp)$/.test(m.contentType)&&Number(m.size)>0&&Number(m.size)<=8*1024*1024;

export async function requireCaptainReviewer(service,auth,{fresh=false}={}){
  if(!auth?.uid)fail('unauthenticated','Sign in with your approved Google account.');
  const t=auth.token??{},email=typeof t.email==='string'?t.email.trim().toLowerCase():'';
  if(t.email_verified!==true||t.firebase?.sign_in_provider!=='google.com')fail('permission-denied','Use a verified Google account approved for Captain reviews.');
  const config=(await service.db.doc('privateConfig/captainReviewers').get()).data();
  if(!config?.emails?.includes(email))fail('permission-denied','This Google account does not have Captain review access.');
  if(fresh&&(!Number.isFinite(t.auth_time)||service.now()/1000-t.auth_time>1800||t.auth_time>service.now()/1000+60))fail('failed-precondition','Verify your Google session again before recording a review.');
  return {uid:auth.uid,email};
}

function summary(snapshot){
  const c=snapshot.data();
  return {id:snapshot.id,name:c.name??'',phone:c.phone??'',status:c.kycStatus??'notSubmitted',approved:c.approved===true,
    paymentMode:c.paymentMode??'test',submittedAt:millis(c.submittedAt),updatedAt:millis(c.updatedAt),version:version(snapshot)};
}

export async function listCaptainApplications(service,auth,data){
  const reviewer=await requireCaptainReviewer(service,auth),status=data.status??'underReview';
  if(!['all','notSubmitted','underReview','changesRequested','approved'].includes(status))fail('invalid-argument','Choose an application status.');
  let query=service.db.collection('captains');
  if(status!=='all')query=query.where('kycStatus','==',status);
  query=query.orderBy(FieldPath.documentId());
  if(data.cursor)query=query.startAfter(uid(data.cursor));
  const [rows,cfg]=await Promise.all([query.limit(31).get(),service.config()]);
  return {reviewer:reviewer.email,paymentMode:cfg.paymentMode??'test',applications:rows.docs.slice(0,30).map(summary),nextCursor:rows.size>30?rows.docs[29].id:null};
}

export async function getCaptainApplication(service,auth,data){
  await requireCaptainReviewer(service,auth);
  const id=uid(data.captainId),[snapshot,cfg]=await Promise.all([service.db.doc(`captains/${id}`).get(),service.config()]);
  if(!snapshot.exists||snapshot.data().deletionStatus)fail('not-found','This Captain application is unavailable.');
  const c=snapshot.data(),photos=await Promise.all(kinds.map(async kind=>({kind,available:validImage(await service.evidence.metadata(`kyc/${id}/${kind}.jpg`))})));
  const history=await snapshot.ref.collection('applicationReviews').orderBy('createdAt','desc').limit(10).get();
  return {...summary(snapshot),workStatus:c.workStatus??null,online:c.online===true,
    requestedSocietyIds:c.requestedSocietyIds??[],societyIds:c.societyIds??[],societies:(cfg.societies??[]).filter(s=>s.active).map(s=>({id:s.id,name:s.name,area:s.area??''})),
    payout:c.payout??(c.upi?{method:'upi',upi:c.upi}:null),workingSlots:c.workingSlots??null,workingWindows:c.workingWindows??[],photos,
    training:{required:cfg.training?.required===true,configured:!!cfg.training?.version,version:cfg.training?.version??null,
      completed:!!cfg.training?.version&&!!c.trainingCompletedAt&&c.trainingVersion===cfg.training.version,quizPassed:!!cfg.training?.version&&!!c.quizPassedAt&&c.trainingVersion===cfg.training.version},
    reviewReason:c.reviewReason??'',reviewIssues:c.reviewIssues??[],paymentModeConfigured:cfg.paymentMode??'test',
    history:history.docs.map(d=>{const r=d.data();return {id:d.id,decision:r.decision,reason:r.reason,reviewer:r.reviewer.email,createdAt:millis(r.createdAt),societyIds:r.societyIds??[]};})};
}

export async function captainReviewEvidence(service,auth,data){
  await requireCaptainReviewer(service,auth);
  const id=uid(data.captainId),kind=data.kind;
  if(!kinds.includes(kind))fail('invalid-argument','Choose an application photo.');
  const c=(await service.db.doc(`captains/${id}`).get()).data();
  if(!c||c.deletionStatus)fail('not-found','This application is unavailable.');
  const path=`kyc/${id}/${kind}.jpg`,metadata=await service.evidence.metadata(path);
  if(!validImage(metadata))fail('not-found','This photo has not been uploaded or is no longer available.');
  return {path,contentType:metadata.contentType,generation:metadata.generation};
}

export async function reviewCaptainApplication(service,auth,data){
  const reviewer=await requireCaptainReviewer(service,auth,{fresh:true}),id=uid(data.captainId),decision=data.decision;
  if(id===reviewer.uid)fail('permission-denied','Another authorized reviewer must review your application.');
  if(!['approve','requestChanges'].includes(decision))fail('invalid-argument','Choose approve or request corrections.');
  if(typeof data.reason!=='string'||data.reason.trim().length<5||data.reason.trim().length>1000)fail('invalid-argument','Write a review note of 5–1000 characters.');
  if(typeof data.expectedVersion!=='string'||!data.expectedVersion)fail('invalid-argument','Refresh the application before reviewing it.');
  const reason=data.reason.trim(),issues=data.issues??[],societyIds=data.societyIds??[];
  if(!Array.isArray(issues)||issues.length>3||issues.some(i=>!['aadhaar','selfie','payout'].includes(i)))fail('invalid-argument','Choose the items that need correction.');
  if(decision==='requestChanges'&&!issues.length)fail('invalid-argument','Choose at least one item to correct.');
  if(decision==='approve'&&(data.identityReviewed!==true||data.payoutReviewed!==true))fail('failed-precondition','Review the identity photos and payout details before approving.');
  const metadata=decision==='approve'?await Promise.all(['aadhaar','selfie'].map(k=>service.evidence.metadata(`kyc/${id}/${k}.jpg`))):[];
  const ref=service.db.doc(`captains/${id}`),reviewId=randomUUID();
  await service.db.runTransaction(async tx=>{
    const [snapshot,config,profile]=await Promise.all([tx.get(ref),tx.get(service.db.doc('config/operations')),tx.get(service.db.doc(`users/${id}`))]);
    const c=snapshot.data(),cfg=config.data();
    if(!c||!profile.exists||c.deletionStatus||profile.data()?.deletionStatus||profile.data()?.deletingRole==='captain')fail('failed-precondition','This Captain account is unavailable.');
    if(c.kycStatus!=='underReview'||c.approved===true)fail('failed-precondition','Only a submitted application awaiting review can be decided.');
    if(version(snapshot)!==data.expectedVersion)fail('aborted','The application changed. Refresh and review the latest details.');
    if(decision==='approve'){
      if(metadata.some(m=>!validImage(m)))fail('failed-precondition','Both identity and selfie uploads are required.');
      if(!['test','live'].includes(cfg?.paymentMode)||c.paymentMode!==cfg.paymentMode)fail('failed-precondition','The application belongs to another payment mode. Review configuration first.');
      if(!Array.isArray(societyIds)||!societyIds.length||societyIds.length>10||new Set(societyIds).size!==societyIds.length||societyIds.some(id=>!c.requestedSocietyIds?.includes(id)||!cfg.societies?.some(s=>s.active&&s.id===id)))fail('invalid-argument','Choose active societies requested by this Captain.');
      const payout=c.payout??{method:'upi',upi:c.upi};
      if(payout.method==='upi'?!/^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$/.test(payout.upi??''):payout.method!=='bank'||!/^\d{9,18}$/.test(payout.accountNumber??''))fail('failed-precondition','Valid payout details are required before approval.');
      if(cfg.training?.required&&(!cfg.training.version||c.trainingVersion!==cfg.training.version||!c.trainingCompletedAt||!c.quizPassedAt))fail('failed-precondition','The current approved training and quiz must be completed first.');
    }
    tx.update(ref,{approved:decision==='approve',kycStatus:decision==='approve'?'approved':'changesRequested',online:false,
      ...(decision==='approve'?{societyIds,approvedAt:stamp(),approvedBy:reviewer.email,payoutReviewedAt:stamp()}:{}),
      reviewReason:reason,reviewIssues:decision==='approve'?[]:[...new Set(issues)],reviewedAt:stamp(),reviewedBy:reviewer.email,updatedAt:stamp()});
    tx.create(ref.collection('applicationReviews').doc(reviewId),{decision,reason,issues:decision==='approve'?[]:issues,societyIds:decision==='approve'?societyIds:[],reviewer,previousVersion:data.expectedVersion,identityReviewed:data.identityReviewed===true,payoutReviewed:data.payoutReviewed===true,createdAt:stamp()});
    tx.create(service.db.doc(`notifications/${reviewId}`),{recipientId:id,role:'captain',category:'account',kind:'applicationReview',title:decision==='approve'?'Your Captain profile is approved':'Your application needs corrections',body:reason,read:false,createdAt:stamp()});
  });
  return {ok:true,decision,captainId:id,reviewId};
}
