import {randomUUID} from 'node:crypto';
import {Timestamp,FieldValue} from 'firebase-admin/firestore';

// Matches the authored five-question bank in the existing Captain design.
export const trainingQuizVersion='wash-safety-1';
const answers=[0,0,1,0,0];
export class TrainingError extends Error {constructor(code,message){super(message);this.code=code;}}
const fail=(code,message)=>{throw new TrainingError(code,message);};
export function trainingConfig(cfg){
  const t=cfg.training;
  if(!t?.version||!Array.isArray(t.videos)||t.videos.length!==3||t.videos.some(v=>!/^https:\/\//.test(v.url??'')||!Number.isFinite(v.seconds)||v.seconds<10||v.seconds>3600))fail('failed-precondition','Approved training videos are awaiting publication.');
  return t;
}
export async function startTraining(service,auth,data){
  const uid=service.actor(auth),training=trainingConfig(await service.config()),index=data.index;
  if(!Number.isInteger(index)||index<0||index>2)fail('invalid-argument','Choose a training video.');
  const session=randomUUID(),now=service.now(),ref=service.db.doc(`captains/${uid}/training/${index}`);
  const result=await service.db.runTransaction(async tx=>{
    const [captain,previous]=await Promise.all([tx.get(service.db.doc(`captains/${uid}`)),tx.get(ref)]);
    if(!captain.exists)fail('failed-precondition','Complete your Captain profile first.');
    const p=previous.data(),watched=p?.version===training.version?Math.min(p.watchedSeconds??0,training.videos[index].seconds):0;
    tx.set(ref,{version:training.version,session,watchedSeconds:watched,positionSeconds:watched,lastHeartbeatAt:Timestamp.fromMillis(now),expiresAt:Timestamp.fromMillis(now+6*3600000)});
    return {watchedSeconds:watched};
  });
  return {...result,session,version:training.version,...training.videos[index]};
}
export async function trainingHeartbeat(service,auth,data){
  const uid=service.actor(auth),training=trainingConfig(await service.config()),index=data.index;
  if(!Number.isInteger(index)||index<0||index>2||!Number.isFinite(data.positionSeconds)||data.positionSeconds<0)fail('invalid-argument','Invalid training progress.');
  const ref=service.db.doc(`captains/${uid}/training/${index}`),cap=service.db.doc(`captains/${uid}`),now=service.now();
  return service.db.runTransaction(async tx=>{
    const [snap,captain]=await Promise.all([tx.get(ref),tx.get(cap)]),p=snap.data();
    if(!captain.exists||!p||p.session!==data.session||p.version!==training.version||p.expiresAt.toMillis()<now)fail('failed-precondition','Reopen this training video to continue.');
    const elapsed=Math.max(0,(now-p.lastHeartbeatAt.toMillis())/1000),advanced=Math.max(0,data.positionSeconds-p.positionSeconds),duration=training.videos[index].seconds;
    // A seek, replayed position or backgrounded player cannot credit unwatched time.
    const credit=advanced<=elapsed+2?Math.min(advanced,elapsed,15):0;
    const watched=Math.min(duration,p.watchedSeconds+credit),done=watched>=duration-2&&data.positionSeconds>=duration-2;
    tx.update(ref,{watchedSeconds:watched,positionSeconds:Math.min(data.positionSeconds,duration),lastHeartbeatAt:Timestamp.fromMillis(now),completed:done});
    const c=captain.data(),completed=c.trainingVersion===training.version?(c.trainingVideos??[]):[];
    const videos=done?[...new Set([...completed,index])]:completed;
    tx.update(cap,{trainingVersion:training.version,trainingVideos:videos,...(videos.length===3?{trainingCompletedAt:Timestamp.fromMillis(now)}:{trainingCompletedAt:FieldValue.delete(),quizPassedAt:FieldValue.delete()})});
    return {watchedSeconds:watched,completed:done};
  });
}
export async function submitQuiz(service,auth,data){
  const uid=service.actor(auth),training=trainingConfig(await service.config());
  if(data.version!==trainingQuizVersion||!Array.isArray(data.answers)||data.answers.length!==5||data.answers.some(n=>![0,1].includes(n)))fail('invalid-argument','Reopen the quiz and answer all five questions.');
  const ref=service.db.doc(`captains/${uid}`),now=service.now();
  return service.db.runTransaction(async tx=>{
    const c=(await tx.get(ref)).data();
    if(!c?.trainingCompletedAt||c.trainingVersion!==training.version||new Set(c.trainingVideos??[]).size!==3)fail('failed-precondition','Finish the approved training videos before taking the quiz.');
    if(now-(c.quizAttemptAt?.toMillis()??0)<10000)fail('resource-exhausted','Please wait a moment before trying the quiz again.');
    const score=answers.reduce((sum,n,i)=>sum+(data.answers[i]===n?1:0),0),passed=score>=4;
    tx.update(ref,{quizVersion:trainingQuizVersion,quizScore:score,quizAttemptAt:Timestamp.fromMillis(now),quizPassedAt:passed?Timestamp.fromMillis(now):FieldValue.delete()});
    tx.create(ref.collection('trainingAttempts').doc(),{version:trainingQuizVersion,trainingVersion:training.version,answers:data.answers,score,passed,createdAt:Timestamp.fromMillis(now)});
    return {score,passed};
  });
}
