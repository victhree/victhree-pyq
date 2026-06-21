/* VicThree PYQ service worker — offline app shell + runtime data cache. */
const CACHE = 'victhree-v12';
const SHELL = [
  './', 'index.html', 'browse.html', 'quiz.html',
  'css/styles.css?v=12',
  'js/data.js?v=12', 'js/home.js?v=12', 'js/browse.js?v=12', 'js/quiz.js?v=12',
  'assets/banner.jpg', 'assets/icon-192.png', 'assets/icon-512.png',
  'manifest.webmanifest', 'data/index.json'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => Promise.all(SHELL.map(u => c.add(u).catch(() => {}))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  const isPage = req.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname.endsWith('/');
  const isData = url.pathname.endsWith('.json');

  if (isPage || isData) {
    // network-first so content stays fresh; fall back to cache offline
    e.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return res;
      }).catch(() => caches.match(req).then(m => m || (isPage ? caches.match('index.html') : undefined)))
    );
  } else {
    // cache-first for versioned static assets (css/js/img)
    e.respondWith(
      caches.match(req).then(m => m || fetch(req).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return res;
      }))
    );
  }
});
