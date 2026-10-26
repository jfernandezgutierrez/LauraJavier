// No account data, API responses, invitation links or authenticated pages are cached.
const PREFIX='huellas-offline-'+self.registration.scope+'-';
const CACHE=PREFIX+'v2';
const OFFLINE=new URL('offline.html',self.registration.scope).href;
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.add(OFFLINE)));self.skipWaiting()});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith(PREFIX)&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',event=>{if(event.request.mode==='navigate'&&event.request.url.startsWith(self.registration.scope)){event.respondWith(fetch(event.request).catch(()=>caches.match(OFFLINE)))}});
