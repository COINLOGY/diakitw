import SwiftUI
import AppKit
import MacdirCore

@MainActor final class ServersModel: ObservableObject {
 @Published var section = 0
 @Published var selectedServerID: String?
 @Published var configs: [ServerConfig] = []
 @Published var states: [String: ServerState] = [:]
 @Published var selections: [String: String] = [:]
 @Published var configError: String?
 @Published var inFlight: Set<String> = []
 @Published var hardwareCache = ServerHardwareCache()
 private var hardwareInFlight: Set<String> = []
 private var polling: Task<Void, Never>?
 private var visible = false
 private let store = ServerConfigStore()
 private var snapshot: ServerConfigStore.Snapshot?
 private var generations: [String: UUID] = [:]
 @Published var adding = false
 @Published var removing: ServerConfig?
 @Published var managementError: String?
 @Published var editing: ServerConfig?
 @Published var draftPort = "22"
 @Published var draftAuthentication = ServerConfig.Authentication.key
 @Published var draftPassword = ""
 private var requests: [String: [ServerCancellation]] = [:]
 @Published var draftName = ""
 @Published var draftTarget = ""
 @Published var draftRole = "bot"
 @Published var draftIdentity = ""
 @Published var draftDomain = ""
 @Published var draftIP = ""
 // Keep the on-disk user@host representation; expose separate editable endpoint fields.
 var draftUser: String {
  get { String(draftTarget.split(separator: "@", omittingEmptySubsequences: false).first ?? "") }
  set { draftTarget = newValue + "@" + draftHost }
 }
 var draftHost: String {
  get { String(draftTarget.split(separator: "@", omittingEmptySubsequences: false).dropFirst().joined(separator: "@")) }
  set { draftTarget = draftUser + "@" + newValue }
 }
 var canManage: Bool { snapshot != nil }
 private func apply(_ value: ServerConfigStore.Snapshot) {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let old = Dictionary(uniqueKeysWithValues: configs.map { ($0.id, $0) })
  let new = Dictionary(uniqueKeysWithValues: value.configs.map { ($0.id, $0) })
  for id in Set(old.keys).union(new.keys) {
   let unchanged = old[id].flatMap { try? encoder.encode($0) } == new[id].flatMap { try? encoder.encode($0) }
   if !unchanged {
    requests.removeValue(forKey: id)?.forEach { $0.cancel() }
    generations[id] = new[id] == nil ? nil : UUID()
    inFlight.remove(id); hardwareInFlight.remove(id)
    states[id] = nil; selections[id] = nil
   }
  }
  snapshot = value; configs = value.configs; configError = nil
  if let selectedServerID, new[selectedServerID] == nil { self.selectedServerID = nil }
 }
 func reload() {
  do { apply(try store.load()) }
  catch {
   requests.values.flatMap { $0 }.forEach { $0.cancel() }; requests = [:]
   snapshot = nil; configs = []; generations = [:]; selectedServerID = nil
   states = [:]; selections = [:]; inFlight = []; hardwareInFlight = []
   configError = (error as? LocalizedError)?.errorDescription ?? "Не удалось прочитать servers.json."
  }
 }
 func beginAdd() {
  editing = nil; draftPort = "22"; draftAuthentication = .key; draftPassword = ""
  draftName = ""; draftTarget = ""; draftRole = "bot"; draftIdentity = ""; draftDomain = ""; draftIP = ""
  managementError = nil; adding = true
 }
 func beginEdit(_ config: ServerConfig) {
  editing = config; draftName = config.name; draftTarget = config.target; draftRole = config.role
  draftIdentity = config.identityFile ?? ""; draftDomain = config.domain ?? ""; draftIP = config.ipAddress ?? ""
  draftPort = String(config.port); draftAuthentication = config.authentication; draftPassword = ""
  managementError = nil; adding = true
 }
 func addServer() {
  guard let snapshot else { return }
  func optional(_ value: String) -> String? { value.isEmpty ? nil : value }
  var created: ServerConfig?
  do {
   let port = try ServerConfig.parsePort(draftPort)
   let replacesPassword = draftAuthentication == .password && !draftPassword.isEmpty
   let reference = draftAuthentication == .key ? nil : (replacesPassword ? UUID().uuidString : editing?.passwordReference)
   if draftAuthentication == .password && !replacesPassword {
    guard let old = editing, old.authentication == .password, old.target == draftTarget, old.port == port, reference != nil else { throw ServerCredentialError.missing }
   }
   let config = ServerConfig(id: editing?.id ?? UUID().uuidString, name: draftName, target: draftTarget, identityFile: draftAuthentication == .key ? optional(draftIdentity) : nil, role: draftRole, domain: optional(draftDomain), ipAddress: optional(draftIP), authentication: draftAuthentication, port: port, passwordReference: reference)
   _ = try config.sshArguments()
   if replacesPassword {
    try ServerPasswordStore.save(draftPassword, for: config, helper: ServerAskpass.helperPath); created = config
   }
   let updated = try editing == nil ? store.add(config, expected: snapshot) : store.update(config, expected: snapshot)
   apply(updated); selectedServerID = config.id; created = nil; managementError = nil
   // Only the old exact app-owned credential; never an SSH key or another server's entry.
   if let old = editing, old.passwordReference != nil, old.passwordReference != reference {
    do { try ServerPasswordStore.delete(old) }
    catch { managementError = "Настройки сохранены, но старый пароль diakitw не удалён из Связки ключей." }
   }
   draftPassword = ""; editing = nil; adding = false; refresh()
  } catch {
   if let created {
    // A failed readback may follow a committed rename. Never delete a referenced credential.
    if let current = try? store.load(), !current.configs.contains(where: { $0.passwordReference == created.passwordReference }) { try? ServerPasswordStore.delete(created) }
   }
   draftPassword = ""
   managementError = (error as? LocalizedError)?.errorDescription ?? "Проверьте user@host, порт 1–65535, роль и абсолютный путь ключа."
  }
 }
 func removeServer(_ config: ServerConfig) {
  guard let snapshot else { return }
  do {
   apply(try store.remove(id: config.id, expected: snapshot)); managementError = nil
   do { try ServerPasswordStore.delete(config) }
   catch { managementError = "Сервер удалён из мониторинга; его пароль diakitw не удалось удалить из Связки ключей." }
  }
  catch { managementError = (error as? LocalizedError)?.errorDescription ?? "Не удалось изменить servers.json." }
  removing = nil
 }
 func setVisible(_ value: Bool) {
  guard visible != value else { return }
  visible = value
  polling?.cancel(); polling = nil
  guard value else {
   requests.values.flatMap { $0 }.forEach { $0.cancel() }; requests = [:]
   for id in generations.keys { generations[id] = UUID() }; inFlight = []; hardwareInFlight = []
   return
  }
  reload()
  polling = Task { [weak self] in
   while !Task.isCancelled {
    guard self?.visible == true else { return }
    self?.refresh()
    do { try await Task.sleep(for: .seconds(30)) } catch { return }
   }
  }
 }
 func refresh() {
  guard visible else { return }
  for config in configs where !hardwareInFlight.contains(config.id) && hardwareCache.needsRefresh(config, now: Date().timeIntervalSince1970) {
   guard let generation = generations[config.id] else { continue }
   hardwareInFlight.insert(config.id)
   let cancellation = ServerCancellation(); requests[config.id, default: []].append(cancellation)
   Task {
    let result: Result<ServerTelemetry, ServerError> = await Task.detached(priority: .utility) {
     do { return ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), specs: true, cancellation: cancellation) }
     catch { return .failure(.probe) }
    }.value
    guard generations[config.id] == generation else { return }
    requests[config.id]?.removeAll { $0 === cancellation }
    hardwareCache.record(config, sample: try? result.get(), now: Date().timeIntervalSince1970)
    hardwareInFlight.remove(config.id)
   }
  }
  for config in configs where !inFlight.contains(config.id) {
   guard let generation = generations[config.id] else { continue }
   inFlight.insert(config.id)
   let cancellation = ServerCancellation(); requests[config.id, default: []].append(cancellation)
   Task {
    let result: Result<ServerTelemetry, ServerError> = await Task.detached(priority: .utility) {
     do { return ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), cancellation: cancellation) }
     catch { return .failure(.probe) }
    }.value
    guard generations[config.id] == generation else { return }
    requests[config.id]?.removeAll { $0 === cancellation }
    var state = states[config.id] ?? ServerState(); state.accept(result); states[config.id] = state
    inFlight.remove(config.id)
    if selections[config.id] == nil {
     selections[config.id] = UserDefaults.standard.string(forKey: "server.interface." + config.id) ?? state.lastSuccess?.preferredInterface
    }
   }
  }
 }
 func select(_ name: String, for id: String) { selections[id] = name; UserDefaults.standard.set(name, forKey: "server.interface." + id) }
 deinit { polling?.cancel(); requests.values.flatMap { $0 }.forEach { $0.cancel() } }
}

struct MacdirRootView: View {
 @ObservedObject var model: Model
 @StateObject private var servers = ServersModel()
 @State private var zoom = 1.0
 @State private var viewport = CGSize.zero

 private var editingText: Bool {
  NSApp.keyWindow?.firstResponder is NSTextView || NSApp.keyWindow?.firstResponder is NSTextField
 }
 private var shortcutsBlocked: Bool { servers.adding || servers.removing != nil }
 /// Design size used by «По размеру»: the panel is never stretched wider than
 /// this, so a 55 % zoom keeps the card proportions instead of inflating them.
 private var designSize: CGSize {
  servers.section == 1
   ? CGSize(width: servers.selectedServerID == nil ? 1440 : 1180, height: 780)
   : CGSize(width: 1180, height: 800)
 }
 private func fit() {
  zoom = WindowZoom.fit(width: viewport.width, height: viewport.height,
   minimumWidth: designSize.width, minimumHeight: designSize.height)
 }
 private func resize(_ size: CGSize) { viewport = size; fit() }
 private func step(_ direction: Int) { if !editingText && !shortcutsBlocked { zoom = WindowZoom.step(zoom, direction: direction) } }
 private func resetZoom() { if !editingText && !shortcutsBlocked { zoom = 1 } }
 private var zoomToolbar: some View {
  HStack(spacing: 6) {
   Button("−") { step(-1) }.keyboardShortcut("-", modifiers: .command)
    .accessibilityLabel("Уменьшить масштаб")
   Button("\(Int((zoom * 100).rounded())) %") { resetZoom() }
    .accessibilityLabel("Сброс масштаба до 100 %")
   Button("+") { step(1) }.keyboardShortcut("+", modifiers: .command)
    .accessibilityLabel("Увеличить масштаб")
   Button("+") { step(1) }.keyboardShortcut("=", modifiers: .command).hidden()
   Button("100 %") { resetZoom() }.keyboardShortcut("0", modifiers: .command).hidden()
   Button("−") { step(-1) }.keyboardShortcut("-", modifiers: .control).hidden()
   Button("+") { step(1) }.keyboardShortcut("+", modifiers: .control).hidden()
   Button("+") { step(1) }.keyboardShortcut("=", modifiers: .control).hidden()
   Button("100 %") { resetZoom() }.keyboardShortcut("0", modifiers: .control).hidden()
   Button("По размеру") { fit() }
  }.buttonStyle(.bordered).controlSize(.small)
   .disabled(shortcutsBlocked)
   .frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 12).padding(.vertical, 5)
 }
 var body: some View {
  VStack(spacing: 0) {
   zoomToolbar
   GeometryReader { geometry in
    VStack(spacing: 0) {
     Picker("Раздел", selection: $servers.section) { Text("Этот Mac").tag(0); Text("Серверы").tag(1) }
      .pickerStyle(.segmented).frame(width: 300).padding(.top, 12)
     if servers.section == 0 { ContentView(model: model) }
     else { ServerPanel(model: servers).frame(minWidth: 1060, minHeight: 740).frame(maxWidth: 1440, alignment: .top) }
    }
    .frame(width: geometry.size.width / CGFloat(zoom), height: geometry.size.height / CGFloat(zoom), alignment: .top)
    .scaleEffect(CGFloat(zoom), anchor: .topLeading)
    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
    .onAppear { resize(geometry.size) }
    .onChange(of: geometry.size) { _, size in resize(size) }
   }
  }
  .tint(.cyan).controlSize(.large)
  .onChange(of: servers.section) { _, new in fit(); servers.setVisible(new == 1 && NSApp.isActive) }
  .onChange(of: servers.selectedServerID) { _, _ in fit() }
  .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) { _ in fit() }
  .onAppear { servers.setVisible(servers.section == 1 && NSApp.isActive) }
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in servers.setVisible(false) }
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in servers.setVisible(servers.section == 1) }
  .onDisappear { servers.setVisible(false) }
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in servers.setVisible(false) }
 }
}

private func measuredGiB(_ value: Double?) -> String {
 MetricPresentation.number(value.map { $0 / 1_073_741_824 }) + " GiB"
}
private func measuredPair(_ used: Double?, _ total: Double?) -> String {
 MetricPresentation.number(used.map { $0 / 1_073_741_824 }) + " из " + measuredGiB(total)
}
private func measuredPercent(_ used: Double?, _ total: Double?) -> String {
 guard let used, let total, used.isFinite, total.isFinite,
       used >= 0, total > 0, used <= total else { return "Н/Д" }
 return MetricPresentation.percent(used / total * 100)
}
private func serverTime(_ epoch: Double?) -> String {
 guard let epoch, epoch.isFinite, epoch >= 0, epoch < 253402300799 else { return "Н/Д" }
 let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ru_RU"); formatter.timeZone = TimeZone(identifier: "Europe/Moscow"); formatter.dateFormat = "dd.MM.yyyy HH:mm:ss 'МСК'"
 return formatter.string(from: Date(timeIntervalSince1970: epoch))
}

struct ServerPanel: View {
 @ObservedObject var model: ServersModel
 @State private var treeExpanded = true
 @State private var historyRange: ServerHistoryRange = .fiveMinutes
 var body: some View {
  ScrollView {
   VStack(alignment: .leading, spacing: 14) {
    HStack {
     Label("Серверы", systemImage: "server.rack").font(.largeTitle.bold())
     Spacer()
     Text("SSH · только чтение · каждые 30 с").foregroundStyle(.secondary)
     Button("Добавить сервер") { model.beginAdd() }.disabled(!model.canManage || model.configs.count >= 16)
     Button("Обновить") { model.reload(); model.refresh() }
    }
    if let error = model.configError { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
    if let error = model.managementError, !model.adding { Text(error).foregroundStyle(.orange) }
    TimelineView(.periodic(from: .now, by: 1)) { context in
     HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 9) {
       Text("Серверы · \(model.configs.count) / 16").font(.headline)
       Button {
        model.selectedServerID = nil
       } label: {
        Label("Все серверы", systemImage: "square.stack.3d.up")
         .frame(maxWidth: .infinity, alignment: .leading)
       }.buttonStyle(.bordered).tint(model.selectedServerID == nil ? .green : .secondary)
        .accessibilityAddTraits(model.selectedServerID == nil ? [.isSelected] : [])
       DisclosureGroup("Подключения", isExpanded: $treeExpanded) {
        ForEach(model.configs) { config in
         let state = model.states[config.id] ?? ServerState()
         Button { model.selectedServerID = config.id } label: {
          HStack(spacing: 7) {
           Circle().fill(state.current(now: context.date.timeIntervalSince1970) == nil ? Color.orange : Color.green)
            .frame(width: 8, height: 8)
           VStack(alignment: .leading, spacing: 2) {
            Text(config.name).lineLimit(1)
            Text(config.headerAddress + ":" + String(config.port)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
           }
           Spacer(minLength: 0)
          }.frame(maxWidth: .infinity, alignment: .leading)
         }.buttonStyle(.bordered).tint(model.selectedServerID == config.id ? .green : .secondary)
          .accessibilityAddTraits(model.selectedServerID == config.id ? [.isSelected] : [])
        }
       }
       if model.configs.isEmpty { Text("Добавьте сервер с готовым SSH-доступом.").font(.caption).foregroundStyle(.secondary) }
      }.padding(12).frame(width: 235, alignment: .topLeading)
       .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 12) {
       if let id = model.selectedServerID, let config = model.configs.first(where: { $0.id == id }) {
        HStack {
         Text("Выбранное подключение").font(.headline)
         Spacer()
         historyPicker
         Button("Изменить") { model.beginEdit(config) }
         Button("Удалить из мониторинга", role: .destructive) { model.removing = config }
        }
        ServerHostPanel(config: config, state: model.states[config.id] ?? ServerState(), hardware: model.hardwareCache.snapshot(config), hardwareLabel: model.hardwareCache.label(config, now: context.date.timeIntervalSince1970), now: context.date.timeIntervalSince1970, busy: model.inFlight.contains(config.id), range: historyRange, selection: Binding(get: { model.selections[config.id] ?? "" }, set: { model.select($0, for: config.id) }))
       } else {
        HStack {
         Text("Все серверы").font(.title2.bold())
         Spacer()
         historyPicker
         Text("На связи: \(model.configs.filter { model.states[$0.id]?.current(now: context.date.timeIntervalSince1970) != nil }.count) / \(model.configs.count)").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(model.configs) { config in
         ServerFleetRow(config: config, state: model.states[config.id] ?? ServerState(), hardware: model.hardwareCache.snapshot(config), now: context.date.timeIntervalSince1970, range: historyRange) {
          model.selectedServerID = config.id
         }
        }
        if model.configs.isEmpty { Text("Сохранённых подключений пока нет. Нажмите «Добавить сервер».").foregroundStyle(.secondary) }
        Text("Показатели каждого сервера отдельно; проценты разных машин не складываются.").font(.caption).foregroundStyle(.secondary)
       }
      }.frame(maxWidth: .infinity, alignment: .topLeading)
     }
    }
    Text("CPU: дельта за 1 с по всем ядрам · RAM: MemTotal − MemAvailable · диск: / · трафик одного интерфейса, без суммы мостов. Старше 90 с — Н/Д. При скрытии вкладки текущие SSH-запросы отменяются.")
     .font(.caption).foregroundStyle(.secondary)
   }.padding(22)
  }
  .sheet(isPresented: $model.adding) { ServerAddSheet(model: model) }
  .alert("Удалить из мониторинга?", isPresented: Binding(get: { model.removing != nil }, set: { if !$0 { model.removing = nil } }), presenting: model.removing) { config in
   Button("Отмена", role: .cancel) { model.removing = nil }.keyboardShortcut(.cancelAction)
   Button("Удалить из мониторинга", role: .destructive) { model.removeServer(config) }
  } message: { config in
   Text("\(config.name) · \(config.target)\nТолько из локального мониторинга. Сервер, службы, SSH-ключи, config и known_hosts не изменяются. Сохранённый пароль только этой записи diakitw будет удалён из Связки ключей. SSH-запрос отменяется.")
  }
 }
 private var historyPicker: some View {
  Picker("Период истории", selection: $historyRange) {
   ForEach(ServerHistoryRange.allCases, id: \.self) { Text($0.label).tag($0) }
  }.pickerStyle(.segmented).fixedSize().accessibilityLabel("Период истории")
 }
}

private struct ServerFleetRow: View {
 let config: ServerConfig
 let state: ServerState
 let hardware: ServerTelemetry?
 let now: Double
 let range: ServerHistoryRange
 let open: () -> Void
 var body: some View {
  let sample = state.current(now: now)
  Button(action: open) {
   VStack(alignment: .leading, spacing: 8) {
    HStack(spacing: 8) {
     VStack(alignment: .leading, spacing: 3) {
      Text(config.name).font(.headline).lineLimit(1)
      Text(config.target + ":" + String(config.port)).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
     }.frame(maxWidth: .infinity, alignment: .leading)
     Text(sample == nil ? (state.error?.rawValue ?? "Нет свежих данных") : "На связи")
      .font(.caption).foregroundStyle(sample == nil ? Color.orange : Color.green).lineLimit(1)
     Image(systemName: "chevron.right").foregroundStyle(.secondary)
    }
    GeometryReader { geometry in
     let side = min(84, max(72, (geometry.size.width - 40) / 13))
     let interface = sample?.preferredInterface
     let traffic = state.traffic(for: interface, in: range, now: now)
     let rxPeaks = traffic.compactMap { $0?.received }
     let txPeaks = traffic.compactMap { $0?.sent }
     let peaks = rxPeaks + txPeaks
     // Fixed 10 MiB/s made ordinary traffic sit on zero; the dial is relative
     // to the visible peak, the absolute value is printed under it.
     let trafficMax = max(65_536, peaks.max() ?? 0)
     let rx = sample?.network.first(where: { $0.name == interface })?.rx
     let tx = sample?.network.first(where: { $0.name == interface })?.tx
     // Ядра и полные объёмы приходят суточным замером, в живом сэмпле их нет:
     // без подстановки на приборах было «ядер: Н/Д» и пустые знаменатели.
     let cores = sample?.cpuCount ?? hardware?.cpuCount
     let memoryTotal = sample?.memoryTotal ?? hardware?.memoryTotal
     let diskTotal = sample?.diskTotal ?? hardware?.diskTotal
     HStack(spacing: 8) {
      fleetGauge("CPU", MetricPresentation.percent(sample?.cpuPercent), GaugeScale.fraction(sample?.cpuPercent, maximum: 100), side: side, detail: coreCount(cores))
      fleetGauge("RAM", measuredPercent(sample?.memoryUsed, memoryTotal), GaugeScale.fraction(sample?.memoryUsed, maximum: memoryTotal), side: side, detail: gibPair(sample?.memoryUsed, memoryTotal))
      fleetGauge("SWAP", measuredPercent(sample?.swapUsed, sample?.swapTotal), GaugeScale.fraction(sample?.swapUsed, maximum: sample?.swapTotal), side: side, detail: gibPair(sample?.swapUsed, sample?.swapTotal))
      fleetGauge("Диск /", measuredPercent(sample?.diskUsed, diskTotal), GaugeScale.fraction(sample?.diskUsed, maximum: diskTotal), side: side, detail: gibPair(sample?.diskUsed, diskTotal))
      fleetGauge("Приём ↓", shortRate(rx), GaugeScale.fraction(rx, maximum: trafficMax), side: side, direction: InstrumentTheme.lime, detail: "макс " + shortRate(rxPeaks.max()))
      fleetGauge("Отдача ↑", shortRate(tx), GaugeScale.fraction(tx, maximum: trafficMax), side: side, direction: InstrumentTheme.cyan, detail: "макс " + shortRate(txPeaks.max()))
      Spacer(minLength: 14)
      ServerLoadActivity(state: state, sample: sample, now: now, range: range, compact: true)
       .frame(maxWidth: .infinity).frame(height: side)
      ServerNetworkActivity(state: state, sample: sample, now: now, range: range, compact: true)
       .frame(maxWidth: .infinity).frame(height: side)
     }.frame(maxWidth: .infinity, alignment: .leading)
    }.frame(height: 108)
   }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
  }.buttonStyle(.plain).accessibilityLabel(config.name + ", " + (sample == nil ? "Нет свежих данных" : "На связи"))
 }
 private func fleetGauge(_ title: String, _ value: String, _ fraction: Double?, side: CGFloat,
                         direction: Color? = nil, detail: String? = nil) -> some View {
  VStack(spacing: 0) {
   NeedleGauge(fraction: fraction, neutral: direction != nil, tickLabels: [],
               directionColor: direction ?? InstrumentTheme.lime, gutter: 8, needleBase: 8)
    .frame(height: side * 0.46)
   Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1)
   Text(value).font(.system(size: direction == nil ? 13 : 11, weight: .semibold, design: .rounded))
    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
   Text(detail ?? " ").font(.system(size: 8, weight: .medium, design: .monospaced))
    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.65)
  }.frame(width: side, height: side).fixedSize()
   .background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 9))
   .accessibilityElement(children: .ignore).accessibilityLabel(title + ": " + value + (detail.map { ", " + $0 } ?? ""))
 }
 /// Short byte rate for the mini dials: "2.6 К/с", not "2.6 KiB/с".
 private func shortRate(_ value: Double?) -> String {
  let presentation = NetworkPresentation(value)
  guard presentation.available else { return "Н/Д" }
  return presentation.displayNumber + " " + (presentation.unit == "MiB" ? "М/с" : "К/с")
 }
 /// Same denominators as the detail cards: used/total in GiB, cores for CPU.
 private func gibPair(_ used: Double?, _ total: Double?) -> String {
  guard let used, let total, used.isFinite, total.isFinite, used >= 0, total >= 0, used <= total else { return "Н/Д" }
  return String(format: "%.1f/%.1fG", used / 1_073_741_824, total / 1_073_741_824)
 }
 private func coreCount(_ count: Double?) -> String {
  guard let raw = count, raw.isFinite, raw >= 1 else { return "ядра: Н/Д" }
  let count = Int(raw.rounded())
  let word = (count % 10 == 1 && count % 100 != 11) ? "ядро"
   : (([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) ? "ядра" : "ядер")
  return String(count) + " " + word
 }
}

/// Monotone cubic through the real samples: no kinks and, unlike Catmull-Rom,
/// no overshoot — the curve never leaves the range of its neighbouring points,
/// so a single spike cannot bend back into a loop.
/// `clampHeight` keeps every control point inside the plot.
private func smoothPath(_ points: [CGPoint], clampHeight: CGFloat? = nil) -> Path {
 var path = Path()
 guard let first = points.first else { return path }
 let clamp: (CGFloat) -> CGFloat = { value in
  guard let clampHeight else { return value }
  return min(max(value, 0), clampHeight)
 }
 path.move(to: CGPoint(x: first.x, y: clamp(first.y)))
 guard points.count > 1 else { return path }
 guard points.count > 2 else {
  path.addLine(to: CGPoint(x: points[1].x, y: clamp(points[1].y)))
  return path
 }
 let count = points.count
 var slope = [CGFloat](repeating: 0, count: count - 1)
 for index in 0..<(count - 1) {
  let dx = points[index + 1].x - points[index].x
  slope[index] = dx == 0 ? 0 : (points[index + 1].y - points[index].y) / dx
 }
 var tangent = [CGFloat](repeating: 0, count: count)
 tangent[0] = slope[0]
 tangent[count - 1] = slope[count - 2]
 for index in 1..<(count - 1) {
  tangent[index] = slope[index - 1] * slope[index] <= 0 ? 0 : (slope[index - 1] + slope[index]) / 2
 }
 // Fritsch–Carlson: ограничиваем наклоны, иначе на пике кривая загибается.
 for index in 0..<(count - 1) where slope[index] != 0 {
  let a = tangent[index] / slope[index], b = tangent[index + 1] / slope[index]
  let norm = a * a + b * b
  if norm > 9 {
   let scale = 3 / norm.squareRoot()
   tangent[index] = scale * a * slope[index]
   tangent[index + 1] = scale * b * slope[index]
  }
 }
 for index in 0..<(count - 1) {
  let dx = points[index + 1].x - points[index].x
  guard dx != 0 else { path.addLine(to: CGPoint(x: points[index + 1].x, y: clamp(points[index + 1].y))); continue }
  path.addCurve(to: CGPoint(x: points[index + 1].x, y: clamp(points[index + 1].y)),
                control1: CGPoint(x: points[index].x + dx / 3,
                                  y: clamp(points[index].y + tangent[index] * dx / 3)),
                control2: CGPoint(x: points[index + 1].x - dx / 3,
                                  y: clamp(points[index + 1].y - tangent[index + 1] * dx / 3)))
 }
 return path
}

/// Number only, for the compact chart title: "7.5", not "7.5 К/с".
private func compactRate(_ value: Double?) -> String {
 let presentation = NetworkPresentation(value)
 return presentation.available ? presentation.displayNumber : "—"
}

/// Light quarter grid behind both trend charts: 25/50/75 % of the plot plus a
/// baseline, so a flat line is readable without an axis.
private func drawChartGrid(_ context: GraphicsContext, size: CGSize) {
 for step in 1...3 {
  let y = size.height * Double(step) / 4
  var grid = Path()
  grid.move(to: CGPoint(x: 0, y: y))
  grid.addLine(to: CGPoint(x: size.width, y: y))
  context.stroke(grid, with: .color(.primary.opacity(0.12)),
                 style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
 }
 var baseline = Path()
 baseline.move(to: CGPoint(x: 0, y: size.height - 0.5))
 baseline.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
 context.stroke(baseline, with: .color(.primary.opacity(0.20)), style: StrokeStyle(lineWidth: 0.5))
}

private struct ServerLoadActivity: View {
 let state: ServerState
 let sample: ServerTelemetry?
 let now: Double
 var range: ServerHistoryRange = .fiveMinutes
 /// Compact mode is used by the fleet card: shorter title with the live value.
 var compact = false
 var body: some View {
  let readings = state.load(in: range, now: now)
  let title: String = compact
   ? "CPU · " + MetricPresentation.percent(sample?.cpuPercent)
   : "История нагрузки · CPU"
  VStack(alignment: .leading, spacing: 4) {
   Text(title)
    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
   if sample != nil && readings.contains(where: { $0?.percent != nil }) {
    Canvas { context, size in
     drawChartGrid(context, size: size)
     // Пропуск замера заполняется половиной последнего максимума — средним
     // между нулём и пиком: линия непрерывна и не выглядит обрывом.
     var pts: [CGPoint] = []
     var previous: ServerLoadPoint?
     var dropToZero = false
     let peak = readings.compactMap { $0?.percent }.max() ?? 0
     let fillY = max(0, Double(size.height) * (1 - (peak / 2) / 100))
     func zero(_ x: Double) { pts.append(CGPoint(x: x, y: fillY)) }
     var firstSampleX: Double?
     var firstSampleY: Double = 0
     var lastSampleX: Double = 0
     var lastSampleY: Double = 0
     for point in readings {
      guard let point, let value = point.percent else { dropToZero = true; continue }
      let x = Double(size.width) * ((point.sampledAt - (now - range.seconds)) / range.seconds)
      let y = Double(size.height) * (1 - value / 100)
      let position = CGPoint(x: x, y: y)
      if firstSampleX == nil { firstSampleX = x; firstSampleY = y }
      lastSampleX = x; lastSampleY = y
      if dropToZero {
       zero(Double(pts.last?.x ?? 0)); zero(x); dropToZero = false
      } else if let previous, !point.follows(previous) {
       zero(Double(pts.last?.x ?? CGFloat(x))); zero(x)
      }
      pts.append(position)
      previous = point
      context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(InstrumentTheme.lime))
     }
     if dropToZero { zero(Double(size.width)) }
     // Края тянутся за крайними замерами: слева — первым значением, справа —
     // последним. Линия не «догоняет» данные и не проваливается к середине.
     if let firstX = firstSampleX, firstX > 1 {
      pts.insert(CGPoint(x: 0, y: firstSampleY), at: 0)
     }
     if !dropToZero, lastSampleX < Double(size.width) - 1 {
      pts.append(CGPoint(x: Double(size.width), y: lastSampleY))
     }
     if pts.count > 1 {
      context.stroke(smoothPath(pts, clampHeight: size.height), with: .color(InstrumentTheme.lime), lineWidth: 1.5)
     }
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
     .accessibilityLabel("История реально измеренной загрузки CPU")
   } else {
    Text("История CPU: Н/Д").font(.caption2).foregroundStyle(.secondary)
     .frame(maxWidth: .infinity, maxHeight: .infinity)
   }
   ServerHistoryAxis(range: range, now: now)
  }.frame(maxWidth: .infinity)
 }
}

private struct ServerHistoryAxis: View {
 let range: ServerHistoryRange
 let now: Double
 private func clock(_ time: Double) -> String {
  guard time.isFinite, time >= 0, time < 4_102_444_800 else { return "—" }
  let components = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: time))
  return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
 }
 var body: some View {
  HStack(spacing: 1) {
   Text(clock(now - range.seconds))
   Spacer(minLength: 1)
   Text(clock(now))
  }.font(.system(size: 8, weight: .medium, design: .monospaced))
   .foregroundStyle(.secondary).lineLimit(1)
   .accessibilityLabel("Время от " + clock(now - range.seconds) + " до " + clock(now))
 }
}

private struct ServerNetworkActivity: View {
 let state: ServerState
 let sample: ServerTelemetry?
 let now: Double
 var range: ServerHistoryRange = .fiveMinutes
 var interface: String? = nil
 /// Compact mode (fleet card): short title that carries both live rates, and no
 /// separate rate widgets, which keeps the chart's minimum width small.
 var compact = false
 var body: some View {
  let name = interface ?? sample?.preferredInterface
  let rx = sample?.network.first(where: { $0.name == name })?.rx
  let tx = sample?.network.first(where: { $0.name == name })?.tx
  let readings = state.traffic(for: name, in: range, now: now)
  let rxMax = readings.compactMap { $0?.received }.max() ?? 0
  let txMax = readings.compactMap { $0?.sent }.max() ?? 0
  let scale = max(1, max(rxMax, txMax))
  let down = compactRate(rx) + "↓"
  let up = compactRate(tx) + "↑"
  let rates = down + " " + up
  let title: String = compact ? "Сеть · " + rates : "Сеть · " + (name ?? "Н/Д")
  VStack(alignment: .leading, spacing: 4) {
   HStack(spacing: 6) {
    Text(title)
     .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    Spacer(minLength: 0)
    if !compact {
     NetworkRateValue(value: rx, direction: "↓", size: 11)
      .foregroundStyle(InstrumentTheme.lime)
     NetworkRateValue(value: tx, direction: "↑", size: 11)
      .foregroundStyle(InstrumentTheme.cyan)
    }
   }
   if sample != nil && name != nil && readings.contains(where: { $0?.hasMeasurement == true }) {
    Canvas { context, size in
     drawChartGrid(context, size: size)
     for incoming in [true, false] {
      let color = incoming ? InstrumentTheme.lime : InstrumentTheme.cyan
      // То же для приёма и отдачи: пропуск садится на половину своего пика.
      var pts: [CGPoint] = []
      var previous: ServerTrafficPoint?
      var dropToZero = false
      let seriesPeak = readings.compactMap { incoming ? $0?.received : $0?.sent }.max() ?? 0
      let fillY = max(0, Double(size.height) * (1 - min(1, (seriesPeak / 2) / scale)))
      func zero(_ x: Double) { pts.append(CGPoint(x: x, y: fillY)) }
      var firstSampleX: Double?
      var firstSampleY: Double = 0
      var lastSampleX: Double = 0
      var lastSampleY: Double = 0
      for point in readings {
       guard let point, let value = incoming ? point.received : point.sent else { dropToZero = true; continue }
       let x = Double(size.width) * ((point.sampledAt - (now - range.seconds)) / range.seconds)
       let y = Double(size.height) * (1 - min(1, value / scale))
       let position = CGPoint(x: x, y: y)
       if firstSampleX == nil { firstSampleX = x; firstSampleY = y }
       lastSampleX = x; lastSampleY = y
       if dropToZero {
        zero(Double(pts.last?.x ?? 0)); zero(x); dropToZero = false
       } else if let previous, !point.follows(previous) {
        zero(Double(pts.last?.x ?? CGFloat(x))); zero(x)
       }
       pts.append(position)
       previous = point
       context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
        with: .color(color))
      }
      if dropToZero { zero(Double(size.width)) }
      // Та же непрерывность для приёма и отдачи: края держат крайние значения.
      if let firstX = firstSampleX, firstX > 1 {
       pts.insert(CGPoint(x: 0, y: firstSampleY), at: 0)
      }
      if !dropToZero, lastSampleX < Double(size.width) - 1 {
       pts.append(CGPoint(x: Double(size.width), y: lastSampleY))
      }
      if pts.count > 1 {
       context.stroke(smoothPath(pts, clampHeight: size.height), with: .color(color), lineWidth: 1.5)
      }
     }
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
     .accessibilityLabel("История реально измеренной активности сети: приём и передача")
   } else {
    Text("Нет свежих данных сети").font(.caption2).foregroundStyle(.secondary)
     .frame(maxWidth: .infinity, maxHeight: .infinity)
   }
   ServerHistoryAxis(range: range, now: now)
  }.frame(maxWidth: .infinity)
 }
}

private struct ServerAddSheet: View {
 @ObservedObject var model: ServersModel
 var body: some View {
  VStack(alignment: .leading, spacing: 14) {
   Text(model.editing == nil ? "Добавить сервер" : "Настройки сервера").font(.title2.bold())
   Form {
    TextField("Название", text: $model.draftName)
    TextField("IP-адрес или домен SSH", text: Binding(get: { model.draftHost }, set: { model.draftHost = $0 }))
    TextField("Логин SSH", text: Binding(get: { model.draftUser }, set: { model.draftUser = $0 }))
    TextField("SSH-порт (1–65535)", text: $model.draftPort)
    Picker("Аутентификация", selection: $model.draftAuthentication) {
     Text("SSH-ключ / ssh-agent").tag(ServerConfig.Authentication.key)
     Text("Логин и пароль").tag(ServerConfig.Authentication.password)
    }.pickerStyle(.segmented)
    Picker("Профиль проб", selection: $model.draftRole) {
     Text("bot — CoinLogy").tag("bot")
     Text("agent — EMCx / Hermes").tag("agent")
    }
    if model.draftAuthentication == .key {
     TextField("SSH identityFile (необязательно, /полный/путь)", text: $model.draftIdentity)
    } else {
     SecureField(model.editing?.passwordReference == nil ? "Пароль SSH" : "Новый пароль (пусто — оставить прежний)", text: $model.draftPassword)
     Text("Пароль хранится только в Связке ключей этого Mac, не в JSON. При смене логина, хоста или порта введите пароль заново.").font(.caption).foregroundStyle(.secondary)
    }
    TextField("Домен для заголовка (необязательно)", text: $model.draftDomain)
    TextField("IP для заголовка (необязательно)", text: $model.draftIP)
   }
   Text("Linux + python3: CPU, RAM, SWAP, диск / и интерфейсы. bot: vpn-bot, coinlogy-admin, coinlogy-monitor. agent: docker и контейнер emcx-hermes. Другие роли и произвольные команды не поддерживаются.").font(.caption).foregroundStyle(.secondary)
   Text("Нужен доверенный ключ хоста в known_hosts (для нестандартного порта — [хост]:порт). Проверка обязательна: новые ключи автоматически не принимаются. В режиме пароля SSH config, прокси, keyboard-interactive и 2FA не используются. Домен/IP выше — только подписи.").font(.caption).foregroundStyle(.secondary)
   Text("После подтверждения: сохранение в ~/Library/Application Support/macdir/servers.json и начало опроса только для чтения. Ключи не копируются; службы на сервере не изменяются. При замене пароля/переходе на ключ удаляется только прежний пароль этой записи diakitw.").font(.caption)
   if let error = model.managementError { Text(error).foregroundStyle(.orange).font(.caption) }
   HStack {
    Spacer()
    Button("Отмена", role: .cancel) { model.draftPassword = ""; model.adding = false; model.managementError = nil }.keyboardShortcut(.cancelAction)
    Button(model.editing == nil ? "Добавить и начать мониторинг" : "Сохранить настройки") { model.addServer() }
     .disabled(model.draftName.isEmpty || model.draftHost.isEmpty || model.draftUser.isEmpty || (try? ServerConfig.parsePort(model.draftPort)) == nil)
   }
  }.padding(24).frame(width: 640)
   .onDisappear { model.draftPassword = "" }
   .onChange(of: model.draftAuthentication) { _, _ in model.draftPassword = "" }
 }
}

private struct ServerHostPanel: View {
 let config: ServerConfig
 let state: ServerState
 let hardware: ServerTelemetry?
 let hardwareLabel: String
 let now: Double
 let busy: Bool
 var range: ServerHistoryRange = .fiveMinutes
 @Binding var selection: String
 private var sample: ServerTelemetry? { state.current(now: now) }
 private var network: ServerNetwork? { sample?.network.first { $0.name == selection } }
 var body: some View {
  VStack(alignment: .leading, spacing: 10) {
   HStack {
    VStack(alignment: .leading, spacing: 4) {
     Text(config.name).font(.title2.bold())
     Text(config.headerAddress).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
     Text(ServerTelemetry.hardwareSummary(hardware)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
      .help("vCPU — логические процессоры ОС, не физические ядра. RAM — MemTotal; диск — полный размер файловой системы /. GiB = 2³⁰ байт.")
     Text(hardwareLabel).font(.caption2).foregroundStyle(.secondary).help(hardwareLabel + ". Кэш характеристик: 24 ч; при ошибке повтор через 30 мин. Живые показатели и их знаменатели RAM/диска обновляются каждые 30 с.")
    }
    Text(config.role == "bot" ? "VPN / bot" : "EMCx / Hermes").font(.caption).foregroundStyle(.secondary)
    Spacer()
    if busy { ProgressView().controlSize(.small) }
    Text(sample != nil ? "Доступен" : (state.error?.rawValue ?? "Нет свежих данных"))
     .foregroundStyle(sample != nil ? Color.green : Color.secondary)
   }
   HStack(spacing: 10) {
    GaugeTile(symbol: "cpu", title: "CPU", value: MetricPresentation.percent(sample?.cpuPercent), detail: "Логические ядра: " + (hardware?.cpuCount.map { String(format: "%.0f", $0) } ?? "Н/Д"), fraction: GaugeScale.fraction(sample?.cpuPercent, maximum: 100), tickLabels: [])
    GaugeTile(symbol: "memorychip", title: "RAM", value: measuredPercent(sample?.memoryUsed, sample?.memoryTotal), detail: measuredPair(sample?.memoryUsed, sample?.memoryTotal), fraction: GaugeScale.fraction(sample?.memoryUsed, maximum: sample?.memoryTotal), tickLabels: [], explanation: "MemTotal − MemAvailable; GiB = 2³⁰ байт")
    GaugeTile(symbol: "arrow.left.arrow.right", title: "SWAP", value: measuredPercent(sample?.swapUsed, sample?.swapTotal), detail: measuredPair(sample?.swapUsed, sample?.swapTotal), fraction: GaugeScale.fraction(sample?.swapUsed, maximum: sample?.swapTotal), tickLabels: [], explanation: MetricPresentation.swapExplanation)
    GaugeTile(symbol: "internaldrive", title: "ДИСК /", value: measuredPercent(sample?.diskUsed, sample?.diskTotal), detail: measuredPair(sample?.diskUsed, sample?.diskTotal) + "\nКорневая файловая система", fraction: GaugeScale.fraction(sample?.diskUsed, maximum: sample?.diskTotal), tickLabels: [])
   }
   HStack {
    Picker("Интерфейс", selection: $selection) {
     ForEach(Array(Set((state.lastSuccess?.network.map(\.name) ?? []) + [selection])).sorted(), id: \.self) { Text($0.isEmpty ? "Н/Д" : $0).tag($0) }
    }.frame(width: 210)
    NetworkRateValue(value: network?.rx, direction: "↓")
     .foregroundStyle(network?.rx == nil ? Color.secondary : Color(red: 0.65, green: 0.90, blue: 0.25))
    NetworkRateValue(value: network?.tx, direction: "↑")
     .foregroundStyle(network?.tx == nil ? Color.secondary : Color(red: 0.30, green: 0.75, blue: 1.0))
    Spacer()
    Text("Uptime " + MetricPresentation.number(sample?.uptimeSeconds.map { $0 / 3600 }) + " ч").font(.caption)
   }.font(.system(size: 24, weight: .semibold, design: .monospaced))
   HStack {
    Text("Снимок: " + serverTime(sample?.sampledAt))
    Spacer()
    Text("Последний успешный: " + serverTime(state.lastSuccess?.sampledAt))
   }.font(.caption).foregroundStyle(.secondary)
   if let sample, !sample.services.isEmpty {
    HStack { ForEach(Array(sample.services.enumerated()), id: \.offset) { _, service in
     Label(service.name + ": " + service.state, systemImage: ["active", "running"].contains(service.state) ? "checkmark.circle" : "questionmark.circle")
      .foregroundStyle(["active", "running"].contains(service.state) ? Color.green : Color.secondary)
    } }.font(.caption)
   } else { Text("Службы: Н/Д").font(.caption).foregroundStyle(.secondary) }
   HStack(spacing: 10) {
    ServerLoadActivity(state: state, sample: sample, now: now, range: range)
    ServerNetworkActivity(state: state, sample: sample, now: now, range: range, interface: selection)
   }.frame(height: 150)

  }.padding(16).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
 }
}

// CLI uses exactly the same sampler, but never creates NSApplication or the Mac model.
func printServerSnapshot() {
 do {
  let configs = try ServerConfig.load(); let probe = try ServerSampler.bundledProbe()
  for config in configs {
   switch ServerSampler.sample(config, probe: probe) {
   case .success(let sample):
    let data = try JSONEncoder().encode(sample)
    print(config.name + "\t" + String(decoding: data, as: UTF8.self))
   case .failure(let error): print(config.name + "\t" + error.rawValue)
   }
  }
 } catch let error as ServerError { print(error.rawValue) }
 catch { print(ServerError.config.rawValue) }
}
