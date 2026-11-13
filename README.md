# diakitw 0.5.2 — preview

[Скачать / Download](https://github.com/COINLOGY/diakitw/releases/tag/v0.5.2) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [MIT](LICENSE) · [Build](BUILDING.md)

## Русский

Открытый код инструментов диагностики и мониторинга для macOS, Windows/Linux и Android, плюс изолированный proxy геолокации 2ip. Собственный код — **MIT**, Copyright (c) 2026 EMCx contributors: бесплатно использовать, изучать, изменять и распространять, в том числе коммерчески, с сохранением уведомления. Сторонние компоненты сохраняют свои лицензии; см. [NOTICE](NOTICE) и [THIRD_PARTY.md](THIRD_PARTY.md). MIT для собственного кода 0.5.2 заменяет старую формулировку «все права сохранены» в неизменённых candidate-пакетах.

| Сборка | Установка и требования | Ограничения |
|---|---|---|
| macOS arm64 / x86_64 DMG | macOS 14+; открыть DMG и скопировать diakitw.app в Applications | Ad-hoc; нет Developer ID/notarization. Intel runtime не проверен. |
| Windows x64 ZIP | Windows 10/11 x64; распаковать весь архив, запустить diakitw.exe | Нет Authenticode; запуск на Windows не проверен. |
| Linux x64 tar.gz | Графическая сессия, glibc, GTK/NSS/ALSA; распаковать целиком и запустить diakitw | Запуск на Linux не проверен; не отключать sandbox. |
| Android APK | Android 8+/API26; установить APK через системный установщик после проверки источника | Debug-подпись, не Play Store; GUI 0.5.2 не подтверждён. |

Общий ZIP содержит пять сборок и описание/манифест/суммы; **iOS исключён**. Исходники доступны по тегу и отдельным source ZIP. Возможности платформ различаются. Mac mutation raster проверка завершилась тайм-аутом; финальный self-check смонтированного приложения не подтверждён. Не отключайте защиту ОС ради запуска.

Проверка: `shasum -a 256 FILE` (macOS), `sha256sum FILE` (Linux), `Get-FileHash -Algorithm SHA256 FILE` (PowerShell); сравнить с release SHA256SUMS. Это проверка байтов, не сертификация безопасности.

Общий публичный API имеет лимит **300 upstream-запросов/сутки, 9000/месяц на всех пользователей**, без SLA. Свобода кода не означает безлимитный сторонний сервис. См. [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md), [BUILDING.md](BUILDING.md), [CHANGELOG.md](CHANGELOG.md).

## English

Source and preview binaries for macOS, Windows/Linux and Android, plus the isolated
2ip proxy. Own code is MIT: free to use, modify and redistribute, including
commercially, subject to retaining the license notice. Third-party runtime/data
licenses remain separate. No iOS source or installer is included.

Install requirements and caveats are in the table above: macOS 14+ (copy the app
from DMG), Windows 10/11 x64 (extract the whole ZIP), graphical Linux x64 with
Electron system dependencies (extract the whole tarball), Android 8+/API26
(system APK installer). Verify SHA-256 before installation. Do not disable OS
protection or the Chromium sandbox. Candidate binaries are unchanged by publication.

This is a **prerelease**, not a production/security certification. macOS is ad-hoc
signed without notarization; Intel runtime is unverified. Windows has no Authenticode;
Windows/Linux target runtime is unverified. Android is debug-signed with the existing
certificate, and 0.5.2 GUI acceptance is unverified. The Mac raster mutation test
timed out and the final mounted-app self-check was not confirmed.

Shared API limits are 300 upstream calls/day and 9000/month total, not per user;
no SLA or unlimited third-party service entitlement. Self-hosting source is included.
Build instructions describe reproducible inputs, not a demonstrated byte-identical
rebuild. Owner signing keys are excluded; use your own Android keystore, which
breaks in-place update compatibility with differently signed installed APKs.

[Contributing](CONTRIBUTING.md) · [Previous v0.4.5](https://github.com/COINLOGY/diakitw/releases/tag/v0.4.5)
