"""Native status replacement regression wiring; not a visual placement test."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / 'Sources/macdir/main.swift').read_text()
status = (root / 'Sources/macdir/ResourceHUD.swift').read_text()
assert 'NSStatusBar.system.statusItem(withLength: statusWidth)' in status
typography = (root / 'Sources/macdir/StatusTypography.swift').read_text()
assert 'let statusWidth = StatusTypography.width(indices: visibleIndices)' in status and '.size().width' in typography
assert 'item?.length =' not in status.split('private func update(', 1)[1]
assert 'NSPanel' not in status and 'orderFrontRegardless' not in status
wrapper = (root / 'Sources/macdir/ServerPanel.swift').read_text()
assert 'MacdirRootView(model: model)' in main and 'ContentView(model: model)' in wrapper
assert 'ResourceStatusController(model: model, mainWindow: window)' in main
assert 'Model()' not in status and 'ResourceSampler()' not in status and '.scan(' not in status
assert 'model.$snapshot.combineLatest(model.$selectedInterface)' in status
assert 'attributedTitle = StatusTypography.title' in status and 'monospacedSystemFont' in typography
assert 'StatusPresentation.segments' in status
assert 'removeStatusItem' in status and 'applicationWillTerminate' in main
assert 'Мини-панель' not in main and 'toggleHUD' not in main
assert 'menuWillOpen' in status and 'Открыть diakitw' in status and 'Завершить diakitw' in status
assert 'applicationShouldTerminateAfterLastWindowClosed' in main
print('PASS: native status item, shared sampling, live menu, no overlay, termination wiring')
