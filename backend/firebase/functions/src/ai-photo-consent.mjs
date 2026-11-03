export const AI_PHOTO_CONSENT_VERSION='vehicle-after-photos-v1';
export class AiPhotoConsentError extends Error {constructor(message){super(message);this.code='invalid-argument';}}
export function photoAiChoice(input){
  if(input.aiPhotoConsent===undefined)return {allowed:false,version:AI_PHOTO_CONSENT_VERSION,state:'notGiven'};
  if(typeof input.aiPhotoConsent!=='boolean'||input.aiPhotoConsentVersion!==AI_PHOTO_CONSENT_VERSION){
    throw new AiPhotoConsentError('Review the current optional Google AI photo permission.');
  }
  return {allowed:input.aiPhotoConsent,version:AI_PHOTO_CONSENT_VERSION,state:input.aiPhotoConsent?'allowed':'declined'};
}
export const customerAllowsPhotoAi=order=>order.aiPhotoConsent?.customer?.allowed===true&&order.aiPhotoConsent.customer.version===AI_PHOTO_CONSENT_VERSION;
