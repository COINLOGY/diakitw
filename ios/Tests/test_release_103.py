"""Read-only source contract for the unsigned iOS 1.0.3 candidate."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / "Info.plist").read_bytes())
assert (info["CFBundleShortVersionString"], info["CFBundleVersion"]) == ("1.0.3", "103")
project = (root / "diakitw.xcodeproj/project.pbxproj").read_text()
assert project.count("MARKETING_VERSION = 1.0.3;CURRENT_PROJECT_VERSION = 103;") == 2
app = (root / "Sources/DiakitwApp.swift").read_text()
assert "1.0.3 · iOS · build 103" in app
assert "@StateObject private var updates = UpdateChecker()" in app
assert "updates.setForeground(phase == .active)" in app
checker = (root / "Sources/UpdateChecker.swift").read_text()
assert re.search(r"#else\s+public static let version = \"1.0.3\"\s+public static let build = 103\s+#endif", checker)
assert "performCheck(manual: false, forceAtLaunch: isStartup)" in checker
assert 'public static let version = "1.0.2"\n    public static let build = 102\n    #else' in checker, "macOS identity must stay unchanged"
checks = (root / "Tests/update_checks.swift").read_text()
assert 'fixture(version: "1.0.3", build: 103, platform: "ios-unsigned")' in checks
assert 'current: "1.0.2", currentBuild: 102)?.build == 103' in checks
assert '"1.0.3 iOS does not self-offer"' in checks
section = (root / "Sources/UpdateSection.swift").read_text()
assert 'Button("Открыть страницу релиза") { openURL(offer.releasePage) }' in section
assert "openURL(" not in checker and "UIApplication.shared.open" not in checker
assert "Автоустановки нет" in section
script = (root / "Scripts/ci-build.sh").read_text()
for name in ("UNSIGNED-device.app.zip", "simulator.app.zip", "SOURCE.zip"):
    assert f"diakitw-1.0.3-ios-{name}" in script
assert "diakitw-0.5.5-ios-" not in script
readme = (root / "README.md").read_text()
assert "iOS 1.0.3 (103)" in readme
assert "0.5.5a" not in readme
workflow = (root.parent / ".github/workflows/ios-build.yml").read_text()
assert "branches: [feat/release-103-ios]" in workflow
assert "group: ios-103" in workflow
assert "1.0.3 unsigned compile/tests (no upload)" in workflow
assert "actions/upload-artifact" not in workflow
assert "Tests/test_release_103.py" in script
print("PASS iOS 1.0.3/103 metadata, checker lifecycle, explicit browser action, archive names")
