import Foundation

public enum TrafficRange: Int, CaseIterable, Sendable {
 case minute = 60, fiveMinutes = 300, fifteenMinutes = 900, hour = 3600
 public var seconds: Double { Double(rawValue) }
 public var label: String {
  switch self { case .minute: return "1 мин"; case .fiveMinutes: return "5 мин"; case .fifteenMinutes: return "15 мин"; case .hour: return "1 ч" }
 }
 public var tickLabels: [String] {
  let middle = self == .minute ? "−30 с" : String(format: "−%g мин", seconds / 120)
  return ["−\(rawValue / 60) мин", middle, "сейчас"]
 }
}

public struct TrafficSample: Sendable {
 public let time: Double
 public let received: Double?
 public let sent: Double?
}

/// Selected-interface history only; values are bytes per actual elapsed second.
public struct TrafficHistory: Sendable {
 public private(set) var samples: [TrafficSample] = []
 public private(set) var interface: String?
 public init() {}
 public func visible(in range: TrafficRange) -> [TrafficSample] {
  guard let end = samples.last?.time else { return [] }
  return samples.filter { $0.time >= end - range.seconds }
 }
 /// Common RX/TX scale, binary powers, 1 KiB/s floor. No clipping at high rates.
 public func scale(in range: TrafficRange) -> Double {
  let peak = visible(in: range).flatMap { [$0.received, $0.sent].compactMap { $0 } }.max() ?? 0
  let rounded = pow(2, ceil(log2(max(1024, peak))))
  return rounded.isFinite ? rounded : Double.greatestFiniteMagnitude
 }
 /// Nil and observations delayed more than 3 seconds break each direction independently.
 public func segments(in range: TrafficRange, received: Bool) -> [[TrafficSample]] {
  var result: [[TrafficSample]] = []; var segment: [TrafficSample] = []
  for sample in visible(in: range) {
   if (received ? sample.received : sample.sent) == nil {
    if !segment.isEmpty { result.append(segment); segment = [] }
    continue
   }
   if let previous = segment.last, sample.time - previous.time > 3 {
    result.append(segment); segment = []
   }
   segment.append(sample)
  }
  if !segment.isEmpty { result.append(segment) }
  return result
 }
 public mutating func select(_ name: String) {
  guard interface != name else { return }
  interface = name; samples.removeAll(keepingCapacity: true)
 }
 public mutating func append(interface: String, time: Double, received: Double?, sent: Double?) {
  guard time.isFinite, time >= 0 else { return }
  select(interface)
  guard samples.last.map({ time > $0.time }) ?? true else { return }
  func valid(_ value: Double?) -> Double? {
   guard let value, value.isFinite, value >= 0 else { return nil }; return value
  }
  samples.removeAll { $0.time < time - 3600 }
  samples.append(TrafficSample(time: time, received: valid(received), sent: valid(sent)))
  if samples.count > 3601 { samples.removeFirst(samples.count - 3601) }
 }
}
