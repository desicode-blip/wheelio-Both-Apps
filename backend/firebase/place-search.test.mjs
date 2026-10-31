import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {GooglePlaces,searchPlaces,selectPlace} from './functions/src/place-search.mjs';

const token='0123456789abcdef0123456789abcdef',origin={latitude:17.4,longitude:78.35};
test('nearby housing and typed autocomplete keep GPS bias/session, mask fields and sanitize results',async()=>{
  const calls=[],provider=new GooglePlaces('server-test-key',async(url,options)=>{
    calls.push({url,body:JSON.parse(options.body),mask:options.headers['X-Goog-FieldMask']});
    assert.equal(options.headers['X-Goog-Api-Key'],'server-test-key');
    return {ok:true,json:async()=>url.includes('searchNearby')?{places:[{id:'nearby_one',displayName:{text:'Example apartments'},formattedAddress:'Hyderabad',private:'discard'}]}:{suggestions:[{placePrediction:{placeId:'typed_one',structuredFormat:{mainText:{text:'Example Society'},secondaryText:{text:'Gachibowli'}}}},{}]}};
  });
  assert.deepEqual(await provider.suggestions('',origin,token),[{placeId:'nearby_one',name:'Example apartments',address:'Hyderabad'}]);
  assert.equal(calls[0].body.rankPreference,'DISTANCE');
  assert.equal(calls[0].body.locationRestriction.circle.radius,5000);
  assert.ok(calls[0].body.includedTypes.includes('apartment_complex'));
  assert.deepEqual(await provider.suggestions('Example',origin,token),[{placeId:'typed_one',name:'Example Society',address:'Gachibowli'}]);
  assert.deepEqual(calls[1].body.includedRegionCodes,['in']);
  assert.deepEqual(calls[1].body.locationBias.circle.center,origin);
  assert.equal(calls[1].body.sessionToken,token);
  assert.equal(await provider.suggestions('',null,token).then(r=>r.length),0);
  assert.equal(calls.length,2);
});
test('place selection obtains verified address components and rejects non-India or invalid positions',async()=>{
  let country='IN';
  const provider=new GooglePlaces('private',async(url,options)=>{
    assert.ok(url.includes('places/example_id?'));
    assert.ok(options.headers['X-Goog-FieldMask'].includes('addressComponents'));
    return {ok:true,json:async()=>({id:'example_id',displayName:{text:'Example Society'},location:origin,addressComponents:[{types:['country'],shortText:country},{types:['locality'],longText:'Hyderabad'},{types:['postal_code'],longText:'500001'},{types:['sublocality_level_1'],longText:'Example area'}]})};
  });
  const p=await provider.details('example_id',token);
  assert.equal(p.pincode,'500001');assert.equal(p.city,'Hyderabad');assert.equal(p.area,'Example area');
  country='US';await assert.rejects(provider.details('example_id',token),{code:'failed-precondition'});
  await assert.rejects(new GooglePlaces('private',async()=>({ok:false})).suggestions('ab',origin,token),{code:'unavailable'});
});

let app,db,service,calls;
before(()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Use the isolated Firebase emulators.');app=initializeApp({projectId:'demo-wheelio'},'place-search-tests');db=getFirestore(app);});
after(async()=>{await deleteApp(app);});
beforeEach(async()=>{
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-wheelio/databases/(default)/documents`,{method:'DELETE'});
  calls=0;
  service={db,now:()=>Date.parse('2026-11-01T08:00:00Z'),config:async()=>({maps:{places:{enabled:true,dailyLimit:1000}},societies:[{id:'served',name:'Example Society',city:'Hyderabad',pincode:'500001',active:true}]}),places:{suggestions:async()=>{calls++;return [{placeId:'example_id',name:'Example Society',address:'Hyderabad'}];},details:async()=>({placeId:'example_id',name:'Example Society',city:'Hyderabad',area:'Area',pincode:'500001',...origin})}};
});
test('guest discovery never creates coverage, and selection matches only an active canonical society',async()=>{
  const data={query:'Example',sessionToken:token},context={clientKey:'isolated-test-client'};
  assert.equal((await searchPlaces(service,null,data,context)).suggestions.length,1);
  assert.equal((await selectPlace(service,null,{placeId:'example_id',sessionToken:token},context)).societyId,'served');
  service.places.details=async()=>({placeId:'other_id',name:'Another Society',city:'Hyderabad',pincode:'500001',...origin});
  assert.equal((await selectPlace(service,null,{placeId:'other_id',sessionToken:token},context)).societyId,null);
  assert.equal((await db.collection('serviceAddresses').get()).size,0);
  assert.equal((await db.collection('addressRequests').get()).size,0);
});
test('invalid input and disabled search fail before any provider call',async()=>{
  await assert.rejects(searchPlaces(service,null,{query:'x'.repeat(121),sessionToken:token},{}),{code:'invalid-argument'});
  await assert.rejects(searchPlaces(service,null,{query:'society',sessionToken:token,origin:{latitude:999,longitude:1}},{}),{code:'invalid-argument'});
  assert.deepEqual(await searchPlaces(service,null,{query:'a',sessionToken:token},{}),{suggestions:[]});
  service.config=async()=>({maps:{places:{enabled:false}}});
  await assert.rejects(searchPlaces(service,null,{query:'society',sessionToken:token},{}),{code:'failed-precondition'});
  assert.equal(calls,0);
});
test('per-client and global limits stop provider calls; only hashes/counters persist',async()=>{
  for(let n=0;n<30;n++)await searchPlaces(service,null,{query:'society',sessionToken:token,origin},{clientKey:'private-client-address'});
  await assert.rejects(searchPlaces(service,null,{query:'society',sessionToken:token},{clientKey:'private-client-address'}),{code:'resource-exhausted'});
  assert.equal(calls,30);
  const rows=await db.collection('placeLookupLimits').get();
  const stored=JSON.stringify(rows.docs.map(d=>({id:d.id,data:d.data()})));
  for(const value of ['private-client-address','society','latitude','longitude',token])assert.ok(!stored.includes(value));
  service.config=async()=>({maps:{places:{enabled:true,dailyLimit:30}}});
  await assert.rejects(searchPlaces(service,null,{query:'society',sessionToken:token},{clientKey:'another-client'}),{code:'resource-exhausted'});
});
