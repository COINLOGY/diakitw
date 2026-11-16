# diakitw 1.0.3 (build 103) — предварительный релиз

[Скачать v1.0.3](https://github.com/COINLOGY/diakitw/releases/tag/v1.0.3) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [Примечания](release/1.0.3.md) · [MIT](LICENSE) · [Build](BUILDING.md)

## Сборки / Downloads
- [diakitw-1.0.3-macos-unsigned-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-macos-unsigned-arm64.dmg) — 1616066 байт; SHA-256 `ab22fb5534ca5d8b4ea91c625c9668aba70406903be496da713425efcb2e8ba0`
- [diakitw-1.0.3-macos-unsigned-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-macos-unsigned-x86_64.dmg) — 1732620 байт; SHA-256 `744b17a8bed4c5ab93cf38382783668a2bc06e0f78a9a63daca82094c790bf92`
- [diakitw-android-1.0.3.apk](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-android-1.0.3.apk) — 127759 байт; SHA-256 `5a8b72b229ef0769639eef112ec303bb585bc87963a53f4807d358d157808aa2`
- [diakitw-1.0.3-windows-x64.zip](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-windows-x64.zip) — 158114064 байт; SHA-256 `de993edf285cd4478bf27893a3b0a8922be975f811006c0db19727eed23fd396`
- [diakitw-1.0.3-linux-x64.tar.gz](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-linux-x64.tar.gz) — 124051641 байт; SHA-256 `b23ddc03ad60ae8bac80fcd778f5cffdbd652389a9b9a4079fc6de90a89da404`

Совместимость обновлятора macOS 1.0.2: дополнительные имена ведут на **те же байты ad-hoc DMG**, без Developer ID/нотариализации:
- [diakitw-1.0.3-macos-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-macos-arm64.dmg) — 1616066 байт; SHA-256 `ab22fb5534ca5d8b4ea91c625c9668aba70406903be496da713425efcb2e8ba0`
- [diakitw-1.0.3-macos-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/diakitw-1.0.3-macos-x86_64.dmg) — 1732620 байт; SHA-256 `744b17a8bed4c5ab93cf38382783668a2bc06e0f78a9a63daca82094c790bf92`

[SHA256SUMS-1.0.3.txt](https://github.com/COINLOGY/diakitw/releases/download/v1.0.3/SHA256SUMS-1.0.3.txt) — сверьте скачанные байты.

## Подпись и установка

**Android:** сертификат SHA-256 `d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8` тот же, что в 1.0.1/1.0.2; обновление поверх с системным подтверждением. С 0.5.x требуется сохранить данные и переустановить: настройки могут потеряться. Новый Android получает только v2 feed.

**macOS:** DMG ad-hoc без Developer ID и нотариализации; Gatekeeper может отклонить обычную установку. Не отключайте защиту ради запуска.
**Windows:** portable ZIP без Authenticode; SmartScreen может предупредить или заблокировать. Не отключайте защиту.
**Linux:** portable tar.gz; нужны графическая сессия и GTK/NSS/ALSA; исполняемый бит сохранён.

**iOS 1.0.3 только компилируется и тестируется: установочного файла в выпуске нет.**

Проверка версии/скачивание не равны автоматической установке: desktop/macOS устанавливаются вручную, Android передаёт APK системному установщику. Реальные циклы обновления на устройствах не подтверждены. Подписи издателей Windows/macOS ожидают одобрения; новые исправления выйдут отдельно.

Исходный commit Android/Windows/Linux: `e3987b8ae337640bc815f03c14f6f874f42f938a`; macOS: `a5a7d3c89dfbfdbbfc22a532e6ac25c866343790`. [История релизов](https://github.com/COINLOGY/diakitw/releases).
