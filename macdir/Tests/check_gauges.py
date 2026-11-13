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
assert main.count('GaugeTile(') == 6, 'six resource gauges including swap'
assert 'model.snapshot.diskOccupied' in main and 'model.snapshot.batteryPercent' in main
assert '.popover(isPresented: $model.showCapacity)' in main
assert 'selectedInterface' in main and '10 MiB/с' in main
print('Gauge UI wiring checks passed (not a rendered GUI test)')
