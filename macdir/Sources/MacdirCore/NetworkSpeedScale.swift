import Foundation

/// Shared bounded drawing scale for both selected-interface directions and chart.
public enum NetworkSpeedScale {
 public static func labels(maximum: Double) -> [String] {
  let unit = maximum >= 1_048_576 ? "MiB" : "KiB"
  let divisor = maximum >= 1_048_576 ? 1_048_576.0 : 1024.0
  return ["0", MetricPresentation.number(maximum / divisor / 2) + " " + unit,
          MetricPresentation.number(maximum / divisor) + " " + unit]
 }
}
