import {validPosition} from './geography.mjs';

/** Only the server key can call Routes. Never return provider bodies or keys. */
export class GoogleRoutes {
  constructor(key, request = fetch) { this.key = key; this.request = request; }
  async arrival(origin, destination) {
    if (!validPosition(origin) || !validPosition(destination)) throw Error('Invalid route position');
    const response = await this.request('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method:'POST', signal:AbortSignal.timeout(8000),
      headers:{'Content-Type':'application/json','X-Goog-Api-Key':this.key,'X-Goog-FieldMask':'routes.duration,routes.distanceMeters'},
      body:JSON.stringify({origin:{location:{latLng:origin}},destination:{location:{latLng:destination}},travelMode:'DRIVE',routingPreference:'TRAFFIC_AWARE',units:'METRIC'}),
    });
    if (!response.ok) throw Error('Route provider unavailable');
    const route=(await response.json()).routes?.[0],seconds=Number(String(route?.duration??'').replace(/s$/,''));
    if (!Number.isFinite(seconds)||seconds<0||seconds>86400||!Number.isFinite(route?.distanceMeters)||route.distanceMeters<0) throw Error('No usable route');
    return {seconds:Math.ceil(seconds),distanceMetres:route.distanceMeters};
  }
}
