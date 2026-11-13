import SwiftUI
import MacdirCore

@MainActor final class ServersModel: ObservableObject {
 @Published var section = 0
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
 }
 func reload() {
  do { apply(try store.load()) }
  catch {
   requests.values.flatMap { $0 }.forEach { $0.cancel() }; requests = [:]
   snapshot = nil; configs = []; generations = [:]
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
   apply(updated); created = nil; managementError = nil
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

 var body: some View {
  VStack(spacing: 0) {
   Picker("Раздел", selection: $servers.section) { Text("Этот Mac").tag(0); Text("Серверы").tag(1) }
    .pickerStyle(.segmented).frame(width: 300).padding(.top, 12)
   if servers.section == 0 { ContentView(model: model) }
   else { ServerPanel(model: servers).frame(minWidth: 1060, minHeight: 740) }
  }
  .tint(.cyan).controlSize(.large)
  .onChange(of: servers.section) { _, new in servers.setVisible(new == 1 && NSApp.isActive) }
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
 var body: some View {
  ScrollView {
   VStack(alignment: .leading, spacing: 18) {
    HStack {
     Label("Серверы", systemImage: "server.rack").font(.largeTitle.bold())
     Spacer()
     Text("SSH · только чтение · каждые 30 с").foregroundStyle(.secondary)
     Button("Добавить сервер") { model.beginAdd() }.disabled(!model.canManage || model.configs.count >= 16)
     Button("Обновить") { model.reload(); model.refresh() }
    }
    if let error = model.configError { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
    if let error = model.managementError, !model.adding { Text(error).foregroundStyle(.orange) }
    if model.configs.isEmpty { Text("Добавьте сервер с готовым SSH-доступом. Ключи и конфигурация не входят в приложение.").foregroundStyle(.secondary) }
    TimelineView(.periodic(from: .now, by: 1)) { context in
     VStack(spacing: 18) {
      ForEach(model.configs) { config in
       HStack {
        Text(config.name + " · " + config.target + ":" + String(config.port)).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button("Настройки") { model.beginEdit(config) }.controlSize(.small)
        Button("Удалить из мониторинга", role: .destructive) { model.removing = config }.controlSize(.small)
       }
       ServerHostPanel(config: config, state: model.states[config.id] ?? ServerState(), hardware: model.hardwareCache.snapshot(config), hardwareLabel: model.hardwareCache.label(config, now: context.date.timeIntervalSince1970), now: context.date.timeIntervalSince1970, busy: model.inFlight.contains(config.id), selection: Binding(get: { model.selections[config.id] ?? "" }, set: { model.select($0, for: config.id) }))
      }
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
}

private struct ServerAddSheet: View {
 @ObservedObject var model: ServersModel
 var body: some View {
  VStack(alignment: .leading, spacing: 14) {
   Text(model.editing == nil ? "Добавить сервер" : "Настройки сервера").font(.title2.bold())
   Form {
    TextField("Название", text: $model.draftName)
    TextField("SSH: логин@хост", text: $model.draftTarget)
    TextField("SSH порт (1–65535)", text: $model.draftPort)
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
     .disabled(model.draftName.isEmpty || model.draftTarget.isEmpty || (try? ServerConfig.parsePort(model.draftPort)) == nil)
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
    GaugeTile(symbol: "cpu", title: "CPU", value: MetricPresentation.percent(sample?.cpuPercent), detail: "Логические ядра: " + (hardware?.cpuCount.map { String(format: "%.0f", $0) } ?? "Н/Д"), fraction: GaugeScale.fraction(sample?.cpuPercent, maximum: 100))
    GaugeTile(symbol: "memorychip", title: "RAM", value: measuredPercent(sample?.memoryUsed, sample?.memoryTotal), detail: measuredPair(sample?.memoryUsed, sample?.memoryTotal), fraction: GaugeScale.fraction(sample?.memoryUsed, maximum: sample?.memoryTotal), explanation: "MemTotal − MemAvailable; GiB = 2³⁰ байт")
    GaugeTile(symbol: "arrow.left.arrow.right", title: "SWAP", value: measuredPercent(sample?.swapUsed, sample?.swapTotal), detail: measuredPair(sample?.swapUsed, sample?.swapTotal), fraction: GaugeScale.fraction(sample?.swapUsed, maximum: sample?.swapTotal), explanation: MetricPresentation.swapExplanation)
    GaugeTile(symbol: "internaldrive", title: "ДИСК /", value: measuredPercent(sample?.diskUsed, sample?.diskTotal), detail: measuredPair(sample?.diskUsed, sample?.diskTotal) + "\nКорневая файловая система", fraction: GaugeScale.fraction(sample?.diskUsed, maximum: sample?.diskTotal))
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
   HStack {
    Text("CPU · последние 60 опросов\n0–100 % · пропуски не соединяются").font(.caption2).foregroundStyle(.secondary)
    Canvas { context, size in
     var path = Path(); var connected = false
     for (i, value) in state.cpuHistory.enumerated() {
      guard let value else { connected = false; continue }
      let point = CGPoint(x: size.width * Double(i) / 59, y: size.height * (1 - value / 100))
      if connected { path.addLine(to: point) } else { path.move(to: point) }; connected = true
     }
     context.stroke(path, with: .color(.blue), lineWidth: 1.5)
    }.frame(height: 28).accessibilityLabel("История реально измеренной загрузки CPU")
   }
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
