import assert from 'node:assert/strict';
import {test} from 'node:test';
import {removedAppAccess} from './functions/src/account-access.mjs';
import {readObjectMetadata} from './functions/src/storage-evidence.mjs';

test('removed app roles block cached-token writes without blocking the remaining app',()=>{
  const p={roles:['captain'],deletedRoles:{customer:1}};
  for(const method of ['createBooking','savePlace','checkout','reportProblem'])assert.equal(removedAppAccess(p,method),true);
  for(const method of ['claim','progress','captainPreferences','location'])assert.equal(removedAppAccess(p,method),false);
  assert.equal(removedAppAccess(p,'profilePhoto',{role:'customer'}),true);
  assert.equal(removedAppAccess(p,'profilePhoto',{role:'captain'}),false);
  assert.equal(removedAppAccess(p,'register',{role:'customer'}),false);
  assert.equal(removedAppAccess({deletingRole:'captain'},'claim'),true);
  assert.equal(removedAppAccess({deletionStatus:'pending'},'createBooking'),true);
});
test('missing Storage objects are absent; permission and provider errors are not disguised',async()=>{
  const missing={code:404},denied={code:403};
  assert.equal(await readObjectMetadata({getMetadata:async()=>{throw missing;}}),null);
  await assert.rejects(readObjectMetadata({getMetadata:async()=>{throw denied;}}),e=>e===denied);
  const meta={contentType:'image/jpeg',size:123};
  assert.equal(await readObjectMetadata({getMetadata:async()=>[meta]}),meta);
});

test('deleted-token coarse discovery remains public, while private mutations stay blocked',()=>{
 const profiles=[{deletionStatus:'pending',deletingRole:'captain',roles:['captain']},{deletionStatus:'completed'},{deletedRoles:{customer:1},roles:['captain']}];
 for(const p of profiles){
  for(const method of ['availability','searchPlaces','selectPlace','serviceLocation'])assert.equal(removedAppAccess(p,method),false);
  for(const method of ['createBooking','savePlace','checkout'])assert.equal(removedAppAccess(p,method),true);
 }
});
