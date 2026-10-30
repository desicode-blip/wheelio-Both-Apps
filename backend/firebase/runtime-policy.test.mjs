import test from 'node:test';
import assert from 'node:assert/strict';
import {callableRuntime,interactiveWarmMinimum} from './functions/src/runtime-policy.mjs';

test('only three interactive availability/preference methods reserve one instance',()=>{
  assert.equal(interactiveWarmMinimum,0,'Recurring cost remains off pending the owner decision.');
  for(const method of ['availability','savePlace','captainPreferences']){
    assert.equal(callableRuntime(method,false,1).minInstances,1);
    assert.equal(callableRuntime(method,false).minInstances,0);
  }
  for(const method of ['checkout','createBooking','verifyPayment','claim','captainOnline','approve','submitCaptainApplication','unknown'])assert.deepEqual(callableRuntime(method,false,1),{minInstances:0});
  assert.throws(()=>callableRuntime('availability',false,2));
});
test('emulators stay on demand and photo runtime limits remain intact',()=>{
  for(const method of ['availability','savePlace','captainPreferences'])assert.deepEqual(callableRuntime(method,true,1),{minInstances:0});
  for(const method of ['checkWashPhotos','verifyIdentity'])assert.deepEqual(callableRuntime(method,false),{minInstances:0,timeoutSeconds:120,memory:'512MiB'});
});
