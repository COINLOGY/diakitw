import Foundation

/// Пороги оповещений. Настройки владельца, переживают перезапуск.
public struct ServerAlertSettings: Codable, Equatable {
 public var offlineEnabled: Bool
 /// Сколько подряд неудачных замеров считать падением.
 public var offlinePolls: Int
 public var cpuEnabled: Bool
 public var cpuThreshold: Double
 /// Сколько подряд замеров выше порога считать устойчивой нагрузкой.
 public var cpuPolls: Int
 public var diskEnabled: Bool
 /// Ниже этого процента свободного места — предупреждение.
 public var diskFreeThreshold: Double

 public init(offlineEnabled: Bool = true, offlinePolls: Int = 3, cpuEnabled: Bool = true,
             cpuThreshold: Double = 90, cpuPolls: Int = 5, diskEnabled: Bool = true,
             diskFreeThreshold: Double = 10) {
  self.offlineEnabled = offlineEnabled
  self.offlinePolls = offlinePolls
  self.cpuEnabled = cpuEnabled
  self.cpuThreshold = cpuThreshold
  self.cpuPolls = cpuPolls
  self.diskEnabled = diskEnabled
  self.diskFreeThreshold = diskFreeThreshold
 }

 /// Значения вне разумных границ не принимаются: файл настроек мог быть испорчен.
 public func sanitized() -> ServerAlertSettings {
  var value = self
  value.offlinePolls = min(max(offlinePolls, 2), 12)
  value.cpuPolls = min(max(cpuPolls, 2), 30)
  value.cpuThreshold = min(max(cpuThreshold, 50), 100)
  value.diskFreeThreshold = min(max(diskFreeThreshold, 1), 50)
  return value
 }

 public static let storageKey = "server.alertSettings"

 public static func load(_ defaults: UserDefaults = .standard) -> ServerAlertSettings {
  guard let data = defaults.data(forKey: storageKey),
        let value = try? JSONDecoder().decode(ServerAlertSettings.self, from: data) else { return ServerAlertSettings() }
  return value.sanitized()
 }

 public func save(_ defaults: UserDefaults = .standard) {
  guard let data = try? JSONEncoder().encode(sanitized()) else { return }
  defaults.set(data, forKey: ServerAlertSettings.storageKey)
 }
}

public enum ServerAlertKind: String, Sendable {
 case offline, cpu, disk, recovered

 public var isProblem: Bool { self != .recovered }
}

public struct ServerAlert: Identifiable, Sendable {
 public let serverID: String
 public let serverName: String
 public let kind: ServerAlertKind
 public let title: String
 public let body: String
 public var id: String { serverID + ":" + kind.rawValue + ":" + title }

 public init(serverID: String, serverName: String, kind: ServerAlertKind, title: String, body: String) {
  self.serverID = serverID; self.serverName = serverName; self.kind = kind
  self.title = title; self.body = body
 }
}

/// Решает, когда показать оповещение. Событие выдаётся только на переходе
/// «норма → проблема» и «проблема → норма», поэтому повторов нет.
public struct ServerAlertEngine {
 private var failures: [String: Int] = [:]
 private var hot: [String: Int] = [:]
 private var offline: Set<String> = []
 private var hotArmed: Set<String> = []
 private var diskArmed: Set<String> = []

 public init() {}

 public mutating func evaluate(serverID: String, name: String,
                               result: Result<ServerTelemetry, ServerError>,
                               settings: ServerAlertSettings) -> [ServerAlert] {
  let settings = settings.sanitized()
  var events: [ServerAlert] = []

  switch result {
  case .failure:
   let count = (failures[serverID] ?? 0) + 1
   failures[serverID] = count
   // Недоступность важнее остальных сигналов: обнуляем счётчики нагрузки.
   hot[serverID] = 0
   if settings.offlineEnabled, count >= settings.offlinePolls, !offline.contains(serverID) {
    offline.insert(serverID)
    events.append(ServerAlert(serverID: serverID, serverName: name, kind: .offline,
                              title: "\(name): нет ответа",
                              body: "\(count) замера подряд без ответа. Проверьте питание и SSH."))
   }

  case .success(let sample):
   failures[serverID] = 0
   var recovered: [String] = []
   if offline.remove(serverID) != nil { recovered.append("связь вернулась") }

   if let cpu = sample.cpuPercent, cpu.isFinite {
    if cpu >= settings.cpuThreshold {
     let count = (hot[serverID] ?? 0) + 1
     hot[serverID] = count
     if settings.cpuEnabled, count >= settings.cpuPolls, !hotArmed.contains(serverID) {
      hotArmed.insert(serverID)
      events.append(ServerAlert(serverID: serverID, serverName: name, kind: .cpu,
                                title: "\(name): процессор \(Int(cpu.rounded())) %",
                                body: "Выше \(Int(settings.cpuThreshold)) % уже \(count) замеров подряд."))
     }
    } else {
     hot[serverID] = 0
     if hotArmed.remove(serverID) != nil { recovered.append("нагрузка спала") }
    }
   }

   if settings.diskEnabled, let free = freePercent(sample) {
    // Гистерезис: снимаем тревогу только когда места заметно больше порога.
    if free <= settings.diskFreeThreshold {
     if !diskArmed.contains(serverID) {
      diskArmed.insert(serverID)
      events.append(ServerAlert(serverID: serverID, serverName: name, kind: .disk,
                                title: "\(name): мало места",
                                body: "Свободно \(String(format: "%.0f", free)) % диска."))
     }
    } else if free >= settings.diskFreeThreshold + 5, diskArmed.remove(serverID) != nil {
     recovered.append("место освободилось")
    }
   }

   if !recovered.isEmpty {
    events.append(ServerAlert(serverID: serverID, serverName: name, kind: .recovered,
                              title: "\(name): в норме",
                              body: recovered.joined(separator: ", ")))
   }
  }
  return events
 }

 /// Процент свободного места, если его можно посчитать достоверно.
 private func freePercent(_ sample: ServerTelemetry) -> Double? {
  guard let total = sample.diskTotal, let free = sample.diskFree,
        total.isFinite, free.isFinite, total > 0, free >= 0, free <= total else { return nil }
  return free / total * 100
 }
}
