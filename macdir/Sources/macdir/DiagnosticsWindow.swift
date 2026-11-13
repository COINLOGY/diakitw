import SwiftUI
import AppKit
import Metal
import UniformTypeIdentifiers
import Darwin
import MacdirCore

@MainActor final class DiagnosticsModel: ObservableObject {
 @Published var seconds = 5
 @Published var duty = 10
 @Published var mebibytes = 16
 @Published var preset = "quick"
 @Published var includeCPU = true
 @Published var includeRAM = true
 @Published var includeGPU = true
 @Published var appleCode = ""
 @Published private(set) var running = false
 @Published private(set) var status = "Готово · открытие окна не запускает нагрузку"
 @Published private(set) var result = ""
 @Published private(set) var history: [DiagnosticSessionReport] = []
 @Published private(set) var began: Double?
 @Published private(set) var ended: Double?
 @Published private(set) var waitBudget = 0.0
 @Published private(set) var exportStatus = ""
 let hasMetal = MTLCreateSystemDefaultDevice() != nil
 private var token: InternetCancellation?
 private var confirming = false
 var plan: DiagnosticPlan {
  preset == "custom" ? DiagnosticPlan(presetID: preset, modes: (includeCPU ? ["cpu"] : []) + (includeRAM ? ["ram"] : []) + (includeGPU ? ["gpu"] : []), limits: DiagnosticLimits(seconds: seconds, duty: duty, mebibytes: mebibytes)) : .preset(preset)
 }
 func cancel() { token?.cancel(); if running { status = "Остановка всей последовательности…" } }
 func request(_ mode: String) {
  confirm(DiagnosticPlan(presetID: "single", modes: [mode], limits: DiagnosticLimits(seconds: seconds, duty: duty, mebibytes: mebibytes)))
 }
 func requestSuite() { confirm(plan) }
 private func confirm(_ plan: DiagnosticPlan) {
  guard !running, !confirming, !plan.stages.isEmpty else { return }
  confirming = true; defer { confirming = false }
  let alert = NSAlert(); alert.messageText = "Запустить последовательность?"
  let stages = plan.stages.map { "\($0.mode.uppercased()): \($0.limits.seconds) с / duty \($0.limits.duty)% / RAM ≤ \($0.limits.mebibytes) МиБ" }.joined(separator: "\n")
  alert.informativeText = stages + "\n\nСуммарный бюджет нагрузки: \(plan.workSeconds) с. Плановый предел ожидания: \(plan.waitBudget) с, включая +1 с внешнего watchdog и 0,5 с завершения на этап; задержки ОС/драйвера не гарантируются.\n\nВозможны нагрев, шум, расход батареи и замедление. Сохраните работу. Duty — не измеренная загрузка. RAM ≤1/8 свободных страниц. Один worker, только последовательное выполнение. Ошибка, недоступность, thermal serious/critical, тайм-аут или Stop отменяют оставшиеся этапы. Закрытие/выход останавливает всю последовательность. Уже отправленную GPU-команду нельзя отозвать. Не сертификат исправности; RAM — буфер, не MemTest; GPU — compute, не FurMark."
  alert.addButton(withTitle: "Отмена"); alert.addButton(withTitle: "Запустить")
  guard alert.runModal() == .alertSecondButtonReturn else { return }
  start(plan)
 }
 private static func hardwareModel() -> String {
  var n = 0
  guard sysctlbyname("hw.model", nil, &n, nil, 0) == 0, n > 0, n < 256 else { return "Н/Д" }
  var bytes = [CChar](repeating: 0, count: n)
  guard sysctlbyname("hw.model", &bytes, &n, nil, 0) == 0 else { return "Н/Д" }
  return String(cString: bytes)
 }
 private func start(_ plan: DiagnosticPlan) {
  guard !running else { return }
  let cancellation = InternetCancellation(); token = cancellation
  let start = ProcessInfo.processInfo.systemUptime
  running = true; began = start; ended = nil; waitBudget = plan.waitBudget
  #if arch(arm64)
  let architecture = "arm64"
  #else
  let architecture = "x86_64"
  #endif
  var session = DiagnosticSessionReport(plan: plan, model: Self.hardwareModel(), os: ProcessInfo.processInfo.operatingSystemVersionString, architecture: architecture, appleCode: appleCode)
  history.append(session)
  let sessionID = session.id
  let helper = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("DiagnosticWorker")
  let parent = String(getpid())
  Task { [weak self] in
   var sequence = DiagnosticSequence(plan: plan, now: start)
   while true {
    let thermal = ProcessInfo.processInfo.thermalState
    guard let stage = sequence.next(now: ProcessInfo.processInfo.systemUptime, cancelled: cancellation.isCancelled, thermal: thermal == .serious || thermal == .critical) else { break }
    guard let self, self.token === cancellation else { cancellation.cancel(); return }
    self.status = "Этап \(session.runs.count + 1)/\(plan.stages.count): \(stage.mode.uppercased()) · подготовка/работа"
    let t = ProcessInfo.processInfo.systemUptime
    let remaining = sequence.deadline - t
    let report: DiagnosticRunReport
    if let helper, FileManager.default.isExecutableFile(atPath: helper.path), remaining > 0 {
     let limits = stage.limits
     let output = await Task.detached(priority: .utility) {
      InternetProcess.run(executable: helper.path, arguments: [stage.mode, String(limits.seconds), String(limits.duty), String(limits.mebibytes), parent], timeout: min(Double(limits.seconds) + 1, remaining), cancellation: cancellation)
     }.value
     guard self.token === cancellation else { return }
     report = DiagnosticRunReport(stage: stage, reason: output.reason, exitCode: output.status, data: output.stdout, elapsed: ProcessInfo.processInfo.systemUptime - t)
    } else {
     report = DiagnosticRunReport(stage: stage, reason: .launchFailed, exitCode: -1, data: Data(), elapsed: 0)
    }
    session.runs.append(report)
    sequence.complete(id: stage.id, succeeded: report.outcome == DiagnosticStatus.completed.rawValue)
    if let index = self.history.firstIndex(where: { $0.id == sessionID }) { self.history[index] = session }
    self.result = session.text
    await Task.yield()
   }
   guard let self, self.token === cancellation else { return }
   for stage in plan.stages where !session.runs.contains(where: { $0.id == stage.id }) {
    session.runs.append(DiagnosticRunReport(stage: stage, skipped: sequence.stopReason ?? "not_started"))
   }
   if let index = self.history.firstIndex(where: { $0.id == sessionID }) { self.history[index] = session }
   self.result = session.text; self.status = sequence.stopReason ?? "Последовательность завершена · не сертификат исправности"
   self.running = false; self.ended = ProcessInfo.processInfo.systemUptime; self.token = nil
  }
 }
 func export(_ report: DiagnosticSessionReport, json: Bool) {
  let panel = NSSavePanel(); panel.allowedContentTypes = [json ? .json : .plainText]
  panel.nameFieldStringValue = "diakitw-diagnostics-\(report.id)." + (json ? "json" : "txt")
  panel.title = "Сохранить протокол локально (без отправки)"
  guard panel.runModal() == .OK, let url = panel.url else { return }
  do {
   let data = try json ? report.json() : Data(report.text.utf8)
   try data.write(to: url, options: .atomic)
   guard try Data(contentsOf: url) == data else { throw CocoaError(.fileWriteUnknown) }
   exportStatus = "Протокол сохранён"
  } catch { exportStatus = "Не удалось сохранить протокол; результаты тестов не изменены" }
 }
 deinit { token?.cancel() }
}
@MainActor final class DiagnosticsWindow: NSObject, NSWindowDelegate {
 static let shared = DiagnosticsWindow()
 private var window: NSWindow?
 let model = DiagnosticsModel()
 func show() {
  if window == nil {
   let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
   w.title = "diakitw — Диагностика"; w.isReleasedWhenClosed = false; w.minSize = NSSize(width: 620, height: 520)
   w.contentView = NSHostingView(rootView: DiagnosticsView(model: model)); w.delegate = self; w.center(); window = w
  }
  window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
 }
 func windowWillClose(_ notification: Notification) { model.cancel() }
 func stop() { model.cancel() }
}
struct DiagnosticsView: View {
 @ObservedObject var model: DiagnosticsModel
 var body: some View {
  ScrollView {
   VStack(alignment: .leading, spacing: 18) {
    Label("Ограниченная диагностика после ремонта", systemImage: "stethoscope").font(.title.bold())
    Text("Открытие окна и выбор preset не запускают нагрузку. История хранится в памяти до выхода; сохраните нужные протоколы.").foregroundStyle(.secondary)
    Picker("Последовательность", selection: $model.preset) {
     Text("Быстрая после ремонта").tag("quick")
     Text("Память / замена платы").tag("memory")
     Text("Графика").tag("graphics")
     Text("Настроить").tag("custom")
    }.disabled(model.running)
    if model.preset == "custom" {
     HStack { Toggle("CPU", isOn: $model.includeCPU); Toggle("RAM", isOn: $model.includeRAM); Toggle("GPU", isOn: $model.includeGPU) }.disabled(model.running)
    }
    Text(model.plan.stages.map { "\($0.mode.uppercased()) \($0.limits.seconds) с / \($0.limits.duty)% / ≤\($0.limits.mebibytes) МиБ" }.joined(separator: " → ")).font(.callout)
    Button("Запустить последовательность…") { model.requestSuite() }.disabled(model.running || model.plan.stages.isEmpty)
    Text("Ручной отдельный тест / настройки custom:").font(.caption)
    HStack {
     Picker("Время", selection: $model.seconds) { ForEach([1, 5, 10, 30], id: \.self) { Text("\($0) с").tag($0) } }
     Picker("Duty", selection: $model.duty) { ForEach([1, 10, 25], id: \.self) { Text("\($0)%").tag($0) } }
     Picker("RAM ≤", selection: $model.mebibytes) { ForEach([1, 16, 32, 64], id: \.self) { Text("\($0) МиБ").tag($0) } }
    }.disabled(model.running)
    HStack(spacing: 12) {
     DiagnosticButton(kind: .cpu) { model.request("cpu") }.disabled(model.running)
     DiagnosticButton(kind: .ram) { model.request("ram") }.disabled(model.running)
     DiagnosticButton(kind: .gpu) { model.request("gpu") }.disabled(model.running || !model.hasMetal)
     Spacer()
     Button("Остановить всё") { model.cancel() }.disabled(!model.running)
    }.buttonStyle(.bordered)
    if !model.hasMetal { Text("GPU недоступен: нет устройства Metal").foregroundStyle(.secondary) }
    if model.running { ProgressView().controlSize(.small) }
    Text(model.status).font(.headline)
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
     if let start = model.began {
      let elapsed = max(0, (model.ended ?? ProcessInfo.processInfo.systemUptime) - start)
      Text("Истекло: \(elapsed, specifier: "%.1f") с · до планового предела: \(max(0, model.waitBudget - elapsed), specifier: "%.1f") с. Это время, не % проверенного оборудования.").monospacedDigit()
     }
    }
    Text(model.result).font(.system(.body, design: .monospaced)).textSelection(.enabled)
    Divider()
    Text("История протоколов (TXT / JSON)").font(.headline)
    ForEach(model.history.reversed()) { report in
     DisclosureGroup("\(report.createdAt.formatted()) · \(report.plan.presetID)") {
      HStack {
       Button("Сохранить TXT…") { model.export(report, json: false) }.disabled(model.running)
       Button("Сохранить JSON…") { model.export(report, json: true) }.disabled(model.running)
      }
      Text(report.text).font(.caption.monospaced()).textSelection(.enabled)
     }
    }
    Text(model.exportStatus).font(.caption)
    Divider()
    Text("Apple Diagnostics — отдельно при загрузке").font(.headline)
    Text("Сохраните работу, подключите питание, обеспечьте вентиляцию, отключите лишнюю периферию. Apple Silicon: выключить, удерживать Power до Options, затем Command-D. Intel: D при старте, при необходимости Option-D. Приложение не перезагружает Mac и не запускает Apple Diagnostics.")
    Link("Инструкция Apple", destination: URL(string: "https://support.apple.com/en-us/102550")!)
    TextField("Reference code для следующего протокола (user_reported)", text: $model.appleCode).disabled(model.running)
    Text("Не вводите персональные данные. Код — ручное сообщение пользователя, не результат diakitw. RAM — только буфер процесса, не MemTest/ECC; CPU — один поток; GPU — короткий compute, не FurMark. Лимиты не увеличены: 1–30 с / 1–25% / 1–64 МиБ и ≤1/8 свободных страниц. Thermal serious/critical и parent-death watchdog сохранены. Диск не тестируется; запись только при выбранном экспорте.").font(.caption).foregroundStyle(.secondary)
   }.padding(24)
  }
 }
}
