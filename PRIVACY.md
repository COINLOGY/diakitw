# Privacy / Конфиденциальность

Локальные показатели устройства обрабатываются приложением. IP/геолокация —
не полностью офлайн-функция: запросы могут выполняться автоматически при активном
интерфейсе и изменении сети. Proxy и провайдер получают публичный IP; fallback
сервисы также видят IP. Геолокация приблизительная, не GPS и не проверка анонимности VPN.

The bundled clients contact a shared HTTPS proxy for public-IP geolocation and
may use fallback public-IP/geolocation services. Providers see the connecting IP.
The proxy forwards the validated caller IP to api.2ip.io, caches bounded results
in memory, and persists quota counters. The service code suppresses request logs;
reverse proxy/hosting providers may have independent retention policies.
Speed tests send/receive traffic to third-party endpoints, can consume data and
must not be mistaken for passive monitoring. External map actions open another app/site.
SSH diagnostics use user-configured hosts and credentials; do not share local
configuration or diagnostic reports without redaction. Clipboard actions expose
copied values to other apps with clipboard access. Review source for platform differences.
