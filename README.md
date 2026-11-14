# diakitw — macOS 0.5.6 (build 56); остальные платформы 0.5.5a (build 55)

[Скачать macOS 0.5.6](https://github.com/COINLOGY/diakitw/releases/tag/v0.5.6) · [Скачать остальные 0.5.5a](https://github.com/COINLOGY/diakitw/releases/tag/v0.5.5) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [Mac instructions](release/0.5.6.md) · [RU/EN 0.5.5a](release/0.5.5a.md) · [MIT](LICENSE) · [Build](BUILDING.md)

## ⚠ Android: обязательная миграция / required migration

**Android: НОВЫЙ ключ. Старое приложение необходимо удалить; данные, настройки и история могут потеряться. Обновление поверх невозможно. Следующие версии используют этот же ключ. NEW signing key: uninstall the old Android app first; data, settings and history may be lost. No in-place upgrade; subsequent versions use this same key.**

Save needed reports outside the app first. Release certificate SHA-256: `f911dd1063fb3acb2ca7adb474c6ffdbc1b81e36eb5b4f4854dd25f7620750ab`. APK v2/v3 verified; the retained candidate filename is not debug signing.

## Сборки / Downloads

- [diakitw-0.5.6-macos-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v0.5.6/diakitw-0.5.6-macos-arm64.dmg) — Apple Silicon; SHA-256 `6dee475414c194d69e3635f22445c4cb027ca8868a7c3e99f01d6b20a6dbc1ba`
- [diakitw-0.5.6-macos-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v0.5.6/diakitw-0.5.6-macos-x86_64.dmg) — Intel; SHA-256 `c72df7c6de13bc0205e65b2ab8389990e67fffbc967b34a10799e4dd878c0a74`
- [diakitw-0.5.5a-windows-x64.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5a-windows-x64.zip)
- [diakitw-0.5.5a-linux-x64.tar.gz](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5a-linux-x64.tar.gz)
- [diakitw-android-0.5.5a-candidate.apk](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-android-0.5.5a-candidate.apk)

- [diakitw-0.5.5-ios-SOURCE.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-SOURCE.zip)
- [diakitw-0.5.5-ios-UNSIGNED-device.app.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-UNSIGNED-device.app.zip)
- [diakitw-0.5.5-ios-simulator.app.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-simulator.app.zip)

macOS 14+: ad-hoc, no Developer ID/notarization. Windows x64: no Authenticode. Linux x64: portable, do not disable sandbox. Android: API26+; uninstall migration required.

**iOS device APP is UNSIGNED: не устанавливаемый IPA; нет автоматической установки / not an installable IPA; no automatic installation.** iOS16+; developer signing/provisioning required. Simulator ZIP is for Xcode Simulator; SOURCE ZIP is the project, not a phone installer.

Mobile: одна кнопка «Старт», HTTP ping RTT в миллисекундах (не ICMP), JSON / single Start, HTTP ping RTT in ms (not ICMP), JSON reports.

Обновления: в diakitw 0.5.5a откройте меню **«Проверить обновления»**, выберите stable **или** preview и нажмите «Проверить обновления». На Mac должно появиться предложение 0.5.6; кнопка «Скачать в браузере» открывает DMG, но не устанавливает его. Повторная ручная проверка доступна через 60 секунд после предыдущей. Для проверки без установки используйте [живой манифест обновлений](https://coinlogy.github.io/diakitw/updates/v1.json). Windows/Linux/Android остаются на 0.5.5a; iOS unsigned не предлагается. Нет автоматической установки и проверки скачанного файла в приложении. Клиентам 0.5.3 и ранее нужна однократная ручная установка.

Проверки / Checks: Desktop 62 tests, Android fixtures/signature/alignment; macOS 0.5.6 — DMG/privacy/signature gates и автономный arm64 self-check. Исполнение 0.5.6 на Intel/Rosetta не проверялось. Нет проверки установленного GUI, миграции на физическом Android или Windows/Linux GUI. См. ограничения в примечаниях к релизам.

[SHA256SUMS для 0.5.5a](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/SHA256SUMS); контрольные суммы macOS 0.5.6 приведены выше и в [примечаниях к выпуску](release/0.5.6.md). Совпадение подтверждает байты, не личность издателя. Не отключайте защиту ОС.

Исходники macOS 0.5.6: [tag v0.5.6](https://github.com/COINLOGY/diakitw/tree/v0.5.6), [ZIP](https://github.com/COINLOGY/diakitw/archive/refs/tags/v0.5.6.zip). Исходники текущей страницы загрузок: [ветка main](https://github.com/COINLOGY/diakitw/tree/main). Остальные платформы: [tag v0.5.5](https://github.com/COINLOGY/diakitw/tree/v0.5.5). Own code MIT; [NOTICE](NOTICE) and [THIRD_PARTY.md](THIRD_PARTY.md) remain intact. [Privacy](PRIVACY.md) · [Security](SECURITY.md) · [Previous releases](https://github.com/COINLOGY/diakitw/releases).
