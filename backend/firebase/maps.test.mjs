import {test} from 'node:test';
import assert from 'node:assert/strict';
import {GoogleRoutes} from './functions/src/maps.mjs';
import {approvedContent} from './functions/src/content.mjs';
import {PrivatePhotoChecks} from './functions/src/photo-checks.mjs';
test('production cannot use the demo-only loopback photo endpoint',async()=>{
  const oldEmulator=process.env.FUNCTIONS_EMULATOR,oldProject=process.env.GCLOUD_PROJECT;
  try{
    process.env.FUNCTIONS_EMULATOR='true';process.env.GCLOUD_PROJECT='wheelio-apps';
    const checks=new PrivatePhotoChecks({doc:()=>({get:async()=>({data:()=>({enabled:true,url:'http://127.0.0.1:8089'})})})});
    await assert.rejects(checks.request('compare',{}),{code:'failed-precondition'});
  }finally{
    if(oldEmulator===undefined)delete process.env.FUNCTIONS_EMULATOR;else process.env.FUNCTIONS_EMULATOR=oldEmulator;
    if(oldProject===undefined)delete process.env.GCLOUD_PROJECT;else process.env.GCLOUD_PROJECT=oldProject;
  }
});
test('Routes requests use server headers and return only bounded duration and distance',async()=>{
  const provider=new GoogleRoutes('private-test-key',async(url,options)=>{
    assert.equal(options.headers['X-Goog-Api-Key'],'private-test-key');
    const body=JSON.parse(options.body);assert.equal(body.routingPreference,'TRAFFIC_AWARE');
    assert.deepEqual(body.origin.location.latLng,{latitude:17.4,longitude:78.35});
    return {ok:true,json:async()=>({routes:[{duration:'83.2s',distanceMeters:510,secret:'never-return'}]})};
  });
  assert.deepEqual(await provider.arrival({latitude:17.4,longitude:78.35},{latitude:17.41,longitude:78.36}),{seconds:84,distanceMetres:510});
  for(const duration of ['bad','-3s','90000s'])await assert.rejects(new GoogleRoutes('',async()=>({ok:true,json:async()=>({routes:[{duration,distanceMeters:1}]})})).arrival({latitude:0,longitude:0},{latitude:1,longitude:1}));
});
test('content publishing validates approved values and cannot change payments or service coverage',()=>{
  assert.throws(()=>approvedContent({paymentMode:'live'}));
  assert.throws(()=>approvedContent({legal:{entity:'Example',termsPrivacyUrl:'javascript:alert(1)'}}));
  assert.throws(()=>approvedContent({support:{phone:'+910000000000',email:'invalid',hours:''}}));
  const training={version:'approved-v1',required:true,videos:[0,1,2].map(()=>({url:'https://example.test/approved.mp4',seconds:20}))};
  assert.deepEqual(approvedContent({training}).training,training);
  assert.throws(()=>approvedContent({training:{...training,videos:[{url:'https://example.test/one.mp4',seconds:20}]}}));
});
