import {trainingConfig} from './training.mjs';
const https=value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&!!u.hostname;}catch{return false;}};
/** Owner-only publication. Deliberately cannot alter money mode, prices or coverage. */
export function approvedContent(input){
  const result={};
  if(input.support){
    const {phone,email,hours}=input.support;
    if(!/^\+91[6-9]\d{9}$/.test(phone??'')||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email??'')||typeof hours!=='string'||hours.length<3||hours.length>300)throw Error('Supply the approved support phone, email and hours.');
    result.support={phone,email,hours};
  }
  if(input.legal){
    const {entity,termsPrivacyUrl}=input.legal;
    if(typeof entity!=='string'||entity.trim().length<2||entity.length>200||!https(termsPrivacyUrl))throw Error('Supply the operating legal entity and approved HTTPS terms/privacy page.');
    result.legal={entity:entity.trim(),termsPrivacyUrl};
  }
  if(input.training){
    const t=trainingConfig(input);
    if(!/^[A-Za-z0-9_-]{1,60}$/.test(t.version)||t.videos.some(v=>!https(v.url))||typeof t.required!=='boolean'||(t.enabled!==undefined&&typeof t.enabled!=='boolean'))throw Error('Check the approved training version, URLs and requirement.');
    result.training={version:t.version,required:t.required,...(t.enabled!==undefined?{enabled:t.enabled}:{}),videos:t.videos.map(v=>({url:v.url,seconds:v.seconds}))};
  }
  if(!Object.keys(result).length||Object.keys(input).some(k=>!['support','legal','training'].includes(k)))throw Error('Publish only support, legal and/or training configuration.');
  return result;
}
