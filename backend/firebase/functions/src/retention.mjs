import {logger} from 'firebase-functions';
import {Timestamp,FieldValue,FieldPath} from 'firebase-admin/firestore';
import {walletCredits} from './wallet-credits.mjs';
const DAY=86400000,ms=v=>v?.toMillis?.()??0;
function yearsAfter(at,years){const d=new Date(at);d.setUTCFullYear(d.getUTCFullYear()+years);return d.getTime();}
const terminal=new Set(['approved','disputeUpheld','cancelled']);
// Bounded, restartable scan: document-ID cursors also find older records without
// new retention timestamps. Never set a purge marker before Storage succeeds.
async function page(s,name,visit,limit=40) {
  const state=s.db.doc('retentionCursors/'+name),cursor=(await state.get()).data()?.after;
  let q=s.db.collection(name).orderBy(FieldPath.documentId());if(cursor)q=q.startAfter(cursor);
  const rows=await q.limit(limit).get();
  const dueField=name==='wallets'?'nextExpiryAt':'retentionDueAt';
  const due=await s.db.collection(name).where(dueField,'<=',name==='wallets'?s.now():Timestamp.fromMillis(s.now())).orderBy(dueField).limit(200).get();
  const unique=new Map([...due.docs,...rows.docs].map(d=>[d.id,d]));
  for(const doc of unique.values()){
    try{
      await visit(doc);
      // Backfill older records without a deadline. Due queries find future
      // cleanup independently of total history size; cursor scans are recovery.
      if(name!=='wallets'){
        const current=await doc.ref.get();if(!current.exists)continue;const d=current.data();
        let at=0;
        if(name==='orders'&&!d.mediaPurgedAt)at=(ms(d.slotEnd)||ms(d.cancelledAt)||ms(d.createdAt))+90*DAY;
        else if(name==='captains'&&!d.kycMediaPurgedAt&&['approved','declined'].includes(d.kycStatus))at=(ms(d.reviewedAt)||ms(d.approvedAt))+90*DAY;
        else if(name==='supportTickets'&&['resolved','closed'].includes(d.status))at=yearsAfter(ms(d.closedAt)||ms(d.updatedAt),1);
        else if(name==='accountDeletionRequests'&&['completed','declined'].includes(d.status)&&ms(d.closedAt))at=yearsAfter(ms(d.closedAt),3);
        else if(!['orders','captains','supportTickets','accountDeletionRequests'].includes(name)){const start=ms(d.createdAt)||ms(d.capturedAt)||ms(d.updatedAt);if(start)at=yearsAfter(start,8);}
        if(at)await doc.ref.update({retentionDueAt:Timestamp.fromMillis(Math.max(at,s.now()+3600000))});
      }
    }catch(error){logger.error('Retention cleanup needs a retry',{collection:name,code:error.code??'cleanup'});}
  }
  await state.set({after:rows.size===limit?rows.docs.at(-1).id:null,updatedAt:Timestamp.fromMillis(s.now())});
}
export async function maintainRetention(s) {
  const now=s.now();
  await page(s,'orders',async doc=>{
    const o=doc.data(),end=ms(o.slotEnd)||ms(o.cancelledAt)||ms(o.createdAt);
    if(!terminal.has(o.status)||!end||now-end<90*DAY||o.mediaPurgedAt)return;
    // Lock report creation before deleting. Unresolved disputes are excluded.
    const locked=await s.db.runTransaction(async tx=>{const current=(await tx.get(doc.ref)).data();if(!terminal.has(current?.status)||current.mediaPurgedAt)return false;tx.update(doc.ref,{mediaRetentionStatus:'purging'});return true;});
    if(!locked)return;
    await s.evidence.deletePrefix(`orders/${doc.id}/`);
    await s.db.recursiveDelete(doc.ref.collection('tracking'));
    const events=await doc.ref.collection('events').get();
    for(const e of events.docs){const d=e.data();if(d.position||d.location||d.latitude||d.longitude)await e.ref.set({type:d.type??'retainedEvent',createdAt:d.createdAt??Timestamp.fromMillis(now)});}
    await doc.ref.update({evidence:{},customerPhotos:{},customerMedia:{},problemPhotos:FieldValue.delete(),vehiclePosition:FieldValue.delete(),coverageLocation:FieldValue.delete(),tower:'',floor:'',parking:'',note:'',photoReview:FieldValue.delete(),...(o.dispute?{'dispute.photos':[]}:{}),mediaRetentionStatus:'purged',mediaPurgedAt:Timestamp.fromMillis(now),retentionDueAt:FieldValue.delete()});
  });
  await page(s,'captains',async doc=>{
    const c=doc.data(),decision=ms(c.reviewedAt)||ms(c.approvedAt);
    if(!decision||now-decision<90*DAY||c.kycMediaPurgedAt||!['approved','declined'].includes(c.kycStatus))return;
    // Do not race an active application resubmission / review.
    const locked=await s.db.runTransaction(async tx=>{const d=(await tx.get(doc.ref)).data();if(ms(d?.reviewedAt)!==ms(c.reviewedAt)||d?.kycStatus!==c.kycStatus||d.kycMediaPurgedAt)return false;tx.update(doc.ref,{kycRetentionStatus:'purging'});return true;});
    if(!locked)return;
    await s.evidence.deletePrefix(`kyc/${doc.id}/`);
    await doc.ref.update({kycMediaPurgedAt:Timestamp.fromMillis(now),retentionDueAt:FieldValue.delete(),kycRetentionStatus:'purged',kyc:{},aadhaarPhoto:FieldValue.delete(),selfiePhoto:FieldValue.delete(),identityChecks:FieldValue.delete()});
  });
  await page(s,'supportTickets',async doc=>{
    const t=doc.data(),closed=ms(t.closedAt)||(['resolved','closed'].includes(t.status)?ms(t.updatedAt):0);
    if(!closed||now-closed<365*DAY)return;
    if(t.orderId){const order=(await s.db.doc('orders/'+t.orderId).get()).data();if(order?.status==='disputed')return;}
    await s.db.recursiveDelete(doc.ref);
  });
  await page(s,'accountDeletionRequests',async doc=>{const t=doc.data();if(['completed','declined'].includes(t.status)&&ms(t.closedAt)>0&&now>=yearsAfter(ms(t.closedAt),3))await s.db.recursiveDelete(doc.ref);});
  await page(s,'wallets',async doc=>{await s.db.runTransaction(async tx=>{const d=(await tx.get(doc.ref)).data();if(d)tx.set(doc.ref,{...walletCredits(d,now),updatedAt:Timestamp.fromMillis(now)},{merge:true});});});
  // Financial records are retained for eight years; unresolved obligations stay.
  for(const collection of ['payments','refunds','walletTopups','earnings','payoutRecords'])await page(s,collection,async doc=>{const d=doc.data(),at=ms(d.createdAt)||ms(d.capturedAt)||ms(d.updatedAt);if(at&&now>=yearsAfter(at,8)&&['captured','processed','credited','approved','paid','voided'].includes(d.status))await s.db.recursiveDelete(doc.ref);});
}
