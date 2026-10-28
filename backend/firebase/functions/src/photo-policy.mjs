// Keep historical test jobs usable when live photo processing is activated.
// An explicit mode list replaces the legacy single-mode gate and fails closed
// when malformed; it cannot enable an unknown booking mode.
export function photoModeEnabled(config,mode){
  if(config?.enabled!==true||!['test','live'].includes(mode))return false;
  if(Object.hasOwn(config,'paymentModes')){
    const modes=config.paymentModes;
    return Array.isArray(modes)&&modes.length>0&&modes.length<=2&&
      new Set(modes).size===modes.length&&modes.every(m=>['test','live'].includes(m))&&modes.includes(mode);
  }
  return config.paymentMode===mode;
}
