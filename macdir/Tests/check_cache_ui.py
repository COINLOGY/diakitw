from pathlib import Path
main = Path('Sources/macdir/main.swift').read_text()
assert 'Button("Проверить кэши")' in main, 'cache audit button missing'
assert '.sheet(isPresented: $model.showCaches)' in main, 'cache sheet missing'
ui = Path('Sources/macdir/CachePanel.swift').read_text()
assert 'ObservableObject' in ui and '@Published' in ui and '@State' not in ui
assert 'NSAlert()' in ui and '.alertSecondButtonReturn' in ui
assert 'Task.detached(priority: .utility)' in ui
assert 'service.cleanupSelected(targets, confirmed: true)' in ui
assert '@Published var selection = CacheSelection()' in ui
assert 'Toggle(' in ui and '!report.selectable' in ui
assert 'selection = CacheSelection()' in ui
assert 'selectedReports.map' in ui and 'report.path' in ui
assert 'ScrollView' in ui and 'Удалить выбранные' in ui
assert 'service.audit()' in ui
assert '--check-caches' in main
assert 'report.disabledReason' in main, 'read-only CLI must explain disabled targets'
assert '.toggleStyle(.checkbox)' in ui, 'selection must be explicit native checkbox'
assert 'Button("Обновить проверку") { model.audit() }.disabled(model.busy)' in ui, 'refresh remains usable when all rows blocked'
assert 'Можно выбрать' in ui and 'Нет доступных для выбора кэшей' in ui, 'eligibility and all-blocked guidance visible'
assert 'report.disabledReason' in ui and 'if let error = report.error' in ui, 'blocked rows explain process and path reasons'
print('PASS: cache UI wiring (not a rendered interaction test)')
