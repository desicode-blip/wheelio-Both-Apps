// Human review and recording only. No payment transfer is initiated here.
const {readFileSync}=require('node:fs');
const {createRequire}=require('node:module');
const {execFileSync}=require('node:child_process');
const path=require('node:path');
async function main(){
  const [action,input,...flags]=process.argv.slice(2);
  if(action!=='check-access'&&(!['resolve-dispute','record-payout'].includes(action)||!input)){console.log('Usage: node backend/firebase/operator.cjs check-access | resolve-dispute|record-payout .cache/review.json [--confirm]\nReview the real case or completed transfer first. Without --confirm this only shows the prepared action.');return;}
  const data=action==='check-access'?{}:JSON.parse(readFileSync(input,'utf8'));
  if(action!=='check-access'&&!flags.includes('--confirm')){console.log(`Prepared ${action} for ${data.orderId??data.captainId??'(missing reference)'}. No data changed. Review the private input and use --confirm to apply your decision.`);return;}
  let cli;
  try{cli=require('firebase-tools/lib/auth.js');}catch{
    const root=process.env.APPDATA?path.join(process.env.APPDATA,'npm/node_modules'):execFileSync('npm',['root','-g'],{encoding:'utf8'}).trim();
    cli=createRequire(path.join(root,'firebase-tools/package.json'))('./lib/auth.js');
  }
  const owner=cli.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');
  if(!owner)throw Error('Sign in to Firebase CLI as the project owner first.');
  const {Firestore}=require('./functions/node_modules/@google-cloud/firestore');
  const {OAuth2Client}=require('./functions/node_modules/google-auth-library');
  const {WashKrewService}=await import('./functions/src/service.mjs');
  const token=await cli.getAccessToken(owner.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
  const authClient=new OAuth2Client();authClient.setCredentials({access_token:token.access_token,expiry_date:Date.now()+3500000});
  const db=new Firestore({projectId:'wheelio-apps',authClient});
  try{if(action==='check-access'){await db.doc('config/operations').get();console.log('Owner access to WashKrew verified (read only).');return;}const service=new WashKrewService({db});await service[action==='resolve-dispute'?'resolveDispute':'recordPayout'](data);console.log(`${action} recorded. No money was transferred by this command.`);}finally{await db.terminate();}
}
main().catch(e=>{console.error(e.code??'Operation failed',e.message);process.exitCode=1;});
