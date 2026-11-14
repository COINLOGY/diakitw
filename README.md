# diakitw 0.5.4 — preview

[Скачать / Download](https://github.com/COINLOGY/diakitw/releases/tag/v0.5.4) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [Release notes / Ограничения](release/0.5.4.md) · [MIT](LICENSE) · [Build](BUILDING.md)

Диагностика и мониторинг: macOS, Windows/Linux, Android и iOS; изолированный proxy геолокации 2ip. Собственный код MIT, сторонние лицензии сохранены: [NOTICE](NOTICE), [THIRD_PARTY.md](THIRD_PARTY.md).

| Сборка | Установка | Ограничения |
|---|---|---|
| macOS arm64 / x86_64 DMG | macOS 14+; скопировать app в Applications | Ad-hoc, без notarization. Offline self-check обеих архитектур, Intel через Rosetta; физический Intel не проверен. |
| Windows x64 ZIP | Windows 10/11; распаковать целиком | Нет Authenticode; целевой runtime не проверен. |
| Linux x64 tar.gz | Графическая сессия, glibc, GTK/NSS/ALSA | Целевой runtime не проверен; не отключать sandbox. |
| Android APK | Android 8+/API26; системный установщик | Прежняя debug-подпись; real install/GUI 0.5.4 не проверены. |
| iOS device / simulator / source | iOS 16+; разработческая сборка/исходники | Device APP unsigned, не устанавливаемый IPA, не TestFlight/App Store. |

Обновления: foreground и ручная проверка, preview по умолчанию, stable по выбору. Только открытие браузера; **нет автоустановки, скачивания или проверки скачанного файла приложением**. Клиентам 0.5.3 и ранее нужна однократная ручная установка 0.5.4. Общий [feed](https://coinlogy.github.io/diakitw/updates/v1.json) содержит пять installer platforms; unsigned iOS не предлагается. Отсутствие stable в feed не означает «установлена актуальная stable».

SHA256SUMS релиза — для ручной проверки байтов; не независимая подпись. Не отключайте защиту ОС. Общий API: 300 upstream-запросов/сутки, 9000/месяц на всех пользователей, без SLA. См. [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md).

## English

Five preview installer/portable packages, plus unsigned iOS device/simulator outputs and source. Full source ZIP matches v0.5.4. Own code is MIT; third-party notices remain intact. Update discovery only: no automatic installation or downloaded-file hash/signature verification. Older clients need one manual bootstrap install. No stable release is asserted. iOS is not an installable IPA. See [release notes](release/0.5.4.md) for actual checks and platform limits.

[Previous releases](https://github.com/COINLOGY/diakitw/releases) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)
