"""Static UI/privacy regression gate; behavior runs in native XCTest on CI."""
from pathlib import Path
import plistlib
r = Path(__file__).resolve().parents[1]
v = (r/'Sources/DiakitwApp.swift').read_text()
m = (r/'Sources/Monitor.swift').read_text()
assert 'presentation.confirm' not in v, 'Start still opens a second confirmation'
assert 'if model.running { model.cancelSpeed() } else { model.startSpeed() }' in v
assert v.index('Text(NetworkPolicy.trafficNotice)') < v.index('if model.running { model.cancelSpeed() }')
assert 'Text(NetworkPolicy.latencyReport(model.latencyMS))' in v, 'real latency missing from report'
assert 'не ICMP' in (r/'Sources/NetworkPolicy.swift').read_text()
assert 'latencyMS = nil' in m, 'new runs must clear old latency'
assert '0.5.5a · iOS · build 55' in v
info = plistlib.loads((r/'Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'], info['CFBundleVersion']) == ('0.5.5', '55')
print('PASS: one direct Start, visible prior traffic consent, HTTP PING report, display/platform versions')
