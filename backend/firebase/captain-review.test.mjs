import assert from 'node:assert/strict';
import {before,beforeEach,after,test} from 'node:test';
import {initializeApp,deleteApp} from './functions/node_modules/firebase-admin/lib/esm/app/index.js';
import {getFirestore,Timestamp} from './functions/node_modules/firebase-admin/lib/esm/firestore/index.js';
import {WashKrewService} from './functions/src/service.mjs';
import {readFile} from 'node:fs/promises';
let app,db,service,clock,metadata;
const project='demo-wheelio-reviews',email='reviewer@example.test';
const reviewer=()=>({uid:'reviewer',token:{email,email_verified:true,firebase:{sign_in_provider:'google.com'},auth_time:Math.floor(clock/1000)}});
before(()=>{if(!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Emulator required.');app=initializeApp({projectId:project},'captain-review-tests');db=getFirestore(app);});
after(()=>deleteApp(app));
beforeEach(async()=>{
 await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${project}/databases/(default)/documents`,{method:'DELETE'});
 clock=Date.parse('2026-11-01T08:00:00+05:30');metadata={contentType:'image/jpeg',size:100,generation:'1'};
 service=new WashKrewService({db,now:()=>clock,evidence:{metadata:async()=>metadata}});
 await db.doc('config/operations').set(JSON.parse(await readFile(new URL('./operations.test.json',import.meta.url))));
 await db.doc('privateConfig/captainReviewers').set({emails:[email]});
 await db.doc('users/applicant').set({name:'Applicant',roles:['captain']});
 await db.doc('captains/applicant').set({name:'Applicant',phone:'+919000000002',approved:false,online:false,kycStatus:'underReview',requestedSocietyIds:['soc_avatar'],paymentMode:'test',payout:{method:'upi',upi:'applicant@bank',status:'pendingVerification'},submittedAt:Timestamp.fromMillis(clock),updatedAt:Timestamp.fromMillis(clock)});
});
async function decision(patch={}){const c=await service.getCaptainApplication(reviewer(),{captainId:'applicant'});return {captainId:'applicant',expectedVersion:c.version,decision:'approve',reason:'Reviewed the submitted identity and payout details.',identityReviewed:true,payoutReviewed:true,societyIds:['soc_avatar'],...patch};}
test('review access rejects phones, unverified/unauthorized Google accounts and revoked reviewers',async()=>{
 await assert.rejects(service.listCaptainApplications(null,{}),{code:'unauthenticated'});
 for(const patch of [{email:'stranger@example.test'},{email_verified:false},{firebase:{sign_in_provider:'phone'}}]){
   const auth=reviewer();auth.token={...auth.token,...patch};await assert.rejects(service.listCaptainApplications(auth,{}),{code:'permission-denied'});
 }
 const list=await service.listCaptainApplications(reviewer(),{});assert.equal(list.applications.length,1);
 await db.doc('privateConfig/captainReviewers').set({emails:[]});
 await assert.rejects(service.getCaptainApplication(reviewer(),{captainId:'applicant'}),{code:'permission-denied'});
});
test('human approval records reviewer/note/societies and notifies without fabricating Online or training',async()=>{
 const result=await service.reviewCaptainApplication(reviewer(),await decision());
 const c=(await db.doc('captains/applicant').get()).data();assert.equal(c.approved,true);assert.equal(c.online,false);assert.equal(c.trainingCompletedAt,undefined);assert.equal(c.approvedBy,email);assert.deepEqual(c.societyIds,['soc_avatar']);
 const log=(await db.doc(`captains/applicant/applicationReviews/${result.reviewId}`).get()).data();assert.equal(log.reviewer.email,email);assert.equal(log.identityReviewed,true);
 const notification=(await db.doc(`notifications/${result.reviewId}`).get()).data();assert.equal(notification.kind,'applicationReview');assert.equal(notification.role,'captain');
 await assert.rejects(service.reviewCaptainApplication(reviewer(),await decision()),{code:'failed-precondition'});
});
test('approval requires actual uploads, human review flags, active requested societies and current training',async()=>{
 for(const patch of [{identityReviewed:false},{payoutReviewed:false},{societyIds:['soc_avali']},{societyIds:[]},{reason:'x'}])await assert.rejects(service.reviewCaptainApplication(reviewer(),await decision(patch)));
 metadata=null;await assert.rejects(service.reviewCaptainApplication(reviewer(),await decision()),{code:'failed-precondition'});metadata={contentType:'image/jpeg',size:100};
 await db.doc('config/operations').update({training:{required:true,version:'approved-v1'}});
 await assert.rejects(service.reviewCaptainApplication(reviewer(),await decision()),{code:'failed-precondition'});
 await db.doc('captains/applicant').update({trainingVersion:'approved-v1',trainingCompletedAt:Timestamp.fromMillis(clock),quizPassedAt:Timestamp.fromMillis(clock)});
 await service.reviewCaptainApplication(reviewer(),await decision());
});
test('stale/concurrent reviews, self approval, old authentication and unsubmitted applicants are rejected',async()=>{
 const stale=await decision();await db.doc('captains/applicant').update({payout:{method:'upi',upi:'changed@bank'}});
 await assert.rejects(service.reviewCaptainApplication(reviewer(),stale),{code:'aborted'});
 const old=reviewer();old.token.auth_time-=1801;await assert.rejects(service.reviewCaptainApplication(old,await decision()),{code:'failed-precondition'});
 await assert.rejects(service.reviewCaptainApplication({...reviewer(),uid:'applicant'},await decision()),{code:'permission-denied'});
 const d=await decision();const results=await Promise.allSettled([service.reviewCaptainApplication(reviewer(),d),service.reviewCaptainApplication(reviewer(),d)]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 await db.doc('captains/applicant').update({approved:false,kycStatus:'notSubmitted'});
 await assert.rejects(service.reviewCaptainApplication(reviewer(),await decision()),{code:'failed-precondition'});
});
test('corrections are specific, auditable and reopen only the submitted application',async()=>{
 const d=await decision({decision:'requestChanges',issues:['selfie'],reason:'Please upload a clear, recent selfie.'});
 await service.reviewCaptainApplication(reviewer(),d);
 const c=(await db.doc('captains/applicant').get()).data();assert.equal(c.kycStatus,'changesRequested');assert.equal(c.approved,false);assert.deepEqual(c.reviewIssues,['selfie']);assert.equal(c.reviewReason,d.reason);
});
test('a missing account profile cannot be approved',async()=>{
 const d=await decision();await db.doc('users/applicant').delete();
 await assert.rejects(service.reviewCaptainApplication(reviewer(),d),{code:'failed-precondition'});
});
test('private evidence accepts only fixed KYC kinds for approved reviewers',async()=>{
 assert.equal((await service.captainReviewEvidence(reviewer(),{captainId:'applicant',kind:'aadhaar'})).path,'kyc/applicant/aadhaar.jpg');
 await assert.rejects(service.captainReviewEvidence(reviewer(),{captainId:'../users',kind:'aadhaar'}),{code:'invalid-argument'});
 await assert.rejects(service.captainReviewEvidence(reviewer(),{captainId:'applicant',kind:'../../secret'}),{code:'invalid-argument'});
 metadata=null;await assert.rejects(service.captainReviewEvidence(reviewer(),{captainId:'applicant',kind:'selfie'}),{code:'not-found'});
});
