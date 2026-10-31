import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve,dirname,basename} from 'node:path';
import {buildAdmin} from '../../apps/admin/build.mjs';

const config={FIREBASE_PROJECT_ID:'demo-wheelio',FIREBASE_API_KEY:'public-test-key',FIREBASE_APP_ID:'public-test-app',FIREBASE_AUTH_DOMAIN:'localhost',FIREBASE_USE_EMULATORS:true};
test('admin deployment versions its module graph and CSS, changes with configuration, and is reproducible',async()=>{
  const parent=resolve(tmpdir()),dir=await mkdtemp(join(parent,'washkrew-admin-build-'));
  assert.equal(dirname(resolve(dir)),parent);
  assert.ok(basename(dir).startsWith('washkrew-admin-build-'));
  try{
    await buildAdmin(config,dir);
    const index=await readFile(join(dir,'index.html'),'utf8'),script=await readFile(join(dir,'admin.mjs'),'utf8');
    const version=index.match(/admin\.mjs\?v=([a-f0-9]{16})/)[1];
    for(const asset of ['config.mjs','review-form.mjs'])assert.ok(script.includes(`${asset}?v=${version}`));
    assert.ok(index.includes(`styles.css?v=${version}`));
    await buildAdmin(config,dir);
    assert.equal(await readFile(join(dir,'index.html'),'utf8'),index);
    await buildAdmin({...config,FIREBASE_API_KEY:'another-public-test-key'},dir);
    assert.notEqual(await readFile(join(dir,'index.html'),'utf8'),index);
  }finally{await rm(dir,{recursive:true,force:true});}
});
test('admin assets must be revalidated after publication',async()=>{
  const firebase=JSON.parse(await readFile(new URL('../../firebase.json',import.meta.url),'utf8'));
  assert.ok(firebase.hosting.headers.some(h=>h.source==='/admin/**'&&h.headers.some(v=>v.key==='Cache-Control'&&v.value==='no-cache')));
});
