import {randomUUID} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {requireCaptainReviewer,CaptainReviewError} from './captain-review.mjs';
const fail=(code,message)=>{throw new CaptainReviewError(code,message);};
const version=s=>`${s.updateTime.seconds}:${s.updateTime.nanoseconds}`;
export async function getVehiclePricing(s,auth){
 await requireCaptainReviewer(s,auth);
 const snapshot=await s.db.doc('config/operations').get(),cfg=snapshot.data();
 return {version:version(snapshot),currency:'INR',vehicleTypes:(cfg.vehicleTypes??[]).map(v=>({kind:v.kind,name:v.name,pricePaise:v.pricePaise,active:v.active!==false})),platformFeeBps:cfg.platformFeeBps??0};
}
export async function updateVehiclePricing(s,auth,data){
 const reviewer=await requireCaptainReviewer(s,auth,{fresh:true}),prices=data.prices,note=typeof data.note==='string'?data.note.trim():'';
 if(!Array.isArray(prices)||prices.length<1||prices.length>20||new Set(prices.map(v=>v?.kind)).size!==prices.length||prices.some(v=>typeof v?.kind!=='string'||!Number.isSafeInteger(v.pricePaise)||v.pricePaise<100||v.pricePaise>1000000)||note.length<5||note.length>1000||typeof data.expectedVersion!=='string')fail('invalid-argument','Enter valid wash prices from ₹1 to ₹10,000 and a change note.');
 const ref=s.db.doc('config/operations'),audit=s.db.doc('pricingReviews/'+randomUUID());
 await s.db.runTransaction(async tx=>{
  const snapshot=await tx.get(ref),cfg=snapshot.data();
  if(data.expectedVersion!==version(snapshot))fail('aborted','Prices or settings changed. Refresh and review the latest prices before saving.');
  const types=cfg.vehicleTypes??[];
  if(prices.some(v=>!types.some(t=>t.kind===v.kind)))fail('invalid-argument','Edit only existing vehicle categories.');
  const next=types.map(v=>({...v,pricePaise:prices.find(p=>p.kind===v.kind)?.pricePaise??v.pricePaise}));
  tx.update(ref,{vehicleTypes:next,pricingUpdatedAt:FieldValue.serverTimestamp()});
  tx.create(audit,{reviewer,note,before:types.map(v=>({kind:v.kind,pricePaise:v.pricePaise})),after:next.map(v=>({kind:v.kind,pricePaise:v.pricePaise})),createdAt:FieldValue.serverTimestamp()});
 });
 return {ok:true};
}
