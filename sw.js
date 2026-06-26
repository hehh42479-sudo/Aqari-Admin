/* ═══════════════════════════════════════════════════════
   Aqari Plus Admin — Service Worker v2
   Strategy:
   - Static assets (CSS/JS/fonts/icons): Cache-first
   - API calls (/api/*): Network-first with timeout fallback
   - Pages: Network-first with offline fallback
   ═══════════════════════════════════════════════════════ */

const CACHE_NAME    = 'aqari-plus-admin-v4';  // v4: real logo + full mobile responsive fix
const API_ORIGIN    = 'https://aqari-backend.onrender.com';
const OFFLINE_URL   = '/Aqari-Admin/offline.html';

/* Static assets to pre-cache on install */
const PRECACHE_ASSETS = [
  '/Aqari-Admin/',
  '/Aqari-Admin/index.html',
  '/Aqari-Admin/style.css',
  '/Aqari-Admin/app.js',
  '/Aqari-Admin/manifest.json',
  '/Aqari-Admin/icon-192.png',
  '/Aqari-Admin/icon-512.png',
  '/Aqari-Admin/apple-touch-icon.png',
  '/Aqari-Admin/favicon-32.png',
];

/* ── Install: pre-cache static assets ─────────────────── */
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(PRECACHE_ASSETS).catch(err => {
        console.warn('[SW] Pre-cache partial failure (ok):', err);
      });
    })
  );
});

/* ── Activate: clean old caches ───────────────────────── */
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

/* ── Fetch: smart routing strategy ────────────────────── */
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET and non-http(s) requests
  if (request.method !== 'GET') return;
  if (!url.protocol.startsWith('http')) return;

  // ── API calls: Network-first, no cache fallback (always fresh) ──
  if (url.origin === API_ORIGIN || url.pathname.includes('/api/')) {
    event.respondWith(networkOnly(request));
    return;
  }

  // ── Google Fonts: Cache-first with long TTL ──
  if (url.origin === 'https://fonts.googleapis.com' ||
      url.origin === 'https://fonts.gstatic.com') {
    event.respondWith(cacheFirst(request, 'aqari-fonts-v1'));
    return;
  }

  // ── Static assets (CSS/JS/images/icons): Cache-first ──
  if (
    url.pathname.endsWith('.css') ||
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.jpg') ||
    url.pathname.endsWith('.svg') ||
    url.pathname.endsWith('.ico') ||
    url.pathname.endsWith('.woff') ||
    url.pathname.endsWith('.woff2') ||
    url.pathname.endsWith('manifest.json')
  ) {
    event.respondWith(cacheFirst(request, CACHE_NAME));
    return;
  }

  // ── HTML pages: Network-first, offline fallback ──
  if (request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(networkFirstWithOfflineFallback(request));
    return;
  }

  // ── Default: Network-first ──
  event.respondWith(networkFirst(request));
});

/* ── Strategy: Cache-First ────────────────────────────── */
async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    return new Response('Offline', { status: 503 });
  }
}

/* ── Strategy: Network-First ──────────────────────────── */
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await caches.match(request);
    return cached || new Response('Offline', { status: 503 });
  }
}

/* ── Strategy: Network-First with offline HTML fallback ── */
async function networkFirstWithOfflineFallback(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await caches.match(request);
    if (cached) return cached;
    // Return the main app shell as offline fallback
    const shell = await caches.match('/Aqari-Admin/index.html') ||
                  await caches.match('/Aqari-Admin/');
    if (shell) return shell;
    return offlineFallbackResponse();
  }
}

/* ── Strategy: Network-Only (for API) ─────────────────── */
async function networkOnly(request) {
  try {
    return await fetch(request);
  } catch {
    return new Response(
      JSON.stringify({ error: 'لا يوجد اتصال بالإنترنت', offline: true }),
      { status: 503, headers: { 'Content-Type': 'application/json' } }
    );
  }
}

/* ── Inline offline fallback HTML ──────────────────────── */
function offlineFallbackResponse() {
  const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>غير متصل — Aqari Admin</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: 'Cairo', Arial, sans-serif;
    background: linear-gradient(135deg, #082949, #0B3A66);
    min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    color: #fff; padding: 24px;
  }
  .box {
    background: rgba(255,255,255,0.1);
    backdrop-filter: blur(10px);
    border-radius: 24px;
    padding: 48px 32px;
    text-align: center;
    max-width: 420px;
    border: 1px solid rgba(255,255,255,0.2);
  }
  .icon { font-size: 72px; margin-bottom: 24px; }
  h1 { font-size: 24px; font-weight: 800; margin-bottom: 12px; }
  p { font-size: 15px; opacity: 0.85; line-height: 1.6; margin-bottom: 28px; }
  button {
    background: #fff; color: #082949;
    border: none; border-radius: 12px;
    padding: 14px 32px; font-size: 15px; font-weight: 700;
    cursor: pointer; font-family: inherit;
  }
  button:hover { background: #E8F0FE; }
</style>
</head>
<body>
  <div class="box">
    <div class="icon">📡</div>
    <h1>لا يوجد اتصال بالإنترنت</h1>
    <p>يبدو أنك غير متصل بالشبكة. تحقق من اتصالك بالإنترنت وأعد المحاولة.</p>
    <button onclick="location.reload()">🔄 إعادة المحاولة</button>
  </div>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' }
  });
}

/* ── Push Notifications (future use) ─────────────────── */
self.addEventListener('push', event => {
  if (!event.data) return;
  const data = event.data.json().catch(() => ({ title: 'Aqari Admin', body: event.data.text() }));
  event.waitUntil(
    data.then(d =>
      self.registration.showNotification(d.title || 'Aqari Plus Admin', {
        body: d.body || '',
        icon: '/Aqari-Admin/icon-192.png',
        badge: '/Aqari-Admin/icon-192.png',
        dir: 'rtl',
        lang: 'ar',
        vibrate: [200, 100, 200],
        data: { url: d.url || '/Aqari-Admin/' }
      })
    )
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = event.notification.data?.url || '/Aqari-Admin/';
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(clientList => {
      for (const client of clientList) {
        if (client.url === url && 'focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
