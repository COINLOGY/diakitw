import SwiftUI
import MacdirCore

enum InstrumentTheme {
 static func adaptive(_ dark: NSColor, _ light: NSColor) -> Color {
  Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
 }
 static let lime = adaptive(NSColor(red: 0.65, green: 0.90, blue: 0.25, alpha: 1), NSColor(red: 0.25, green: 0.43, blue: 0.05, alpha: 1))
 static let cyan = adaptive(NSColor(red: 0.25, green: 0.75, blue: 1, alpha: 1), NSColor(red: 0.02, green: 0.38, blue: 0.55, alpha: 1))
 static let red = adaptive(NSColor(red: 1, green: 0.35, blue: 0.38, alpha: 1), NSColor(red: 0.72, green: 0.12, blue: 0.18, alpha: 1))
 static let panel = Color(nsColor: NSColor(name: nil) { appearance in
  appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
   ? NSColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1)
   : NSColor(red: 0.94, green: 0.96, blue: 0.97, alpha: 1)
 })
}

func gaugeColor(_ fraction: Double?, battery: Bool = false) -> Color {
 switch battery ? GaugeScale.batteryBand(fraction) : GaugeScale.band(fraction) {
 case .green: return InstrumentTheme.lime
 case .blue: return InstrumentTheme.cyan
 case .red: return InstrumentTheme.red
 case .unknown: return .secondary
 }
}

struct InstrumentNeedle: Shape {
 var fraction: Double
 var animatableData: Double {
  get { fraction }
  set { fraction = newValue }
 }
 func path(in rect: CGRect) -> Path {
  let points = GaugeGeometry(width: rect.width, height: rect.height).needlePoints(fraction: fraction)
  var path = Path()
  if let first = points.first {
   path.move(to: first)
   for point in points.dropFirst() { path.addLine(to: point) }
   path.closeSubpath()
  }
  return path
 }
}

struct NeedleGauge: View {
 let fraction: Double?
 var battery = false
 var neutral = false
 var upperLabel = "100%"
 var tickLabels: [String]? = nil
 var directionColor: Color = InstrumentTheme.lime
 private var labels: [String] {
  if let tickLabels { return tickLabels }
  if neutral { return ["0", "5", String(upperLabel.split(separator: " ").first ?? "10")] }
  return ["0%", "50%", "100%"]
 }
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 private func color(_ f: Double) -> Color {
  neutral ? directionColor : gaugeColor(f, battery: battery)
 }
 var body: some View {
  GeometryReader { geo in
   let geometry = GaugeGeometry(width: geo.size.width, height: geo.size.height)
   let radius = geometry.radius
   let center = geometry.center
   ZStack(alignment: .topLeading) {
    Canvas { context, _ in
     for i in 0..<40 {
      let f = Double(i) / 40
      var arc = Path()
      arc.addArc(center: center, radius: radius, startAngle: .degrees(GaugeScale.angle(fraction: f)), endAngle: .degrees(GaugeScale.angle(fraction: f + 0.021)), clockwise: false)
      context.stroke(arc, with: .color(color(f).opacity(fraction == nil ? 0.22 : 0.9)), style: StrokeStyle(lineWidth: 8 * 7 / 9, lineCap: .butt))
     }
     for i in 0...10 {
      let angle = GaugeScale.angle(fraction: Double(i) / 10) * .pi / 180
      let inner = radius - (i % 5 == 0 ? 13 : 9)
      var tick = Path()
      tick.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
      tick.addLine(to: CGPoint(x: center.x + cos(angle) * (radius - 5), y: center.y + sin(angle) * (radius - 5)))
      context.stroke(tick, with: .color(.primary.opacity(i % 5 == 0 ? 0.85 : 0.5)), lineWidth: i % 5 == 0 ? 1.5 : 1)
     }
    }
    if let fraction, fraction.isFinite, (0...1).contains(fraction) {
     InstrumentNeedle(fraction: fraction).fill(color(fraction))
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: fraction)
     Circle().fill(Color(red: 0.078, green: 0.102, blue: 0.129))
      .overlay(Circle().strokeBorder(color(fraction), lineWidth: 1.5))
      .frame(width: 8, height: 8).position(center)
    } else {
     Text("Н/Д").font(.caption).foregroundStyle(.secondary).position(x: center.x, y: center.y - 18)
    }
    ForEach(0..<3) { i in
     let box = geometry.labelBox(i)
     Text(labels[i]).font(.system(size: 10, weight: .semibold, design: .monospaced))
      .lineLimit(1).minimumScaleFactor(0.75)
      .frame(width: box.width, height: box.height)
      .position(x: box.midX, y: box.midY)
    }
   }.foregroundStyle(.primary.opacity(0.85))
  }.accessibilityHidden(true)
 }
}

struct GaugeTile: View {
 let symbol: String
 let title: String
 let value: String
 let detail: String
 let fraction: Double?
 var battery = false
 var neutral = false
 var upperLabel = "100%"
 var networkRate: Double?
 var amountOnly = false
 var explanation: String?
 var body: some View {
  let network = NetworkPresentation(networkRate)
  HStack(spacing: 4) {
   VStack(alignment: .leading, spacing: 5) {
    Label(title, systemImage: symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
    if neutral {
     NetworkRateValue(value: networkRate, size: 16)
      .foregroundStyle(network.available ? Color(red: 0.65, green: 0.90, blue: 0.25) : Color.secondary)
    } else {
     Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(gaugeColor(fraction, battery: battery)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
    }
    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(3).frame(height: 38, alignment: .topLeading)
   }.frame(maxWidth: .infinity, alignment: .leading)
   if amountOnly {
    Image(systemName: symbol).font(.system(size: 30, weight: .light)).foregroundStyle(.secondary).frame(width: 100, height: 88)
   } else {
    NeedleGauge(fraction: fraction, battery: battery, neutral: neutral, upperLabel: upperLabel).frame(width: 100, height: 88)
   }
  }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 88).padding(12)
   .background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 14))
   .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
   .accessibilityElement(children: .ignore)
   .accessibilityLabel(title)
   .accessibilityValue(value + ". " + detail + (fraction == nil ? ". Шкала недоступна" : ""))
   .help(explanation ?? detail)
 }
}
