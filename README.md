# diakitw 1.0.6 (build 106) — предварительный релиз

[Скачать v1.0.6](https://github.com/COINLOGY/diakitw/releases/tag/v1.0.6) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [Примечания](release/1.0.6.md) · [MIT](LICENSE) · [Build](BUILDING.md)

## Сборки / Downloads
- [diakitw-1.0.6-macos-unsigned-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-macos-unsigned-arm64.dmg) — 1645463 байт; SHA-256 `65320e78eb3fe6e34141094b5f59886e9c0e941e6c690d067c5b74d38de47806`
- [diakitw-1.0.6-macos-unsigned-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-macos-unsigned-x86_64.dmg) — 1760375 байт; SHA-256 `b25f61c1b583ec44f2fbbf3700afc0450100991d1d0bd04a400ddda1b7610215`
- [diakitw-android-1.0.6.apk](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-android-1.0.6.apk) — 131855 байт; SHA-256 `5feaa7d116dbe2bf314b122e387de44aaa58ec6317a0b1d99815a0906c62c8e1`
- [diakitw-1.0.6-windows-x64.zip](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-windows-x64.zip) — 158115874 байт; SHA-256 `b5a0d4a3911ecc2cf30b87d2ad0b7f4f8c7efbdd4181aaaa0d646cb76ea1375c`
- [diakitw-1.0.6-linux-x64.tar.gz](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-linux-x64.tar.gz) — 124052439 байт; SHA-256 `e5dee68ef37912fc2800321e7e1dd4ab6398e1b3ba6b73c6f11364ab017363c4`

Дополнительные имена macOS ведут на **те же байты ad-hoc DMG**, без Developer ID и нотариализации:
- [diakitw-1.0.6-macos-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-macos-arm64.dmg) — 1645463 байт; SHA-256 `65320e78eb3fe6e34141094b5f59886e9c0e941e6c690d067c5b74d38de47806`
- [diakitw-1.0.6-macos-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/diakitw-1.0.6-macos-x86_64.dmg) — 1760375 байт; SHA-256 `b25f61c1b583ec44f2fbbf3700afc0450100991d1d0bd04a400ddda1b7610215`

[SHA256SUMS-1.0.6.txt](https://github.com/COINLOGY/diakitw/releases/download/v1.0.6/SHA256SUMS-1.0.6.txt) — сверьте скачанные байты.

## Подпись и установка

**Android:** сертификат SHA-256 `d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8` тот же, что в 1.0.1–1.0.5; обновление поверх с системным подтверждением. С 0.5.x требуется сохранить данные и переустановить: настройки могут потеряться. Android получает обновления из v2 feed.

**macOS:** DMG ad-hoc без Developer ID и нотариализации; Gatekeeper может отклонить обычную установку. Не отключайте защиту ради запуска.
**Windows:** portable ZIP без Authenticode; SmartScreen может предупредить или заблокировать. Не отключайте защиту.
**Linux:** portable tar.gz; нужны графическая сессия и GTK/NSS/ALSA; исполняемый бит сохранён.

**iOS 1.0.6 только компилируется и тестируется: установочного файла в выпуске нет.**

Проверка версии и скачивание не равны автоматической установке: desktop/macOS устанавливаются вручную, Android передаёт проверенный APK системному установщику. Реальные циклы обновления на физических устройствах не подтверждены.

Исходный commit выпуска: `ad7ffe939b68702de4e48064654381ea206ba90f`. [История релизов](https://github.com/COINLOGY/diakitw/releases).
