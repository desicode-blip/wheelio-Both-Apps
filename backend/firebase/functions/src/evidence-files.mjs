export function evidenceFiles(orderId,order){
  const files=[];
  for(const [angle,path] of Object.entries(order.customerPhotos??{}))files.push({path,name:`customer/${angle}.jpg`});
  for(const [side,entry] of Object.entries(order.evidence??{}))files.push({path:entry.path,name:`captain/${side}.jpg`});
  for(const [i,path] of (order.dispute?.photos??[]).entries())files.push({path,name:`problem/${i+1}.jpg`});
  if(order.dispute?.captainResponse?.path)files.push({path:order.dispute.captainResponse.path,name:'captain/response.m4a'});
  if(files.length>16||files.some(f=>typeof f.path!=='string'||!f.path.startsWith(`orders/${orderId}/`)||f.path.includes('..')||!/^(((customer|captain)\/[a-z0-9_]+|problem\/[0-9]+)\.jpg|captain\/response\.m4a)$/.test(f.name)))throw Error('Invalid evidence record.');
  return files;
}
