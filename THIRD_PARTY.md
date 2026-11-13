# Сторонние компоненты / Third-party components

MIT в корне относится только к собственному коду и документации EMCx, не заменяет лицензии ниже.
The root MIT license covers our own code/documentation, not third-party components.

| Component | Use / license |
|---|---|
| Electron 45.2.3 | Distributed Windows/Linux runtime; MIT, Electron contributors. Original LICENSE retained in each package. |
| Chromium, V8, Node.js and bundled libraries | Their own BSD/MIT/Apache and other notices; complete platform-specific LICENSES.chromium.html retained in each package, including FFmpeg notices. Do not replace it with the project MIT file. |
| Natural Earth 1:110m map data | Public domain; Android world-110m.json is a reduced dataset. Original attribution and terms in app/src/main/assets/MAP-LICENSE.txt; https://www.naturalearthdata.com/about/terms-of-use/ |
| @electron/packager 20.3.0, resedit 3.1.0 and transitive npm dependencies | Build tools, not shipped as app dependencies; exact graph/integrity and license metadata in package-lock.json. Preserve their own notices if redistributing tools. |
| JDK, Gradle 8.13, Android Gradle Plugin, Android SDK/build tools | Build-only tools; NOT included in this repository/source archive or distributed as SDKs. Install separately under their licenses. No signing keystore is distributed. |
| Swift, Apple SDK/frameworks | Build tools/system runtime, not relicensed or redistributed as SDKs. |
| 2ip, fallback IP services, Cloudflare speed endpoints, external maps | External services, not code licensed here. Provider terms/quotas apply. |

The public shared proxy has a total budget of 300 upstream requests/day and
9000/month, shared across users, not per-user entitlements. Cache hits may avoid
upstream calls. No SLA; outages, rate limiting and exhausted quota are expected.
Free software does not mean unlimited or permanently free third-party service.
You may self-host the proxy with your own provider account and credentials.
