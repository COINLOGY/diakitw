import Foundation

/// Экспорт истории сервера в CSV: строки выровнены по моментам замеров, поэтому
/// таблицу можно открыть в Numbers или отдать в отчёт без ручной правки.
public enum ServerHistoryExport {
 public static let header = "server,timestamp,iso_time,cpu_percent,disk_used_bytes,disk_total_bytes,rx_bytes_per_second,tx_bytes_per_second"

 /// Запятые и кавычки в имени сервера не должны ломать таблицу.
 static func escape(_ value: String) -> String {
  let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
  let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
  return needsQuotes ? "\"" + escaped + "\"" : escaped
 }

 static func number(_ value: Double?) -> String {
  guard let value, value.isFinite else { return "" }
  return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
 }

 public static func csv(server: String, state: ServerState, range: ServerHistoryRange,
                        now: Double) -> String {
  let load = state.load(in: range, now: now)
  let traffic = state.traffic(in: range, now: now)
  let disk = state.disk(in: range, now: now)

  var cpu: [Double: Double] = [:]
  for point in load.compactMap({ $0 }) {
   if let percent = point.percent, percent.isFinite { cpu[point.sampledAt] = percent }
  }
  var net: [Double: (Double?, Double?)] = [:]
  for point in traffic.compactMap({ $0 }) { net[point.sampledAt] = (point.received, point.sent) }
  var storage: [Double: (Double?, Double?)] = [:]
  for point in disk.compactMap({ $0 }) { storage[point.sampledAt] = (point.used, point.total) }

  let stamps = Set(cpu.keys).union(net.keys).union(storage.keys).sorted()
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone.current
  formatter.formatOptions = [.withInternetDateTime]

  var lines = [header]
  lines.reserveCapacity(stamps.count + 1)
  let name = escape(server)
  for stamp in stamps {
   let iso = formatter.string(from: Date(timeIntervalSince1970: stamp))
   let link = net[stamp] ?? (nil, nil)
   let space = storage[stamp] ?? (nil, nil)
   lines.append([name, number(stamp), iso, number(cpu[stamp]),
                 number(space.0), number(space.1), number(link.0), number(link.1)].joined(separator: ","))
  }
  return lines.joined(separator: "\n") + "\n"
 }
}
