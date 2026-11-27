import SwiftUI
import MacdirCore

/// Shares the model's samples; rendering never starts monitoring or a clock.
struct TrafficChart: View {
 let history: TrafficHistory
 @Binding var range: TrafficRange
 var expanded = false
 @State private var hoverX: CGFloat?
 private let receiveColor = Color(red: 0.65, green: 0.90, blue: 0.25)
 private let sendColor = Color(red: 0.30, green: 0.75, blue: 1.0)
 private var scaleLabel: String {
  var value = history.scale(in: range)
  let units = ["Б/с", "KiB/с", "MiB/с", "GiB/с", "TiB/с"]
  var index = 0
  while value >= 1024 && index < units.count - 1 { value /= 1024; index += 1 }
  return "0–" + MetricPresentation.number(value) + " " + units[index]
 }
 var body: some View {
  VStack(spacing: 3) {
   HStack(spacing: 8) {
    if expanded { Text("Сетевая активность").fontWeight(.semibold).lineLimit(1) }
    Text(scaleLabel).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
    Spacer(minLength: 0)
    Picker("Период графика", selection: $range) {
     ForEach(TrafficRange.allCases, id: \.self) { Text($0.label).tag($0) }
    }.labelsHidden().pickerStyle(.menu).controlSize(.mini).fixedSize()
   }.font(.system(size: 10)).foregroundStyle(.secondary)
   Canvas { context, size in
    let top = history.scale(in: range)
    let end = history.samples.last?.time ?? 0
    let width = max(0, size.width - 4)
    let height = max(0, size.height - 4)
    let baseline = size.height - 2
    for fraction in [0.0, 0.5, 1.0] {
     var grid = Path()
     let y = baseline - height * fraction
     grid.move(to: CGPoint(x: 2, y: y)); grid.addLine(to: CGPoint(x: size.width - 2, y: y))
     context.stroke(grid, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
    }
    // Separate subpaths and fills ensure missing observations never bridge a gap.
    for received in [true, false] {
     let color = received ? receiveColor : sendColor
     for segment in history.segments(in: range, received: received) {
      let points = segment.map { sample in
       CGPoint(x: 2 + (sample.time - (end - range.seconds)) / range.seconds * width,
               y: baseline - ((received ? sample.received : sample.sent)! / top) * height)
      }
      guard let first = points.first, let last = points.last else { continue }
      var line = Path(); line.move(to: first)
      for point in points.dropFirst() { line.addLine(to: point) }
      if points.count > 1 {
       var area = line
       area.addLine(to: CGPoint(x: last.x, y: baseline))
       area.addLine(to: CGPoint(x: first.x, y: baseline)); area.closeSubpath()
       context.fill(area, with: .color(received ? color.opacity(0.18) : color.opacity(0.12)))
       context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
      } else {
       context.fill(Path(ellipseIn: CGRect(x: first.x - 1.5, y: first.y - 1.5, width: 3, height: 3)), with: .color(color))
      }
     }
    }
   // Курсор: время замера и обе скорости в этой точке.
   if let hoverX, size.width > 4 {
    let end = history.samples.last?.time ?? 0
    let plot = max(1, size.width - 4)
    let span = max(1e-9, range.seconds)
    let moment = (end - span) + Double((hoverX - 2) / plot) * span
    let visible = history.samples.filter { $0.time >= end - span }
    if let nearest = visible.min(by: { abs($0.time - moment) < abs($1.time - moment) }) {
     let x = 2 + plot * CGFloat((nearest.time - (end - span)) / span)
     drawChartCursor(context, size: size, x: x, accent: .white.opacity(0.6))
     let top = max(1, history.scale(in: range))
     if let received = nearest.received {
      drawChartDot(context, x: x, y: baseline - CGFloat(min(1, received / top)) * height, accent: receiveColor)
     }
     if let sent = nearest.sent {
      drawChartDot(context, x: x, y: baseline - CGFloat(min(1, sent / top)) * height, accent: sendColor)
     }
     drawChartTip(context, size: size, at: x,
                  lines: [chartTimeLabel(nearest.time),
                          "↓ " + chartRateText(nearest.received) + "   ↑ " + chartRateText(nearest.sent)],
                  accent: receiveColor)
    }
   }
   }.chartHoverTracking($hoverX)
   .frame(height: expanded ? nil : 46).frame(maxHeight: expanded ? .infinity : nil)
   // A dark plotting surface keeps the requested lime/cyan readable in both themes.
   .background(Color(red: 0.08, green: 0.10, blue: 0.13), in: RoundedRectangle(cornerRadius: 4))
   .clipShape(RoundedRectangle(cornerRadius: 4))
   .overlay {
    if history.visible(in: range).allSatisfy({ $0.received == nil && $0.sent == nil }) {
     Text("Нет данных").font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
    }
   }
   HStack {
    Text(range.tickLabels[0]); Spacer(minLength: 0)
    Text(range.tickLabels[1]); Spacer(minLength: 0)
    Text(range.tickLabels[2])
   }.font(.system(size: 9)).foregroundStyle(.secondary)
  }.frame(height: expanded ? nil : 84)
   .accessibilityElement(children: .contain)
   .accessibilityLabel("Трафик \(history.interface ?? ""): приём — зелёный, отправка — голубой; \(scaleLabel)")
   .help("Приём ↓ — зелёный, отправка ↑ — голубой. Общая автошкала скорости, не загрузка канала. Время относительно последнего замера. Пропуски и паузы более 3 с — разрывы. История до 1 ч с момента выбора интерфейса; смена интерфейса очищает историю.")
 }
}
