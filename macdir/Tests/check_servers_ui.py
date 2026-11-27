"""Source wiring only; no claim of rendered GUI verification."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
m = (p/'Sources/macdir/main.swift').read_text()
assert 'rootView: MacdirRootView(model: model)' in m
assert '--server-snapshot' in m and m.index('--server-snapshot') < m.index('let app = NSApplication.shared')
s = (p/'Sources/macdir/ServerPanel.swift').read_text()
assert 'ContentView(model: model)' in s
assert 'Этот Mac' in s and 'Серверы' in s
assert s.index('title: "RAM"') < s.index('title: "SWAP"') < s.index('title: "ДИСК /"')
assert '.seconds(interval)' in s and '.onDisappear' in s
assert 'intervalChoices' in s and 'server.refreshInterval' in s and 'server.backgroundCollecting' in s
assert 'ServerMultiplex.controlPath(for:' in s, 'frequent polling must reuse the SSH control socket'
assert 'Task.detached' in s and 'inFlight' in s
assert 'Europe/Moscow' in s and 'lastSuccess' in s
assert 'ResourceStatusController' not in s
assert 'state.current(now: now)' in s
assert s.index('Text(config.headerAddress)') < s.index('Text(ServerTelemetry.hardwareSummary(hardware))') < s.index('title: "CPU"')
assert 'hardwareCache.needsRefresh(config, now:' in s
assert 'specs: true' in s and 'hardwareInFlight' in s
assert 'hardware: model.hardwareCache.snapshot(config)' in s
assert 'Text(hardwareLabel)' in s
# Мастер-процесс ControlPersist живёт в группе ssh: при штатном завершении
# группу убивать нельзя, иначе сокет исчезает и соединение не переиспользуется.
process = (p/'Sources/MacdirCore/ServerSSHProcess.swift').read_text()
assert 'if !reaped { _ = kill(-pid, SIGKILL) }' in process, 'normal exit must keep the ControlPersist master alive'
assert 'kill(-pid, SIGTERM)' in process, 'timeout path must still stop the process group'
# История графиков переживает перезапуск: файл на сервер, атомарная запись,
# жёсткие границы на чтении и запись не чаще раза в 30 с.
store = (p/'Sources/MacdirCore/ServerHistoryStore.swift').read_text()
assert 'public enum ServerHistoryStore' in store
assert 'maxBytes = 262_144' in store and 'maxPoints = 400' in store
assert '0o600' in store and 'replaceItemAt' in store
assert 'ServerHistoryStore.load(config.id, now: now)' in s, 'history must be restored at startup'
assert 'persistHistory(config.id)' in s and 'persistAll()' in s
assert 'historySaveInterval: Double = 30' in s
assert 'ServerHistoryStore.remove(config.id)' in s, 'removing a server must drop its history file'
print('Servers UI wiring passed (not rendered UI)')
