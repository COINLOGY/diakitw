import SwiftUI
import AppKit
import MacdirCore

@MainActor final class InternetTestModel: ObservableObject {
 @Published private(set) var running = false
 @Published private(set) var status = "Готов к тесту — запуск только по кнопке"
 @Published private(set) var quality = InternetQuality()
 @Published private(set) var latency = InternetLatency()
 @Published private(set) var started: Date?
 @Published private(set) var finished: Date?
 @Published private(set) var phase = 0
 private var token: InternetCancellation?
 private var task: Task<Void, Never>?
 func cancel() { token?.cancel(); if running { status = "Остановка…" } }
 func start() {
  guard !running else { return }
  let cancellation = InternetCancellation(); token = cancellation
  running = true; started = Date(); finished = nil; quality = InternetQuality(); latency = InternetLatency(); phase = 1
  status = "1/2 · ICMP до 1.1.1.1 · до 10 с"
  task = Task { [weak self] in
   let ping = await Task.detached(priority: .utility) {
    InternetProcess.run(executable: "/sbin/ping", arguments: ["-n", "-c", "8", "-W", "1000", "-t", "10", "1.1.1.1"], timeout: 12, cancellation: cancellation, progress: { data in
     let parsed = InternetLatency.parse(String(decoding: data, as: UTF8.self))
     Task { @MainActor [weak self] in
      guard let self, self.token === cancellation, self.running, self.phase == 1 else { return }
      self.latency = parsed
     }
    })
   }.value
   guard let self, self.token === cancellation else { return }
   self.latency = InternetLatency.parse(String(decoding: ping.stdout, as: UTF8.self))
   if cancellation.isCancelled { self.complete("Отменено · частичные измерения"); return }
   self.phase = 2; self.status = "2/2 · Скачивание + отдача · networkQuality · до 25 с"
   let speed = await Task.detached(priority: .utility) {
    InternetProcess.run(executable: "/usr/bin/networkQuality", arguments: ["-c", "-M", "20"], timeout: 25, cancellation: cancellation)
   }.value
   guard self.token === cancellation else { return }
   self.quality = InternetQuality.decode(speed.stdout)
   if cancellation.isCancelled { self.complete("Отменено · частичные измерения"); return }
   let complete = speed.reason == .finished && speed.status == 0 && self.quality.downloadMbps != nil && self.quality.uploadMbps != nil && ping.reason == .finished && ping.status == 0 && self.latency.mean != nil && self.latency.lossPercent != nil
   let message = complete ? "Тест завершён" : "Частичный результат / недоступно"
   self.complete(message + " · скорость: " + Self.description(speed) + " · ICMP: " + Self.description(ping))
  }
 }
 private func complete(_ message: String) { status = message; running = false; finished = Date(); phase = 0; task = nil }
 private static func description(_ output: InternetProcess.Output) -> String {
  switch output.reason {
  case .finished: return output.status == 0 ? "готово" : "ошибка \(output.status)"
  case .cancelled: return "отмена"
  case .timeout: return "тайм-аут"
  case .outputLimit: return "превышен лимит вывода"
  case .launchFailed: return "не удалось запустить"
  }
 }
 deinit { token?.cancel() }
}

@MainActor final class InternetTestWindow: NSObject, NSWindowDelegate {
 static let shared = InternetTestWindow()
 private var window: NSWindow?
 let model = InternetTestModel()
 func show() {
  if window == nil {
   let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
   w.title = "diakitw — Тест интернета"; w.isReleasedWhenClosed = false; w.minSize = NSSize(width: 700, height: 600)
   w.contentView = NSHostingView(rootView: InternetTestView(model: model)); w.delegate = self; w.center(); window = w
  }
  window?.deminiaturize(nil); window?.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
 }
 func windowWillClose(_ notification: Notification) { model.cancel() }
 func stop() { model.cancel() }
}

struct InternetSpeedGauge: View {
 let title: String
 let value: Double?
 let color: Color
 var body: some View {
  let maximum = InternetDialScale.maximum(value)
  let valid = value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
  VStack(alignment: .leading, spacing: 8) {
   Text(title).font(.headline)
   NeedleGauge(fraction: GaugeScale.fraction(valid, maximum: maximum), neutral: true,
    tickLabels: (0...2).map { String(format: "%.0f", maximum * Double($0) / 2) }, directionColor: color).frame(height: 120)
   Text(valid.map { String(format: "%.2f Mbps", $0) } ?? "Н/Д")
    .font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(valid == nil ? .secondary : color)
   Text("Шкала отображения · 0–\(String(format: "%.0f", maximum)) Mbps").font(.caption).foregroundStyle(.secondary)
  }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
   .background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 12))
   .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
 }
}

struct InternetTestView: View {
 @ObservedObject var model: InternetTestModel
 private func number(_ value: Double?, _ unit: String) -> String { value.map { String(format: "%.2f %@", $0, unit) } ?? "Н/Д" }
 private func metric(_ title: String, _ value: Double?, _ unit: String, color: Color = .primary) -> some View {
  VStack(alignment: .leading, spacing: 8) {
   Text(title).font(.caption).foregroundStyle(.secondary)
   Text(number(value, unit)).font(.system(size: 27, weight: .semibold, design: .monospaced)).foregroundStyle(value == nil ? .secondary : color).lineLimit(1).minimumScaleFactor(0.6)
  }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
 }
 var body: some View {
  ScrollView {
   VStack(alignment: .leading, spacing: 16) {
    Label("Тест интернета", systemImage: "speedometer").font(.title.bold())
    Text("Начать тест: значительный трафик (возможны гигабайты), кратковременная загрузка соединения. Используется текущий маршрут macOS, включая VPN; выбор интерфейса на главном экране тест не ограничивает.")
     .font(.callout).foregroundStyle(.secondary)
    HStack { InternetSpeedGauge(title: "↓ Скачивание", value: model.quality.downloadMbps, color: InstrumentTheme.lime); InternetSpeedGauge(title: "↑ Отдача", value: model.quality.uploadMbps, color: InstrumentTheme.cyan) }
    HStack { metric("Ping · средний RTT", model.latency.mean, "мс"); metric("Джиттер", model.latency.jitter, "мс"); metric("Потери ICMP", model.latency.lossPercent, "%") }
    HStack {
     Button("Начать тест") { model.start() }.buttonStyle(.borderedProminent).disabled(model.running)
     Button("Отмена") { model.cancel() }.disabled(!model.running)
     if model.running { ProgressView().controlSize(.small) }
     Spacer()
     TimelineView(.periodic(from: .now, by: 1)) { context in
      if let start = model.started {
       Text("\(Int(max(0, (model.finished ?? context.date).timeIntervalSince(start)))) с").monospacedDigit()
      }
     }
    }
    Text(model.status).font(.callout).textSelection(.enabled)
    Divider()
    VStack(alignment: .leading, spacing: 7) {
     Text("Сервер скорости: \(model.quality.endpoint ?? "Н/Д — выбирается networkQuality")")
     Text("Интерфейс networkQuality: \(model.quality.interface ?? "Н/Д") · отзывчивость под нагрузкой: \(number(model.quality.responsiveness, "RPM")) (не ICMP ping)")
     Text("ICMP: 1.1.1.1 (Cloudflare), отдельный узел, не сервер скорости. 8 запросов до нагрузочного теста; получено RTT: \(model.latency.samples.count). Блокировка ICMP не доказывает потерю HTTPS-трафика.")
     Text("Ping = средний RTT ответов; джиттер = среднее |RTTᵢ − RTTᵢ₋₁| по последовательным полученным ответам, не stddev. Потери — только по итоговым счётчикам ping; без них Н/Д.")
     Text("Скорость: networkQuality -c -M 20, параллельная загрузка/отдача; бит/с ÷ 1 000 000 = Mbps. Короткий тест — оценка текущего маршрута, не гарантия тарифа. Н/Д означает: ещё не измерено, ошибка или недостаточно данных.")
     Text("Тестовые файлы diakitw не создаёт: сетевой тест выполняет macOS, вывод ограничен в памяти. Лимит времени, не точная квота байтов. Внутренние кэши/журналы macOS не контролируются и не удаляются.")
     if let start = model.started { Text("Начало: \(start.formatted(date: .abbreviated, time: .standard))") }
     if let end = model.finished { Text("Окончание: \(end.formatted(date: .abbreviated, time: .standard))") }
    }.font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
   }.padding(24).controlSize(.large).tint(.cyan)
  }
 }
}
