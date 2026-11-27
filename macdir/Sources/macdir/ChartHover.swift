import SwiftUI
import AppKit
import MacdirCore

/// Время замера в подсказке: часы, минуты и секунды местного времени.
private enum ChartClock {
 /// Один форматтер на всё приложение: подсказка перерисовывается на каждое
 /// движение мыши, создавать DateFormatter каждый кадр слишком дорого.
 static let formatter: DateFormatter = {
  let value = DateFormatter()
  value.locale = Locale(identifier: "ru_RU")
  value.timeZone = TimeZone.current
  value.dateFormat = "HH:mm:ss"
  return value
 }()
}

func chartTimeLabel(_ epoch: Double) -> String {
 guard epoch.isFinite, epoch > 0, epoch < 4_102_444_800 else { return "—" }
 return ChartClock.formatter.string(from: Date(timeIntervalSince1970: epoch))
}

/// Скорость в подсказке: те же единицы, что на оси графика.
func chartRateText(_ value: Double?) -> String {
 guard let value, value.isFinite, value >= 0 else { return "—" }
 let units = ["Б/с", "К/с", "М/с", "Г/с", "Т/с"]
 var size = value
 var index = 0
 while size >= 1024 && index < units.count - 1 { size /= 1024; index += 1 }
 return MetricPresentation.number(size) + " " + units[index]
}

/// Вертикальная линия под курсором: показывает, к какому моменту относится замер.
func drawChartCursor(_ context: GraphicsContext, size: CGSize, x: CGFloat, accent: Color) {
 var line = Path()
 line.move(to: CGPoint(x: x, y: 0))
 line.addLine(to: CGPoint(x: x, y: size.height))
 context.stroke(line, with: .color(accent.opacity(0.55)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
}

/// Точка на самом замере — чтобы видеть, из какой точки взято значение.
func drawChartDot(_ context: GraphicsContext, x: CGFloat, y: CGFloat, accent: Color) {
 context.fill(Path(ellipseIn: CGRect(x: x - 3.2, y: y - 3.2, width: 6.4, height: 6.4)), with: .color(.black.opacity(0.55)))
 context.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)), with: .color(accent))
}

/// Карточка с временем и значением: ставится у курсора и не вылезает за края.
func drawChartTip(_ context: GraphicsContext, size: CGSize, at x: CGFloat, lines: [String], accent: Color) {
 guard !lines.isEmpty, size.width > 20 else { return }
 let texts = lines.map { line in
  context.resolve(Text(line)
   .font(.system(size: 10, weight: .semibold, design: .monospaced))
   .foregroundStyle(Color.primary))
 }
 let measured = texts.map { $0.measure(in: CGSize(width: 260, height: 40)) }
 let width = min(size.width - 4, (measured.map { $0.width }.max() ?? 0) + 14)
 let height = measured.reduce(0) { $0 + $1.height } + 8
 var originX = x - width / 2
 originX = min(max(2, originX), max(2, size.width - width - 2))
 let box = CGRect(x: originX, y: 4, width: width, height: height)
 let shape = Path(roundedRect: box, cornerRadius: 5)
 context.fill(shape, with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.95)))
 context.stroke(shape, with: .color(accent.opacity(0.7)), lineWidth: 0.8)
 var cursorY = box.minY + 4
 for (text, measuredSize) in zip(texts, measured) {
  context.draw(text, at: CGPoint(x: box.minX + 7, y: cursorY), anchor: .topLeading)
  cursorY += measuredSize.height
 }
}

/// Прозрачный слой, который сообщает X курсора, но не перехватывает клики:
/// строки парка — это кнопки, и нажатие обязано доходить до них.
struct ChartHoverArea: NSViewRepresentable {
 let onMove: (CGFloat?) -> Void

 init(onMove: @escaping (CGFloat?) -> Void) { self.onMove = onMove }

 func makeNSView(context: Context) -> NSView {
  let view = TrackingView()
  view.onMove = onMove
  return view
 }

 func updateNSView(_ nsView: NSView, context: Context) {
  (nsView as? TrackingView)?.onMove = onMove
 }

 final class TrackingView: NSView {
  var onMove: ((CGFloat?) -> Void)?

  override var isOpaque: Bool { false }

  /// nil — событие не наше: клик по графику в карточке открывает сервер.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func updateTrackingAreas() {
   super.updateTrackingAreas()
   for area in trackingAreas { removeTrackingArea(area) }
   addTrackingArea(NSTrackingArea(rect: .zero,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil))
  }

  override func mouseMoved(with event: NSEvent) {
   onMove?(convert(event.locationInWindow, from: nil).x)
  }

  override func mouseEntered(with event: NSEvent) {
   onMove?(convert(event.locationInWindow, from: nil).x)
  }

  override func mouseExited(with event: NSEvent) { onMove?(nil) }
 }
}

extension View {
 /// Запоминает X курсора над графиком; nil — курсор вне графика.
 func chartHoverTracking(_ x: Binding<CGFloat?>) -> some View {
  overlay(ChartHoverArea { value in
   if x.wrappedValue != value { x.wrappedValue = value }
  })
 }
}
