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
# 1.0.7 deliberately uses three compact resource dials; the native layout probe
# covers their positions across narrow/wide viewports and light/dark appearances.
assert main.count('GaugeTile(') == 6, 'three resource, two network and one disk gauge'
for title in ('ПРОЦЕССОР', 'ПАМЯТЬ', 'SWAP'):
 assert any('GaugeTile(' in line and 'title: "'+title+'"' in line for line in main.splitlines())
assert 'model.snapshot.diskOccupied' in main
assert '.popover(isPresented: $model.showCapacity)' in main
assert 'selectedInterface' in main and 'networkDirection: "↑"' in main and 'networkDirection: "↓"' in main
print('Gauge UI wiring checks passed (not a rendered GUI test)')
