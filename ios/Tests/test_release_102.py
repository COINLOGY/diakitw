"""Read-only source contract for the unsigned iOS 1.0.2 candidate."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / "Info.plist").read_bytes())
assert (info["CFBundleShortVersionString"], info["CFBundleVersion"]) == ("1.0.2", "102")
project = (root / "diakitw.xcodeproj/project.pbxproj").read_text()
assert project.count("MARKETING_VERSION = 1.0.2;CURRENT_PROJECT_VERSION = 102;") == 2
app = (root / "Sources/DiakitwApp.swift").read_text()
assert "1.0.2 · iOS · build 102" in app
assert "@StateObject private var updates = UpdateChecker()" in app
assert "updates.setForeground(phase == .active)" in app
checker = (root / "Sources/UpdateChecker.swift").read_text()
assert re.search(r"#else\s+public static let version = \"1.0.2\"\s+public static let build = 102\s+#endif", checker)
assert "performCheck(manual: false, forceAtLaunch: isStartup)" in checker
section = (root / "Sources/UpdateSection.swift").read_text()
assert 'Button("Открыть страницу релиза") { openURL(offer.releasePage) }' in section
assert "openURL(" not in checker and "UIApplication.shared.open" not in checker
assert "Автоустановки нет" in section
script = (root / "Scripts/ci-build.sh").read_text()
for name in ("UNSIGNED-device.app.zip", "simulator.app.zip", "SOURCE.zip"):
    assert f"diakitw-1.0.2-ios-{name}" in script
assert "diakitw-0.5.5-ios-" not in script
readme = (root / "README.md").read_text()
assert "iOS 1.0.2 (102)" in readme
assert "0.5.5a" not in readme
print("PASS iOS 1.0.2/102 metadata, checker lifecycle, explicit browser action, archive names")
