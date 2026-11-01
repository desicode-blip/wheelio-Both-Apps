// Client feedback only. The server independently authorizes and validates every review.
export function reviewRequirements(decision, application, form) {
  const missing=[];
  if(application.status!=='underReview')missing.push('Only an application awaiting review can be decided.');
  const length=form.note.trim().length;
  if(length<5||length>1000)missing.push('Write a review note of 5–1000 characters.');
  if(decision==='requestChanges'){
    if(!form.issues.length)missing.push('Select at least one item that needs correction.');
    return missing;
  }
  if(!['aadhaar','selfie'].every(kind=>application.photos.some(p=>p.kind===kind&&p.available)))missing.push('Both the Aadhaar photo and selfie must be uploaded.');
  if(application.paymentMode!==application.paymentModeConfigured)missing.push('The application payment mode does not match the current booking mode.');
  if(application.training.required&&(!application.training.completed||!application.training.quizPassed))missing.push('The required training and quiz must be completed.');
  if(!form.identityReviewed)missing.push('Confirm that you reviewed the Aadhaar photo and selfie.');
  if(!form.payoutReviewed)missing.push('Confirm that you reviewed the payout details.');
  const active=new Set(application.societies.filter(s=>application.requestedSocietyIds.includes(s.id)).map(s=>s.id));
  if(application.coveragePolicy!=='captainAreaV1'&&(!form.societyIds.length||form.societyIds.length>10||form.societyIds.some(id=>!active.has(id))))missing.push('Select at least one active society requested by this Captain (maximum 10).');
  return missing;
}
