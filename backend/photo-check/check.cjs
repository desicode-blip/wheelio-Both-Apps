// Exercise the actual private services as the Functions runtime account. Creates
// one short-lived Cloud Run job; no Firebase user, captain, order or payment.
const path=require('node:path');
async function main(){
  const auth=require('./owner.cjs').firebaseOwnerAuth();
  const owner=auth.getAllAccounts().find(a=>a.user.email==='ajay@trustkeyper.com');if(!owner)throw Error('Sign in as the Firebase owner.');
  const token=await auth.getAccessToken(owner.tokens.refresh_token,['https://www.googleapis.com/auth/cloud-platform']),headers={Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'};
  async function api(url,method='GET',body){const r=await fetch(url,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(60000)}),d=await r.json();if(!r.ok)throw Error(`${r.status}: ${d.error?.message??'Service check failed'}`);return d;}
  async function wait(op){for(let i=0;!op.done&&i<80;i++){await new Promise(r=>setTimeout(r,3000));op=await api('https://run.googleapis.com/v2/'+op.name);}if(!op.done||op.error)throw Error(op.error?.message??'Service check timed out');return op.response;}
  const service=await api('https://run.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/services/washkrew-photo-check');
  const fn=await api('https://cloudfunctions.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/functions/updateCaptainLocation');
  const jobId='washkrew-photo-qa-'+Date.now(),job='https://run.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/jobs/'+jobId;
  const script=String.raw`
import json, base64, os, urllib.request, cv2, numpy as np
def request(url, data=None, headers={}):
    req=urllib.request.Request(url,data=json.dumps(data).encode() if data is not None else None,headers={"Content-Type":"application/json",**headers})
    return json.load(urllib.request.urlopen(req,timeout=80))
metadata="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/"
url=os.environ["PHOTO_CHECK_URL"]
identity=urllib.request.urlopen(urllib.request.Request(metadata+"identity?audience="+url,headers={"Metadata-Flavor":"Google"})).read().decode()
authorization={"Authorization":"Bearer "+identity}
fixtures=["https://raw.githubusercontent.com/scikit-image/scikit-image/v0.25.2/skimage/data/astronaut.png","https://raw.githubusercontent.com/matplotlib/matplotlib/v3.10.0/lib/matplotlib/mpl-data/sample_data/grace_hopper.jpg"]
reference,other=[base64.b64encode(urllib.request.urlopen(u,timeout=30).read()).decode() for u in fixtures]
assert request(url+"/compare",{"reference":reference,"capture":reference},authorization)["status"]=="candidateMatch"
assert request(url+"/compare",{"reference":reference,"capture":other},authorization)["status"]=="review"
_,blank=cv2.imencode(".jpg",np.ones((480,640,3),np.uint8)*150)
image=base64.b64encode(blank).decode()
assert request(url+"/thumbnail",{"capture":image},authorization)["issue"]=="obscured"
access=request(metadata+"token",headers={"Metadata-Flavor":"Google"})["access_token"]
parts=[{"text":"Review four after-wash vehicle photos. Return JSON issues with side index 0-3 and a brief reason for images that do not show a visible vehicle. Never invent cleanliness. {\"issues\":[{\"side\":0,\"reason\":\"Vehicle is not visible\"}]}"}]
for side in range(4): parts.extend([{"text":"Side "+str(side)},{"inlineData":{"mimeType":"image/jpeg","data":image}}])
result=request("https://aiplatform.googleapis.com/v1/projects/wheelio-apps/locations/global/publishers/google/models/gemini-3.5-flash:generateContent",{"contents":[{"role":"user","parts":parts}],"generationConfig":{"temperature":0,"responseMimeType":"application/json","maxOutputTokens":4096}}, {"Authorization":"Bearer "+access})
content=json.loads("".join(p.get("text","") for p in result["candidates"][0]["content"]["parts"]))
assert isinstance(content["issues"],list) and len(content["issues"])>0
print("PASS: private IAM invocation, matching/different face comparison, thumbnail quality and structured Gemini vehicle-photo advice. No booking, account or payment created.")
`;
  await wait(await api('https://run.googleapis.com/v2/projects/wheelio-apps/locations/asia-south1/jobs?jobId='+jobId,'POST',{template:{taskCount:1,parallelism:1,template:{serviceAccount:fn.serviceConfig.serviceAccountEmail,maxRetries:0,timeout:'180s',containers:[{image:service.template.containers[0].image,command:['python'],args:['-c',script],env:[{name:'PHOTO_CHECK_URL',value:service.uri}],resources:{limits:{cpu:'1',memory:'1Gi'}}}]}}}));
  try{
    const execution=await wait(await api(job+':run','POST',{}));
    if(execution.succeededCount!==1)throw Error('Private service acceptance failed.');
    console.log('Passed deployed service checks: private IAM access, matching/different-person face comparison, image quality/thumbnail and real Gemini image review. No user, captain, booking or payment created.');
  }catch(e){
    const logs=await api('https://logging.googleapis.com/v2/entries:list','POST',{resourceNames:['projects/wheelio-apps'],filter:`resource.type="cloud_run_job" AND resource.labels.job_name="${jobId}"`,orderBy:'timestamp desc',pageSize:12});
    console.error((logs.entries??[]).map(x=>x.textPayload??'').join('\n'));throw e;
  }finally{await wait(await api(job,'DELETE'));}
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
