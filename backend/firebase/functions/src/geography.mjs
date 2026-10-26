export function validPosition(p){return p&&Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Math.abs(p.latitude)<=90&&Math.abs(p.longitude)<=180;}
export function metresBetween(a,b){
 if(!validPosition(a)||!validPosition(b))return null;
 const r=Math.PI/180,dLat=(b.latitude-a.latitude)*r,dLon=(b.longitude-a.longitude)*r;
 const h=Math.sin(dLat/2)**2+Math.cos(a.latitude*r)*Math.cos(b.latitude*r)*Math.sin(dLon/2)**2;
 return Math.round(6371000*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h))));
}
export function areaFits(captain,order,societies){
 const p=captain.areaPreference;if(!p||p.mode==='all')return true;
 if(p.mode==='societies')return p.societyIds?.includes(order.societyId)===true;
 if(p.mode==='place')return String(p.place).toLowerCase()===String(order.area).toLowerCase();
 const society=societies?.find(s=>s.id===order.societyId),distance=metresBetween(captain.position,society?.location);
 return p.mode==='radius'&&distance!==null&&distance<=p.radiusKm*1000;
}
