#!/usr/bin/env python3
"""Гейт: оповещения, история диска/аптайма, экспорт и подсветка режимов.

Проверяются исходники, а не отрисованный интерфейс: цель — чтобы фича
не исчезла при следующей правке вёрстки и не обходила пороги при снятии тревоги.
"""
import pathlib

p = pathlib.Path(__file__).resolve().parent.parent
alerts = (p / 'Sources/MacdirCore/ServerAlerts.swift').read_text()
core = (p / 'Sources/MacdirCore/ServerTelemetry.swift').read_text()
export = (p / 'Sources/MacdirCore/ServerHistoryExport.swift').read_text()
notifier = (p / 'Sources/macdir/ServerNotifier.swift').read_text()
ui = (p / 'Sources/macdir/ServerPanel.swift').read_text()
chips = (p / 'Sources/macdir/ServerAlertUI.swift').read_text()

# --- движок оповещений: событие только на переходе, иначе будет спам ---
assert 'public struct ServerAlertEngine' in alerts
assert 'case offline, cpu, disk, recovered' in alerts
assert 'if settings.offlineEnabled, count >= settings.offlinePolls, !offline.contains(serverID)' in alerts
assert 'if settings.cpuEnabled, count >= settings.cpuPolls, !hotArmed.contains(serverID)' in alerts
assert 'if !diskArmed.contains(serverID)' in alerts
# тревога по диску снимается только при заметном запасе, а не на границе
assert 'free >= settings.diskFreeThreshold + 5' in alerts
# восстановление связи гасит счётчик нагрузки
assert 'hot[serverID] = 0' in alerts
# пороги из файла настроек санируются
assert 'value.offlinePolls = min(max(offlinePolls, 2), 12)' in alerts
assert 'value.cpuThreshold = min(max(cpuThreshold, 50), 100)' in alerts
assert 'value.diskFreeThreshold = min(max(diskFreeThreshold, 1), 50)' in alerts
# недостоверный диск не должен давать деления на ноль
assert 'total > 0, free >= 0, free <= total' in alerts

# --- история диска и аптайма + тренд + давность ответа ---
assert 'public struct ServerDiskPoint' in core
assert 'public var diskTrendPerDay: Double?' in core
assert 'last.0 - first.0 >= 600' in core, 'тренд без минимального окна — это шум'
assert 'public func lastAnswerText(' in core
assert 'public var failuresToday: Int' in core
assert 'public var rebootsToday: Int' in core
assert 'current < previous - 60' in core, 'перезагрузка = аптайм уменьшился'
assert 'diskHistory = ServerState.trim(diskHistory' in core
assert 'public let disk: [SavedDisk]?' in core, 'история диска должна попадать в файл'

# --- экспорт CSV ---
assert 'public enum ServerHistoryExport' in export
assert '"server,timestamp,iso_time,cpu_percent' in export
assert 'static func escape(_ value: String) -> String' in export
assert 'ISO8601DateFormatter()' in export
assert 'joined(separator: ",")' in export

# --- уведомления macOS ---
assert 'UNUserNotificationCenter' in notifier
assert 'requestAuthorization(options: [.alert, .sound])' in notifier
assert 'UNNotificationRequest(identifier:' in notifier

# --- подключение в интерфейсе ---
assert 'alertEngine.evaluate(' in ui
assert 'ServerNotifier.shared.post(alert)' in ui
assert 'ServerAlertSettingsSheet(model: model)' in ui, 'лист настроек должен открываться'
assert 'model.exportHistory(historyRange)' in ui, 'кнопка экспорта должна вызывать экспорт'
assert 'fleetStatusLine(state: state, now: now)' in ui
assert 'state.lastAnswerText(now: now)' in ui
assert 'state.diskTrendPerDay' in ui

# --- подсветка режимов: активная кнопка отличается от неактивной ---
assert 'struct ModeChip: View' in chips
assert 'Color.accentColor.opacity(0.18)' in chips, 'включённый режим должен быть подложен акцентом'
assert 'Color.accentColor.opacity(0.85)' in chips, 'включённый режим должен иметь яркую обводку'
assert '.accessibilityAddTraits(isOn ? [.isSelected] : [])' in chips
assert 'isOn: model.refreshInterval == seconds' in ui, 'интервал должен показывать выбранное значение'
assert 'isOn: model.backgroundCollecting' in ui
assert 'isOn: historyRange == value' in ui
assert 'isOn: model.alertsOn' in ui
assert 'Picker("Обновление"' not in ui, 'старый выпадающий список интервала должен быть заменён чипами'

print('Оповещения, история диска и аптайма, экспорт CSV и подсветка режимов: проверено')
