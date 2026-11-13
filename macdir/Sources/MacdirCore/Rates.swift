import Foundation
public enum Rates {
 public static func perSecond(old: UInt64, new: UInt64, seconds: Double) -> Double? {
  guard seconds.isFinite, seconds > 0, new >= old else { return nil }
  let value = Double(new - old) / seconds
  return value.isFinite ? value : nil
 }
 public static func cpu(old: [UInt64], new: [UInt64]) -> Double? {
  guard old.count == 4, new.count == 4, zip(old, new).allSatisfy({ $1 >= $0 }) else { return nil }
  let delta = zip(old, new).map { $1 - $0 }; let total = delta.reduce(0, +)
  guard total > 0 else { return nil }; return Double(total - delta[2]) / Double(total) * 100
 }
}
