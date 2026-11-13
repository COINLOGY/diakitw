import SwiftUI
import AppKit
import MacdirCore

@MainActor final class CacheModel: ObservableObject {
 @Published var reports: [CacheReport] = []
 @Published var busy = false
 @Published var selection = CacheSelection()
 @Published var outcome = "Нажмите «Проверить». Проверка ничего не удаляет."
 private let service = CacheService()
 func audit() {
  guard !busy else { return }; busy = true; selection = CacheSelection(); outcome = "Проверка…"
  let service = self.service
  Task {
   reports = await Task.detached(priority: .utility) { service.audit() }.value
   busy = false; outcome = "Проверка завершена. Размеры логические, не гарантированное освобождаемое место."
  }
 }
 func requestCleanup() {
  let targets = selection.targets(in: reports)
  let selectedReports = reports.filter { targets.contains($0.id) }
  guard !busy, !targets.isEmpty else { return }
  let alert = NSAlert()
  alert.messageText = "Удалить выбранные кэши (\(targets.count))?"
  alert.informativeText = "Будет безвозвратно удалено содержимое ТОЛЬКО перечисленных папок. Размер мог измениться. Закройте приложения и обновляторы; не запускайте их до завершения."
  let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 220))
  text.isEditable = false; text.isSelectable = true
  text.string = selectedReports.map { report in "\(report.id.name)\n\(report.path)\n\(exactBytes(report.bytes ?? 0))" }.joined(separator: "\n\n")
  text.isVerticallyResizable = true
  text.textContainer?.widthTracksTextView = true
  let scroll = NSScrollView(frame: text.frame)
  scroll.hasVerticalScroller = true; scroll.documentView = text
  alert.accessoryView = scroll
  alert.alertStyle = .warning
  alert.addButton(withTitle: "Отмена")
  alert.addButton(withTitle: "Удалить содержимое кэша")
  // The default/Return action is Cancel, never deletion.
  guard alert.runModal() == .alertSecondButtonReturn else { return }
  busy = true; selection = CacheSelection(); outcome = "Очистка…"; let service = self.service
  Task {
   let result = await Task.detached(priority: .utility) { () -> (String, [CacheReport]) in
    let results = service.cleanupSelected(targets, confirmed: true)
    let message = results.map { result in
     "\(result.target.name): " + (result.error.map { "остановлено — \($0). Возможно частичное удаление." } ?? "содержимое очищено (или уже отсутствует).")
    }.joined(separator: "\n")
    return (message, service.audit())
   }.value
   outcome = result.0; reports = result.1; busy = false
  }
 }
}
struct CachePanel: View {
 @ObservedObject var model: CacheModel
 @Environment(\.dismiss) private var dismiss
 var body: some View {
  VStack(alignment: .leading, spacing: 16) {
   HStack { Text("Проверка и очистка кэшей").font(.title2.bold()); Spacer(); Button("Закрыть") { dismiss() }.keyboardShortcut(.cancelAction) }
   Text("Все доступные непосредственные папки ~/Library/Caches. Владельцы определяются по метаданным установленных приложений в /Applications и ~/Applications. Неизвестные и системные владельцы — только просмотр. Containers, Application Support и профили вне Caches не проверяются.")
   HStack {
    Button("Обновить проверку") { model.audit() }.disabled(model.busy)
    Button("Удалить выбранные… (\(bytes(CacheReport.eligibleBytes(model.reports.filter { model.selection.ids.contains($0.id) }))))") { model.requestCleanup() }.disabled(model.busy || model.selection.targets(in: model.reports).isEmpty)
    if model.busy { ProgressView().controlSize(.small) }
   }
   Text(model.busy ? "Потенциал: проверка…" : "Доступно к очистке: \(exactBytes(CacheReport.eligibleBytes(model.reports))) · логический объём, не гарантия освобождения места").font(.caption).textSelection(.enabled)
   if !model.busy && !model.reports.isEmpty {
    Text(model.reports.contains(where: { $0.selectable })
      ? "Можно выбрать: \(model.reports.filter { $0.selectable }.count) из \(model.reports.count). Отметьте нужные кэши; серые галочки заблокированы — причина указана под строкой."
      : "Нет доступных для выбора кэшей. Причина указана под каждой строкой. Закройте нужное приложение или дождитесь обновления, затем нажмите «Обновить проверку». Неизвестные, системные и небезопасные пути остаются заблокированы.")
     .font(.caption).textSelection(.enabled)
   }
   ScrollView { LazyVStack(alignment: .leading) { ForEach(model.reports) { report in
    VStack(alignment: .leading, spacing: 6) {
     HStack {
      Toggle(report.id.name, isOn: Binding(get: { model.selection.ids.contains(report.id) }, set: { model.selection.set(report.id, selected: $0) }))
       .toggleStyle(.checkbox)
       .disabled(model.busy || !report.selectable)
      Spacer()
      Text(report.error == nil ? (report.present ? exactBytes(report.bytes ?? 0) : "0 Б · отсутствует") : "Н/Д")

     }
     Text(report.path).font(.caption).textSelection(.enabled)
     if report.selectable { Text("Можно выбрать").font(.caption).foregroundStyle(.secondary) }
     if let error = report.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
     if let reason = report.disabledReason { Text(reason).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
    }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
   } } }.frame(minHeight: 180, maxHeight: 380)
   ScrollView { Text(model.outcome).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(maxHeight: 100)
   Text("Ссылки, другие тома и недоступные пути блокируют операцию. Запущенный обновлятор (даже другого приложения) может блокировать очистку. Не запускайте приложение во время операции. Кэш может создаться заново; корневые папки сохраняются.").font(.caption).foregroundStyle(.secondary)
  }.padding(24).frame(width: 760)
 }
}
