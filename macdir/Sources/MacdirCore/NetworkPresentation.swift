import Foundation

/// One numeric contract for all RX/TX surfaces, independent of utilization fields.
public struct NetworkPresentation {
 public let number: String
 public let unit: String
 public let available: Bool
  private let rawValue: Double?
 public var displayNumber: String { available ? MetricPresentation.number(rawValue.map { $0 / (unit == "MiB" ? 1_048_576 : 1024) }) : "Н/Д" }
 public var text: String { displayNumber + " " + unit + "/с" }
 public var compact: String { (available ? number : "000.0") + (unit == "MiB" ? "M" : "K") }
 public init(_ value: Double?) {
  rawValue = value
  available = value.map { $0.isFinite && $0 >= 0 } ?? false
  let kib = available ? value! / 1024 : 0
  // Round before comparing: 999.95 KiB must not render a seventh digit.
  let useMiB = (kib * 10).rounded() >= 10_000
  unit = useMiB ? "MiB" : "KiB"
  let scaled = useMiB ? kib / 1024 : kib
  guard available else { number = "  Н/Д"; return }
  guard scaled < 999.95 else { number = "+++.+"; return }
  let result = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), scaled)
  number = result.count <= 5 ? String(repeating: "0", count: 5 - result.count) + result : "+++.+"
 }
}
