import Foundation

/// Pure proportional scale; the containing SwiftUI view receives the inverse proposal.
public enum WindowZoom {
 public static let minimum = 0.55
 public static let maximum = 1.5
 public static func fit(width: Double, height: Double, minimumWidth: Double, minimumHeight: Double) -> Double {
  guard width.isFinite, height.isFinite, minimumWidth > 0, minimumHeight > 0 else { return minimum }
  return max(minimum, min(maximum, width / minimumWidth, height / minimumHeight))
 }
 public static func step(_ value: Double, direction: Int) -> Double {
  max(minimum, min(maximum, (value * 10 + Double(direction)).rounded() / 10))
 }
}
