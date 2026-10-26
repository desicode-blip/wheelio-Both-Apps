// Push messages are intentionally coarse. Exact locations, phone numbers and
// vehicle identity remain behind authenticated order reads.
export function orderNotices(before,after) {
  const notices=[];
  const titles={searching:'Booking confirmed',onTheWay:'Captain assigned',washing:'Wash started',photosReady:'Your wash photos are ready',approved:'Wash approved',cancelled:'Booking cancelled',disputed:'Wash problem received'};
  if(before.status!==after.status&&titles[after.status]){
    notices.push({recipientId:after.customerId,role:'customer',kind:after.status==='approved'&&after.approvalSource==='automatic'?'autoApproved':after.status,title:after.status==='approved'&&after.approvalSource==='automatic'?'Wash approved at midnight':titles[after.status]});
    if(after.captainId&&['cancelled','approved','disputed'].includes(after.status))notices.push({recipientId:after.captainId,role:'captain',kind:after.status,title:titles[after.status]});
  }
  if(before.refundStatus!==after.refundStatus&&['processed','delayed'].includes(after.refundStatus))notices.push({recipientId:after.customerId,role:'customer',kind:'refund',title:after.refundStatus==='processed'?'Refund processed':'Refund update'});
  if(before.vehicleHelp?.requestedAt?.toMillis?.()!==after.vehicleHelp?.requestedAt?.toMillis?.()&&after.vehicleHelp?.status==='waiting')notices.push({recipientId:after.customerId,role:'customer',kind:'vehicleHelp',title:'Your captain cannot find your vehicle'});
  if(before.vehicleHelp?.status!==after.vehicleHelp?.status&&after.vehicleHelp?.status==='answered'&&after.captainId)notices.push({recipientId:after.captainId,role:'captain',kind:'vehicleHelpAnswered',title:'Your owner replied'});
  if(!before.noShowChecking&&after.noShowChecking){
    notices.push({recipientId:after.customerId,role:'customer',kind:'washStatusCheck',title:'We’re checking your wash'});
    if(after.captainId)notices.push({recipientId:after.captainId,role:'captain',kind:'slotEnded',title:'Your wash window ended'});
  }
  if(before.dispute?.outcome!==after.dispute?.outcome&&['upheld','rejected'].includes(after.dispute?.outcome))notices.push({recipientId:after.customerId,role:'customer',kind:'disputeDecision',title:'Your report has an update'});
  const bodies={searching:'We’re finding a captain for your wash.',onTheWay:'Your captain is on the way.',washing:'Washing has started. Photos when it is done.',photosReady:'Photos are ready. Approve the wash or tell us if something is wrong.',approved:'Your wash has been approved.',autoApproved:'The review deadline passed and your wash was approved.',cancelled:'Open the booking to check your cancellation and refund.',disputed:'We’ve got your report and are checking the photos.',vehicleHelp:'Open your booking to reply to your captain.',vehicleHelpAnswered:'Open the job to see the owner’s reply.',refund:'Open your booking for the verified refund status.'};
  return notices.filter(n=>n.recipientId).map(n=>({...n,body:bodies[n.kind]??'Open WashKrew for the latest booking details.'}));
}

// Quiet hours are defined by the existing design in Hyderabad time, independent
// of the server's timezone. Preferences suppress push, never the private inbox.
export function pushDelivery(notice,prefs,now,legacyEnabled){
  if(prefs?.enabled===false||legacyEnabled===false||notice.deletedAt)return {send:false,sound:false};
  const category=notice.category??(notice.role==='captain'
    ? ['approved','disputed','payoutSent','upiChanged'].includes(notice.kind)?'money':['levelUp','probation'].includes(notice.kind)?'level':['blocked','phoneChanged'].includes(notice.kind)?'account':'jobs'
    : ['refund','paymentPending'].includes(notice.kind)?'payments':['phoneChanged','account'].includes(notice.kind)?'account':notice.kind==='offer'?'offers':'bookings');
  const jobAlert=notice.role==='captain'&&notice.kind==='offer';
  if(!jobAlert&&((prefs?.offCategories??[]).includes(category)||prefs?.mutedUntil>now))return {send:false,sound:false};
  const hour=new Date(now+19800000).getUTCHours(),quiet=prefs?.quietHours===true&&(hour>=22||hour<7);
  return {send:true,sound:jobAlert||((prefs?.soundOn??true)&&!quiet)};
}
