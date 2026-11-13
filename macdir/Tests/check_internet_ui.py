from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / 'Sources/macdir/main.swift').read_text()
panel = root / 'Sources/macdir/InternetTestWindow.swift'
assert panel.exists(), 'missing separate internet window'
s = panel.read_text()
assert 'Button("Тест интернета") { InternetTestWindow.shared.show() }' in main
assert 'static let shared' in s and 'if window == nil' in s and 'isReleasedWhenClosed = false' in s
assert 'Button("Начать тест") { model.start() }' in s
assert 'guard !running else { return }' in s
assert '.onAppear' not in s and '.task' not in s, 'opening must not start tests'
assert 'windowWillClose' in s and 'model.cancel()' in s
assert 'InternetTestWindow.shared.stop()' in main
for word in ['Mbps', 'Джиттер', 'Потери ICMP', '1.1.1.1', 'VPN', 'Н/Д', 'RPM', 'трафик', 'файлы']:
    assert word in s, word
core = (root / 'Sources/MacdirCore/InternetProcess.swift').read_text()
assert 'POSIX_SPAWN_SETPGROUP' in core and 'kill(-pid' in core
assert '262144' in core and 'FileHandle(forWriting' not in core
assert 'createFile' not in core and 'Data(contentsOf:' not in core
assert '["-c", "-M", "20"]' in s
assert 'Task.detached' in s
assert 'InternetSpeedGauge(title:' in s and s.count('InternetSpeedGauge(title:') == 2, 'dual measured speed gauges missing'
assert 'InternetDialScale.maximum(value)' in s and 'Шкала отображения' in s
print('PASS internet UI source gates (not rendered GUI acceptance)')
