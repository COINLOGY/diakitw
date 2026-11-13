import SwiftUI
import MacdirCore

/// Fixed number and unit slots keep both directions stationary across updates.
struct NetworkRateValue: View {
 let value: Double?
 var direction = ""
 var size: CGFloat = 24
 var body: some View {
  let formatted = NetworkPresentation(value)
  HStack(alignment: .firstTextBaseline, spacing: 4) {
   if !direction.isEmpty { Text(direction).frame(width: size * 0.65) }
   Text(formatted.displayNumber).monospacedDigit().frame(width: size * 3.8, alignment: .trailing)
   Text(formatted.unit + "/с").font(.system(size: size * 0.55, design: .monospaced)).frame(width: size * 1.9, alignment: .leading)
  }.font(.system(size: size, weight: .semibold, design: .monospaced)).fixedSize()
 }
}
