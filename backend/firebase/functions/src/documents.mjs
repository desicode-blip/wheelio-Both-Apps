import {PDFDocument,StandardFonts,rgb} from 'pdf-lib';

export async function receiptPdf(order){
  const pdf=await PDFDocument.create(),page=pdf.addPage([595,842]);
  const regular=await pdf.embedFont(StandardFonts.Helvetica),bold=await pdf.embedFont(StandardFonts.HelveticaBold);
  const line=(label,value,y)=>{page.drawText(label,{x:42,y,size:11,font:regular});page.drawText(String(value??'').replace(/[^\x20-\x7e]/g,' ').slice(0,76),{x:195,y,size:11,font:regular});};
  page.drawText('WashKrew',{x:42,y:785,size:25,font:bold,color:rgb(0,73/255,1)});
  page.drawText('Payment receipt',{x:42,y:752,size:18,font:bold});
  const money=n=>`INR ${(Number(n??0)/100).toFixed(2)}`;
  const rows=[['Booking',order.ref],['Service','Doorstep exterior wash'],['Vehicle',order.plate],['Booked date',order.day],['Booked window',`${order.startHour}:00 - ${order.endHour}:00 (IST)`],['Payment status',order.paymentStatus],['Cash payment',money(order.pricePaise)],['Credit used',money(order.creditUsedPaise)],['Free wash used',order.freeWashUsed?'Yes':'No'],['Payment reference',order.razorpayPaymentId??(order.paymentSource==='wallet'?'Wallet / free wash':'Not available')],['Refund amount',money(order.refundAmountPaise)],['Refund status',order.refundStatus??'none']];
  rows.forEach(([k,v],i)=>line(k,v,710-i*29));
  page.drawText(order.paymentMode==='live'?'Live payment record':'Test payment record - no real money charged',{x:42,y:294,size:10,font:bold});
  page.drawText('Generated from the stored booking and verified payment status.',{x:42,y:270,size:10,font:regular});
  page.drawText('This receipt does not certify a bank payout or an unresolved refund.',{x:42,y:251,size:10,font:regular});
  return Buffer.from(await pdf.save());
}

export function evidenceFiles(orderId,order){
  const files=[];
  for(const [angle,path] of Object.entries(order.customerPhotos??{}))files.push({path,name:`customer/${angle}.jpg`});
  for(const [side,entry] of Object.entries(order.evidence??{}))files.push({path:entry.path,name:`captain/${side}.jpg`});
  for(const [i,path] of (order.dispute?.photos??[]).entries())files.push({path,name:`problem/${i+1}.jpg`});
  if(order.dispute?.captainResponse?.path)files.push({path:order.dispute.captainResponse.path,name:'captain/response.m4a'});
  if(files.length>16||files.some(f=>typeof f.path!=='string'||!f.path.startsWith(`orders/${orderId}/`)||f.path.includes('..')||!/^(((customer|captain)\/[a-z0-9_]+|problem\/[0-9]+)\.jpg|captain\/response\.m4a)$/.test(f.name)))throw Error('Invalid evidence record.');
  return files;
}
