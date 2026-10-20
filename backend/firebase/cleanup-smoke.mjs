// Remove only the disposable identities and records from smoke.mjs.
import { readFile, unlink, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, deleteUser } from 'firebase/auth';
import { collection, doc, getDoc, getDocs, getFirestore, query, where } from 'firebase/firestore';

const qa = JSON.parse(await readFile('.cache/firebase-qa.json', 'utf8'));
if (qa.projectId !== 'wheelio-apps' || qa.identities.some(i =>
  !/^wheelio-qa-[a-z0-9]+-(customer|isolation)@example\.invalid$/.test(i.email))) {
  throw new Error('Unexpected QA manifest; refusing cleanup.');
}
const config = JSON.parse(await readFile('firebase.local.json', 'utf8'));
if (config.FIREBASE_PROJECT_ID !== qa.projectId) throw new Error('QA project mismatch.');
const app = initializeApp({ projectId: qa.projectId, apiKey: config.FIREBASE_API_KEY, appId: config.FIREBASE_APP_ID }, 'qa-cleanup');
const auth = getAuth(app), db = getFirestore(app);
const literal = (value) => `'${value.replaceAll("'", "''")}'`;
try {
  for (const identity of [...qa.identities]) {
    const { user } = await signInWithEmailAndPassword(auth, identity.email, identity.password);
    if (user.uid !== identity.uid) throw new Error('QA identity mismatch; refusing cleanup.');
    const paths = new Set(qa.documents.filter(path => path === `users/${user.uid}` || path === `captainApplications/${user.uid}`));
    const requests = await getDocs(query(collection(db, 'washRequests'), where('customerId', '==', user.uid)));
    for (const request of requests.docs) paths.add(request.ref.path);
    if ((await getDoc(doc(db, 'captainApplications', user.uid))).exists()) paths.add(`captainApplications/${user.uid}`);
    for (const path of paths) {
      if (!/^(users|captainApplications|washRequests)\/[A-Za-z0-9]+$/.test(path)) throw new Error('Unexpected QA document.');
      const args = ['firestore:delete', path, '--force', '--project', qa.projectId, '--account', 'ajay@trustkeyper.com'];
      const result = process.platform === 'win32'
        ? spawnSync('powershell.exe', ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
            `& firebase ${args.map(literal).join(' ')}; exit $LASTEXITCODE`], { stdio: 'inherit' })
        : spawnSync('firebase', args, { stdio: 'inherit' });
      if (result.error) throw result.error;
      if (result.status !== 0) throw new Error('QA document cleanup failed; credentials were retained for retry.');
    }
    await deleteUser(user);
    qa.identities = qa.identities.filter(i => i.uid !== user.uid);
    qa.documents = qa.documents.filter(path => !paths.has(path));
    await writeFile('.cache/firebase-qa.json', JSON.stringify(qa), { mode: 0o600 });
  }
  await unlink('.cache/firebase-qa.json');
  console.log('Removed all disposable QA documents, accounts and local credentials.');
} finally { await deleteApp(app); }
