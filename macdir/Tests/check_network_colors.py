from pathlib import Path
p=Path(__file__).resolve().parents[1]
s=(p/'Sources/macdir/main.swift').read_text()
assert 'selectedNetwork?.received == nil ? Color.secondary : Color(red: 0.65, green: 0.90, blue: 0.25)' in s, 'download must be lime'
assert 'selectedNetwork?.sent == nil ? Color.secondary : Color(red: 0.30, green: 0.75, blue: 1.0)' in s, 'upload must be light blue'
print('Network color wiring passed')
