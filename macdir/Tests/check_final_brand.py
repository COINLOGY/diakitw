"""Final display/export/icon source contracts; offline only."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
d = (r/'Sources/MacdirCore/Diagnostics.swift').read_text()
w = (r/'Sources/macdir/DiagnosticsWindow.swift').read_text()
assert 'diakitw · протокол' in d
assert 'public let product: String' in d and 'product = "diakitw"' in d
assert 'diakitw-diagnostics-' in w and 'diakitw — Диагностика' in w
assert 'не результат macdir' not in w
assert '001.0K' in (r/'Sources/macdir/OfflineSelfCheck.swift').read_text()
assert '03-modular-w-icon.svg' in (r/'make_icon.py').read_text()
assert 'recommended-1024.png' not in (r/'make_icon.py').read_text()
print('Final brand/export/icon source contracts PASS')
