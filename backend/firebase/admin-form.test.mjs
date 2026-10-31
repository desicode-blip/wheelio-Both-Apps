import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewRequirements} from '../../apps/admin/public/review-form.mjs';
const app={status:'underReview',paymentMode:'live',paymentModeConfigured:'live',photos:[{kind:'aadhaar',available:true},{kind:'selfie',available:true}],training:{required:false},societies:[{id:'society'}],requestedSocietyIds:['society']};
const ready={note:'Reviewed the submitted evidence.',identityReviewed:true,payoutReviewed:true,societyIds:['society'],issues:[]};
test('approval explains missing human review requirements instead of a silently disabled control',()=>{
 const missing=reviewRequirements('approve',app,{...ready,note:'',identityReviewed:false,payoutReviewed:false,societyIds:[]});
 assert.equal(missing.length,4);assert.ok(missing.some(s=>s.includes('review note')));assert.ok(missing.some(s=>s.includes('society')));
 assert.deepEqual(reviewRequirements('approve',app,ready),[]);
});
test('corrections use their own requirements without requiring approval acknowledgments',()=>{
 assert.deepEqual(reviewRequirements('requestChanges',app,{...ready,identityReviewed:false,payoutReviewed:false,societyIds:[],issues:['selfie']}),[]);
 assert.ok(reviewRequirements('requestChanges',app,ready).some(s=>s.includes('item')));
});
test('missing uploads, mode mismatch, invalid societies and required training remain blocked',()=>{
 for(const patch of [{photos:[]},{paymentMode:'test'},{requestedSocietyIds:[]},{training:{required:true,completed:false,quizPassed:false}},{status:'approved'}])assert.ok(reviewRequirements('approve',{...app,...patch},ready).length);
});
