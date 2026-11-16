if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('hg-media-sw.js', { scope: './' })
        .catch(function () {});
    }
    (function () {
      var cacheName = 'guomu-media-v1';
      async function openCache() { return caches.open(cacheName); }
      window.guomuMediaCache = {
        async clear() {
          if (!window.caches) return 0;
          await caches.delete(cacheName);
          return 1;
        },
        async size() {
          if (!window.caches) return 0;
          try {
            var cache = await openCache();
            var keys = await cache.keys();
            var total = 0;
            for (var i = 0; i < keys.length; i++) {
              var response = await cache.match(keys[i]);
              if (!response) continue;
              try {
                var blob = await response.blob();
                total += blob.size;
              } catch (_) {}
            }
            return total;
          } catch (_) {
            return 0;
          }
        },
        async prefetchHls(url, segments) {
          if (!url || !window.fetch) return 0;
          var limit = Math.max(1, Math.min(segments || 8, 30));
          async function readPlaylist(playlistUrl, depth) {
            var response = await fetch(playlistUrl, {
              credentials: 'omit',
              cache: 'default'
            });
            if (!response.ok) return 0;
            var text = await response.text();
            var lines = text.split(/\r?\n/).map(function (line) {
              return line.trim();
            }).filter(Boolean);
            if (text.indexOf('#EXT-X-STREAM-INF') >= 0 && depth < 3) {
              var variant = lines.find(function (line) {
                return line.charAt(0) !== '#';
              });
              if (variant) {
                return readPlaylist(new URL(variant, playlistUrl).toString(), depth + 1);
              }
            }
            var media = lines.filter(function (line) {
              return line.charAt(0) !== '#';
            }).slice(0, limit);
            await Promise.all(media.map(function (item) {
              return fetch(new URL(item, playlistUrl).toString(), {
                credentials: 'omit',
                cache: 'default'
              }).catch(function () {});
            }));
            return media.length;
          }
          try { return await readPlaylist(url, 0); } catch (_) { return 0; }
        }
      };
    })();
