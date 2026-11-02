import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, orderBy, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-wheelio',
    firestore: { host: '127.0.0.1', port: 8080, rules: await readFile(new URL('./firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => env.clearFirestore());
const user = (uid = 'alice') => env.authenticatedContext(uid, { email: `${uid}@example.test` }).firestore();
test('wallet top-ups are readable only by their owner and never client writable',async()=>{
 await env.withSecurityRulesDisabled(async c=>{await setDoc(doc(c.firestore(),'walletTopups/topup'),{customerId:'alice',amountPaise:10000,status:'credited'});});
 await assertSucceeds(getDoc(doc(user(),'walletTopups/topup')));
 await assertFails(getDoc(doc(user('bob'),'walletTopups/topup')));
 await assertFails(setDoc(doc(user(),'walletTopups/forged'),{customerId:'alice',status:'credited',amountPaise:10000}));
 await assertFails(updateDoc(doc(user(),'walletTopups/topup'),{status:'credited',amountPaise:100000}));
});
const profile = (uid = 'alice') => ({ name: '', email: `${uid}@example.test`, phone: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const request = (uid = 'alice') => ({ customerId: uid, vehicleType: 'hatchback', registration: 'TS09AB1234', society: 'Test society', parking: 'B1, 42',
  washType: 'wetOutside', preferredDate: '2026-10-25', timeWindow: '8–10 AM', notes: '', status: 'requested', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const application = () => ({ name: 'Test Captain', phone: '9876543210', area: 'Narsingi', status: 'submitted', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
async function customer(uid = 'alice') { const db = user(uid); await setDoc(doc(db, 'users', uid), profile(uid)); return db; }

test('a user can create, read and update their own profile', async () => {
  const db = await customer();
  await assertSucceeds(getDoc(doc(db, 'users/alice')));
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { name: 'Alice', updatedAt: serverTimestamp() }));
});
test('anonymous clients cannot create profiles or requests', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(db, 'users/alice'), profile()));
  await assertFails(setDoc(doc(db, 'washRequests/a'), request()));
});
test('a user cannot read or change another profile', async () => {
  await customer(); const db = user('bob');
  await assertFails(getDoc(doc(db, 'users/alice')));
  await assertFails(updateDoc(doc(db, 'users/alice'), { name: 'Bob', updatedAt: serverTimestamp() }));
});
test('profile cannot claim another email or server role', async () => {
  const db = user();
  await assertFails(setDoc(doc(db, 'users/alice'), { ...profile(), email: 'victim@example.test' }));
  await assertFails(setDoc(doc(db, 'users/alice'), { ...profile(), role: 'admin' }));
  await customer();
  await assertFails(updateDoc(doc(db, 'users/alice'), { role: 'admin', updatedAt: serverTimestamp() }));
});
test('a customer can submit and query only their own requests', async () => {
  const db = await customer();
  await assertSucceeds(setDoc(doc(db, 'washRequests/a'), request()));
  await assertSucceeds(getDocs(query(collection(db, 'washRequests'), where('customerId', '==', 'alice'), orderBy('createdAt', 'desc'))));
  await assertFails(getDocs(collection(db, 'washRequests')));
});
test('requests need a real profile and may not impersonate another owner', async () => {
  await assertFails(setDoc(doc(user(), 'washRequests/a'), request()));
  const db = await customer();
  await assertFails(setDoc(doc(db, 'washRequests/a'), request('bob')));
});
test('another customer cannot read, change or cancel a request', async () => {
  const db = await customer(); await setDoc(doc(db, 'washRequests/a'), request());
  const bob = await customer('bob');
  await assertFails(getDoc(doc(bob, 'washRequests/a')));
  await assertFails(updateDoc(doc(bob, 'washRequests/a'), { status: 'cancelled', updatedAt: serverTimestamp() }));
});
test('owner cancellation works, but cannot resurrect or edit a cancelled request', async () => {
  const db = await customer(); const ref = doc(db, 'washRequests/a'); await setDoc(ref, request());
  await assertSucceeds(updateDoc(ref, { status: 'cancelled', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { status: 'requested', updatedAt: serverTimestamp() }));
});
test('clients cannot confirm jobs, invent payments or override price', async () => {
  const db = await customer(); const ref = doc(db, 'washRequests/a');
  await assertFails(setDoc(ref, { ...request(), price: 1 }));
  await assertFails(setDoc(ref, { ...request(), status: 'paid' }));
  await setDoc(ref, request());
  await assertFails(updateDoc(ref, { status: 'approved', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { status: 'cancelled', customerId: 'bob', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(db, 'payments/a'), { paid: true }));
});
test('invalid or excessive request content and client timestamps are rejected', async () => {
  const db = await customer(); const ref = doc(db, 'washRequests/a');
  for (const patch of [{ registration: '<script>' }, { notes: 'x'.repeat(501) }, { vehicleType: 'truck' },
    { preferredDate: '2026-99-99' }, { timeWindow: 'whenever' }, { createdAt: new Date(0) }]) {
    await assertFails(setDoc(ref, { ...request(), ...patch }));
  }
});
test('captain may apply and edit details, but cannot approve themselves', async () => {
  const db = await customer(); const ref = doc(db, 'captainApplications/alice');
  await assertSucceeds(setDoc(ref, application()));
  await assertSucceeds(updateDoc(ref, { area: 'Kokapet', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { status: 'approved', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(db, 'captainApplications/bob'), application()));
});
test('captain applications are private and cannot start with approved status', async () => {
  const db = await customer();
  await assertFails(setDoc(doc(db, 'captainApplications/alice'), { ...application(), status: 'approved' }));
  await setDoc(doc(db, 'captainApplications/alice'), application());
  await assertFails(getDoc(doc(user('bob'), 'captainApplications/alice')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'captainApplications/alice')));
});

test('coverage refresh is authenticated read-only; private geo and saved locations remain server-only',async()=>{
 await env.withSecurityRulesDisabled(async ctx=>{
  await setDoc(doc(ctx.firestore(),'availabilitySignals/current'),{revision:1,updatedAt:serverTimestamp()});
  await setDoc(doc(ctx.firestore(),'coverageLocations/loc_private'),{name:'QA home',location:{latitude:17,longitude:78}});
 });
 await assertSucceeds(getDoc(doc(user(),'availabilitySignals/current')));
 await assertFails(setDoc(doc(user(),'availabilitySignals/current'),{revision:999}));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'availabilitySignals/current')));
 await assertFails(getDoc(doc(user(),'coverageLocations/loc_private')));
});
