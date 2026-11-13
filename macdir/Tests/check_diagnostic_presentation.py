from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'Sources/macdir/DiagnosticsWindow.swift').read_text()
core=(r/'Sources/MacdirCore/Diagnostics.swift').read_text()
assert 'DiagnosticRunReport(stage: stage, reason: output.reason' in s, 'runner uses typed report'
assert 'DiagnosticSummary.make' in core, 'typed report retains shared outcome policy'
assert 'reason: output.reason' in s and 'exitCode: output.status' in s
assert 'systemUptime - t' in s, 'monotonic measured elapsed'
assert 'if cancellation.isCancelled' not in s, 'late cancel must not overwrite actual finished reason'
for mode in ['cpu','ram','gpu']:
    assert f'DiagnosticButton(kind: .{mode}' in s, mode
assert 'DiagnosticResult: Decodable' not in s, 'one tested decoder'
c=(r/'Sources/macdir/DiagnosticControls.swift').read_text()
for icon in ['cpu','memorychip','display']:
    assert f'"{icon}"' in c
assert '.white' in c and 'kind.color' in c
print('Diagnostic presentation wiring PASS (not live GUI interaction)')
