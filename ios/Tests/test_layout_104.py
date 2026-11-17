"""iOS dashboard ordering and telemetry provenance contract."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
view = (root / "Sources/DiakitwApp.swift").read_text()
monitor = (root / "Sources/Monitor.swift").read_text()
assert view.index('Text("Ресурсы")') < view.index('Text("Сеть")') < view.index('Text("Хранилище")')
assert view.index('Text("Сеть")') < view.index('title: "↓ RX"') < view.index('title: "↑ TX"')
assert 'model.rxRate' in view and 'model.txRate' in view
assert 'model.download, maximum: Dial.speedScale(model.download)' in view, "Preserve consented speed test"
assert 'model.networkHistory' in view and 'Сетевая активность' in view
assert 'getifaddrs' in monitor and 'ifi_ibytes' in monitor and 'ifi_obytes' in monitor
assert 'NetworkPolicy.counterDelta' in monitor and 'Int(exactly: incoming)' in monitor
assert '85F4.1' in (root / 'PrivacyInfo.xcprivacy').read_text()
assert 'NSHomeDirectory()' in monitor and '.systemFreeSize' in monitor, "Volume estimate remains app-home only"
assert 'Map(' not in view, "No unsupported map"
assert 'NetworkPolicy.trafficNotice' in view and 'model.startSpeed()' in view
print("PASS: iOS resource/network/disk order and honest optional interface telemetry")
