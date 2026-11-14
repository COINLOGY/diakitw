"""Static presentation contract; native geometry is tested separately on CI."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
d=(r/'Sources/Dial.swift').read_text()
v=(r/'Sources/DiakitwApp.swift').read_text()
assert '[(-99,0),(0,-10),(21,-4),(21,4),(0,10)]' in d, 'wide-base 10 missing'
assert 'radius - 5 * 7/9' in v, 'arc must thin to 7/9'
assert '.color(Theme.background)' in v and 'hub.insetBy(dx: 0.5, dy: 0.5)' in v, 'dark inset hub'
assert '.frame(width: 145, height: 105)' in v and 'minHeight: 128' in v
assert 'return (radius, radius+22, radius*hypot(21,4)/114)' in d
assert 'TEST FIXTURE' not in v
print('PASS: expressive-v4 source contract, original centers/heights retained')
