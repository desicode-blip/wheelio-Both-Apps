import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {validPosition} from './geography.mjs';

export class PlaceSearchError extends Error {
  constructor(code,message){super(message);this.code=code;}
}
const fail=(code,message)=>{throw new PlaceSearchError(code,message);};
const normalize=s=>String(s??'').toLowerCase().replace(/[^\p{L}\p{N}]/gu,'');
const placeId=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{5,200}$/.test(id);
const session=id=>typeof id==='string'&&/^[A-Za-z0-9_-]{16,36}$/.test(id);
const component=(p,type)=>p.addressComponents?.find(c=>c.types?.includes(type));

/** No client key or unrestricted provider response leaves this server adapter. */
export class GooglePlaces {
  constructor(key,request=fetch){this.key=key;this.request=request;}
  async requestJson(path,body,mask){
    const r=await this.request('https://places.googleapis.com/v1/'+path,{
      method:body?'POST':'GET',signal:AbortSignal.timeout(8000),
      headers:{'Content-Type':'application/json','X-Goog-Api-Key':this.key,'X-Goog-FieldMask':mask},
      ...(body?{body:JSON.stringify(body)}:{}),
    });
    if(!r.ok)fail('unavailable','Place search is unavailable. Try again or enter the address by hand.');
    return r.json();
  }
  async suggestions(query,origin,token){
    if(!query){
      if(!origin)return [];
      const d=await this.requestJson('places:searchNearby',{
        includedTypes:['apartment_building','apartment_complex','condominium_complex','housing_complex'],
        locationRestriction:{circle:{center:origin,radius:5000}},rankPreference:'DISTANCE',maxResultCount:8,languageCode:'en',
      },'places.id,places.displayName,places.formattedAddress');
      return (d.places??[]).slice(0,8).filter(p=>placeId(p.id)&&p.displayName?.text).map(p=>({placeId:p.id,name:p.displayName.text.slice(0,160),address:(p.formattedAddress??'').slice(0,400)}));
    }
    const d=await this.requestJson('places:autocomplete',{
      input:query,includedRegionCodes:['in'],languageCode:'en',regionCode:'in',sessionToken:token,
      ...(origin?{locationBias:{circle:{center:origin,radius:15000}},origin}:{}),
    },'suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat');
    return (d.suggestions??[]).slice(0,8).map(s=>s.placePrediction).filter(p=>placeId(p?.placeId)&&p.structuredFormat?.mainText?.text).map(p=>({placeId:p.placeId,name:p.structuredFormat.mainText.text.slice(0,160),address:(p.structuredFormat.secondaryText?.text??'').slice(0,400)}));
  }
  async details(id,token){
    const p=await this.requestJson('places/'+encodeURIComponent(id)+'?languageCode=en&sessionToken='+encodeURIComponent(token),null,'id,displayName,formattedAddress,addressComponents,location');
    if(!placeId(p.id)||p.id!==id||!validPosition(p.location)||component(p,'country')?.shortText!=='IN')fail('failed-precondition','Choose an address in India.');
    const pick=(...types)=>types.map(t=>component(p,t)?.longText).find(Boolean)??'';
    return {placeId:p.id,name:String(p.displayName?.text??'').slice(0,120),address:String(p.formattedAddress??'').slice(0,400),area:pick('sublocality_level_1','sublocality','neighborhood','route'),city:pick('locality','administrative_area_level_3','administrative_area_level_2'),pincode:pick('postal_code'),latitude:p.location.latitude,longitude:p.location.longitude};
  }
}

// Guest search is needed before checkout login. Limits use only a server-derived
// daily hash, never client-supplied identity, raw IP, query or GPS persistence.
async function reserveLookup(service,context,cfg){
  const now=service.now(),day=Math.floor(now/86400000),minute=Math.floor(now/60000);
  const hash=createHash('sha256').update(day+':'+String(context?.clientKey??'unknown')).digest('hex');
  const ref=service.db.doc('placeLookupLimits/'+hash),global=service.db.doc('placeLookupLimits/day-'+day);
  const limit=Number.isSafeInteger(cfg.maps.places?.dailyLimit)?Math.max(1,Math.min(20000,cfg.maps.places.dailyLimit)):1000;
  await service.db.runTransaction(async tx=>{
    const [one,total]=await Promise.all([tx.get(ref),tx.get(global)]),p=one.data()??{},g=total.data()??{};
    const count=p.minute===minute?(p.minuteCount??0):0;
    if(count>=30||(p.dayCount??0)>=300||(g.count??0)>=limit)fail('resource-exhausted','Place search is busy. Try again shortly or enter the address by hand.');
    const expiresAt=Timestamp.fromMillis((day+2)*86400000);
    tx.set(ref,{minute,minuteCount:count+1,dayCount:(p.dayCount??0)+1,expiresAt});
    tx.set(global,{count:(g.count??0)+1,expiresAt});
  });
}

export async function searchPlaces(service,_auth,data,context){
  if(typeof data.query!=='string'||data.query.trim().length>120||!session(data.sessionToken))fail('invalid-argument','Check the place search.');
  const query=data.query.trim();
  if(data.origin!==undefined&&!validPosition(data.origin))fail('invalid-argument','Check the search location.');
  if(query.length<2&&(query.length||!data.origin))return {suggestions:[]};
  const cfg=await service.config();
  if(cfg.maps?.places?.enabled!==true||!service.places)fail('failed-precondition','Place search is not available. Enter the address by hand.');
  await reserveLookup(service,context,cfg);
  try{return {suggestions:await service.places.suggestions(query,data.origin?{latitude:data.origin.latitude,longitude:data.origin.longitude}:null,data.sessionToken)};}
  catch(e){if(e instanceof PlaceSearchError)throw e;fail('unavailable','Place search is unavailable. Try again or enter the address by hand.');}
}

export async function selectPlace(service,_auth,data,context){
  if(!placeId(data.placeId)||!session(data.sessionToken))fail('invalid-argument','Choose a place from the search results.');
  const cfg=await service.config();
  if(cfg.maps?.places?.enabled!==true||!service.places)fail('failed-precondition','Place search is not available. Enter the address by hand.');
  await reserveLookup(service,context,cfg);
  let place;
  try{place=await service.places.details(data.placeId,data.sessionToken);}catch(e){if(e instanceof PlaceSearchError)throw e;fail('unavailable','This address could not be loaded. Try again.');}
  // Provider discovery never grants service coverage. Only an exact configured
  // place identity or canonical name/city/pincode can select a live society.
  const society=cfg.societies?.find(s=>s.active===true&&((s.googlePlaceId??s.mapPlaceId)===place.placeId||
    (normalize(s.name)===normalize(place.name)&&normalize(s.city??'Hyderabad')===normalize(place.city)&&s.pincode===place.pincode)));
  return {place,societyId:society?.id??null};
}
