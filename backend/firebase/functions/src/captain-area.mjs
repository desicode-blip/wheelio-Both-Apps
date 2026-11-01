import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {geohashForLocation,geohashQueryBounds} from 'geofire-common';
import {validPosition,metresBetween} from './geography.mjs';
import {normalizeWorkingSlots,windowTimes} from './booking-policy.mjs';

export const areaPolicy=cfg=>cfg?.coveragePolicy==='captainAreaV1';
export const hasArea=c=>validPosition(c?.serviceArea?.center)&&Number.isFinite(c.serviceArea.radiusKm)&&c.serviceArea.radiusKm>=1&&c.serviceArea.radiusKm<=10;
export const covers=(c,p)=>hasArea(c)&&validPosition(p)&&metresBetween(c.serviceArea.center,p)<=c.serviceArea.radiusKm*1000;
const hash=s=>createHash('sha256').update(s).digest('hex').slice(0,32);
export class CaptainAreaError extends Error{constructor(code,message){super(message);this.code=code;}}
const fail=(code,message)=>{throw new CaptainAreaError(code,message);};
export async function resolveLocation(service,cfg,id,tx){
  if(id?.startsWith('loc_'))return (await (tx?tx.get(service.db.doc(`coverageLocations/${id}`)):service.db.doc(`coverageLocations/${id}`).get())).data();
  return cfg?.societies?.find(s=>s.id===id&&s.active);
}
// Only public place data, not parking instructions or a Customer's identity.
export async function saveLocation(service,place){
  const location=place.location??{latitude:place.latitude,longitude:place.longitude};
  if(!validPosition(location))fail('invalid-argument','Confirm the building on the map.');
  const name=typeof place.name==='string'?place.name.trim():'';
  if(name.length<2||name.length>120)fail('invalid-argument','Enter the building or home name.');
  const id='loc_'+hash(`${name.toLowerCase()}:${location.latitude.toFixed(5)}:${location.longitude.toFixed(5)}`);
  const entry={id,name,area:String(place.area??'').slice(0,120),city:String(place.city??'').slice(0,80),pincode:String(place.pincode??'').slice(0,6),location:{latitude:location.latitude,longitude:location.longitude},active:true};
  await service.db.doc(`coverageLocations/${id}`).set({...entry,updatedAt:FieldValue.serverTimestamp()});
  return entry;
}
export async function nearbyCaptains(service,position,tx){
  if(!validPosition(position))return {docs:[]};
  const bounds=geohashQueryBounds([position.latitude,position.longitude],10000);
  const rows=await Promise.all(bounds.map(([a,b])=>{
    const q=service.db.collection('captains').where('approved','==',true).orderBy('serviceArea.geohash').startAt(a).endAt(b);
    return tx?tx.get(q):q.get();
  }));
  return {docs:[...new Map(rows.flatMap(r=>r.docs).map(d=>[d.id,d])).values()].filter(d=>covers(d.data(),position))};
}
export async function saveCaptainArea(service,auth,data){
  const uid=service.actor(auth),center=data.center,radiusKm=data.radiusKm,label=typeof data.label==='string'?data.label.trim():'';
  if(!validPosition(center)||!Number.isInteger(radiusKm)||radiusKm<1||radiusKm>10||label.length<2||label.length>120)fail('invalid-argument','Choose a map centre, area name and radius from 1 to 10 km.');
  const slots=normalizeWorkingSlots(data.workingSlots);
  if(slots===null)fail('invalid-argument','Choose your working hours.');
  const ref=service.db.doc(`captains/${uid}`);
  await service.db.runTransaction(async tx=>{
    const c=(await tx.get(ref)).data();
    if(!c||c.deletionStatus)fail('permission-denied','Complete your Captain account first.');
    tx.update(ref,{serviceArea:{center:{latitude:center.latitude,longitude:center.longitude},radiusKm,label,geohash:geohashForLocation([center.latitude,center.longitude]),version:(c.serviceArea?.version??0)+1,updatedAt:FieldValue.serverTimestamp()},workingSlots:slots,areaPreference:{mode:'serviceArea'},updatedAt:FieldValue.serverTimestamp()});
    signal(tx,service);
  });
  const saved=(await ref.get()).data().serviceArea;
  return {ok:true,serviceArea:{center:saved.center,radiusKm:saved.radiusKm,label:saved.label,version:saved.version}};
}
export function signal(tx,service){tx.set(service.db.doc('availabilitySignals/current'),{revision:FieldValue.increment(1),updatedAt:FieldValue.serverTimestamp()},{merge:true});}
// A provisional Captain owns capacity across ALL addresses, not once per building.
// Query + reservation happen in the payment transaction; concurrent captures retry.
export async function areaCapacity(service,tx,order,windows){
  const [captains,bookings]=await Promise.all([nearbyCaptains(service,order.coverageLocation,tx),tx.get(service.db.collection('orders').where('day','==',order.day))]);
  const busy=bookings.docs.filter(d=>d.id!==order.id).map(d=>d.data()).filter(o=>o.paymentMode===order.paymentMode&&o.capacityReserved&& !['cancelled','approved'].includes(o.status));
  return windows.map(w=>{
    const times=windowTimes(order.day,w);
    return captains.docs.find(d=>{
      const c=d.data();
      return d.id!==order.customerId&&c.paymentMode===order.paymentMode&&!['blocked','refresher'].includes(c.workStatus)&&service.worksWindow(c,w,order.day,true)&&
        !busy.some(o=>(o.captainId??o.capacityCaptainId)===d.id&&o.slotStart?.toMillis()<times.end&&o.slotEnd?.toMillis()>times.start);
    })?.id??null;
  });
}

export const areaLock=(service,tx,captainId,order,window)=>tx.get(service.db.doc('captainCapacity/'+hash(`${captainId}:${order.paymentMode}:${order.day}:${window.startHour}`)));
export const touchAreaLock=(tx,lock)=>{if(lock)tx.set(lock.ref,{revision:FieldValue.increment(1)},{merge:true});};
