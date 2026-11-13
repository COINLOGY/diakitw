"""Source integration gates, not rendered GUI evidence."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
s = (p / 'Sources/macdir/ServerPanel.swift').read_text()
assert 'value: MetricPresentation.percent(sample?.cpuPercent)' in s
for kind in ['memory', 'swap', 'disk']:
    assert f'value: measuredPercent(sample?.{kind}Used, sample?.{kind}Total)' in s
    assert f'measuredPair(sample?.{kind}Used, sample?.{kind}Total)' in s
assert 'used >= 0, total > 0, used <= total' in s
assert 'fraction: GaugeScale.fraction(sample?.swapUsed, maximum: sample?.swapTotal)' in s
assert 'explanation: MetricPresentation.swapExplanation' in s
assert '% линии: Н/Д' not in s
assert 'SecureField(' in s and 'model.draftPassword = ""' in s
assert 'MetricPresentation.number(value / 1_073_741_824)' in (p / 'Sources/MacdirCore/ServerTelemetry.swift').read_text()
print('Server paired metrics/auth preservation wiring passed (not rendered UI)')
