"""Presentation source wiring; Swift checks/render fixtures cover behavior."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / 'Sources/macdir/main.swift').read_text()
for expression in ['MetricPresentation.percent(model.snapshot.cpu)', 'MetricPresentation.utilization(model.snapshot.memoryUsed', 'MetricPresentation.usedTotal(model.snapshot.memoryUsed', 'MetricPresentation.utilization(model.snapshot.swap', 'MetricPresentation.usedTotal(model.snapshot.swap', 'explanation: MetricPresentation.swapExplanation', 'MetricPresentation.utilization(model.snapshot.diskOccupied', 'MetricPresentation.usedTotal(model.snapshot.diskOccupied', 'MetricPresentation.battery(model.snapshot.batteryPercent)', 'MetricPresentation.powerState(model.snapshot.power)', 'ProcessInfo.processInfo.processorCount']:
    assert expression in main, expression
for obsolete in ['scalePercent', '001.0', '010.0', 'Wh Н/Д', 'Текущий объём; 0']:
    assert obsolete not in main, obsolete
hud = (root / 'Sources/macdir/ResourceHUD.swift').read_text()
assert 'MetricPresentation.capacity(s.memoryUsed' in hud
assert 'MetricPresentation.size(s.swap)' in hud
assert 'MetricPresentation.capacity(s.diskOccupied' in hud
assert 'scalePercent' not in hud
assert 'toggleVisibility' in hud and 'toggleRAMMode' in hud
update = hud.split('private func update(', 1)[1]
assert 'item?.length' not in update and 'StatusTypography.width' not in update
assert 'indices.isEmpty ? NSImage' in update
assert 'StatusPresentation.saveVisible' in hud and 'StatusPresentation.saveRAMMode' in hud
gauge = (root / 'Sources/macdir/NeedleGauge.swift').read_text()
assert 'var upperLabel = "100%"' in gauge and '["0%", "50%", "100%"]' in gauge
assert 'if amountOnly' in gauge
chart = (root / 'Sources/macdir/TrafficChart.swift').read_text()
assert '"0–" + MetricPresentation.number(value)' in chart
assert 'MetricPresentation.number(max(0, context.date.timeIntervalSince(model.scanStarted)))' in main
print('PASS: simplified values, honest swap/network, visibility and no sample-driven resize wiring')
