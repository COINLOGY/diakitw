import Foundation

/// Measurement-only formatting. Counts, dates, addresses and exact byte evidence stay intact.
public enum MetricPresentation {
 public static let swapExplanation = "Использовано / выделено сейчас. Процент от текущего выделенного объёма SWAP, который может меняться; это не фиксированная ёмкость и не оценка состояния памяти. При нулевом объёме процент не определён. GiB = 2³⁰ байт."
 public static func number(_ value: Double?) -> String {
  guard let value, value.isFinite, value >= 0 else { return "Н/Д" }
  let text = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
  return text
 }
 public static func battery(_ value: Double?) -> String {
  guard let value, value.isFinite, value >= 0, value <= 100 else { return "Н/Д" }
  return String(format: "%.0f%%", locale: Locale(identifier: "en_US_POSIX"), value)
 }
 public static func powerState(_ value: String) -> String {
  String(value.split(separator: "·", maxSplits: 1).first ?? "").trimmingCharacters(in: .whitespaces)
 }
 public static func percent(_ value: Double?) -> String {
  let text = number(value)
  return text == "Н/Д" ? text : text + " %"
 }
 public static func utilization(_ used: Int64?, total: Int64?) -> String {
  guard let used, let total, used >= 0, total > 0, used <= total else { return "Н/Д" }
  return percent(Double(used) / Double(total) * 100)
 }
 public static func size(_ value: Int64?) -> String {
  number(value.map { Double($0) / 1_073_741_824 }) + " GiB"
 }
 public static func usedTotal(_ used: Int64?, total: Int64?) -> String {
  number(used.map { Double($0) / 1_073_741_824 }) + " из " + size(total)
 }
 public static func capacity(_ used: Int64?, total: Int64?) -> String {
  utilization(used, total: total) + " · " + usedTotal(used, total: total)
 }
 /// Percentage of an explicit drawing scale, never of unknown link capacity.
 public static func scalePercent(_ rate: Double?) -> String {
  percent(rate.map { $0 / (10 * 1_048_576) * 100 }) + " шкалы 10.0 MiB/с"
 }
}
