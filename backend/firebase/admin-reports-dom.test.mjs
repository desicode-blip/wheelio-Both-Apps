import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {JSDOM} from 'jsdom';
import {reviewRequirements} from '../../apps/admin/public/review-form.mjs';

const fixture={id:'wash-fixture',reference:'WH-FIXTURE',version:'1:2',kind:'damage',paymentMode:'test',note:'Scratch visible after wash',createdAt:1,media:['customer/front.jpg','captain/after_0.jpg','captain/response.m4a']};
const settle=async()=>{for(let i=0;i<10;i++)await new Promise(setImmediate);};
async function portal(call,fetchMedia=async()=>({ok:true,blob:async()=>new Blob(['fixture'])})){
 const html=await readFile(new URL('../../apps/admin/public/index.html',import.meta.url),'utf8');
 const source=(await readFile(new URL('../../apps/admin/public/admin.mjs',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,'');
 const dom=new JSDOM(html,{url:'http://localhost/admin/'}),user={uid:'reviewer-fixture',email:'reviewer@example.test',getIdToken:async()=>'demo-token'},auth={currentUser:user};
 let listener;const revoked=[];
 const context=vm.createContext({document:dom.window.document,location:dom.window.location,Intl,URLSearchParams,Blob,console,reviewRequirements,
  config:{firebase:{projectId:'demo-wheelio'},emulator:true},initializeApp:()=>({}),getAuth:()=>auth,getFunctions:()=>({}),
  setPersistence:async()=>{},browserSessionPersistence:{},GoogleAuthProvider:class{},signInWithPopup:async()=>{},reauthenticateWithPopup:async()=>{},signOut:async()=>{},
  connectAuthEmulator:()=>{},connectFunctionsEmulator:()=>{},onAuthStateChanged:(_,fn)=>{listener=fn;},httpsCallable:(_,name)=>async data=>({data:await call(name,data)}),fetch:fetchMedia,
  URL:{createObjectURL:()=>`blob:demo-${Math.random()}`,revokeObjectURL:url=>revoked.push(url)},
 });
 await vm.runInContext('(async()=>{'+source+';globalThis.qa={loadWashReports};})()',context);
 return {dom,auth,qa:context.qa,revoked,logout:async()=>{auth.currentUser=null;await listener(null);},close:()=>dom.window.close()};
}
test('actual admin DOM loads private report media; explicit confirmed decision submits once with pinned version',async()=>{
 let reviewed=false,resolve,calls=0,payload;const names=[];
 const p=await portal(async(name,data)=>{
  names.push(name);if(name==='listWashReports')return {reports:reviewed?[]:[fixture]};
  assert.equal(name,'reviewWashReport');calls++;payload=data;await new Promise(r=>resolve=r);reviewed=true;return {ok:true};
 });
 try{
  await p.qa.loadWashReports();const doc=p.dom.window.document;
  assert.equal(doc.getElementById('wash-reports-workspace').hidden,false);
  const button=text=>[...doc.querySelectorAll('button')].find(b=>b.textContent===text);
  button('Load private evidence').click();await settle();assert.equal(doc.querySelectorAll('#wash-reports img').length,2);assert.equal(doc.querySelectorAll('#wash-reports audio[controls]').length,1);
  button('Uphold report').click();await settle();assert.equal(calls,0);
  doc.querySelector('#wash-reports textarea').value='Reviewed all evidence; damage report upheld.';
  doc.querySelector('#wash-reports input[type=checkbox]').checked=true;
  button('Uphold report').click();button('Uphold report').click();await settle();assert.equal(calls,1);
  assert.equal(payload.expectedVersion,'1:2');assert.equal(payload.orderId,'wash-fixture');assert.equal(payload.evidenceReviewed,true);
  resolve();await settle();assert.match(doc.getElementById('wash-reports').textContent,/No wash reports awaiting review/);
  assert.equal(p.revoked.length,3);assert.deepEqual(names,['listWashReports','reviewWashReport','listWashReports']);
 }finally{p.close();}
});
test('sign-out discards a late private report response and failed evidence load remains retryable',async()=>{
 let resolve;const p=await portal(async()=>new Promise(r=>resolve=r));
 try{
  const pending=p.qa.loadWashReports();await settle();await p.logout();resolve({reports:[fixture]});await pending;
  assert.equal(p.dom.window.document.getElementById('wash-reports').children.length,0);assert.equal(p.dom.window.document.getElementById('wash-reports-workspace').hidden,true);
 }finally{p.close();}
 const q=await portal(async()=>({reports:[fixture]}),async()=>({ok:false}));
 try{
  await q.qa.loadWashReports();const view=[...q.dom.window.document.querySelectorAll('button')].find(b=>b.textContent==='Load private evidence');view.click();await settle();
  assert.equal(view.disabled,false);assert.match(q.dom.window.document.getElementById('wash-reports').textContent,/evidence is unavailable/);
 }finally{q.close();}
});
