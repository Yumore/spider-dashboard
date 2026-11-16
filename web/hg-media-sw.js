const CACHE_NAME = 'guomu-media-v1';
const MEDIA_PATTERN = /\.(m3u8|ts|m4s|mp4|m4a|aac|key)(?:$|\?)/i;

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

async function mediaCacheKey(request) {
  const url = new URL(request.url);
  url.search = '';
  url.hash = '';
  return new Request(url.toString(), { method: 'GET' });
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || !MEDIA_PATTERN.test(request.url)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const key = await mediaCacheKey(request);
    const cached = await cache.match(key);
    if (cached) return cached;
    try {
      const response = await fetch(request);
      if (response.ok || response.type === 'opaque') {
        await cache.put(key, response.clone());
      }
      return response;
    } catch (error) {
      return Response.error();
    }
  })());
});
