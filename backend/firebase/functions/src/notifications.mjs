// Push messages are intentionally coarse. Exact locations, phone numbers and
// vehicle identity remain behind authenticated order reads.
export function orderNotices(before,after) {
  const notices=[];
  const titles={searching:'Booking confirmed',onTheWay:'Captain assigned',washing:'Wash started',photosReady:'Your wash photos are ready',approved:'Wash approved',cancelled:'Booking cancelled',disputed:'Wash problem received'};
  if(before.status!==after.status&&titles[after.status]){
    notices.push({recipientId:after.customerId,role:'customer',kind:after.status,title:titles[after.status]});
    if(after.captainId&&['cancelled','approved','disputed'].includes(after.status))notices.push({recipientId:after.captainId,role:'captain',kind:after.status,title:titles[after.status]});
  }
  if(before.refundStatus!==after.refundStatus&&['processed','delayed'].includes(after.refundStatus))notices.push({recipientId:after.customerId,role:'customer',kind:'refund',title:after.refundStatus==='processed'?'Refund processed':'Refund update'});
  return notices.map(n=>({...n,title:(after.paymentMode==='test'?'Test · ':'')+n.title,body:'Open WashKrew for the latest booking details.'}));
}
