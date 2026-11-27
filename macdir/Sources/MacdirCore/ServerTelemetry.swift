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

public struct ServerState {
 public private(set) var lastSuccess: ServerTelemetry?
 public private(set) var error: ServerError?
 public private(set) var cpuHistory: [Double?] = []
 public private(set) var loadHistory: [ServerLoadPoint?] = []
 public private(set) var trafficHistory: [ServerTrafficPoint?] = []
 private var trafficByInterface: [String: [ServerTrafficPoint?]] = [:]
 public init() {}
 public mutating func accept(_ result: Result<ServerTelemetry, ServerError>) {
  let previousCount = trafficHistory.count
  switch result {
  case .success(let sample):
   lastSuccess = sample; error = nil; cpuHistory.append(sample.cpuPercent)
   if let sampledAt = sample.sampledAt { loadHistory.append(ServerLoadPoint(sampledAt: sampledAt, percent: sample.cpuPercent)) }
   else { loadHistory.append(nil) }
   if let name = sample.preferredInterface, let sampledAt = sample.sampledAt,
      let net = sample.network.first(where: { $0.name == name }) {
    trafficHistory.append(ServerTrafficPoint(interface: name, sampledAt: sampledAt, received: net.rx, sent: net.tx))
   } else { trafficHistory.append(nil) }
  case .failure(let failure): error = failure; cpuHistory.append(nil); loadHistory.append(nil); trafficHistory.append(nil)
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
  for name in Array(trafficByInterface.keys) {
   let bounded = Array((trafficByInterface[name] ?? []).suffix(121))
   if bounded.compactMap({ $0 }).isEmpty { trafficByInterface.removeValue(forKey: name) }
   else { trafficByInterface[name] = bounded }
  }
  cpuHistory = Array(cpuHistory.suffix(121))
  trafficHistory = Array(trafficHistory.suffix(121))
  loadHistory = Array(loadHistory.suffix(121))
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
 public struct Snapshot: Codable { public let savedAt: Double; public let load: [SavedLoad]; public let traffic: [String: [SavedTraffic]] }
 /// Только окно последнего часа: более старые точки ни одному диапазону не нужны.
 public func historySnapshot(now: Double = Date().timeIntervalSince1970) -> Snapshot {
  let floor = now - 3600
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
  return Snapshot(savedAt: now, load: load, traffic: traffic)
 }
 /// Восстанавливает историю так, чтобы линии продолжились, а не начинались с нуля.
 public mutating func restore(_ snapshot: Snapshot, now: Double = Date().timeIntervalSince1970) {
  let floor = now - 3600
  let restoredLoad = snapshot.load
   .filter { $0.t.isFinite && $0.t >= floor && $0.t <= now + 60 }
   .sorted { $0.t < $1.t }
   .suffix(121)
   .map { ServerLoadPoint(sampledAt: $0.t, percent: $0.v.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }) }
  if !restoredLoad.isEmpty { loadHistory = Array(restoredLoad) }
  var restoredTraffic: [String: [ServerTrafficPoint?]] = [:]
  for (name, points) in snapshot.traffic {
   let clean = points
    .filter { $0.t.isFinite && $0.t >= floor && $0.t <= now + 60 }
    .sorted { $0.t < $1.t }
    .suffix(121)
    .map { ServerTrafficPoint(interface: name, sampledAt: $0.t, received: $0.rx, sent: $0.tx) }
   if !clean.isEmpty { restoredTraffic[name] = clean }
  }
  if !restoredTraffic.isEmpty {
   trafficByInterface = restoredTraffic
   if trafficHistory.isEmpty, let first = restoredTraffic.keys.sorted().first, let points = restoredTraffic[first] {
    trafficHistory = points
   }
  }
 }
}
