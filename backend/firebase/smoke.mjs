// Exercise the deployed Auth/Firestore backend with disposable QA identities.
// Run from the repository root: node backend/firebase/smoke.mjs
import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase/app';
import { createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { addDoc, collection, doc, getDoc, getDocs, getFirestore, orderBy, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

const config = JSON.parse(await readFile('firebase.local.json', 'utf8'));
try {
  await access('.cache/firebase-qa.json');
  throw new Error('Clean up the previous QA run before starting another smoke test.');
} catch (error) { if (error.code !== 'ENOENT') throw error; }
if (config.FIREBASE_PROJECT_ID !== 'wheelio-apps') throw new Error('Unexpected smoke-test project.');
const sdk = { projectId: config.FIREBASE_PROJECT_ID, apiKey: config.FIREBASE_API_KEY, appId: config.FIREBASE_APP_ID, authDomain: config.FIREBASE_AUTH_DOMAIN };
const run = Date.now().toString(36);
const app = initializeApp(sdk, `qa-${run}`);
const auth = getAuth(app), db = getFirestore(app);
const qa = { projectId: sdk.projectId, identities: [], documents: [] };
await mkdir('.cache', { recursive: true });
async function checkpoint() { await writeFile('.cache/firebase-qa.json', JSON.stringify(qa), { mode: 0o600 }); }
async function create(label) {
  const email = `wheelio-qa-${run}-${label}@example.invalid`, password = randomBytes(24).toString('base64url');
  const { user } = await createUserWithEmailAndPassword(auth, email, password);
  qa.identities.push({ uid: user.uid, email, password }); await checkpoint();
  const path = `users/${user.uid}`;
  await setDoc(doc(db, path), { name: 'WashKrew QA', email, phone: '', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
  qa.documents.push(path); await checkpoint(); return user;
}
try {
  const alice = await create('customer');
  await updateDoc(doc(db, `users/${alice.uid}`), { name: 'WashKrew QA Updated', updatedAt: serverTimestamp() });
  const ref = await addDoc(collection(db, 'washRequests'), { customerId: alice.uid, vehicleType: 'hatchback', registration: 'TS09QA1234', society: 'Disposable QA society',
    parking: 'QA parking', washType: 'wetOutside', preferredDate: '2026-10-25', timeWindow: '8–10 AM', notes: 'Disposable smoke-test request; no service needed.',
    status: 'requested', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
  qa.documents.push(ref.path); await checkpoint();
  const requests = await getDocs(query(collection(db, 'washRequests'), where('customerId', '==', alice.uid), orderBy('createdAt', 'desc')));
  assert.equal(requests.size, 1);
  await updateDoc(ref, { status: 'cancelled', updatedAt: serverTimestamp() });
  assert.equal((await getDoc(ref)).data().status, 'cancelled');
  const application = `captainApplications/${alice.uid}`;
  await setDoc(doc(db, application), { name: 'Disposable QA Captain', phone: '9876543210', area: 'QA test area', status: 'submitted', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
  qa.documents.push(application); await checkpoint();
  await signOut(auth); await create('isolation');
  await assert.rejects(getDoc(ref), error => error.code === 'permission-denied');
  await signOut(auth);
  await signInWithEmailAndPassword(auth, qa.identities[0].email, qa.identities[0].password);
  assert.equal((await getDoc(doc(db, `users/${alice.uid}`))).data().name, 'WashKrew QA Updated');
  await signOut(auth);
  console.log('PASS: live sign-up, profile update, request save/query/cancel, captain application, account isolation, login and logout.');
  console.log('Disposable QA records are listed in .cache/firebase-qa.json for cleanup.');
} finally { await deleteApp(app); }
