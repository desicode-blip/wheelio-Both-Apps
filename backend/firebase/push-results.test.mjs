import test from 'node:test';
import assert from 'node:assert/strict';
import {pushResultSummary} from './functions/src/push-results.mjs';

test('resolved multicast with rejected Apple credentials reports no success',()=>{
  const result=pushResultSummary({responses:[{success:false,error:{code:'messaging/third-party-auth-error',message:'private provider detail'}}]},1);
  assert.equal(result.sent,0);assert.equal(result.failed,1);assert.equal(result.configurationError,true);
  assert.deepEqual(result.invalidTokenIndexes,[]);
  assert.deepEqual(result.errors,{'messaging/third-party-auth-error':1});
  assert.ok(!JSON.stringify(result).includes('private provider detail'));
});
test('mixed responses remove only invalid tokens and retain transient/configuration failures',()=>{
  const result=pushResultSummary({responses:[{success:true},{success:false,error:{code:'messaging/registration-token-not-registered'}},{success:false,error:{code:'messaging/server-unavailable'}},{success:false,error:{code:'messaging/invalid-apns-credentials'}}]},4);
  assert.equal(result.sent,1);assert.equal(result.failed,3);assert.equal(result.configurationError,true);
  assert.deepEqual(result.invalidTokenIndexes,[1]);
});
test('missing or malformed responses fail closed without logging provider text',()=>{
  assert.deepEqual(pushResultSummary({responses:[{error:{code:'Bearer secret value'}},{}]},3),{sent:0,failed:3,invalidTokenIndexes:[],errors:{'messaging/incomplete-response':3},configurationError:false});
});
