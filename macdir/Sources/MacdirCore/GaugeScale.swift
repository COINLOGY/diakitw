import Foundation
import CoreGraphics

/// Shared, unit-independent needle mapping. Missing telemetry stays missing.
/// Adaptive display range in measured Mbps, never advertised link capacity.
public enum InternetDialScale {
 public static func maximum(_ value: Double?) -> Double {
  guard let value, value.isFinite, value > 100 else { return 100 }
  let base = pow(10, floor(log10(value)))
  for multiplier in [1.0, 2.0, 5.0, 10.0] {
   let limit = base * multiplier
   if limit >= value && limit.isFinite { return limit }
  }
  return value
 }
}

/// Same capped dial size in Mac, server and internet cards. Labels occupy
/// reserved rectangles above/below the arc, never radial positions on its ink.
public struct GaugeGeometry {
 public let width: Double
 public let radius: Double
 public let center: CGPoint
 public init(width: Double, height: Double) {
  self.width = max(0, width)
  radius = max(0, min(60, width / 2 - 12, height - 44))
  center = CGPoint(x: width / 2, y: radius + 22)
 }
 /// Approved v4: wider triangle base; v2 tip and straight tail stay unchanged.
 /// Keep a three-point gap from the deepest tick (radius - 13).
 /// The existing 22-point lower gutter also contains the maximum tail (9.34 pt).
 public func needlePoints(fraction: Double?) -> [CGPoint] {
  guard let fraction, fraction.isFinite, (0...1).contains(fraction) else { return [] }
  let scale = max(0, radius - 16) / 99
  let angle = fraction * .pi
  return [(-99.0, 0.0), (0, -10), (21, -4), (21, 4), (0, 10)].map { x, y in
   CGPoint(x: center.x + (x * cos(angle) - y * sin(angle)) * scale,
           y: center.y + (x * sin(angle) + y * cos(angle)) * scale)
  }
 }
 public func labelBox(_ index: Int) -> CGRect {
  let span = min(width, 2 * radius + 24)
  let slot = span / 3
  return CGRect(x: (width - span) / 2 + Double(index) * slot, y: index == 1 ? 0 : center.y + 8,
                width: slot, height: 14)
 }
}

public enum GaugeScale {
 public static func batteryBand(_ fraction: Double?) -> Band {
  switch band(fraction) {
  case .green: return .red
  case .red: return .green
  case .blue: return .blue
  case .unknown: return .unknown
  }
 }
 public enum Band { case green, blue, red, unknown }
 public static func band(_ fraction: Double?) -> Band {
  guard let fraction, fraction.isFinite, fraction >= 0, fraction <= 1 else { return .unknown }
  return fraction <= 0.2 ? .green : fraction <= 0.8 ? .blue : .red
 }
 public static func angle(fraction: Double) -> Double { -180 + 180 * fraction }
 public static func fraction(_ value: Double?, maximum: Double?) -> Double? {
  guard let value, let maximum, value.isFinite, maximum.isFinite,
        value >= 0, maximum > 0 else { return nil }
  return min(1, value / maximum)
 }
}
