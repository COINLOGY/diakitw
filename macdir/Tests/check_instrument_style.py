"""Wiring gate; rendered geometry is verified separately by check_layout."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
s = (r/'Sources/macdir/NeedleGauge.swift').read_text()
assert '["0%", "50%", "100%"]' in s, 'only endpoints and midpoint percentage labels'
assert 'if neutral' in s and '["0", "5", String(upperLabel.split' in s, 'network midpoint in real units'
assert 'ForEach(0..<3)' in s
assert 'for i in 0...10' in s and 'for i in 0..<40' in s
assert 'if let fraction' in s, 'unknown must not draw needle'
assert 'battery: battery' in s
assert 'InstrumentTheme.panel' in s, 'graphite instrument panels missing'
assert 'static let lime' in s and 'static let cyan' in s, 'appearance-aware readable instrument colors missing'
print('PASS instrument percentage/network scale wiring')
