import {createHash,randomUUID} from 'node:crypto';
import {Timestamp,FieldValue,FieldPath} from 'firebase-admin/firestore';
import {requireCaptainReviewer,CaptainReviewError} from './captain-review.mjs';
const fail=(code,message)=>{throw new CaptainReviewError(code,message);};
const clean=(v,max)=>typeof v==='string'?v.trim().slice(0,max):'';
const hash=v=>createHash('sha256').update(v).digest('hex');
const statuses=['new','acknowledged','verified','processing','completed','declined'];
export async function requestDeletion(s,data,ip) {
  if(data.website)return {reference:null}; // Honeypot: no PII persisted.
  const phone=clean(data.phone,20),name=clean(data.name,120),email=clean(data.email,160),reason=clean(data.reason,1000),role=data.role;
  if(!['customer','captain','both'].includes(role)||name.length<2||!/^\+91[6-9]\d{9}$/.test(phone)||email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))fail('invalid-argument','Check the account type, name, mobile number and email.');
  const now=s.now(),day=Math.floor(now/86400000),hour=Math.floor(now/3600000),ref=s.db.doc('accountDeletionRequests/'+hash(phone+':'+role+':'+day)),limits=[s.db.doc('deletionRequestLimits/'+hash('ip:'+ip+':'+hour)),s.db.doc('deletionRequestLimits/'+hash('phone:'+phone+':'+day))];
  return s.db.runTransaction(async tx=>{
    const [old,...rates]=await Promise.all([tx.get(ref),...limits.map(r=>tx.get(r))]);
    if(old.exists)return {reference:old.data().reference};
    if(rates.some((d,i)=>(d.data()?.count??0)>=(i===0?5:2)))fail('resource-exhausted','Too many requests. Please contact info@washkrew.com.');
    const reference='DEL-'+randomUUID().toUpperCase();
    tx.create(ref,{reference,name,phone,email,reason,role,source:'washkrew.com/delete-account',status:'new',createdAt:Timestamp.fromMillis(now),acknowledgeBy:Timestamp.fromMillis(now+2*86400000),dueAt:Timestamp.fromMillis(now+90*86400000),updatedAt:Timestamp.fromMillis(now),version:1});
    for(let i=0;i<limits.length;i++)tx.set(limits[i],{count:(rates[i].data()?.count??0)+1,expiresAt:Timestamp.fromMillis(now+2*86400000)});
    return {reference};
  });
}
export async function listDeletionRequests(s,auth,data) {
  await requireCaptainReviewer(s,auth);
  if(data.status&&!statuses.includes(data.status)&&data.status!=='all')fail('invalid-argument','Choose a request status.');
  let q=s.db.collection('accountDeletionRequests');
  if(data.status&&data.status!=='all')q=q.where('status','==',data.status);
  q=q.orderBy(FieldPath.documentId());
  if(data.cursor){if(!/^[a-f0-9]{64}$/.test(data.cursor))fail('invalid-argument','Refresh the request list.');q=q.startAfter(data.cursor);}
  const rows=await q.limit(31).get();
  return {requests:rows.docs.slice(0,30).map(d=>({...d.data(),id:d.id,createdAt:d.data().createdAt.toMillis(),dueAt:d.data().dueAt.toMillis()})),nextCursor:rows.size>30?rows.docs[29].id:null};
}
export async function reviewDeletionRequest(s,auth,data) {
  const reviewer=await requireCaptainReviewer(s,auth,{fresh:true});
  if(!/^[a-f0-9]{64}$/.test(data.id??'')||!Number.isSafeInteger(data.version)||!['acknowledged','verified','completed','declined'].includes(data.status)||typeof data.note!=='string'||data.note.trim().length<5||data.note.length>1000)fail('invalid-argument','Select a request and record your review note.');
  const ref=s.db.doc('accountDeletionRequests/'+data.id),note=data.note.trim(),lease=randomUUID();
  let verifiedUid=null;
  if(data.status==='verified'){const existing=(await ref.get()).data();if(!existing)fail('not-found','Request not found.');try{verifiedUid=(await s.accounts.findByPhone(existing.phone)).uid;}catch(e){if(e.code!=='auth/user-not-found')throw e;}}
  const request=await s.db.runTransaction(async tx=>{
    const d=(await tx.get(ref)).data();if(!d)fail('not-found','Request not found.');
    if(d.version!==data.version)fail('aborted','This request changed. Refresh before reviewing.');
    if(['completed','declined'].includes(d.status))fail('failed-precondition','This request is already closed.');
    if((d.leaseUntil?.toMillis()??0)>s.now())fail('aborted','Cleanup is already running. Refresh shortly.');
    if(data.status==='verified'&&(!['acknowledged','verified','processing'].includes(d.status)||data.ownershipConfirmed!==true))fail('failed-precondition','Acknowledge first, contact the registered number and confirm ownership. Never ask for an SMS code.');
    if(data.status==='completed'&&(!['verified','processing'].includes(d.status)||!d.verifiedBy||s.now()-(d.verifiedAt?.toMillis()??0)>7*86400000||data.confirmDeletion!==true))fail('failed-precondition','Verify ownership first, then explicitly confirm permanent deletion.');
    if(data.status==='acknowledged'&&d.status!=='new')fail('failed-precondition','Only new requests can be acknowledged.');
    tx.update(ref,{status:data.status==='completed'?'processing':data.status,version:d.version+1,reviewer:reviewer.email,note,updatedAt:Timestamp.fromMillis(s.now()),...(data.status==='verified'?{verifiedBy:reviewer.email,verifiedUid,verifiedAt:Timestamp.fromMillis(s.now())}:{}),...(data.status==='completed'?{lease,leaseUntil:Timestamp.fromMillis(s.now()+240000)}:{}),...(data.status==='declined'?{closedAt:Timestamp.fromMillis(s.now())}:{})});
    tx.create(ref.collection('reviews').doc(),{reviewer:reviewer.email,action:data.status,note,createdAt:Timestamp.fromMillis(s.now())});
    return d;
  });
  if(data.status!=='completed')return {ok:true};
  try {
    // Resolve the verified phone with Admin Auth. Never trust a browser-supplied
    // UID or manufacture a phone sign-in. This path is private operator cleanup.
    let user;try{user=await s.accounts.findByPhone(request.phone);}catch(e){if(e.code!=='auth/user-not-found')throw e;}
    if((user?.uid??null)!==(request.verifiedUid??null))fail('failed-precondition','This number now has a different account. Verify ownership again.');
    if(user){
      const profile=(await s.db.doc('users/'+user.uid).get()).data();
      if(profile?.phone!==request.phone&&!profile?.deletionStatus)fail('failed-precondition','Registered account details changed. Verify ownership again.');
      for(const role of request.role==='both'?['customer','captain']:[request.role]){
        const current=(await s.db.doc('users/'+user.uid).get()).data();
        if(current?.deletionStatus==='completed')break;
        if(current?.deletedRoles?.[role]||current?.roles&&!current.roles.includes(role))continue;
        await s.deleteAccount(null,{role,confirm:true},{operatorOwner:user.uid});
      }
    }
    await ref.update({status:'completed',closedAt:Timestamp.fromMillis(s.now()),updatedAt:Timestamp.fromMillis(s.now()),lease:FieldValue.delete(),leaseUntil:FieldValue.delete(),version:FieldValue.increment(1)});
    return {ok:true};
  }catch(e){await ref.update({lease:FieldValue.delete(),leaseUntil:FieldValue.delete()});throw e;}
}
