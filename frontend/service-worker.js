const CACHE_NAME = "vidgrab-v3";

const STATIC_ASSETS = [
  "/",
  "/assets/app-logo.png",
  "/assets/app.src.js?v=3",
  "/assets/app-config.js?v=3",
  "/manifest.json?v=3",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/admin/")) {
    return;
  }

  if (url.pathname.startsWith("/info") || url.pathname.startsWith("/download")) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      return cached || fetch(event.request).then((response) => {
        if (
          response &&
          response.status === 200 &&
          response.type === "basic" &&
          (url.pathname.startsWith("/assets/") || url.pathname === "/" || url.pathname === "/manifest.json")
        ) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
