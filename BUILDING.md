# Сборка / Building

Source layout: macdir (Swift/macOS), diakitw-desktop (Electron), diakitw-android
(Java/Android), proxy (Python standard library). Build on a controlled builder;
SDKs, dependency caches and private signing keys are deliberately excluded.
Publication did not rebuild binaries. A clean-room, byte-identical rebuild has
NOT been demonstrated; timestamps, toolchain versions, packaging and signatures
can differ. Production source matches candidates except licensing text; fixture
addresses and workstation scratch paths are sanitized in the public copy.

## macOS
macOS 14+, Swift tools 5.9+ / compatible Apple SDK and command line tools.
`cd macdir; mkdir -p "$HOME/.cache/diakitw/scratch"; bash build.sh`
This arm64 recipe performs builds/tests and writes versioned output; it refuses
existing outputs. Some visual checks require a desktop session. For Intel:
`swift build --build-system native -c release --triple x86_64-apple-macosx14.0 --scratch-path .build-diakitw-intel -Xswiftc -file-prefix-map -Xswiftc "$PWD=/diakitw-src" -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/diakitw-src"`
After both builds, `python3 package-diagnostics-dmg.py` packages the DMGs.
Ad-hoc signing is not Developer ID/notarization. Do not disable Gatekeeper.

## Windows / Linux
Install a current compatible Node.js/npm; use the committed lockfile:
`cd diakitw-desktop; npm ci; npm test`
Run `npx electron app` on a supported graphical desktop for manual acceptance.
Package separately: `npx electron-packager app diakitw --platform=win32 --arch=x64 --electron-version=45.2.3 --asar --out=out`
and replace `win32` with `linux` for Linux. Archive the WHOLE output directory,
including LICENSE and LICENSES.chromium.html. These are build recipes, not a
claim that cross-built packages were runtime-tested. No native app npm dependencies.

## Android
Install JDK 17, Gradle 8.13, Android SDK platform 36 and build-tools 35.0.0.
Set JAVA_HOME and ANDROID_HOME to your own installations; do not commit local paths.
`cd diakitw-android; gradle --no-daemon --max-workers=1 assembleDebug`
`python3 -m unittest discover -s tests -p 'test_*.py'`
Pure Java tests are in tests/; instrumentation fixtures are in app/src/androidTest.
Use your own local debug/release keystore. The owner's keystore is excluded.
A differently signed APK cannot update the installed candidate in place; uninstall
may lose data. Do not distribute debug builds as Play Store production releases.

## Proxy
Python 3.9+; no pip dependencies. `cd proxy; python3 -m unittest discover -v`.
See DEPLOYMENT.md for a placeholder-domain configuration. Do not deploy without
reviewing permissions, TLS, trusted peer UID, quota initialization and provider terms.
