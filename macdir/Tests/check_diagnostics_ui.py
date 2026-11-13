from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'Sources/macdir/DiagnosticsWindow.swift'
assert p.exists(), 'separate diagnostics window missing'
s=p.read_text() + (root/'Sources/macdir/DiagnosticControls.swift').read_text(); main=(root/'Sources/macdir/main.swift').read_text()
for text in ['NSWindowDelegate','windowWillClose','model.cancel()', 'NSAlert()', 'alertSecondButtonReturn', 'InternetCancellation', 'Task.detached', 'DiagnosticWorker', 'guard !running', 'TimelineView', 'CPU', 'RAM', 'GPU Metal']:
    assert text in s, text
assert 'Button("Диагностика")' in main
assert 'DiagnosticsWindow.shared.stop()' in main
assert 'guard alert.runModal() == .alertSecondButtonReturn' in s, 'only explicit Start consents'
assert '@State ' not in s
print('Diagnostics UI source wiring PASS (not rendered interaction)')
