import {before,after,beforeEach,test} from 'node:test';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,collection,query,where,getDocs} from 'firebase/firestore';
import {ref,uploadBytes,getBytes} from 'firebase/storage';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-wheelio',firestore:{host:'127.0.0.1',port:8080,rules:await readFile(new URL('./firestore.rules',import.meta.url),'utf8')},storage:{host:'127.0.0.1',port:9199,rules:await readFile(new URL('./storage.rules',import.meta.url),'utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{await env.clearFirestore();await env.clearStorage();await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  await setDoc(doc(db,'orders/job'),{customerId:'alice',captainId:'captain',status:'onTheWay',pricePaise:14900});
  await setDoc(doc(db,'captains/captain'),{approved:true,kycStatus:'approved'});
  await setDoc(doc(db,'captains/applicant'),{approved:false,kycStatus:'notSubmitted'});
  await setDoc(doc(db,'jobOffers/offer'),{orderId:'job',captainId:'otherCaptain',societyId:'soc_avatar'});
  await setDoc(doc(db,'orders/job/tracking/current'),{latitude:17,longitude:78});
  await setDoc(doc(db,'earnings/job'),{captainId:'captain',amount:11600,status:'awaitingApproval'});
});});
const actor=uid=>env.authenticatedContext(uid);
test('profile and problem photos remain private; dispute audio belongs only to the assigned captain',async()=>{
 const bytes=new Uint8Array([1,2,3]),owner=actor('alice').storage(),captain=actor('captain').storage(),stranger=actor('stranger').storage();
 await assertSucceeds(uploadBytes(ref(owner,'profiles/alice/customer.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertFails(getBytes(ref(captain,'profiles/alice/customer.jpg')));
 await assertFails(uploadBytes(ref(stranger,'profiles/alice/customer.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(ref(owner,'profiles/alice/customer.jpg'),new Uint8Array(),{contentType:'image/jpeg'}));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'orders/job'),{status:'photosReady'}));
 await assertSucceeds(uploadBytes(ref(owner,'orders/job/problems/alice_0.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertSucceeds(getBytes(ref(captain,'orders/job/problems/alice_0.jpg')));
 await assertFails(getBytes(ref(stranger,'orders/job/problems/alice_0.jpg')));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'orders/job'),{status:'disputed'}));
 await assertSucceeds(uploadBytes(ref(captain,'orders/job/dispute_response/captain.m4a'),bytes,{contentType:'audio/mp4'}));
 await assertFails(uploadBytes(ref(owner,'orders/job/dispute_response/captain.m4a'),bytes,{contentType:'audio/mp4'}));
});
test('exact booking, private tracking and earnings are visible only to the appropriate parties',async()=>{
  for(const uid of ['alice','captain']) {
    await assertSucceeds(getDoc(doc(actor(uid).firestore(),'orders/job')));
    await assertSucceeds(getDoc(doc(actor(uid).firestore(),'orders/job/tracking/current')));
  }
  for(const uid of ['stranger','otherCaptain']){
    await assertFails(getDoc(doc(actor(uid).firestore(),'orders/job')));
    await assertFails(getDoc(doc(actor(uid).firestore(),'orders/job/tracking/current')));
  }
  await assertSucceeds(getDoc(doc(actor('captain').firestore(),'earnings/job')));
  await assertFails(getDoc(doc(actor('alice').firestore(),'earnings/job')));
});
test('owners cannot forge payment, assignment, approval, KYC or earnings; offers never confer booking access',async()=>{
  for(const [uid,path,changes] of [['alice','orders/job',{paymentStatus:'captured'}],['captain','orders/job',{status:'approved'}],['applicant','captains/applicant',{approved:true}],['captain','earnings/job',{amount:999999}]])await assertFails(updateDoc(doc(actor(uid).firestore(),path),changes));
  await assertSucceeds(getDocs(query(collection(actor('otherCaptain').firestore(),'jobOffers'),where('captainId','==','otherCaptain'))));
  await assertFails(updateDoc(doc(actor('otherCaptain').firestore(),'jobOffers/offer'),{status:'accepted'}));
  await assertFails(setDoc(doc(actor('alice').firestore(),'orders/forged'),{customerId:'alice',status:'approved'}));
});
test('only assigned captain can upload the right photo stage; unauthorized reads and invalid payloads fail',async()=>{
  const bytes=new Uint8Array([255,216,255,224,1,2,3]);const path='orders/job/captain/before_0.jpg';
  await assertFails(uploadBytes(ref(actor('stranger').storage(),path),bytes,{contentType:'image/jpeg'}));
  await assertSucceeds(uploadBytes(ref(actor('captain').storage(),path),bytes,{contentType:'image/jpeg'}));
  await assertSucceeds(getBytes(ref(actor('alice').storage(),path)));
  await assertFails(getBytes(ref(actor('otherCaptain').storage(),path)));
  await assertFails(uploadBytes(ref(actor('captain').storage(),'orders/job/captain/after_0.jpg'),bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(actor('captain').storage(),'orders/job/captain/before_1.jpg'),bytes,{contentType:'text/html'}));
  await assertFails(uploadBytes(ref(actor('captain').storage(),'orders/job/captain/before_1.jpg'),new Uint8Array(8*1024*1024+1),{contentType:'image/jpeg'}));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'orders/job'),{status:'washing'}));
  await assertFails(uploadBytes(ref(actor('captain').storage(),path),bytes,{contentType:'image/jpeg'}));
  await assertSucceeds(uploadBytes(ref(actor('captain').storage(),'orders/job/captain/after_0.jpg'),bytes,{contentType:'image/jpeg'}));
});
test('KYC photos stay private and are locked after submission',async()=>{
  const path='kyc/applicant/aadhaar.jpg',bytes=new Uint8Array([255,216,255,224]);
  await assertSucceeds(uploadBytes(ref(actor('applicant').storage(),path),bytes,{contentType:'image/jpeg'}));
  await assertFails(getBytes(ref(actor('captain').storage(),path)));
  await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'captains/applicant'),{kycStatus:'underReview'}));
  await assertFails(uploadBytes(ref(actor('applicant').storage(),path),bytes,{contentType:'image/jpeg'}));
});


test('wallet balances and address approval resist forgery, cross-user reads and public queries',async()=>{
  await env.withSecurityRulesDisabled(async c=>{
    await setDoc(doc(c.firestore(),'wallets/alice_test'),{customerId:'alice',paymentMode:'test',freeWashes:1,creditPaise:7500});
    await setDoc(doc(c.firestore(),'addressRequests/address'),{customerId:'alice',status:'underReview'});
  });
  const alice=actor('alice').firestore(),bob=actor('bob').firestore(),anon=env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(alice,'wallets/alice_test')));
  await assertSucceeds(getDoc(doc(alice,'wallets/alice_live')));
  await assertSucceeds(getDoc(doc(alice,'addressRequests/address')));
  for(const db of [bob,anon])for(const path of ['wallets/alice_test','addressRequests/address'])await assertFails(getDoc(doc(db,path)));
  await assertFails(getDocs(collection(alice,'wallets')));
  await assertFails(getDocs(collection(anon,'addressRequests')));
  for(const patch of [{freeWashes:999},{customerId:'bob'},{creditPaise:-1},{extra:'x'.repeat(10000)}])
    await assertFails(updateDoc(doc(alice,'wallets/alice_test'),patch));
  await assertFails(setDoc(doc(alice,'wallets/forged_test'),{customerId:'alice',freeWashes:1}));
  await assertFails(updateDoc(doc(alice,'addressRequests/address'),{status:'approved',societyId:'soc_avatar'}));
});

test('private recordings are scoped to the booking parties and pending-payment owner',async()=>{
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'orders/job'),{status:'pendingPayment'}));
  const path='orders/job/customer/note_audio',bytes=new Uint8Array([1,2,3]);
  await assertSucceeds(uploadBytes(ref(actor('alice').storage(),path),bytes,{contentType:'audio/mp4'}));
  await assertFails(uploadBytes(ref(actor('captain').storage(),path),bytes,{contentType:'audio/mp4'}));
  await assertFails(uploadBytes(ref(actor('alice').storage(),'orders/job/customer/note_video'),bytes,{contentType:'text/html'}));
  await assertSucceeds(getBytes(ref(actor('captain').storage(),path)));
  await assertFails(getBytes(ref(actor('stranger').storage(),path)));
  await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'orders/job'),{status:'searching'}));
  await assertFails(uploadBytes(ref(actor('alice').storage(),path),bytes,{contentType:'audio/mp4'}));
});

test('inbox entries are private and tokens remain inaccessible even to clients that own them',async()=>{
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'notifications/n'),{recipientId:'alice',read:false});
  await setDoc(doc(c.firestore(),'deviceTokens/t'),{uid:'alice',token:'private-token',role:'customer'});
 });
 await assertSucceeds(getDocs(query(collection(actor('alice').firestore(),'notifications'),where('recipientId','==','alice'))));
 for(const uid of ['alice','stranger']){
  await assertFails(getDoc(doc(actor(uid).firestore(),'deviceTokens/t')));
  await assertFails(updateDoc(doc(actor(uid).firestore(),'notifications/n'),{recipientId:uid,read:true}));
 }
 await assertFails(getDoc(doc(actor('stranger').firestore(),'notifications/n')));
});

test('deleted accounts cannot keep uploading profile images with a cached token',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'users/deleted'),{deletionStatus:'completed'}));
 await assertFails(uploadBytes(ref(actor('deleted').storage(),'profiles/deleted/customer.jpg'),new Uint8Array([1]),{contentType:'image/jpeg'}));
});
