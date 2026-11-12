import {initializeApp} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js';
import {getAuth,setPersistence,browserSessionPersistence,GoogleAuthProvider,signInWithPopup,reauthenticateWithPopup,onAuthStateChanged,signOut,connectAuthEmulator} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js';
import {getFunctions,httpsCallable,connectFunctionsEmulator} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-functions.js';
import {config} from './config.mjs';
import {reviewRequirements} from './review-form.mjs';
const $=id=>document.getElementById(id),app=initializeApp(config.firebase,'washkrew-admin'),auth=getAuth(app),functions=getFunctions(app,'asia-south1');
if(config.emulator){
  if(!['localhost','127.0.0.1'].includes(location.hostname)||!config.firebase.projectId.startsWith('demo-'))throw Error('Emulator configuration is restricted to local demo projects.');
  connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});connectFunctionsEmulator(functions,'127.0.0.1',5001);
}
await setPersistence(auth,browserSessionPersistence);
const base=config.emulator?'http://127.0.0.1:5001/'+config.firebase.projectId+'/asia-south1/':'https://asia-south1-'+config.firebase.projectId+'.cloudfunctions.net/';
const labels={underReview:'Awaiting review',notSubmitted:'Not submitted',changesRequested:'Corrections requested',approved:'Approved'};
let deletionCursor=null,deletionGeneration=0;
let generation=0,selection=0,cursor=null,selected=null,mode='test',busy=false,photoURLs=[];
const call=async(name,data={})=>(await httpsCallable(functions,name,{timeout:30000})(data)).data;
const element=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
const date=t=>t?new Intl.DateTimeFormat('en-IN',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Kolkata'}).format(t)+' IST':'—';
function message(text,error=false){$('message').textContent=text;$('message').className=error?'error':'';$('message').hidden=!text;}
function clearPhotos(){photoURLs.forEach(u=>URL.revokeObjectURL(u));photoURLs=[];}
function emptyDetail(){clearPhotos();selected=null;$('detail').replaceChildren(element('div','Select an application to review its submitted details.','empty'));}
async function login(fresh=false){try{message('');const provider=new GoogleAuthProvider();provider.setCustomParameters({prompt:'select_account'});if(fresh&&auth.currentUser)await reauthenticateWithPopup(auth.currentUser,provider);else await signInWithPopup(auth,provider);if(fresh)message('Google session verified.');}catch(e){message(e.message||'Google sign-in did not finish.',true);}}
$('google').onclick=()=>login();$('reauth').onclick=()=>login(true);
$('signout').onclick=async()=>{generation++;selection++;emptyDetail();$('wash-reports-workspace').hidden=true;$('wash-reports').replaceChildren();await signOut(auth);};
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
  if(c.coveragePolicy==='captainAreaV1')form.append(element('p',c.serviceArea?('Serving area: '+c.serviceArea.label+' · '+c.serviceArea.radiusKm+' km. All homes and societies inside this radius use Captain coverage and working hours.'):'Serving area not set. Identity approval is allowed, but the Captain must choose a serving area before going online.','muted'));
  else form.append(element('p','Approve only the societies you have reviewed. Existing work restrictions are not removed by an application approval.','muted'));
  for(const society of (c.coveragePolicy==='captainAreaV1'?[]:c.societies).filter(s=>c.requestedSocietyIds.includes(s.id))){const ch=check(society.name+(society.area?' · '+society.area:''));ch.input.value=society.id;ch.input.disabled=c.status!=='underReview';societies.append(ch.row);societyInputs.push(ch.input);}
  if(c.coveragePolicy!=='captainAreaV1'&&!societyInputs.length)societies.append(element('p','No active requested societies.','muted'));form.append(societies);
  const identity=check('I reviewed the Aadhaar photo and selfie.'),payment=check('I reviewed the payout details.');form.append(identity.row,payment.row);
  const noteLabel=element('label','Review note (visible to the Captain)'),note=element('textarea');note.id='review-note';noteLabel.htmlFor=note.id;note.maxLength=1000;note.placeholder='Explain your decision or the corrections needed.';form.append(noteLabel,note);
  const issues=element('fieldset'),legend=element('legend','For corrections, select the items to fix');issues.append(legend);const issueInputs=[];
  for(const [value,label] of [['aadhaar','Aadhaar photo'],['selfie','Selfie'],['payout','Payout details']]){const ch=check(label);ch.input.value=value;issues.append(ch.row);issueInputs.push(ch.input);}form.append(issues);
  const actions=element('div',undefined,'actions'),approve=element('button',c.paymentModeConfigured==='live'?'Approve for live bookings':'Approve for test bookings','approve'),correct=element('button','Request corrections');
  const actionStatus=element('p',undefined,'notice');actionStatus.setAttribute('role','status');actionStatus.setAttribute('aria-live','polite');
  const values=()=>({note:note.value,identityReviewed:identity.input.checked,payoutReviewed:payment.input.checked,societyIds:societyInputs.filter(i=>i.checked).map(i=>i.value),issues:issueInputs.filter(i=>i.checked).map(i=>i.value)});
  const update=()=>{
    approve.disabled=busy||c.status!=='underReview';correct.disabled=busy||c.status!=='underReview';
    if(!busy){const missing=reviewRequirements('approve',c,values());actionStatus.className='notice';actionStatus.textContent=missing.length?'Before approving: '+missing.join(' '):'Review requirements complete. Choose Approve, then confirm your decision.';}
  };
  form.addEventListener('input',update);
  const confirmation=element('div',undefined,'notice');confirmation.hidden=true;const confirmationText=element('p'),confirmReview=element('button','Confirm review'),cancelReview=element('button','Cancel');confirmation.append(confirmationText,confirmReview,cancelReview);form.append(confirmation);
  let pendingDecision=null;
  cancelReview.onclick=()=>{pendingDecision=null;confirmation.hidden=true;};
  async function decide(decision){
    if(busy)return;
    const missing=reviewRequirements(decision,c,values());if(missing.length){actionStatus.className='error';actionStatus.textContent=missing.join(' ');return;}
    const societies=societyInputs.filter(i=>i.checked).map(i=>i.value),changes=issueInputs.filter(i=>i.checked).map(i=>i.value);
    confirmation.hidden=true;pendingDecision=null;busy=true;update();actionStatus.textContent='Saving your review…';message('Saving your review…');
    try{await call('reviewCaptainApplication',{captainId:c.id,decision,expectedVersion:c.version,reason:note.value.trim(),societyIds:societies,issues:changes,identityReviewed:identity.input.checked,payoutReviewed:payment.input.checked});busy=false;await loadList();await loadDetail(c.id);message(decision==='approve'?(c.coveragePolicy==='captainAreaV1'?'Captain approved. They can work after saving their serving area and going online.':'Captain approved for the selected societies. They can go online in the Captain app.'):'Corrections requested. The Captain can update the marked items and submit again.');}
    catch(e){busy=false;update();actionStatus.className='error';actionStatus.textContent=e.message||'Review was not saved. Refresh before trying again.';message(actionStatus.textContent,true);}
  }
  function prepare(decision){const missing=reviewRequirements(decision,c,values());if(missing.length){actionStatus.className='error';actionStatus.textContent=missing.join(' ');if(note.value.trim().length<5)note.focus({preventScroll:true});actionStatus.scrollIntoView({block:'nearest'});return;}pendingDecision=decision;confirmationText.textContent=decision==='approve'?c.coveragePolicy==='captainAreaV1'?'Approve '+c.name+' to work within their saved serving area?':'Approve '+c.name+' for '+societyInputs.filter(i=>i.checked).length+' selected societies in '+c.paymentModeConfigured+' mode?':'Send these correction requests to '+c.name+'?';confirmation.hidden=false;confirmReview.focus();}
  confirmReview.onclick=()=>{if(pendingDecision)decide(pendingDecision);};
  form.addEventListener('input',()=>{pendingDecision=null;confirmation.hidden=true;});
  approve.onclick=()=>prepare('approve');correct.onclick=()=>prepare('requestChanges');actions.append(approve,correct);form.append(actions,actionStatus);update();root.append(form);
  const history=section('Review history');if(!c.history.length)history.append(element('p','No recorded reviews.','muted'));
  for(const review of c.history){const entry=element('div',undefined,'history');entry.append(element('strong',review.decision==='approve'?'Approved':'Corrections requested'),element('p',review.reason),element('small',review.reviewer+' · '+date(review.createdAt)));history.append(entry);}root.append(history);
}
onAuthStateChanged(auth,async user=>{
  generation++;selection++;emptyDetail();$('wash-reports-workspace').hidden=true;$('wash-reports').replaceChildren();$('email').textContent=user?.email??'';$('signout').hidden=!user;$('signin').hidden=!!user;$('workspace').hidden=true;
  reportGeneration++;reportURLs.forEach(u=>URL.revokeObjectURL(u));reportURLs=[];$('refund-workspace').hidden=true;$('refund-requests').replaceChildren();$('pricing-workspace').hidden=true;$('pricing-editor').replaceChildren();refundGeneration++;pricingGeneration++;
  $('identity-workspace').hidden=true;$('identity-checks').replaceChildren();$('deletion-workspace').hidden=true;$('deletion-requests').replaceChildren();deletionGeneration++;
  if(user){await loadList();if(!$('workspace').hidden){await loadDeletionRequests();await loadIdentityReviews();await loadWashReports();await loadRefundRequests();await loadVehiclePricing();}}else message('');
});


$('deletion-status').onchange=()=>loadDeletionRequests();
$('deletion-refresh').onclick=()=>loadDeletionRequests();
$('deletion-more').onclick=()=>loadDeletionRequests(true);
async function loadDeletionRequests(append=false){
  const seq=++deletionGeneration,account=auth.currentUser?.uid;if(!account)return;
  if(!append){deletionCursor=null;$('deletion-requests').replaceChildren();}
  try{
    const data=await call('listDeletionRequests',{status:$('deletion-status').value,...(append&&deletionCursor?{cursor:deletionCursor}:{})});
    if(seq!==deletionGeneration||auth.currentUser?.uid!==account)return;
    $('deletion-workspace').hidden=false;deletionCursor=data.nextCursor;$('deletion-more').hidden=!deletionCursor;
    for(const r of data.requests){
      const box=section(r.reference),facts=element('div',undefined,'facts');
      facts.append(fact('Name',r.name),fact('Registered mobile',r.phone),fact('App',r.role),fact('Status',r.status),fact('Received',date(r.createdAt)),fact('Complete by',date(r.dueAt)));box.append(facts,element('p',r.email),element('p',r.reason));
      if(r.note)box.append(element('p','Last review: '+r.note));
      if(!['completed','declined'].includes(r.status)){
        const label=element('label','Review note'),note=element('textarea');note.maxLength=1000;label.append(note);box.append(label);
        const verified=check('I contacted the registered number and verified ownership. No SMS code was requested.');
        const permanent=check('I confirm permanent deletion of the requested app account(s).');
        if(['acknowledged','verified','processing'].includes(r.status))box.append(verified.row);
        if(['verified','processing'].includes(r.status))box.append(permanent.row);
        const actions=element('div',undefined,'actions'),status=element('p');status.setAttribute('role','status');
        const targets=r.status==='new'?['acknowledged','declined']:r.status==='acknowledged'?['verified','declined']:['verified','completed','declined'];
        for(const target of targets){const btn=element('button',target==='completed'?'Delete verified account(s)':target==='verified'?'Confirm ownership':target==='acknowledged'?'Acknowledge':'Decline');
          btn.onclick=async()=>{for(const b of actions.children)b.disabled=true;status.textContent='Saving…';try{await call('reviewDeletionRequest',{id:r.id,version:r.version,status:target,note:note.value,ownershipConfirmed:verified.input.checked,confirmDeletion:permanent.input.checked});await loadDeletionRequests();}catch(e){status.textContent=e.message;for(const b of actions.children)b.disabled=false;}};actions.append(btn);}
        box.append(actions,status);
      }
      $('deletion-requests').append(box);
    }
    if(!$('deletion-requests').children.length)$('deletion-requests').append(element('p','No deletion requests in this status.','muted'));
  }catch(e){if(seq===deletionGeneration&&auth.currentUser?.uid===account)message(e.message||'Deletion requests could not be loaded.',true);}
}

$('identity-refresh').onclick=()=>loadIdentityReviews();
async function loadIdentityReviews(){
  const account=auth.currentUser?.uid;if(!account)return;
  try{
    const data=await call('listIdentityReviews');if(auth.currentUser?.uid!==account)return;
    $('identity-workspace').hidden=false;$('identity-checks').replaceChildren();
    for(const item of data.checks){
      const box=section('Booking '+item.id),view=element('button','View current private selfie'),note=element('textarea'),label=element('label','Verification note');label.append(note);
      const confirmed=check('I verified this is the assigned Captain through a human identity check.');
      view.onclick=async()=>{view.disabled=true;try{const token=await auth.currentUser.getIdToken(),r=await fetch(base+'identityReviewPhoto?orderId='+encodeURIComponent(item.id),{headers:{Authorization:'Bearer '+token},cache:'no-store'});if(!r.ok)throw Error('Selfie unavailable. Refresh this review.');const url=URL.createObjectURL(await r.blob());if(auth.currentUser?.uid!==account){URL.revokeObjectURL(url);return;}photoURLs.push(url);const img=element('img');img.src=url;img.alt='Current job selfie';img.style.maxWidth='280px';box.append(img);}catch(e){message(e.message,true);}finally{view.disabled=false;}};
      box.append(element('p','Captain '+item.captainId+' · Review before '+date(item.expiresAt)),view,label,confirmed.row);
      for(const accept of [true,false]){const b=element('button',accept?'Accept verified selfie':'Request retake');b.onclick=async()=>{if(accept&&!confirmed.input.checked){message('Complete and confirm the human identity check first.',true);return;}b.disabled=true;try{await call('reviewCaptainIdentity',{orderId:item.id,accept,reason:note.value});await loadIdentityReviews();}catch(e){message(e.message,true);b.disabled=false;}};box.append(b);}
      $('identity-checks').append(box);
    }
    if(!data.checks.length)$('identity-checks').append(element('p','No current selfies awaiting human review.','muted'));
  }catch(e){if(auth.currentUser?.uid===account)message(e.message,true);}
}

let reportGeneration=0,reportURLs=[];
$('wash-reports-refresh').onclick=()=>loadWashReports();
async function loadWashReports(){
 const seq=++reportGeneration,account=auth.currentUser?.uid;if(!account)return;
 reportURLs.forEach(u=>URL.revokeObjectURL(u));reportURLs=[];$('wash-reports').replaceChildren();
 try{
  const data=await call('listWashReports');if(seq!==reportGeneration||auth.currentUser?.uid!==account)return;
  $('wash-reports-workspace').hidden=false;
  for(const item of data.reports){
   const box=section(item.reference+' · '+item.kind+' · '+item.paymentMode),status=element('p');status.setAttribute('role','status');
   box.append(element('p',item.note||'No description added.'),element('p','Received '+date(item.createdAt)));
   const media=element('div',undefined,'facts'),view=element('button','Load private evidence');box.append(view,media);
   view.onclick=async()=>{
    view.disabled=true;media.replaceChildren();status.textContent='Loading evidence…';
    try{
     for(const name of item.media){
      const token=await auth.currentUser.getIdToken(),r=await fetch(base+'washReportPhoto?'+new URLSearchParams({orderId:item.id,name}),{headers:{Authorization:'Bearer '+token},cache:'no-store'});
      if(!r.ok)throw Error('Some evidence is unavailable. Refresh and investigate before deciding.');
      const blob=await r.blob();if(seq!==reportGeneration||auth.currentUser?.uid!==account)return;
      const url=URL.createObjectURL(blob);reportURLs.push(url);const label=element('figure'),m=element(name.endsWith('.m4a')?'audio':'img');
      m.src=url;if(name.endsWith('.m4a'))m.controls=true;else{m.alt=name;m.width=240;m.style.maxWidth='100%';}
      label.append(m,element('figcaption',name));media.append(label);
     }
     status.textContent=item.media.length?'Evidence loaded. Review every available angle.':'No media attached; investigate with the parties before deciding.';
    }catch(e){status.textContent=e.message;view.disabled=false;}
   };
   const label=element('label','Decision note (visible to both parties)'),note=element('textarea');note.maxLength=1000;label.append(note);box.append(label);
   const confirmed=check('I reviewed the report and available evidence and confirm this human decision.');box.append(confirmed.row);
   const actions=element('div',undefined,'actions');let saving=false;
   for(const [outcome,title] of [['upheld','Uphold report'],['rejected','Reject report'],['damagePriority','Escalate damage review']]){
    const button=element('button',title);button.onclick=async()=>{
     if(saving)return;
     if(!confirmed.input.checked||note.value.trim().length<5){status.textContent='Confirm your review and add a clear decision note.';return;}
     saving=true;for(const b of actions.querySelectorAll('button'))b.disabled=true;
     try{await call('reviewWashReport',{orderId:item.id,expectedVersion:item.version,outcome,note:note.value.trim(),evidenceReviewed:true});await loadWashReports();}
     catch(e){status.textContent=e.message;saving=false;for(const b of actions.querySelectorAll('button'))b.disabled=false;}
    };actions.append(button);
   }
   box.append(actions,status);$('wash-reports').append(box);
  }
  if(!data.reports.length)$('wash-reports').append(element('p','No wash reports awaiting review.','muted'));
 }catch(e){if(auth.currentUser?.uid===account)message(e.message,true);}
}

let refundGeneration=0,refundCursor=null,pricingGeneration=0;
const money=paise=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR'}).format(paise/100);
$('refund-status').onchange=()=>loadRefundRequests();$('refund-refresh').onclick=()=>loadRefundRequests();$('refund-more').onclick=()=>loadRefundRequests(true);
async function loadRefundRequests(append=false){
 const seq=++refundGeneration,account=auth.currentUser?.uid;if(!account)return;
 if(!append){refundCursor=null;$('refund-requests').replaceChildren();}
 try{
  const data=await call('listRefundRequests',{status:$('refund-status').value,...(append&&refundCursor?{cursor:refundCursor}:{})});
  if(seq!==refundGeneration||auth.currentUser?.uid!==account)return;
  $('refund-workspace').hidden=false;refundCursor=data.nextCursor;$('refund-more').hidden=!refundCursor;
  for(const item of data.requests){
   const box=section((item.bookingRef??item.id)+' · '+item.paymentMode),facts=element('div',undefined,'facts');
   facts.append(fact('Paid booking value',money(item.paidValuePaise)),fact('Gateway fee',item.gatewayFeePaise==null?'Historical entitlement preserved':money(item.gatewayFeePaise)),fact('Eligible coupon',money(item.amountPaise)),fact('Status',item.status),fact('Reason',({customerCancellation:'Customer cancellation',serviceUnavailable:'Service unavailable',washProblemUpheld:'Upheld wash report'})[item.reason]??item.reason),fact('Received',date(item.createdAt)));box.append(facts);
   if(item.calculation==='savedHistoricalEntitlement')box.append(element('p','This amount preserves an earlier saved refund entitlement. It is not charged another gateway fee.','muted'));
   if(item.note)box.append(element('p',item.note));if(item.couponCode)box.append(element('p','Issued private coupon: '+item.couponCode));
   if(['pending','ineligible'].includes(item.status)){
    const label=element('label','Decision note (visible to the Customer)'),note=element('textarea');note.maxLength=1000;label.append(note);box.append(label);
    const confirmed=check('I reviewed this booking, payment and refund calculation and confirm this decision.');box.append(confirmed.row);
    const actions=element('div',undefined,'actions'),status=element('p');status.setAttribute('role','status');let saving=false;
    for(const [decision,title] of [['issue','Issue single-use coupon'],['decline','Decline request']]){
     const button=element('button',title,decision==='issue'?'approve':undefined);button.disabled=decision==='issue'&&item.amountPaise<=0;
     button.onclick=async()=>{
      if(saving)return;if(!confirmed.input.checked||note.value.trim().length<5){status.textContent='Confirm your review and add a clear decision note.';return;}
      saving=true;for(const b of actions.querySelectorAll('button'))b.disabled=true;
      try{await call('reviewRefundRequest',{requestId:item.id,expectedVersion:item.version,decision,note:note.value.trim(),confirm:true});await loadRefundRequests();}
      catch(e){status.textContent=e.message;saving=false;for(const b of actions.querySelectorAll('button'))b.disabled=b.textContent==='Issue single-use coupon'&&item.amountPaise<=0;}
     };actions.append(button);
    }box.append(actions,status);
   }
   $('refund-requests').append(box);
  }
  if(!append&&!data.requests.length)$('refund-requests').append(element('p','No refund requests in this status.','muted'));
 }catch(e){if(auth.currentUser?.uid===account)message(e.message,true);}
}
$('pricing-refresh').onclick=()=>loadVehiclePricing();
async function loadVehiclePricing(){
 const seq=++pricingGeneration,account=auth.currentUser?.uid;if(!account)return;
 try{
  const data=await call('getVehiclePricing');if(seq!==pricingGeneration||auth.currentUser?.uid!==account)return;
  $('pricing-workspace').hidden=false;const box=$('pricing-editor');box.replaceChildren();
  box.append(element('p','WashKrew commission: '+(data.platformFeeBps/100)+'% of wash value, in addition to actual gateway fees.','muted'));
  const inputs=[];
  for(const v of data.vehicleTypes){
   const label=element('label',v.name+' (₹)'),input=element('input');input.type='text';input.inputMode='decimal';input.value=(v.pricePaise/100).toFixed(2);input.setAttribute('aria-label',v.name+' price in rupees');label.append(input);box.append(label);inputs.push({kind:v.kind,input});
  }
  const label=element('label','Change note'),note=element('textarea');note.maxLength=1000;label.append(note);box.append(label);
  const confirmed=check('I confirm these customer prices for new bookings.');box.append(confirmed.row);
  const save=element('button','Save vehicle prices','primary'),status=element('p');status.setAttribute('role','status');let saving=false;
  save.onclick=async()=>{
   if(saving)return;
   const prices=inputs.map(({kind,input})=>({kind,pricePaise:/^\d{1,5}(\.\d{1,2})?$/.test(input.value.trim())?Math.round(Number(input.value)*100):null}));
   if(!confirmed.input.checked||note.value.trim().length<5||prices.some(v=>!Number.isInteger(v.pricePaise)||v.pricePaise<100||v.pricePaise>1000000)){status.textContent='Enter prices from ₹1 to ₹10,000, a change note, and confirm them.';return;}
   saving=true;save.disabled=true;
   try{await call('updateVehiclePricing',{expectedVersion:data.version,prices,note:note.value.trim()});await loadVehiclePricing();message('Vehicle prices saved. Existing bookings keep their agreed prices.');}
   catch(e){status.textContent=e.message;saving=false;save.disabled=false;}
  };box.append(save,status);
 }catch(e){if(auth.currentUser?.uid===account)message(e.message,true);}
}
