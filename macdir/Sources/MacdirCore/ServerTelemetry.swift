import Foundation
import CoreFoundation
import Darwin

public enum ServerError: String, Error { case credential = "SSH: пароль не сохранён / Связка ключей недоступна", askpass = "SSH Askpass не включён в сборку", cancelled = "SSH: отменено"; case config = "Некорректная конфигурация", unavailable = "SSH недоступен", denied = "SSH: доступ отклонён", hostKey = "SSH: проверьте ключ хоста", timeout = "SSH: время ожидания истекло", payload = "Некорректная телеметрия", probe = "Проба не найдена" }
public struct ServerNetwork: Codable { public let name: String; public let rx: Double?; public let tx: Double? }
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
 public init() {}
 public mutating func accept(_ result: Result<ServerTelemetry, ServerError>) {
  switch result {
  case .success(let sample): lastSuccess = sample; error = nil; cpuHistory.append(sample.cpuPercent)
  case .failure(let failure): error = failure; cpuHistory.append(nil)
  }
  cpuHistory = Array(cpuHistory.suffix(60))
 }
 public func current(now: Double = Date().timeIntervalSince1970) -> ServerTelemetry? { guard error == nil, let lastSuccess, lastSuccess.isFresh(now: now) else { return nil }; return lastSuccess }
}
