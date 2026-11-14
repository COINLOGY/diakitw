import Foundation

/// Fixed-width menu fields; persisted keys preserve existing disk preference.
public enum StatusPresentation {
 public enum DiskMode: String { case occupied, free }
 public enum RAMMode: String { case percent, used }
 public enum Metric: String, CaseIterable { case cpu, ram, swap, disk, rx, tx }
 public static func diskMode(defaults: UserDefaults = .standard) -> DiskMode {
  DiskMode(rawValue: defaults.string(forKey: "statusDiskMode") ?? "") ?? .occupied
 }
 public static func saveDiskMode(_ mode: DiskMode, defaults: UserDefaults = .standard) {
  defaults.set(mode.rawValue, forKey: "statusDiskMode")
 }
 public static func ramMode(defaults: UserDefaults = .standard) -> RAMMode {
  RAMMode(rawValue: defaults.string(forKey: "statusRAMMode") ?? "") ?? .percent
 }
 public static func saveRAMMode(_ mode: RAMMode, defaults: UserDefaults = .standard) {
  defaults.set(mode.rawValue, forKey: "statusRAMMode")
 }
 public static func visible(_ metric: Metric, defaults: UserDefaults = .standard) -> Bool {
  defaults.object(forKey: "statusShow." + metric.rawValue) as? Bool ?? true
 }
 public static func saveVisible(_ visible: Bool, metric: Metric, defaults: UserDefaults = .standard) {
  defaults.set(visible, forKey: "statusShow." + metric.rawValue)
 }
 public struct Segment {
  public let text: String
  public let band: GaugeScale.Band
 }
 private static func field(_ value: Double?, width: Int = 5, decimals: Int = 1) -> String {
  let valid = value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? 0
  let result = String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, valid)
  if result.count > width { return "+++.+" }
  return String(repeating: " ", count: width - result.count) + result
 }
 public static func rate(_ value: Double?) -> String {
  let compact = NetworkPresentation(value).compact
  // Replace padding only: retain the zero before the decimal, units and overflow.
  let padding = compact.prefix(2).prefix(while: { $0 == "0" }).count
  return String(repeating: " ", count: padding) + String(compact.dropFirst(padding))
 }
 public static func segments(_ s: ResourceSnapshot, interface: String, diskMode: DiskMode = .occupied, ramMode: RAMMode = .percent) -> [Segment] {
  func memory(_ value: Int64?) -> String { field(value.map { Double($0) / 1_073_741_824 }) + "G" }
  func validRate(_ value: Double?) -> Bool { value.map { $0.isFinite && $0 >= 0 } ?? false }
  let cpu = GaugeScale.fraction(s.cpu, maximum: 100)
  let ram = GaugeScale.fraction(s.memoryUsed.map(Double.init), maximum: Double(s.memoryTotal))
  let disk = GaugeScale.fraction(s.diskOccupied.map(Double.init), maximum: s.diskTotal.map(Double.init))
  let n = s.networks.first { $0.name == interface }
  return [
   Segment(text: field(cpu.map { $0 * 100 }) + "%", band: GaugeScale.band(cpu)),
   Segment(text: ramMode == .percent ? field(ram.map { $0 * 100 }) + "%" : memory(s.memoryUsed), band: GaugeScale.band(ram)),
   Segment(text: memory(s.swap), band: GaugeScale.band(GaugeScale.fraction(s.swap.map(Double.init), maximum: s.swapTotal.map(Double.init)))),
   Segment(text: diskMode == .free ? memory(s.diskFree) : field(disk.map { $0 * 100 }) + "%", band: GaugeScale.band(disk)),
   Segment(text: "↓" + rate(n?.received), band: validRate(n?.received) ? .green : .unknown),
   Segment(text: "↑" + rate(n?.sent), band: validRate(n?.sent) ? .blue : .unknown)
  ]
 }
}
