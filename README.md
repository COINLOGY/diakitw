# diakitw0.5.5a — stable (0.5.5 / build 55)

[Скачать / Download](https://github.com/COINLOGY/diakitw/releases/tag/v0.5.5) · [Сайт / Website](https://coinlogy.github.io/diakitw/) · [RU/EN instructions](release/0.5.5a.md) · [MIT](LICENSE) · [Build](BUILDING.md)

## ⚠ Android: обязательная миграция / required migration

**Android: НОВЫЙ ключ. Старое приложение необходимо удалить; данные, настройки и история могут потеряться. Обновление поверх невозможно. Следующие версии используют этот же ключ. NEW signing key: uninstall the old Android app first; data, settings and history may be lost. No in-place upgrade; subsequent versions use this same key.**

Save needed reports outside the app first. Release certificate SHA-256: `f911dd1063fb3acb2ca7adb474c6ffdbc1b81e36eb5b4f4854dd25f7620750ab`. APK v2/v3 verified; the retained candidate filename is not debug signing.

## Сборки / Downloads

- [diakitw-0.5.5a-windows-x64.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5a-windows-x64.zip)
- [diakitw-0.5.5a-linux-x64.tar.gz](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5a-linux-x64.tar.gz)
- [diakitw-android-0.5.5a-candidate.apk](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-android-0.5.5a-candidate.apk)
- [diakitw-0.5.5-macos-arm64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-macos-arm64.dmg)
- [diakitw-0.5.5-macos-x86_64.dmg](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-macos-x86_64.dmg)
- [diakitw-0.5.5-ios-SOURCE.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-SOURCE.zip)
- [diakitw-0.5.5-ios-UNSIGNED-device.app.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-UNSIGNED-device.app.zip)
- [diakitw-0.5.5-ios-simulator.app.zip](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/diakitw-0.5.5-ios-simulator.app.zip)

macOS 14+: ad-hoc, no Developer ID/notarization. Windows x64: no Authenticode. Linux x64: portable, do not disable sandbox. Android: API26+; uninstall migration required.

**iOS device APP is UNSIGNED: не устанавливаемый IPA; нет автоматической установки / not an installable IPA; no automatic installation.** iOS16+; developer signing/provisioning required. Simulator ZIP is for Xcode Simulator; SOURCE ZIP is the project, not a phone installer.

Mobile: одна кнопка «Старт», HTTP ping RTT в миллисекундах (не ICMP), JSON / single Start, HTTP ping RTT in ms (not ICMP), JSON reports.

Обновления: выберите **stable**, затем «Проверить» / select **stable**, then Check updates. Preview remains a separate channel. Browser-only discovery; no automatic installation or in-app downloaded-file verification. Clients 0.5.3 and earlier need a manual bootstrap install. [Shared feed](https://coinlogy.github.io/diakitw/updates/v1.json): five installer platforms, no unsigned iOS offer.

Проверки / Checks: Desktop 62 tests, Android fixtures/signature/alignment, Apple CI builds and offline checks. No physical device migration or target Windows/Linux GUI testing is claimed; Intel self-check used Rosetta. See release notes for limits.

[SHA256SUMS](https://github.com/COINLOGY/diakitw/releases/download/v0.5.5/SHA256SUMS) validates bytes, not independent publisher identity. Do not disable OS protection.

Полные исходники / full source: [tag v0.5.5](https://github.com/COINLOGY/diakitw/tree/v0.5.5), [ZIP](https://github.com/COINLOGY/diakitw/archive/refs/tags/v0.5.5.zip). Own code MIT; [NOTICE](NOTICE) and [THIRD_PARTY.md](THIRD_PARTY.md) remain intact. [Privacy](PRIVACY.md) · [Security](SECURITY.md) · [Previous releases](https://github.com/COINLOGY/diakitw/releases).
