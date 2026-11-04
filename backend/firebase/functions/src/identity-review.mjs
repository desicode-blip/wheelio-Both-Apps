import {requireCaptainReviewer,CaptainReviewError} from './captain-review.mjs';
export async function listIdentityReviews(s,auth) {
  await requireCaptainReviewer(s,auth);
  const rows=await s.db.collection('identityChecks').where('status','==','review').limit(50).get();
  return {checks:rows.docs.filter(d=>d.data().expiresAt.toMillis()>s.now()).map(d=>({id:d.id,captainId:d.data().captainId,expiresAt:d.data().expiresAt.toMillis(),model:d.data().model??''}))};
}
export async function reviewCaptainIdentity(s,auth,data) {
  const reviewer=await requireCaptainReviewer(s,auth,{fresh:true});
  const check=/^[A-Za-z0-9_-]{1,100}$/.test(data.orderId??'')?(await s.db.doc('identityChecks/'+data.orderId).get()).data():null;
  if(!check||check.captainId===reviewer.uid)throw new CaptainReviewError('permission-denied','Another authorized reviewer must check this selfie.');
  await s.reviewIdentity(data);
  await s.db.doc('identityChecks/'+data.orderId).update({reviewer:reviewer.email});
  return {ok:true};
}
export async function identityReviewEvidence(s,auth,data) {
  await requireCaptainReviewer(s,auth);
  if(!/^[A-Za-z0-9_-]{1,100}$/.test(data.orderId??''))throw new CaptainReviewError('invalid-argument','Choose an identity check.');
  const d=(await s.db.doc('identityChecks/'+data.orderId).get()).data();
  if(d?.status!=='review'||d.expiresAt.toMillis()<=s.now()||!/^identity\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[a-f0-9-]+\.jpg$/.test(d.path??''))throw new CaptainReviewError('not-found','This identity check is no longer available.');
  const meta=await s.evidence.metadata(d.path);
  if(!meta||!/^image\/(jpeg|png|webp)$/.test(meta.contentType))throw new CaptainReviewError('not-found','The selfie is no longer available.');
  return {path:d.path,generation:meta.generation,contentType:meta.contentType};
}
