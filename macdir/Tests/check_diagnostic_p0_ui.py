"""Source wiring only: does not claim rendered UI or SavePanel interaction."""
from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/macdir/DiagnosticsWindow.swift').read_text()
for required in ['NSSavePanel()', 'allowedContentTypes', 'panel.runModal() == .OK', 'Data(contentsOf: url)', 'history.append', 'DiagnosticSequence(', 'cancellation.isCancelled', 'sequence.deadline', 'systemUptime', 'Apple Diagnostics', 'https://support.apple.com/en-us/102550', 'model.requestSuite()', 'model.cancel()']:
    assert required in s, required
assert 'timeIntervalSince(start)' not in s
print('P0 UI source wiring PASS (not GUI acceptance)')
