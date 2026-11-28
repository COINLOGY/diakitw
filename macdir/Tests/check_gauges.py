"""UI wiring guards; geometry and invalid telemetry are exercised by CoreChecks."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
face = root / 'Sources/macdir/NeedleGauge.swift'
assert face.exists(), 'analog gauge view missing'
s = face.read_text()
assert 'if let fraction' in s, 'unavailable telemetry must not draw a zero needle'
assert 'duration: 0.25' in s and 'accessibilityReduceMotion' in s
assert 'GaugeScale.angle' in s and 'Canvas' in s
main = (root / 'Sources/macdir/main.swift').read_text()
# Four square resources including disk, followed by two square network dials.
# Native probes check alignment and the long chart at narrow/wide widths.
assert main.count('GaugeTile(') == 6, 'four resource including disk and two network gauges'
for title in ('ПРОЦЕССОР', 'ПАМЯТЬ', 'SWAP', 'ДИСК · ЗАНЯТО'):
 assert any('GaugeTile(' in line and 'title: "'+title+'"' in line for line in main.splitlines())
assert 'model.snapshot.diskOccupied' in main
assert '.popover(isPresented: $model.showCapacity)' in main
assert 'selectedInterface' in main and 'networkDirection: "↑"' in main and 'networkDirection: "↓"' in main
print('Gauge UI wiring checks passed (not a rendered GUI test)')
