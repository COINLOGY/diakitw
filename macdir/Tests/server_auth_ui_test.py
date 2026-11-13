from pathlib import Path
p = Path(__file__).resolve().parents[1] / 'Sources/macdir/ServerPanel.swift'
s = p.read_text()
assert 'SecureField(' in s, 'password field must be secure'
assert 'beginEdit' in s and 'Настройки' in s, 'existing servers editable'
assert 'draftPort' in s and 'draftAuthentication' in s, 'port and auth controls'
assert 'draftPassword = ""' in s and 'onDisappear' in s, 'password cleared on dismiss'
assert 'ServerPasswordStore.save' in s and 'ServerPasswordStore.delete' in s
print('Server settings UI wiring checks passed (not rendered interaction)')
