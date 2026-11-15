# diakitw 1.0.2 (build 102) — предварительный релиз

[Скачать v1.0.2](https://github.com/COINLOGY/diakitw/releases/tag/v1.0.2) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [Примечания](release/1.0.2.md) · [MIT](LICENSE) · [Build](BUILDING.md)

## Сборки / Downloads
- [diakitw-1.0.2-macos-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/diakitw-1.0.2-macos-arm64.dmg) — 1612723 байт; SHA-256 `9a95e993bbee821d638f5851cb1502e5f8f46987a61231feaa36f3d91b0dd1e1`
- [diakitw-1.0.2-macos-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/diakitw-1.0.2-macos-x86_64.dmg) — 1726649 байт; SHA-256 `30e298b80bd52c9c20a6e4ca368a7a4ce275699c9d879310aa79c01956a7058e`
- [diakitw-android-1.0.2.apk](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/diakitw-android-1.0.2.apk) — 123663 байт; SHA-256 `0952d1526845213e1dffc1217e507f758202631cfdd01fb2e687120981f6254e`
- [diakitw-1.0.2-windows-x64.zip](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/diakitw-1.0.2-windows-x64.zip) — 158111881 байт; SHA-256 `c73c00f1faab320708cdfb5e57520d97a4ed2914953696e1b4017646b546ae16`
- [diakitw-1.0.2-linux-x64.tar.gz](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/diakitw-1.0.2-linux-x64.tar.gz) — 124049478 байт; SHA-256 `6cc5be86588eebd75a4bf4ef195841727611b30c83a9a9ab17de7d5c5f638c74`

[SHA256SUMS-1.0.2.txt](https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/SHA256SUMS-1.0.2.txt) — сверьте скачанные байты.

## Подпись и установка

**Android:** подписан тем же release-сертификатом, что 1.0.1 (SHA-256 `d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8`); обновление 1.0.1→1.0.2 допускает установку поверх с системным подтверждением. APK 0.5.x использует другой ключ: сначала сохраните данные и удалите старую версию; настройки могут потеряться. Новый клиент получает обновления только из v2 feed.

**macOS:** DMG ad-hoc без Developer ID и нотариализации; Gatekeeper может отклонить. Не отключайте защиту ради запуска.
**Windows:** portable ZIP без Authenticode; SmartScreen может предупредить или заблокировать. Не отключайте защиту.
**Linux:** portable tar.gz; нужны графическая сессия и GTK/NSS/ALSA. Исполняемый бит сохранён.

**iOS 1.0.2 только компилируется и тестируется: установочного файла в выпуске нет.**

Проверка обновления не равна автоустановке: desktop/macOS устанавливаются вручную, Android передаёт проверенный APK системному установщику. Реальный переход 1.0.1→1.0.2 на физических устройствах не подтверждён.

Исходный commit сборок: `3e4d763cbfb7a7749d0d0d0769b47635b352c5d7`. [История релизов](https://github.com/COINLOGY/diakitw/releases).
