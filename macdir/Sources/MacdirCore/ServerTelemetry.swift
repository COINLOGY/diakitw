import Foundation
import CoreFoundation
import Darwin

public enum ServerError: String, Error { case credential = "SSH: пароль не сохранён / Связка ключей недоступна", askpass = "SSH Askpass не включён в сборку", cancelled = "SSH: отменено"; case config = "Некорректная конфигурация", unavailable = "SSH недоступен", denied = "SSH: доступ отклонён", hostKey = "SSH: проверьте ключ хоста", timeout = "SSH: время ожидания истекло", payload = "Некорректная телеметрия", probe = "Проба не найдена" }
public struct ServerNetwork: Codable { public let name: String; public let rx: Double?; public let tx: Double? }
public struct ServerTrafficPoint {
 public let interface: String
 public let sampledAt: Double
 public let received: Double?
 public let sent: Double?
 public var hasMeasurement: Bool { received != nil || sent != nil }
 public func follows(_ previous: Self) -> Bool {
  interface == previous.interface && sampledAt > previous.sampledAt && sampledAt - previous.sampledAt <= 45
 }
}
public enum ServerHistoryRange: Int, CaseIterable, Sendable {
 case minute = 60, fiveMinutes = 300, fifteenMinutes = 900, hour = 3600
 public var seconds: Double { Double(rawValue) }
 public var label: String {
  switch self { case .minute: return "1 мин"; case .fiveMinutes: return "5 мин"; case .fifteenMinutes: return "15 мин"; case .hour: return "60 мин" }
 }
}
public struct ServerLoadPoint {
 public let sampledAt: Double
 public let percent: Double?
 public func follows(_ previous: Self) -> Bool {
  sampledAt > previous.sampledAt && sampledAt - previous.sampledAt <= 45
 }
}
public struct ServerService: Codable { public let name: String; public let state: String }
public struct ServerTelemetry: Codable {
 public let sampledAt: Double?
 public let cpuPercent: Double?
 public let cpuCount: Double?
 public let memoryTotal: Double?; public let memoryAvailable: Double?
 public let swapTotal: Double?; public let swapFree: Double?
 public let diskTotal: Double?; public let diskFree: Double?
 public let uptimeSeconds: Double?
 public let network: [ServerNetwork]; public let services: [ServerService]
 public static func used(_ total: Double?, _ free: Double?) -> Double? { guard let total, let free, total.isFinite, free.isFinite, total >= 0, free >= 0, free <= total else { return nil }; return total - free }
 /// Logical processors reported by the guest OS, not physical cores.
 public static func hardwareSummary(_ sample: ServerTelemetry?) -> String {
  let locale = Locale(identifier: "en_US_POSIX")
  func capacity(_ value: Double?) -> String {
   guard let value, value.isFinite, value > 0 else { return "Н/Д" }
   return MetricPresentation.number(value / 1_073_741_824) + " GiB"
  }
  let cpu = sample?.cpuCount.flatMap { value -> String? in
   guard value.isFinite, value > 0, value.rounded() == value else { return nil }
   return String(format: "%.0f", locale: locale, value)
  } ?? "Н/Д"
  return "vCPU \(cpu) · RAM \(capacity(sample?.memoryTotal)) · Диск / \(capacity(sample?.diskTotal))"
 }
 public var memoryUsed: Double? { Self.used(memoryTotal, memoryAvailable) }
 public var swapUsed: Double? { Self.used(swapTotal, swapFree) }
 public var diskUsed: Double? { Self.used(diskTotal, diskFree) }
 public func isFresh(now: Double = Date().timeIntervalSince1970) -> Bool { guard let sampledAt else { return false }; return now.isFinite && now >= sampledAt && now - sampledAt <= 90 }
 public static func decode(_ data: Data) throws -> Self {
  guard data.count <= 65536, let d = try JSONSerialization.jsonObject(with: data) as? [String: Any], number(d["schema"]) == 1 else { throw ServerError.payload }
  let cpu = number(d["cpu_percent"])
  let cores = number(d["cpu_count"])
  let net = (d["network"] as? [[String: Any]] ?? []).prefix(128).compactMap { n -> ServerNetwork? in
   guard let name = safeName(n["name"]) else { return nil }; return ServerNetwork(name: name, rx: number(n["rx_bytes_per_second"]), tx: number(n["tx_bytes_per_second"]))
  }
  let services = (d["services"] as? [[String: Any]] ?? []).prefix(64).compactMap { s -> ServerService? in
   guard let name = safeName(s["name"]) else { return nil }
   let state = s["state"] as? String ?? "unknown"
   return ServerService(name: name, state: ["active", "running", "inactive", "failed", "activating", "deactivating", "not-found", "unknown"].contains(state) ? state : "unknown")
  }
  return Self(sampledAt: number(d["sampled_at"]), cpuPercent: cpu.flatMap { $0 <= 100 ? $0 : nil }, cpuCount: cores.flatMap { $0 > 0 && $0.rounded() == $0 ? $0 : nil }, memoryTotal: number(d["memory_total"]), memoryAvailable: number(d["memory_available"]), swapTotal: number(d["swap_total"]), swapFree: number(d["swap_free"]), diskTotal: number(d["disk_total"]), diskFree: number(d["disk_free"]), uptimeSeconds: number(d["uptime_seconds"]), network: net, services: services)
 }
 private static func number(_ value: Any?) -> Double? { guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }; let d = n.doubleValue; return d.isFinite && d >= 0 ? d : nil }
 public var preferredInterface: String? { network.first { $0.name.hasPrefix("eth") || $0.name.hasPrefix("en") }?.name ?? network.first { $0.name != "lo" }?.name }
 private static func safeName(_ value: Any?) -> String? { guard let s = value as? String, s.range(of: "\\A[A-Za-z0-9_.:@-]{1,128}\\z", options: .regularExpression) != nil else { return nil }; return s }
}

/// Занятое место и объём файловой системы в момент замера.
public struct ServerDiskPoint {
 public let sampledAt: Double
 public let used: Double?
 public let total: Double?
}

public struct ServerState {
 /// Окно истории — час, а не фиксированные 121 точка: при опросе 5 с линия
 /// обрывалась на 10-й минуте, хотя выбран диапазон «60 мин». 720 точек — это
 /// ровно час на 5 с и страховка от раздувания памяти.
 public static let historyWindow: Double = 3600
 public static let historyLimit = 720
 public private(set) var lastSuccess: ServerTelemetry?
 public private(set) var error: ServerError?
 public private(set) var cpuHistory: [Double?] = []
 public private(set) var loadHistory: [ServerLoadPoint?] = []
 public private(set) var trafficHistory: [ServerTrafficPoint?] = []
 private var trafficByInterface: [String: [ServerTrafficPoint?]] = [:]
 /// Недоступность и перезагрузки: нужны строке парка и оповещениям.
 public private(set) var consecutiveFailures = 0
 public private(set) var lastSuccessAt: Double?
 public private(set) var diskHistory: [ServerDiskPoint?] = []
 public private(set) var uptimeHistory: [Double?] = []
 private var failureTimes: [Double] = []
 private var rebootTimes: [Double] = []
 private var lastUptime: Double?
 public init() {}
 public mutating func accept(_ result: Result<ServerTelemetry, ServerError>, now: Double = Date().timeIntervalSince1970) {
  let previousCount = trafficHistory.count
  switch result {
  case .success(let sample):
   lastSuccess = sample; error = nil; cpuHistory.append(sample.cpuPercent)
   consecutiveFailures = 0
   if let sampledAt = sample.sampledAt { lastSuccessAt = max(lastSuccessAt ?? sampledAt, sampledAt) }
   if let previous = lastUptime, let current = sample.uptimeSeconds, current.isFinite,
      previous.isFinite, current < previous - 60 {
    // Аптайм уменьшился — сервер перезагружался.
    rebootTimes.append(now)
   }
   if let current = sample.uptimeSeconds, current.isFinite { lastUptime = current }
   if let sampledAt = sample.sampledAt {
    diskHistory.append(ServerDiskPoint(sampledAt: sampledAt, used: sample.diskUsed, total: sample.diskTotal))
    uptimeHistory.append(sample.uptimeSeconds)
   } else {
    diskHistory.append(nil); uptimeHistory.append(nil)
   }
   if let sampledAt = sample.sampledAt { loadHistory.append(ServerLoadPoint(sampledAt: sampledAt, percent: sample.cpuPercent)) }
   else { loadHistory.append(nil) }
   if let name = sample.preferredInterface, let sampledAt = sample.sampledAt,
      let net = sample.network.first(where: { $0.name == name }) {
    trafficHistory.append(ServerTrafficPoint(interface: name, sampledAt: sampledAt, received: net.rx, sent: net.tx))
   } else { trafficHistory.append(nil) }
  case .failure(let failure):
   error = failure; cpuHistory.append(nil); loadHistory.append(nil); trafficHistory.append(nil)
   diskHistory.append(nil); uptimeHistory.append(nil)
   consecutiveFailures += 1
   failureTimes.append(now)
  }
  // Keep a separate measured history for each selected interface. Every poll,
  // including a failed probe, adds a nil slot so a line cannot bridge a gap.
  for name in Array(trafficByInterface.keys) {
   var history = trafficByInterface[name] ?? []
   history.append(nil)
   trafficByInterface[name] = history
  }
  if case .success(let sample) = result, let sampledAt = sample.sampledAt {
   for net in sample.network {
    var history = trafficByInterface[net.name] ?? Array(repeating: nil, count: previousCount + 1)
    history[history.count - 1] = ServerTrafficPoint(interface: net.name, sampledAt: sampledAt, received: net.rx, sent: net.tx)
    trafficByInterface[net.name] = history
   }
  }
  let newest = (loadHistory.compactMap { $0?.sampledAt } + trafficByInterface.values.flatMap { $0.compactMap { $0?.sampledAt } }).max()
  for name in Array(trafficByInterface.keys) {
   let bounded = ServerState.trim(trafficByInterface[name] ?? [], newest: newest, timestamp: { $0.sampledAt })
   if bounded.compactMap({ $0 }).isEmpty { trafficByInterface.removeValue(forKey: name) }
   else { trafficByInterface[name] = bounded }
  }
  cpuHistory = ServerState.trim(cpuHistory, newest: newest, timestamp: { $0.sampledAt })
  trafficHistory = ServerState.trim(trafficHistory, newest: newest, timestamp: { $0.sampledAt })
  loadHistory = ServerState.trim(loadHistory, newest: newest, timestamp: { $0.sampledAt })
  diskHistory = ServerState.trim(diskHistory, newest: newest, timestamp: { $0.sampledAt })
  uptimeHistory = Array(uptimeHistory.suffix(ServerState.historyLimit))
  let dayFloor = now - 86_400
  failureTimes = failureTimes.filter { $0 >= dayFloor }
  rebootTimes = rebootTimes.filter { $0 >= dayFloor }
 }

 /// Сколько сбоев за последние сутки — для строки парка.
 public var failuresToday: Int { failureTimes.count }
 /// Сколько перезагрузок за последние сутки.
 public var rebootsToday: Int { rebootTimes.count }

 /// История занятого места за период — для тренда и экспорта.
 public func disk(in range: ServerHistoryRange, now: Double) -> [ServerDiskPoint?] {
  guard now.isFinite else { return [] }
  return diskHistory.drop { $0.map { $0.sampledAt < now - range.seconds } ?? true }.map { point in
   guard let point, point.sampledAt >= now - range.seconds, point.sampledAt <= now else { return nil }
   return point
  }
 }

 /// Скорость роста диска в байтах за сутки: нужна не меньше десяти минут данных,
 /// иначе шум перевешивает сигнал.
 public var diskTrendPerDay: Double? {
  let points = diskHistory.compactMap { $0 }.compactMap { point -> (Double, Double)? in
   guard let used = point.used, used.isFinite, point.sampledAt.isFinite else { return nil }
   return (point.sampledAt, used)
  }
  guard let first = points.first, let last = points.last, last.0 - first.0 >= 600 else { return nil }
  return (last.1 - first.1) / (last.0 - first.0) * 86_400
 }

 /// «12 с назад», «5 мин назад» — читаемая давность последнего ответа.
 public func lastAnswerText(now: Double = Date().timeIntervalSince1970) -> String {
  guard let lastSuccessAt, lastSuccessAt.isFinite, now.isFinite else { return "нет ответа" }
  let age = max(0, now - lastSuccessAt)
  if age < 90 { return "\(Int(age.rounded())) с назад" }
  if age < 5_400 { return "\(Int((age / 60).rounded())) мин назад" }
  if age < 172_800 { return "\(Int((age / 3_600).rounded())) ч назад" }
  return "\(Int((age / 86_400).rounded())) дн назад"
 }
 /// Оставляет час истории и не больше 720 точек. Пустые слоты — разрывы — не режутся.
 static func trim<T>(_ points: [T?], newest: Double?, timestamp: (T) -> Double) -> [T?] {
  let reference = newest.flatMap { $0.isFinite ? $0 : nil } ?? 0
  let cut = reference - historyWindow
  var kept = points.filter { point in
   guard let point else { return true }
   let at = timestamp(point)
   return at.isFinite ? at >= cut : true
  }
  if kept.count > historyLimit { kept = Array(kept.suffix(historyLimit)) }
  return kept
 }
 // Keep nil slots: unsuccessful probes and missing measurements are discontinuities.
 public func load(in range: ServerHistoryRange, now: Double) -> [ServerLoadPoint?] {
  guard now.isFinite else { return [] }
  let first = loadHistory.firstIndex { $0.map { $0.sampledAt >= now - range.seconds } ?? false } ?? loadHistory.count
  return loadHistory.dropFirst(first).map { point in
   guard let point, point.sampledAt >= now - range.seconds, point.sampledAt <= now else { return nil }
   return point
  }
 }
 public func traffic(in range: ServerHistoryRange, now: Double) -> [ServerTrafficPoint?] {
  filteredTraffic(trafficHistory, in: range, now: now)
 }
 /// Первый интерфейс, для которого есть история: нужен до первого живого замера,
 /// иначе восстановленные линии не рисуются после перезапуска.
 public var knownInterface: String? { trafficByInterface.keys.sorted().first }
 public func traffic(for name: String?, in range: ServerHistoryRange, now: Double) -> [ServerTrafficPoint?] {
  guard let name, let history = trafficByInterface[name] else { return [] }
  return filteredTraffic(history, in: range, now: now)
 }
 private func filteredTraffic(_ history: [ServerTrafficPoint?], in range: ServerHistoryRange, now: Double) -> [ServerTrafficPoint?] {
  guard now.isFinite else { return [] }
  let first = history.firstIndex { $0.map { $0.sampledAt >= now - range.seconds } ?? false } ?? history.count
  return history.dropFirst(first).map { point in
   guard let point, point.sampledAt >= now - range.seconds, point.sampledAt <= now else { return nil }
   return point
  }
 }
 public func current(now: Double = Date().timeIntervalSince1970) -> ServerTelemetry? { guard error == nil, let lastSuccess, lastSuccess.isFresh(now: now) else { return nil }; return lastSuccess }
 // MARK: — История на диск
 /// Компактный снимок истории для файла: точка = [время, значение].
 public struct SavedLoad: Codable { public let t: Double; public let v: Double? }
 public struct SavedTraffic: Codable { public let t: Double; public let rx: Double?; public let tx: Double? }
 public struct SavedDisk: Codable { public let t: Double; public let u: Double?; public let total: Double? }
 public struct Snapshot: Codable {
  public let savedAt: Double
  public let load: [SavedLoad]
  public let traffic: [String: [SavedTraffic]]
  /// Появились позже: файлы прежних версий читаются без них.
  public let disk: [SavedDisk]?
  public let uptime: [Double?]?
  public init(savedAt: Double, load: [SavedLoad], traffic: [String: [SavedTraffic]],
              disk: [SavedDisk]? = nil, uptime: [Double?]? = nil) {
   self.savedAt = savedAt; self.load = load; self.traffic = traffic; self.disk = disk; self.uptime = uptime
  }
 }
 /// Только окно последнего часа: более старые точки ни одному диапазону не нужны.
 public func historySnapshot(now: Double = Date().timeIntervalSince1970) -> Snapshot {
  let floor = now - ServerState.historyWindow
  let load = loadHistory.compactMap { point -> SavedLoad? in
   guard let point, point.sampledAt.isFinite, point.sampledAt >= floor, point.sampledAt <= now + 60 else { return nil }
   return SavedLoad(t: point.sampledAt, v: point.percent)
  }
  var traffic: [String: [SavedTraffic]] = [:]
  for (name, points) in trafficByInterface {
   let saved = points.compactMap { point -> SavedTraffic? in
    guard let point, point.sampledAt.isFinite, point.sampledAt >= floor, point.sampledAt <= now + 60 else { return nil }
    return SavedTraffic(t: point.sampledAt, rx: point.received, tx: point.sent)
   }
   if !saved.isEmpty { traffic[name] = saved }
  }
  let disk = diskHistory.compactMap { point -> SavedDisk? in
   guard let point, point.sampledAt.isFinite, point.sampledAt >= floor, point.sampledAt <= now + 60 else { return nil }
   return SavedDisk(t: point.sampledAt, u: point.used, total: point.total)
  }
  return Snapshot(savedAt: now, load: load, traffic: traffic, disk: disk, uptime: uptimeHistory)
 }
 /// Восстанавливает историю так, чтобы линии продолжились, а не начинались с нуля.
 public mutating func restore(_ snapshot: Snapshot, now: Double = Date().timeIntervalSince1970) {
  let floor = now - ServerState.historyWindow
  let restoredLoad = snapshot.load
   .filter { $0.t.isFinite && $0.t >= floor && $0.t <= now + 60 }
   .sorted { $0.t < $1.t }
   .suffix(ServerState.historyLimit)
   .map { ServerLoadPoint(sampledAt: $0.t, percent: $0.v.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }) }
  if !restoredLoad.isEmpty { loadHistory = Array(restoredLoad) }
  var restoredTraffic: [String: [ServerTrafficPoint?]] = [:]
  for (name, points) in snapshot.traffic {
   let clean = points
    .filter { $0.t.isFinite && $0.t >= floor && $0.t <= now + 60 }
    .sorted { $0.t < $1.t }
    .suffix(ServerState.historyLimit)
    .map { ServerTrafficPoint(interface: name, sampledAt: $0.t, received: $0.rx, sent: $0.tx) }
   if !clean.isEmpty { restoredTraffic[name] = clean }
  }
  if let savedDisk = snapshot.disk {
   let restoredDisk = savedDisk
    .filter { $0.t.isFinite && $0.t >= floor && $0.t <= now + 60 }
    .sorted { $0.t < $1.t }
    .suffix(ServerState.historyLimit)
    .map { ServerDiskPoint(sampledAt: $0.t, used: $0.u, total: $0.total) }
   if !restoredDisk.isEmpty { diskHistory = Array(restoredDisk) }
  }
  if let savedUptime = snapshot.uptime, let last = savedUptime.compactMap({ $0 }).last, last.isFinite {
   lastUptime = last
  }
  if !restoredTraffic.isEmpty {
   trafficByInterface = restoredTraffic
   if trafficHistory.isEmpty, let first = restoredTraffic.keys.sorted().first, let points = restoredTraffic[first] {
    trafficHistory = points
   }
  }
 }
}
