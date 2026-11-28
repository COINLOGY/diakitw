"""Active iOS 1.1.1 build-only source contract; execute directly."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / "Info.plist").read_bytes())
assert (info["CFBundleShortVersionString"], info["CFBundleVersion"]) == ("1.1.1", "111")
project = (root / "diakitw.xcodeproj/project.pbxproj").read_text()
assert project.count("MARKETING_VERSION = 1.1.1;CURRENT_PROJECT_VERSION = 111;") == 2
view = (root / "Sources/DiakitwApp.swift").read_text()
assert "1.1.1 · iOS · build 111" in view
assert "@StateObject private var updates = UpdateChecker()" in view
assert "updates.setForeground(phase == .active)" in view
assert not re.search(r"(?:cycleCount|batteryCycleCount|циклов батареи)", view, re.I)
checker = (root / "Sources/UpdateChecker.swift").read_text()
for branch in (r"#if os\(macOS\)", r"#else"):
    assert re.search(branch + r'\s+public static let version = "1.1.1"\s+public static let build = 111', checker)
assert "performCheck(manual: false, forceAtLaunch: isStartup)" in checker
assert 'return "ios-unsigned"' in checker
assert 'case "ios-unsigned": expected = "diakitw-\\(text)-ios-UNSIGNED-device.app.zip"' in checker
checks = (root / "Tests/update_checks.swift").read_text()
assert 'fixture(version: "1.1.1", build: 111, platform: "ios-unsigned")' in checks
assert 'current: "1.0.4", currentBuild: 104)?.build == 111' in checks
assert '"1.1.1 iOS does not self-offer"' in checks
section = (root / "Sources/UpdateSection.swift").read_text()
assert 'Button("Открыть страницу релиза") { openURL(offer.releasePage) }' in section
assert "Автоустановки нет" in section
assert "openURL(" not in checker and "UIApplication.shared.open" not in checker
script = (root / "Scripts/ci-build.sh").read_text()
for name in ("UNSIGNED-device.app.zip", "simulator.app.zip", "SOURCE.zip"):
    assert f"diakitw-1.1.1-ios-{name}" in script
assert "Tests/test_release_111.py" in script
assert ".github/workflows/ios-build-111.yml" in script
assert "CODE_SIGNING_ALLOWED=NO" in script and "CODE_SIGNING_REQUIRED=NO" in script
assert 'if codesign -dv "$DEVICE"' in script
assert 'bash test.sh' in script and 'Tests/update_checks.swift' in script
readme = (root / "README.md").read_text()
assert "iOS 1.1.1 (111)" in readme and "cannot be installed directly" in readme
workflow = (root.parent / ".github/workflows/ios-build-111.yml").read_text()
assert "branches: [feat/release-111-candidate]" in workflow
assert "group: ios-111" in workflow
assert "1.1.1 unsigned compile/tests (no upload)" in workflow
assert "timeout-minutes: 50" in workflow
assert "actions/upload-artifact" not in workflow
assert "bash ios/Scripts/ci-build.sh" in workflow
fixture = (root / "Scripts/fixture_copy.py").read_text()
assert "    private func metric" in fixture, "fixture scroll wrapper must close inside body, before methods"
assert "    static let helpText" not in fixture, "fixture wrapper must not consume the profile editor"
print("PASS iOS 1.1.1/111 metadata, updater, unsigned build-only contract")
