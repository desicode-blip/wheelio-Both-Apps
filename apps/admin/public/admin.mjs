import {initializeApp} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js';
import {getAuth,setPersistence,browserSessionPersistence,GoogleAuthProvider,signInWithPopup,reauthenticateWithPopup,onAuthStateChanged,signOut,connectAuthEmulator} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js';
import {getFunctions,httpsCallable,connectFunctionsEmulator} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-functions.js';
import {config} from './config.mjs';
const $=id=>document.getElementById(id),app=initializeApp(config.firebase,'washkrew-admin'),auth=getAuth(app),functions=getFunctions(app,'asia-south1');
if(config.emulator){
  if(!['localhost','127.0.0.1'].includes(location.hostname)||!config.firebase.projectId.startsWith('demo-'))throw Error('Emulator configuration is restricted to local demo projects.');
  connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});connectFunctionsEmulator(functions,'127.0.0.1',5001);
}
await setPersistence(auth,browserSessionPersistence);
const base=config.emulator?'http://127.0.0.1:5001/'+config.firebase.projectId+'/asia-south1/':'https://asia-south1-'+config.firebase.projectId+'.cloudfunctions.net/';
const labels={underReview:'Awaiting review',notSubmitted:'Not submitted',changesRequested:'Corrections requested',approved:'Approved'};
let generation=0,selection=0,cursor=null,selected=null,mode='test',busy=false,photoURLs=[];
const call=async(name,data={})=>(await httpsCallable(functions,name)(data)).data;
const element=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
const date=t=>t?new Intl.DateTimeFormat('en-IN',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Kolkata'}).format(t)+' IST':'—';
function message(text,error=false){$('message').textContent=text;$('message').className=error?'error':'';$('message').hidden=!text;}
function clearPhotos(){photoURLs.forEach(u=>URL.revokeObjectURL(u));photoURLs=[];}
function emptyDetail(){clearPhotos();selected=null;$('detail').replaceChildren(element('div','Select an application to review its submitted details.','empty'));}
async function login(fresh=false){try{message('');const provider=new GoogleAuthProvider();provider.setCustomParameters({prompt:'select_account'});if(fresh&&auth.currentUser)await reauthenticateWithPopup(auth.currentUser,provider);else await signInWithPopup(auth,provider);if(fresh)message('Google session verified.');}catch(e){message(e.message||'Google sign-in did not finish.',true);}}
$('google').onclick=()=>login();$('reauth').onclick=()=>login(true);
$('signout').onclick=async()=>{generation++;selection++;emptyDetail();await signOut(auth);};
$('refresh').onclick=()=>loadList();$('status').onchange=()=>loadList();$('more').onclick=()=>loadList(true);
async function loadList(append=false){
  const current=++generation;selection++;emptyDetail();$('refresh').disabled=true;message('Loading applications…');
  if(!append){cursor=null;$('applications').replaceChildren();}
  try{
    const data=await call('listCaptainApplications',{status:$('status').value,...(append&&cursor?{cursor}:{})});if(current!==generation)return;
    mode=data.paymentMode;$('mode').textContent=(config.emulator?'Local emulator · ':'')+(mode==='live'?'Live booking mode':'Test booking mode');
    $('workspace').hidden=false;cursor=data.nextCursor;$('more').hidden=!cursor;
    for(const item of data.applications){
      const button=element('button',undefined,'application');button.dataset.id=item.id;button.setAttribute('aria-current','false');
      button.append(element('span',item.name||'Unnamed applicant'),element('small',item.phone),element('small',labels[item.status]??item.status));
      button.onclick=()=>loadDetail(item.id);$('applications').append(button);
    }
    if(!$('applications').children.length)$('applications').append(element('p','No applications in this status.','muted'));
    message('');
  }catch(e){if(current===generation){$('workspace').hidden=true;message(e.message||'Applications could not be loaded.',true);}}
  finally{if(current===generation)$('refresh').disabled=false;}
}
async function loadDetail(id){
  if(busy)return;const current=++selection;emptyDetail();message('Loading application…');
  for(const button of $('applications').querySelectorAll('button'))button.setAttribute('aria-current',String(button.dataset.id===id));
  try{const data=await call('getCaptainApplication',{captainId:id});if(current!==selection)return;selected=data;renderDetail(data);message('');}
  catch(e){if(current===selection)message(e.message||'Application could not be loaded.',true);}
}
function fact(label,value){const e=element('div',undefined,'fact');e.append(element('small',label),element('span',value??'—'));return e;}
function section(title){const e=element('section',undefined,'section');e.append(element('h3',title));return e;}
function check(label,onChange){const row=element('label',undefined,'check'),input=element('input');input.type='checkbox';row.append(input,element('span',label));if(onChange)input.onchange=onChange;return {row,input};}
function renderDetail(c){
  const root=$('detail');root.replaceChildren();
  const head=element('div',undefined,'identity-head'),title=element('div');title.append(element('h2',c.name||'Unnamed applicant'),element('p',c.phone,'muted'));head.append(title,element('span',labels[c.status]??c.status,'badge'));root.append(head);
  const facts=element('div',undefined,'facts');facts.append(fact('Submitted',date(c.submittedAt)),fact('Application mode',c.paymentMode));if(c.training.enabled)facts.append(fact('Training',c.training.required?(c.training.completed?'Current training completed':'Current training incomplete'):'Not required by current configuration'),fact('Quiz',c.training.quizPassed?'Current quiz passed':c.training.required?'Current quiz incomplete':'Not required by current configuration'));else facts.append(fact('Approval process','Admin document review'));root.append(facts);
  if(c.training.required&&(!c.training.completed||!c.training.quizPassed))root.append(element('p','Approval is blocked until the configured training and quiz are completed. Design placeholders cannot complete training.','notice'));
  if(c.status==='notSubmitted')root.append(element('p','The Captain has not submitted an application. They must finish onboarding and agree to the rules before a review can be recorded.','notice'));
  if(c.reviewReason)root.append(element('p','Last review: '+c.reviewReason,'notice'));
  const photos=section('Identity photos'),grid=element('div',undefined,'photos');
  for(const p of c.photos){
    const box=element('div',undefined,'photo');box.append(element('h3',p.kind==='aadhaar'?'Aadhaar photo':p.kind==='selfie'?'Captain selfie':'Bank proof'));
    if(!p.available)box.append(element('p','Not uploaded','muted'));
    else{const button=element('button','View private photo');button.onclick=async()=>{
      button.disabled=true;button.textContent='Loading…';
      try{const token=await auth.currentUser.getIdToken(),r=await fetch(base+'captainApplicationPhoto?captainId='+encodeURIComponent(c.id)+'&kind='+encodeURIComponent(p.kind),{headers:{Authorization:'Bearer '+token},cache:'no-store'});
        if(!r.ok)throw Error(await r.text());const blob=await r.blob();if(selected!==c)return;const url=URL.createObjectURL(blob);photoURLs.push(url);const image=element('img');image.alt=p.kind==='selfie'?'Submitted Captain selfie':'Submitted '+p.kind+' photo';image.src=url;box.append(image);button.hidden=true;
      }catch(e){message(e.message||'Private photo could not be loaded.',true);button.disabled=false;button.textContent='Retry private photo';}
    };box.append(button);}grid.append(box);
  }photos.append(grid);root.append(photos);
  const payout=section('Payout details'),p=c.payout;
  payout.append(fact('Method',p?.method??'Not supplied'));
  if(p?.method==='upi')payout.append(fact('UPI ID',p.upi));
  else if(p?.method==='bank')payout.append(fact('Account number',p.accountNumber));
  root.append(payout);
  const form=section('Record your review'),societies=element('div'),societyInputs=[];
  form.append(element('p','Approve only the societies you have reviewed. Existing work restrictions are not removed by an application approval.','muted'));
  for(const society of c.societies.filter(s=>c.requestedSocietyIds.includes(s.id))){const ch=check(society.name+(society.area?' · '+society.area:''));ch.input.value=society.id;ch.input.disabled=c.status!=='underReview';societies.append(ch.row);societyInputs.push(ch.input);}
  if(!societyInputs.length)societies.append(element('p','No active requested societies.','muted'));form.append(societies);
  const identity=check('I reviewed the Aadhaar photo and selfie.'),payment=check('I reviewed the payout details.');form.append(identity.row,payment.row);
  const noteLabel=element('label','Review note (visible to the Captain)'),note=element('textarea');note.id='review-note';noteLabel.htmlFor=note.id;note.maxLength=1000;note.placeholder='Explain your decision or the corrections needed.';form.append(noteLabel,note);
  const issues=element('fieldset'),legend=element('legend','For corrections, select the items to fix');issues.append(legend);const issueInputs=[];
  for(const [value,label] of [['aadhaar','Aadhaar photo'],['selfie','Selfie'],['payout','Payout details']]){const ch=check(label);ch.input.value=value;issues.append(ch.row);issueInputs.push(ch.input);}form.append(issues);
  const actions=element('div',undefined,'actions'),approve=element('button',c.paymentModeConfigured==='live'?'Approve for live bookings':'Approve for test bookings','approve'),correct=element('button','Request corrections');
  const eligible=c.status==='underReview'&&c.photos.filter(p=>['aadhaar','selfie'].includes(p.kind)&&p.available).length===2&&(!c.training.required||(c.training.completed&&c.training.quizPassed));
  const update=()=>{approve.disabled=busy||!eligible||!identity.input.checked||!payment.input.checked||!societyInputs.some(i=>i.checked)||note.value.trim().length<5;correct.disabled=busy||c.status!=='underReview'||!issueInputs.some(i=>i.checked)||note.value.trim().length<5;};
  form.addEventListener('input',update);
  const confirmation=element('div',undefined,'notice');confirmation.hidden=true;const confirmationText=element('p'),confirmReview=element('button','Confirm review'),cancelReview=element('button','Cancel');confirmation.append(confirmationText,confirmReview,cancelReview);form.append(confirmation);
  let pendingDecision=null;
  cancelReview.onclick=()=>{pendingDecision=null;confirmation.hidden=true;};
  async function decide(decision){
    if(busy)return;
    const societies=societyInputs.filter(i=>i.checked).map(i=>i.value),changes=issueInputs.filter(i=>i.checked).map(i=>i.value);
    confirmation.hidden=true;pendingDecision=null;busy=true;update();message('Saving your review…');
    try{await call('reviewCaptainApplication',{captainId:c.id,decision,expectedVersion:c.version,reason:note.value.trim(),societyIds:societies,issues:changes,identityReviewed:identity.input.checked,payoutReviewed:payment.input.checked});busy=false;await loadList();await loadDetail(c.id);message(decision==='approve'?'Captain approved for the selected societies. They can go online in the Captain app.':'Corrections requested. The Captain can update the marked items and submit again.');}
    catch(e){busy=false;update();message(e.message||'Review was not saved. Refresh before trying again.',true);}
  }
  function prepare(decision){pendingDecision=decision;confirmationText.textContent=decision==='approve'?'Approve '+c.name+' for '+societyInputs.filter(i=>i.checked).length+' selected societies in '+c.paymentModeConfigured+' mode?':'Send these correction requests to '+c.name+'?';confirmation.hidden=false;confirmReview.focus();}
  confirmReview.onclick=()=>{if(pendingDecision)decide(pendingDecision);};
  form.addEventListener('input',()=>{pendingDecision=null;confirmation.hidden=true;});
  approve.onclick=()=>prepare('approve');correct.onclick=()=>prepare('requestChanges');actions.append(approve,correct);form.append(actions);update();root.append(form);
  const history=section('Review history');if(!c.history.length)history.append(element('p','No recorded reviews.','muted'));
  for(const review of c.history){const entry=element('div',undefined,'history');entry.append(element('strong',review.decision==='approve'?'Approved':'Corrections requested'),element('p',review.reason),element('small',review.reviewer+' · '+date(review.createdAt)));history.append(entry);}root.append(history);
}
onAuthStateChanged(auth,async user=>{
  generation++;selection++;emptyDetail();$('email').textContent=user?.email??'';$('signout').hidden=!user;$('signin').hidden=!!user;$('workspace').hidden=true;
  if(user)await loadList();else message('');
});
