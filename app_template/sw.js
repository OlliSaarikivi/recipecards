// sw.template.js
const CACHE = 'recipe-cards-__GIT_HASH__';
const CORE_ASSETS = [
  '/',
  'index.html',
  'manifest.webmanifest',
  'icon-180.png',
  'icon-192.png',
  'icon-512.png'
];

// Install: cache core assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(CORE_ASSETS))
  );
  self.skipWaiting();
});

// Activate: remove old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Fetch: cache-first for core, runtime cache for SVGs
self.addEventListener('fetch', event => {
  const req = event.request;
  const url = new URL(req.url);

  if (req.method !== 'GET' || url.origin !== self.location.origin) return;

  // SVG cards: cache as visited
  if (req.url.includes('/card/') && req.url.endsWith('.svg')) {
    event.respondWith(
      caches.match(req).then(res =>
        res ||
        fetch(req).then(netRes => {
          if (netRes.ok) {
            caches.open(CACHE).then(cache => cache.put(req, netRes.clone()));
          }
          return netRes;
        })
      )
    );
    return;
  }

  // Core: cache-first
  if (
    CORE_ASSETS.includes(url.pathname) ||
    req.url.endsWith('.png') ||
    req.url.endsWith('.webmanifest')
  ) {
    event.respondWith(
      caches.match(req).then(res => res || fetch(req))
    );
    return;
  }

  // Everything else: network-first, fallback cache
  event.respondWith(
    fetch(req).catch(() => caches.match(req))
  );
});
