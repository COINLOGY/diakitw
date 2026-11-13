import Foundation
import CoreFoundation

public struct InternetLatency {
 public var samples: [Double] = []
 public var lossPercent: Double?
 public var mean: Double? { samples.isEmpty ? nil : samples.reduce(0, +) / Double(samples.count) }
 // Mean absolute difference of successive received RTTs (not standard deviation).
 public var jitter: Double? { samples.count < 2 ? nil : zip(samples, samples.dropFirst()).map { abs($0 - $1) }.reduce(0, +) / Double(samples.count - 1) }
 public init() {}
 public static func parse(_ text: String) -> Self {
  var result = Self()
  guard text.utf8.count <= 262144 else { return result }
  func captures(_ pattern: String, _ line: String) -> [String]? {
   guard let regex = try? NSRegularExpression(pattern: pattern), let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
   return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: line).map { String(line[$0]) } }
  }
  var seen = Set<Int>()
  for line in text.components(separatedBy: .newlines) {
   if let c = captures(#"^64 bytes from 1\.1\.1\.1: icmp_seq=(\d+) ttl=\d+ time=([0-9]+(?:\.[0-9]+)?) ms$"#, line), let seq = Int(c[0]), let rtt = Double(c[1]), rtt.isFinite, rtt <= 60000, seen.insert(seq).inserted, result.samples.count < 100 {
    result.samples.append(rtt)
   }
   if let c = captures(#"^(\d+) packets transmitted, (\d+) packets received,"#, line), let sent = Double(c[0]), let received = Double(c[1]), sent > 0, sent <= 100, received >= 0, received <= sent {
    result.lossPercent = 100 * (sent - received) / sent
   }
  }
  return result
 }
}

public struct InternetQuality {
 public var downloadMbps: Double?; public var uploadMbps: Double?; public var responsiveness: Double?
 public var endpoint: String?; public var interface: String?
 public init() {}
 public static func decode(_ data: Data) -> Self {
  var result = Self()
  guard data.count <= 262144, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return result }
  // networkQuality documents error fields only for incomplete tests.
  // Do not promote accompanying partial throughput into a successful result.
  guard object["error_code"] == nil, object["error_domain"] == nil else { return result }
  func number(_ key: String, maximum: Double) -> Double? {
   guard let n = object[key] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
   let v = n.doubleValue; return v.isFinite && v >= 0 && v <= maximum ? v : nil
  }
  func text(_ key: String) -> String? {
   guard let s = object[key] as? String, !s.isEmpty, s.count <= 253, s.range(of: "^[A-Za-z0-9._:-]+$", options: .regularExpression) != nil else { return nil }; return s
  }
  result.downloadMbps = number("dl_throughput", maximum: 1e15).map { $0 / 1_000_000 }
  result.uploadMbps = number("ul_throughput", maximum: 1e15).map { $0 / 1_000_000 }
  result.responsiveness = number("responsiveness", maximum: 1e9)
  result.endpoint = text("test_endpoint"); result.interface = text("interface_name")
  return result
 }
}
