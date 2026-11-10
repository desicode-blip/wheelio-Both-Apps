import {createHash} from 'node:crypto';

// A retry key identifies one immutable checkout, not a mutable booking form.
export function checkoutIdentity(data) {
 const requested=data.windows??[{startHour:data.startHour,endHour:data.endHour}];
 const windows=Array.isArray(requested)?requested.map(w=>[w?.startHour,w?.endHour]).sort((a,b)=>a[0]-b[0]):null;
 const fields={plate:String(data.plate??'').toUpperCase().replaceAll(' ',''),vehicleKind:data.vehicleKind,washKind:data.washKind,
  societyId:data.societyId,tower:data.tower??'',floor:data.floor,parking:data.parking??'',note:data.note??'',day:data.day,windows,
  anyTime:data.anyTime===true,useFreeWash:data.useFreeWash===true,useCredit:data.useCredit===true,paymentChoice:data.paymentChoice??null,
  expectedAmountPaise:data.expectedAmountPaise??null,addressKey:data.addressKey??null,
  vehiclePosition:data.vehiclePosition?{latitude:data.vehiclePosition.latitude,longitude:data.vehiclePosition.longitude}:null};
 return createHash('sha256').update(JSON.stringify(fields)).digest('hex');
}
