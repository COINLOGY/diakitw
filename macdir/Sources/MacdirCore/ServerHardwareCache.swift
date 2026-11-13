import Foundation

/// Daily header facts only. Live gauge denominators remain part of live telemetry.
public struct ServerHardwareCache {
 private struct Entry: Codable {
  var measured: Double?
  var attempted: Double
  var cpu: Double?
  var memory: Double?
  var disk: Double?
 }
 private var entries: [String: Entry] = [:]
 private let url: URL
 public private(set) var persistenceFailed = false
 public static var defaultURL: URL { ServerConfig.configURL.deletingLastPathComponent().appendingPathComponent("hardware-cache.json") }
 public init(url: URL = Self.defaultURL) {
  self.url = url
  if let data = try? Data(contentsOf: url), data.count <= 65536,
     let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
   entries = decoded.filter { _, e in
    e.attempted.isFinite && e.attempted >= 0 &&
    (e.measured == nil || (e.measured!.isFinite && e.measured! >= 0)) &&
    (e.cpu == nil || (e.cpu!.isFinite && e.cpu! > 0 && e.cpu!.rounded() == e.cpu!)) &&
    (e.memory == nil || (e.memory!.isFinite && e.memory! > 0)) &&
    (e.disk == nil || (e.disk!.isFinite && e.disk! > 0))
   }
  }
 }
 private func key(_ c: ServerConfig) -> String { c.id + "|" + c.target + "|" + String(c.port) + "|" + c.role }
 public func needsRefresh(_ c: ServerConfig, now: Double) -> Bool {
  guard now.isFinite, now >= 0 else { return false }
  guard let e = entries[key(c)] else { return true }
  if let date = e.measured, now >= date, now - date < 86400 { return false }
  return now < e.attempted || now - e.attempted >= 1800
 }
 public mutating func record(_ c: ServerConfig, sample: ServerTelemetry?, now: Double) {
  guard now.isFinite, now >= 0 else { return }
  var e = entries[key(c)] ?? Entry(measured: nil, attempted: now)
  e.attempted = now
  if let s = sample, let cpu = s.cpuCount, cpu.isFinite, cpu > 0, cpu.rounded() == cpu,
     let memory = s.memoryTotal, memory.isFinite, memory > 0,
     let disk = s.diskTotal, disk.isFinite, disk > 0 {
   e.measured = now; e.cpu = cpu; e.memory = memory; e.disk = disk
  }
  entries[key(c)] = e
  do {
   try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
   try JSONEncoder().encode(entries).write(to: url, options: .atomic)
   persistenceFailed = false
  } catch { persistenceFailed = true }
 }
 public func measuredAt(_ c: ServerConfig) -> Double? { entries[key(c)]?.measured }
 public func snapshot(_ c: ServerConfig) -> ServerTelemetry? {
  guard let e = entries[key(c)], e.measured != nil else { return nil }
  return ServerTelemetry(sampledAt: e.measured, cpuPercent: nil, cpuCount: e.cpu, memoryTotal: e.memory, memoryAvailable: nil, swapTotal: nil, swapFree: nil, diskTotal: e.disk, diskFree: nil, uptimeSeconds: nil, network: [], services: [])
 }
 public func label(_ c: ServerConfig, now: Double) -> String {
  guard let date = measuredAt(c) else { return "Характеристики: Н/Д" }
  let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.timeZone = TimeZone(identifier: "Europe/Moscow"); f.dateFormat = "dd.MM.yyyy HH:mm 'МСК'"
  let stale = now < date || now - date >= 86400
  return "Замер: " + f.string(from: Date(timeIntervalSince1970: date)) + (stale ? " · устарели" : " · раз в сутки") + (persistenceFailed ? " · кэш не сохранён" : "")
 }
}
