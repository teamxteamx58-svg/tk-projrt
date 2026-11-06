// Service worker minimal : nécessaire pour que Chrome propose l'installation.
// Ne met rien en cache : toutes les requêtes passent directement au réseau.
self.addEventListener("install", function (e) { self.skipWaiting(); });
self.addEventListener("activate", function (e) { e.waitUntil(self.clients.claim()); });
self.addEventListener("fetch", function (e) { e.respondWith(fetch(e.request)); });
