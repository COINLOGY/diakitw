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
telem = (p/'Sources/MacdirCore/ServerTelemetry.swift').read_text()
store = (p/'Sources/MacdirCore/ServerHistoryStore.swift').read_text()
assert 'public enum ServerHistoryStore' in store
assert 'maxBytes = 1_048_576' in store and 'maxPoints = ServerState.historyLimit' in store
assert '0o600' in store and 'replaceItemAt' in store
assert 'ServerHistoryStore.load(config.id, now: now)' in s, 'history must be restored at startup'
assert 'persistHistory(config.id)' in s and 'persistAll()' in s
assert 'historySaveInterval: Double = 30' in s
assert 'historyWindow: Double = 3600' in telem and 'historyLimit = 720' in telem, 'history is a one-hour window, not 121 points'
assert 'suffix(121)' not in telem, 'fixed 121-point cap must be gone'
# Порядок важен: cpuHistory выравнивается по уже обрезанному окну, иначе
# к концу часовой серии он отстаёт от loadHistory ровно на одну точку.
assert telem.index('cpuHistory = loadHistory.map { $0?.percent }') > telem.index('loadHistory = ServerState.trim(loadHistory'), 'cpuHistory must be derived from the trimmed window'
assert 'ServerHistoryStore.remove(config.id)' in s, 'removing a server must drop its history file'
assert 'ServerHistoryStore.prune(keeping: Set(configs.map { $0.id }))' in s, 'stale history files must be swept at startup'
# Оси графиков: CPU — фиксированные 0–100 %, сеть — максимум отображаемого периода.
assert 'chartAxisLabels(top: "100%", middle: "50%", bottom: "0%"' in s, 'CPU axis must show 0..100 %'
assert 'chartAxisLabels(top: axisRate(scale), middle: axisRate(scale / 2), bottom: "0"' in s, 'network axis must use the period maximum'
assert 'private func axisRate(' in s and 'private func chartAxisLabels(' in s
assert "Text(clock(now - range.seconds / 2))" in s, 'time axis needs a middle tick'
print('Servers UI wiring passed (not rendered UI)')
