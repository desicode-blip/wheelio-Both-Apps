import {requireCaptainReviewer,CaptainReviewError} from './captain-review.mjs';
import {evidenceFiles} from './evidence-files.mjs';
const fail=(code,message)=>{throw new CaptainReviewError(code,message);};
const version=s=>`${s.updateTime.seconds}:${s.updateTime.nanoseconds}`;
const orderId=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,100}$/.test(value)?value:fail('invalid-argument','Choose a wash report.');
export async function listWashReports(s,auth){
 await requireCaptainReviewer(s,auth);
 const rows=await s.db.collection('orders').where('status','==','disputed').limit(50).get();
 return {reports:rows.docs.filter(d=>d.data().dispute).map(d=>{const o=d.data();return {id:d.id,version:version(d),reference:o.ref,paymentMode:o.paymentMode,kind:o.dispute.kind,note:o.dispute.note,outcome:o.dispute.outcome,createdAt:o.dispute.createdAt?.toMillis?.()??null,
  captainId:o.captainId,customerId:o.customerId,basePricePaise:o.basePricePaise??o.pricePaise,decisionNote:o.dispute.decisionNote??'',media:evidenceFiles(d.id,o).map(f=>f.name)};})};
}
export async function reviewWashReport(s,auth,data){
 const reviewer=await requireCaptainReviewer(s,auth,{fresh:true}),id=orderId(data.orderId),o=(await s.db.doc('orders/'+id).get()).data();
 if(!o||[o.customerId,o.captainId].includes(reviewer.uid))fail('permission-denied','Another authorized reviewer must review this wash.');
 if(data.evidenceReviewed!==true||typeof data.expectedVersion!=='string')fail('failed-precondition','Review the evidence and refresh this report before deciding.');
 return s.resolveDispute({orderId:id,outcome:data.outcome,note:data.note,bonusFreeWashes:0,expectedVersion:data.expectedVersion,reviewer});
}
export async function washReportEvidence(s,auth,data){
 await requireCaptainReviewer(s,auth);
 const id=orderId(data.orderId),o=(await s.db.doc('orders/'+id).get()).data();
 if(!o?.dispute||o.status!=='disputed')fail('not-found','This report is no longer awaiting review.');
 const file=evidenceFiles(id,o).find(f=>f.name===data.name);
 if(!file)fail('not-found','Choose evidence attached to this report.');
 const meta=await s.evidence.metadata(file.path),audio=file.name.endsWith('.m4a');
 if(!meta||!(audio?/^audio\/(mp4|aac)$/:/^image\/(jpeg|png|webp)$/).test(meta.contentType)||!(Number(meta.size)>0&&Number(meta.size)<=(audio?20:8)*1024*1024))fail('not-found','This evidence is not available.');
 return {path:file.path,generation:meta.generation,contentType:meta.contentType};
}
