from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'Sources/macdir/main.swift').read_text()
assert 'networkRate: selectedNetwork?.received' in s and 'directionColor: InstrumentTheme.lime' in s, 'download must be lime'
assert 'networkRate: selectedNetwork?.sent' in s and 'directionColor: InstrumentTheme.cyan' in s, 'upload must be light blue'
assert 'network.available ? directionColor : Color.secondary' in (p/'Sources/macdir/NeedleGauge.swift').read_text(), 'unknown rate has neutral tint'
print('Network color wiring passed')
