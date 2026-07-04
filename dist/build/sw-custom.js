// Tobmate Custom Service Worker
// 오프라인 캐시 + 홈화면 설치 지원

const CACHE_NAME = 'tobmate-v1';
const STATIC_CACHE = 'tobmate-static-v1';
const API_CACHE = 'tobmate-api-v1';

// 프리캐시 대상 (핵심 정적 파일)
const PRECACHE_URLS = [
  '/',
  '/manifest.json',
  '/favicon.ico',
  '/assets/img/icon-192.png',
  '/assets/img/icon-512.png',
  '/assets/css/font-awesome.min.css',
  '/assets/img/avatar-1.png',
];

// 오프라인 폴백 페이지
const OFFLINE_PAGE = '/offline.html';

// ── Install ──
self.addEventListener('install', event => {
  console.log('[SW] Install');
  event.waitUntil(
    caches.open(STATIC_CACHE).then(cache => {
      return cache.addAll(PRECACHE_URLS).catch(err => {
        console.warn('[SW] 일부 캐시 실패:', err);
      });
    })
  );
  self.skipWaiting();
});

// ── Activate ──
self.addEventListener('activate', event => {
  console.log('[SW] Activate');
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k !== STATIC_CACHE && k !== API_CACHE)
          .map(k => {
            console.log('[SW] 구버전 캐시 삭제:', k);
            return caches.delete(k);
          })
      )
    )
  );
  self.clients.claim();
});

// ── Fetch ──
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // 소켓/API 요청은 캐시 안 함
  if (url.pathname.includes('socket.io') ||
      url.pathname.includes('/go_room/') ||
      url.pathname.startsWith('/tpi-api/') ||
      url.pathname.startsWith('/au-api/') ||
      event.request.method !== 'GET') {
    return;
  }

  // 금시세 API — 네트워크 우선, 실패시 캐시
  if (url.pathname.includes('/au/goldprice')) {
    event.respondWith(
      fetch(event.request)
        .then(res => {
          const clone = res.clone();
          caches.open(API_CACHE).then(c => c.put(event.request, clone));
          return res;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // 정적 파일 — 캐시 우선
  if (url.pathname.match(/\.(js|css|png|jpg|ico|svg|woff|woff2)$/)) {
    event.respondWith(
      caches.match(event.request).then(cached => {
        if (cached) return cached;
        return fetch(event.request).then(res => {
          const clone = res.clone();
          caches.open(STATIC_CACHE).then(c => c.put(event.request, clone));
          return res;
        });
      })
    );
    return;
  }

  // HTML 페이지 — 네트워크 우선, 실패시 캐시 또는 오프라인 페이지
  if (event.request.headers.get('accept').includes('text/html')) {
    event.respondWith(
      fetch(event.request)
        .catch(() =>
          caches.match(event.request).then(cached =>
            cached || caches.match(OFFLINE_PAGE)
          )
        )
    );
    return;
  }
});

// ── Push 알림 (텔레그램 대체용, 추후 활성화) ──
self.addEventListener('push', event => {
  if (!event.data) return;
  const data = event.data.json();
  self.registration.showNotification(data.title || 'Tobmate', {
    body: data.body || '',
    icon: '/assets/img/icon-192.png',
    badge: '/assets/img/icon-192.png',
    data: { url: data.url || '/' }
  });
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data.url)
  );
});
