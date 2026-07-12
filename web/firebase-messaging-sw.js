// Firebase Cloud Messaging Service Worker
// This handles background push notifications on web
// Also handles static asset caching for PWA offline support

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// =============================================
// CACHE CONFIGURATION
// =============================================

// IMPORTANT: Update this version when deploying new builds to bust the cache
// Should match the version in pubspec.yaml for consistency
const CACHE_VERSION = '77';
const CACHE_NAME = `aurogram-v${CACHE_VERSION}`;

// Static assets to pre-cache on install
// NOTE: Do NOT include main.dart.js here - it changes every build and should be fetched fresh
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/offline.html',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  '/icons/icon_transparent.png',
  '/assets/images/aryabhatt.png',
  '/favicon.png',
];

// Critical app files that should always check network first.
// HTML must be here so users always get the latest shell after deploys.
const NETWORK_FIRST_PATTERNS = [
  /main\.dart\.js$/,
  /flutter_bootstrap\.js$/,
  /\/$/,           // navigation to root
  /index\.html$/,  // direct index.html requests
];

// Assets to cache on first fetch (dynamic caching)
const CACHEABLE_PATTERNS = [
  /\.(?:js|css|woff2?|ttf|eot)$/,
  /assets\/.*\.(?:png|jpg|jpeg|gif|webp|svg)$/,
  /canvaskit\/.*\.(?:js|wasm)$/,
];

// Assets to never cache
const NEVER_CACHE_PATTERNS = [
  /firestore\.googleapis\.com/,
  /firebase.*\.com\/v1/,
  /identitytoolkit\.googleapis\.com/,
  /securetoken\.googleapis\.com/,
];

// Initialize Firebase with your config
firebase.initializeApp({
  apiKey: 'AIzaSyCWZFQNhmaJnDW78rd7iJXeKN0bOdmg24s',
  appId: '1:735015361682:web:da57a1bfa188cda3645a4b',
  messagingSenderId: '735015361682',
  projectId: 'ty-dev-516d7',
  authDomain: 'aurogram.in',
  storageBucket: 'ty-dev-516d7.appspot.com',
  measurementId: 'G-NHR6XL5GVV',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.tag || 'default',
    data: payload.data,
    // Add action buttons for specific notification types
    actions: getNotificationActions(payload.data?.type),
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Get notification actions based on type
function getNotificationActions(type) {
  switch (type) {
    case 'incoming_call':
      return [
        { action: 'answer', title: 'Answer' },
        { action: 'decline', title: 'Decline' },
      ];
    case 'message':
      return [
        { action: 'reply', title: 'Reply' },
      ];
    default:
      return [];
  }
}

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click:', event);
  
  event.notification.close();

  const data = event.notification.data || {};
  let url = '/';

  // Determine URL based on notification type
  if (data.type === 'message' && data.spaceId) {
    url = `/space/${data.spaceId}`;
  } else if (data.type === 'reply' && data.postId) {
    url = `/post/${data.postId}`;
  } else if (data.type === 'follow' && data.userId) {
    url = `/profile/${data.userId}`;
  }

  // Handle action button clicks
  if (event.action === 'answer' && data.callId) {
    url = `/call/${data.callId}`;
  } else if (event.action === 'decline') {
    // Just close the notification
    return;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If app is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.postMessage({ type: 'notification_click', data });
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

// =============================================
// CACHE MANAGEMENT
// =============================================

// Handle messages from the page (e.g. force skipWaiting)
self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
  }
});

// Handle service worker installation - pre-cache static assets
self.addEventListener('install', (event) => {
  console.log('[firebase-messaging-sw.js] Service worker installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[firebase-messaging-sw.js] Pre-caching static assets');
        // Try to cache each asset, but don't fail if some are missing
        return Promise.allSettled(
          STATIC_ASSETS.map((url) => 
            cache.add(url).catch((err) => {
              console.warn(`[firebase-messaging-sw.js] Failed to cache: ${url}`, err);
            })
          )
        );
      })
      .then(() => {
        console.log('[firebase-messaging-sw.js] Service worker installed');
        // Let the page decide when to activate via 'skipWaiting' message.
        // Calling skipWaiting() here caused immediate activate → claim →
        // controllerchange → reload loops on every deploy.
        // self.skipWaiting();  // REMOVED — was causing infinite reload loops
      })
  );
});

// Handle service worker activation - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[firebase-messaging-sw.js] Service worker activating...');
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('[firebase-messaging-sw.js] Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => {
        console.log('[firebase-messaging-sw.js] Service worker activated');
        // clients.claim() makes this SW take control of all open tabs.
        // The page's 'controllerchange' listener handles the reload.
        // Do NOT broadcast additional messages — that caused infinite reload loops.
        return clients.claim();
      })
  );
});

// Handle fetch events with appropriate caching strategies
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;
  
  // Skip requests that should never be cached
  const url = event.request.url;
  if (NEVER_CACHE_PATTERNS.some((pattern) => pattern.test(url))) {
    return;
  }

  // Skip cross-origin requests except for specific CDNs
  const isAllowedOrigin = 
    url.startsWith(self.location.origin) ||
    url.includes('fonts.googleapis.com') ||
    url.includes('fonts.gstatic.com');
  
  if (!isAllowedOrigin) return;

  // Use NETWORK-FIRST for critical app files (main.dart.js, etc.)
  // This ensures users always get the latest app code
  const isNetworkFirst = NETWORK_FIRST_PATTERNS.some((pattern) => pattern.test(url));
  
  if (isNetworkFirst) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          // Cache the fresh response for offline use
          if (response && response.status === 200) {
            const responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then((cache) => cache.put(event.request, responseToCache))
              .catch(() => {});
          }
          return response;
        })
        .catch(async () => {
          // Network failed, try cache as fallback
          const cachedResponse = await caches.match(event.request);
          if (cachedResponse) return cachedResponse;
          // For documents, show offline page
          if (event.request.destination === 'document') {
            return caches.match('/offline.html');
          }
          return null;
        })
    );
    return;
  }

  // Use CACHE-FIRST for static assets (images, fonts, etc.)
  event.respondWith(
    caches.match(event.request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          // Return cached version
          return cachedResponse;
        }

        // Fetch from network
        return fetch(event.request)
          .then((response) => {
            // Don't cache non-ok responses
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // Check if this is a cacheable asset
            const shouldCache = CACHEABLE_PATTERNS.some((pattern) => pattern.test(url));
            
            if (shouldCache) {
              // Clone the response since we need to use it twice
              const responseToCache = response.clone();
              
              caches.open(CACHE_NAME)
                .then((cache) => {
                  cache.put(event.request, responseToCache);
                })
                .catch((err) => {
                  console.warn('[firebase-messaging-sw.js] Failed to cache:', url, err);
                });
            }

            return response;
          })
          .catch(async () => {
            // Network failed, try to return offline fallback
            if (event.request.destination === 'document') {
              // Try index.html first, then fallback to offline.html
              const indexResponse = await caches.match('/index.html');
              if (indexResponse) return indexResponse;
              return caches.match('/offline.html');
            }
            return null;
          });
      })
  );
});
