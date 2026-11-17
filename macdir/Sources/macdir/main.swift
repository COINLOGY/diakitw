import SwiftUI
import AppKit
import Network
import MacdirCore

final class Cancellation: @unchecked Sendable {
 private let lock = NSLock()
 private var value = false
 func cancel() { lock.lock(); value = true; lock.unlock() }
 var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
@MainActor final class Model: ObservableObject {
 @Published var showCaches = false
 let caches = CacheModel()
 @Published var sort = [KeyPathComparator(\FileNode.logical, order: .reverse)]
 @Published var tab = 0
 @Published var selectedInterface = "en0" {
  didSet { trafficHistory.select(selectedInterface) }
 }
 @Published var trafficHistory = TrafficHistory()
 @Published var trafficRange: TrafficRange = .minute
 @Published var computerName = "Недоступно"
 @Published var externalAddress: String?
 @Published var egressLocation: EgressLocation?
 private var identityRequest: Task<EgressLocation?, Never>?
 var internalAddressText: String { MacIdentity.internalText(snapshot.interfaceAddresses, interface: selectedInterface) }
 private var identityMonitor: Task<Void, Never>?
 private let pathMonitor = NWPathMonitor()
 private var identityRefresh = IdentityRefreshPolicy()
 private var identityGeneration = 0
 var identityVisible = false { didSet { if !identityVisible && !statusVisible { identityChanged() } } }
 var statusVisible = false { didSet { if !statusVisible && !identityVisible { identityChanged() } } }
 func identityChanged() {
  identityGeneration += 1
  identityRequest?.cancel()
  egressLocation = nil
  externalAddress = nil
  identityRefresh.changed(now: ProcessInfo.processInfo.systemUptime)
 }
 @Published var result: ScanResult?
 @Published var current: FileNode?
 @Published var crumbs: [FileNode] = []
 @Published var scanning = false
 @Published var selected: String?
 @Published var snapshot = ResourceSnapshot()
 @Published var largest: [FileNode] = []
 @Published var elapsed = ""
 @Published var scanStarted = Date()
 @Published var showIssues = false
 @Published var showCapacity = false
 @Published var rows: [FileNode] = []
 @Published var tiles: [FileNode] = []
 private var presentationID = UUID()
 func prepareRows() {
  let id = UUID(); presentationID = id
  let children = current?.children ?? []
  let input = tab == 0 ? children : largest
  let order = sort
  Task {
   let prepared = await Task.detached(priority: .utility) { (input.sorted(using: order), mapNodes(children)) }.value
   guard presentationID == id else { return }
   rows = prepared.0; tiles = prepared.1
  }
 }
 private var cancellation = Cancellation()
 private var monitor: Task<Void, Never>?
 private let queue = DispatchQueue(label: "macdir.resources", qos: .utility)
 private let sampler = ResourceSampler()
 var volume: URL?
 init() {
  scan(URL(fileURLWithPath: "/"))
  pathMonitor.pathUpdateHandler = { [weak self] _ in
   Task { @MainActor [weak self] in self?.identityChanged() }
  }
  pathMonitor.start(queue: DispatchQueue(label: "macdir.identity-route", qos: .utility))
  identityMonitor = Task { [weak self] in
   let name = await Task.detached(priority: .utility) {
    MacIdentity.localComputerName()
   }.value
   guard !Task.isCancelled else { return }
   self?.computerName = name
   while !Task.isCancelled {
    guard self != nil else { return }
    guard self?.identityRefresh.take(now: ProcessInfo.processInfo.systemUptime, foreground: self?.statusVisible == true || (self?.identityVisible == true && NSApp.isActive)) == true else {
     do { try await Task.sleep(for: .seconds(1)) } catch { return }
     continue
    }
    let generation = self?.identityGeneration
    // Keep the last valid flag until the refresh completes; route changes clear it immediately.
    let request = Task { await GeoLookup.fetch() }
    self?.identityRequest = request
    let location = await request.value
    guard !Task.isCancelled else { return }
    guard self?.identityGeneration == generation, (self?.statusVisible == true || (self?.identityVisible == true && NSApp.isActive)) else { continue }
    self?.identityRequest = nil
    self?.egressLocation = location
    self?.externalAddress = location?.ip
    do { try await Task.sleep(for: .seconds(1)) } catch { return }
   }
  }
  monitor = Task { [weak self] in
   while !Task.isCancelled {
    guard let self else { return }
    let sampler = self.sampler
    let sample = await withCheckedContinuation { continuation in
     self.queue.async { continuation.resume(returning: sampler.sample(volume: URL(fileURLWithPath: "/"))) }
    }
    self.snapshot = sample
    if let time = sample.networkSampleTime {
     let network = sample.networks.first { $0.name == self.selectedInterface }
     self.trafficHistory.append(interface: self.selectedInterface, time: time, received: network?.received, sent: network?.sent)
    }
    do { try await Task.sleep(for: .seconds(1)) } catch { return }
   }
  }
 }
 deinit { monitor?.cancel(); identityMonitor?.cancel(); identityRequest?.cancel(); pathMonitor.cancel(); cancellation.cancel() }
 func stop() { monitor?.cancel(); identityMonitor?.cancel(); identityRequest?.cancel(); pathMonitor.cancel(); cancellation.cancel() }
 func choose() {
  let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
  panel.directoryURL = volume ?? FileManager.default.homeDirectoryForCurrentUser
  panel.allowsMultipleSelection = false; panel.message = "Выберите папку. Анализ папок читает только метаданные."
  if panel.runModal() == .OK, let url = panel.url { scan(url) }
 }
 func scan(_ url: URL) {
  cancellation.cancel()
  cancellation = Cancellation(); let token = cancellation
  volume = url; scanning = true; result = nil; current = nil; largest = []; crumbs = []; selected = nil; rows = []; tiles = []; presentationID = UUID()
  let start = Date()
  scanStarted = start
  Task {
   let preview = await Task.detached(priority: .utility) {
    MacdirCore.Scanner.scan(url, cancelled: { true })
   }.value
   guard token === self.cancellation else { return }
   result = preview; current = preview.root; crumbs = [preview.root]; elapsed = "Подсчёт размеров…"; prepareRows()
   guard !token.isCancelled else { return }
   let output = await Task.detached(priority: .utility) {
    MacdirCore.Scanner.scan(url, cancelled: { token.isCancelled }, progress: { frame in
     Task { @MainActor in
      guard token === self.cancellation, self.scanning, !token.isCancelled else { return }
      self.result = frame; self.current = frame.root; self.crumbs = [frame.root]
      self.elapsed = "Подсчёт размеров…"; self.prepareRows()
     }
    })
   }.value
   let top = await Task.detached(priority: .utility) {
    var files: [FileNode] = []; var stack = [output.root]
    while let n = stack.popLast() {
     if n.isDirectory { stack.append(contentsOf: n.children) }
     else if n.logical > 0 {
      files.append(n); files.sort { $0.logical > $1.logical }
      if files.count > 100 { files.removeLast() }
     }
    }
    return files
   }.value
   guard token === self.cancellation else { return }
   result = output; current = output.root; crumbs = [output.root]; largest = top; prepareRows()
   elapsed = MetricPresentation.number(Date().timeIntervalSince(start)) + " с"; scanning = false
  }
 }
 func cancel() { cancellation.cancel(); scanning = false }
 func navigate(_ node: FileNode) {
  selected = node.path
  if node.isDirectory {
   if scanning || node.state == "Не обследовано" { scan(URL(fileURLWithPath: node.path)); return }
   current = node; crumbs.append(node)
   if !node.path.hasPrefix("macdir:") { volume = URL(fileURLWithPath: node.path) }
   prepareRows()
  }
 }
 func back(_ index: Int) {
  current = crumbs[index]; crumbs = Array(crumbs.prefix(index + 1)); selected = nil
  if let current, !current.path.hasPrefix("macdir:") { volume = URL(fileURLWithPath: current.path) }
  prepareRows()
 }
 func reveal(_ path: String) { guard !path.hasPrefix("macdir:") else { return }; NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
}

struct Tile: View {
 let symbol: String; let title: String; let value: String; let detail: String
 var body: some View {
  VStack(alignment: .leading, spacing: 8) {
   Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
   Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
   Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
  }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
   .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
 }
}
struct Treemap: View {
 let nodes: [FileNode]; let action: (FileNode) -> Void
 func boxes(_ items: ArraySlice<FileNode>, _ rect: CGRect) -> [(FileNode, CGRect)] {
  guard !items.isEmpty, rect.width.isFinite, rect.height.isFinite,
        rect.width > 0, rect.height > 0 else { return [] }
  if items.count == 1 { return [(items.first!, rect)] }
  let total = items.reduce(0.0) { $0 + Double($1.logical) }
  let half = total / 2
  var sum = 0.0; var count = 0
  for n in items.dropLast() { sum += Double(n.logical); count += 1; if sum >= half { break } }
  let ratio = total > 0 ? sum / total : 0.5
  let a: CGRect; let b: CGRect
  if rect.width >= rect.height {
   let width = rect.width * ratio
   a = CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)
   b = CGRect(x: rect.minX + width, y: rect.minY, width: rect.width - width, height: rect.height)
  } else {
   let height = rect.height * ratio
   a = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
   b = CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: rect.height - height)
  }
  return boxes(items.prefix(count), a) + boxes(items.dropFirst(count), b)
 }
 var body: some View {
  GeometryReader { geo in
   let cells = boxes(nodes[...], CGRect(origin: .zero, size: geo.size))
   ZStack(alignment: .topLeading) {
    ForEach(Array(cells.enumerated()), id: \.element.0.id) { index, cell in
     let node = cell.0; let r = cell.1
     Button { action(node) } label: {
      VStack(alignment: .leading, spacing: 4) {
       if r.width > 65 && r.height > 32 {
        Text(node.name).font(.caption.weight(.medium)).lineLimit(2)
        if r.height > 58 { Text(bytes(node.logical)).font(.caption2).opacity(0.8) }
       }
      }.padding(r.width > 65 ? 8 : 0).frame(width: max(0, r.width - 3), height: max(0, r.height - 3), alignment: .topLeading)
       .background(Color(hue: Double(index % 12) / 18 + 0.42, saturation: 0.55, brightness: 0.68), in: RoundedRectangle(cornerRadius: 5)).foregroundStyle(.white)
     }.buttonStyle(.plain).offset(x: r.minX, y: r.minY).help("\(node.path)\n\(bytes(node.logical))")
    }
   }
  }
 }
}
struct ContentView: View {
 @ObservedObject var model: Model
 private var selectedInterface: String { model.selectedInterface }
 private var selectedNetwork: NetworkRate? { model.snapshot.networks.first { $0.name == selectedInterface } }

 private var networkSelector: some View {
  HStack {
   Label("Сеть", systemImage: "network").font(.headline)
   Picker("Интерфейс шкалы и графика", selection: $model.selectedInterface) {
    ForEach(Array(Set(model.snapshot.networks.map(\.name) + [selectedInterface])).sorted(), id: \.self) { Text($0).tag($0) }
   }.labelsHidden().frame(width: 110).help("Интерфейс приборов и графика; смена очищает историю графика")
   Spacer(minLength: 0)
  }
 }

 private var networkInstruments: some View {
  let scale = model.trafficHistory.scale(in: model.trafficRange)
  let labels = NetworkSpeedScale.labels(maximum: scale)
  return ViewThatFits(in: .horizontal) {
   HStack(alignment: .center, spacing: 10) {
    receiveGauge(scale: scale, labels: labels).frame(minWidth: 210)
    sendGauge(scale: scale, labels: labels).frame(minWidth: 210)
    TrafficChart(history: model.trafficHistory, range: $model.trafficRange).frame(minWidth: 280, maxWidth: .infinity)
   }
   VStack(spacing: 10) {
    HStack(spacing: 10) {
     receiveGauge(scale: scale, labels: labels)
     sendGauge(scale: scale, labels: labels)
    }
    TrafficChart(history: model.trafficHistory, range: $model.trafficRange).frame(maxWidth: .infinity)
   }
  }.fixedSize(horizontal: false, vertical: true)
 }
 private func receiveGauge(scale: Double, labels: [String]) -> some View {
  GaugeTile(symbol: "arrow.down", title: "ПРИЁМ", value: NetworkPresentation(selectedNetwork?.received).text + " ↓", detail: selectedInterface + " · 0–" + labels[2] + "/с", fraction: GaugeScale.fraction(selectedNetwork?.received, maximum: scale), neutral: true, networkRate: selectedNetwork?.received, networkDirection: "↓", tickLabels: labels, directionColor: InstrumentTheme.lime)
 }
 private func sendGauge(scale: Double, labels: [String]) -> some View {
  GaugeTile(symbol: "arrow.up", title: "ОТДАЧА", value: NetworkPresentation(selectedNetwork?.sent).text + " ↑", detail: selectedInterface + " · 0–" + labels[2] + "/с", fraction: GaugeScale.fraction(selectedNetwork?.sent, maximum: scale), neutral: true, networkRate: selectedNetwork?.sent, networkDirection: "↑", tickLabels: labels, directionColor: InstrumentTheme.cyan)
 }

 var body: some View {
  GeometryReader { viewport in
   ScrollView(.vertical) {
    dashboard(viewport: viewport.size)
   }
  }.frame(minWidth: 800, minHeight: 500)
   .sheet(isPresented: $model.showCaches) { CachePanel(model: model.caches) }
   .onChange(of: model.sort) { _, _ in model.prepareRows() }
   .onChange(of: model.tab) { _, _ in model.prepareRows() }
    .onAppear { model.identityVisible = true; if !model.statusVisible { model.identityChanged() } }
    .onDisappear { model.identityVisible = false; if !model.statusVisible { model.identityChanged() } }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in if !model.statusVisible { model.identityChanged() } }
   .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in if !model.statusVisible { model.identityChanged() } }
   .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.stop() }
 }

 @ViewBuilder private var toolbarActions: some View {
    Button("Тест интернета") { InternetTestWindow.shared.show() }
    Button("Диагностика") { DiagnosticsWindow.shared.show() }
    Button("Терминал") { DesktopActions.shared.terminal() }
    Button("Мониторинг системы") { DesktopActions.shared.processes() }
    Button("Проверить кэши") { model.showCaches = true; model.caches.audit() }
    Button("Корень /") { model.scan(URL(fileURLWithPath: "/")) }
    Button { model.choose() } label: { Label("Выбрать папку", systemImage: "folder.badge.plus") }.buttonStyle(.borderedProminent).keyboardShortcut("o")
 }
 private var diskGauge: some View {
  Button { model.showCapacity.toggle() } label: {
   GaugeTile(symbol: "internaldrive", title: "ДИСК · ЗАНЯТО", value: MetricPresentation.utilization(model.snapshot.diskOccupied, total: model.snapshot.diskTotal), detail: MetricPresentation.usedTotal(model.snapshot.diskOccupied, total: model.snapshot.diskTotal), fraction: GaugeScale.fraction(model.snapshot.diskOccupied.map(Double.init), maximum: model.snapshot.diskTotal.map(Double.init)), explanation: "APFS: занято в общем пуле, не сумма папок. Нажмите для точных байтов.")
  }.buttonStyle(.plain)
   .popover(isPresented: $model.showCapacity) { Text(model.snapshot.diskDetail).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(20) }
 }
 private func compactToolbar(viewportWidth: CGFloat) -> some View {
  let headerLayout = viewportWidth >= 1500 ? AnyLayout(HStackLayout(alignment: .center, spacing: 14)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 7))
  return headerLayout {
   HStack(spacing: 8) {
    Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "macdir", withExtension: "icns") ?? URL(fileURLWithPath: "assets/macdir.icns")) ?? NSImage())
     .resizable().frame(width: 32, height: 32).accessibilityLabel("diakitw Modular W")
    VStack(alignment: .leading, spacing: 0) {
     Text("diakitw").font(.system(size: 22, weight: .bold, design: .rounded))
     Text("Пространство и ресурсы вашего Mac").font(.caption2).foregroundStyle(.secondary)
    }
    Spacer(minLength: 0)
   }
   ViewThatFits(in: .horizontal) {
    HStack(spacing: 6) { toolbarActions }.fixedSize(horizontal: true, vertical: false)
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 128), alignment: .leading), count: viewportWidth >= 800 ? 4 : 2), alignment: .leading, spacing: 6) { toolbarActions }
   }
  }
 }
 private var compactIdentity: some View {
  HStack(alignment: .top, spacing: 12) {
   VStack(alignment: .leading, spacing: 3) {
    Text("Этот Mac · интерфейс " + selectedInterface).font(.caption2).foregroundStyle(.secondary)
    Text(model.computerName).font(.headline).lineLimit(1).help(model.computerName)
    Text("Внутренний: " + model.internalAddressText).font(.caption).lineLimit(1).truncationMode(.middle).help(model.internalAddressText)
   }.frame(maxWidth: .infinity, alignment: .leading)
   VStack(alignment: .leading, spacing: 3) {
    Text("Выход в интернет / VPN").font(.caption2).foregroundStyle(.secondary)
    HStack(spacing: 8) {
     Text(model.externalAddress ?? "Недоступен").font(.system(size: 17, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.75)
     if let flag = model.egressLocation?.flag {
      Text(flag).font(.system(size: 16)).fixedSize().layoutPriority(1)
     }
     Text(model.egressLocation.map { [$0.country, $0.city].compactMap { $0 }.joined(separator: " · ") }.flatMap { $0.isEmpty ? nil : $0 } ?? "Страна / город недоступны")
      .font(.caption).lineLimit(1).minimumScaleFactor(0.75)
    }
    Text("2ip через EMCx · резерв GeoJS · выход/VPN, не GPS").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
     .help("HTTPS aia.emcx.pro/diakitw-api/geo: EMCx и 2ip получают IP выхода/VPN; токен 2ip только на сервере. При ошибке — GeoJS/Cloudflare. Приблизительные страна/город, не GPS. Серверные квоты 300/день, 9000/месяц; кэш 1 ч. Строка меню работает и в фоне; debounce 2 с, минимум и период 60 с; до 8 с и 16 KiB на провайдера, без cookies/redirects. Ошибка очищает данные. Карта — только по нажатию.")
   }.frame(maxWidth: .infinity, alignment: .leading)
   Button("Карта") { if let url = model.egressLocation?.mapURL { DesktopActions.shared.openMap(url) } }
    .disabled(model.egressLocation?.mapURL == nil)
    .help("Открыть Apple Maps: передаётся приблизительная координата выхода либо только страна; не GPS. Сервис карт получает сетевой запрос только после нажатия.")
  }.padding(10).background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 12))
   .textSelection(.enabled)
 }
 private func compactResources(viewportWidth: CGFloat) -> some View {
  VStack(alignment: .leading, spacing: 7) {
   Text("Ресурсы").font(.headline)
   LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 220), spacing: 8), count: viewportWidth >= 1040 ? 4 : 2), spacing: 8) {
    GaugeTile(symbol: "cpu", title: "ПРОЦЕССОР", value: MetricPresentation.percent(model.snapshot.cpu), detail: "\(ProcessInfo.processInfo.processorCount) логических ядер", fraction: GaugeScale.fraction(model.snapshot.cpu, maximum: 100))
    GaugeTile(symbol: "memorychip", title: "ПАМЯТЬ", value: MetricPresentation.utilization(model.snapshot.memoryUsed, total: model.snapshot.memoryTotal), detail: MetricPresentation.usedTotal(model.snapshot.memoryUsed, total: model.snapshot.memoryTotal), fraction: GaugeScale.fraction(model.snapshot.memoryUsed.map(Double.init), maximum: Double(model.snapshot.memoryTotal)), explanation: "Активная + wired + сжатая память; GiB = 2³⁰ байт")
    GaugeTile(symbol: "arrow.left.arrow.right", title: "SWAP", value: MetricPresentation.utilization(model.snapshot.swap, total: model.snapshot.swapTotal), detail: MetricPresentation.usedTotal(model.snapshot.swap, total: model.snapshot.swapTotal), fraction: GaugeScale.fraction(model.snapshot.swap.map(Double.init), maximum: model.snapshot.swapTotal.map(Double.init)), explanation: MetricPresentation.swapExplanation)
    GaugeTile(symbol: "bolt.fill", title: "БАТАРЕЯ · ЗАРЯД", value: MetricPresentation.battery(model.snapshot.batteryPercent), detail: MetricPresentation.powerState(model.snapshot.power) + " · циклы: " + (model.snapshot.batteryCycles.map(String.init) ?? "Н/Д"), fraction: GaugeScale.fraction(model.snapshot.batteryPercent, maximum: 100), battery: true)
   }
  }
 }
 private var compactNetwork: some View {
  VStack(alignment: .leading, spacing: 7) { networkSelector; networkInstruments }
 }
 private var compactDisk: some View {
  VStack(alignment: .leading, spacing: 7) {
   Text("Диск").font(.headline)
   ViewThatFits(in: .horizontal) {
    HStack(alignment: .top, spacing: 8) {
     diskGauge.frame(width: 240)
     DiskCapacityOverview(snapshot: model.snapshot, scan: model.result).frame(maxWidth: .infinity)
    }
    VStack(spacing: 8) { diskGauge; DiskCapacityOverview(snapshot: model.snapshot, scan: model.result) }
   }
  }
 }
 private func dashboard(viewport: CGSize) -> some View {
  VStack(alignment: .leading, spacing: 9) {
   compactToolbar(viewportWidth: viewport.width)
   HStack(spacing: 8) {
    if model.scanning { ProgressView().controlSize(.small); Button("Остановить") { model.cancel() } }
    if let volume = model.volume { Button { model.scan(volume) } label: { Label("Сканировать заново", systemImage: "arrow.clockwise") }.disabled(model.scanning) }
   }.controlSize(.small)
   compactIdentity
   compactResources(viewportWidth: viewport.width)
   compactNetwork
   compactDisk
   if model.scanning {
    TimelineView(.periodic(from: .now, by: 1)) { context in
     HStack {
      Text(model.result?.currentPath.isEmpty == false ? model.result!.currentPath : (model.volume?.path ?? "/")).lineLimit(1).truncationMode(.middle)
      Spacer()
      Text("Файлов: \(model.result?.files ?? 0) · \(MetricPresentation.number(max(0, context.date.timeIntervalSince(model.scanStarted)))) с").monospacedDigit()
     }.font(.caption).help(model.result?.currentPath ?? model.volume?.path ?? "/")
    }
   }
   if let current = model.current, let result = model.result {
    HStack {
     ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) { ForEach(Array(model.crumbs.enumerated()), id: \.offset) { i, crumb in
       Button(crumb.name.isEmpty ? "/" : crumb.name) { model.back(i) }.buttonStyle(.link)
       if i < model.crumbs.count - 1 { Image(systemName: "chevron.right").font(.caption2) }
      } }
     }
     Spacer()
     Text("\(current.complete ? "Учтено" : "Частично ≥") \(exactBytes(current.logical)) логически · \(exactBytes(current.allocated)) блоков").font(.caption.monospacedDigit()).textSelection(.enabled)
    }
    HSplitView {
     VStack(alignment: .leading, spacing: 8) {
      Picker("Вид", selection: $model.tab) { Text("Содержимое папки").tag(0); Text("Крупнейшие 100").tag(1) }.pickerStyle(.segmented)
      Table(model.rows, selection: $model.selected, sortOrder: $model.sort) {
       TableColumn("Имя", value: \.name) { node in
        HStack { Image(systemName: node.isDirectory ? "folder.fill" : "doc").foregroundStyle(node.isDirectory ? .cyan : .secondary); Text(node.name).lineLimit(1) }
         .onTapGesture(count: 2) { if model.tab == 0 { model.navigate(node) } }
         .contextMenu { if node.isDirectory && model.tab == 0 { Button("Открыть папку") { model.navigate(node) } }; Button("Показать в Finder") { model.reveal(node.path) } }
       }.width(min: 180, ideal: 270)
       TableColumn("Размер", value: \.logical) { node in Text(node.target != nil ? "—" : node.sizeText).monospacedDigit().help("Учтённый вклад: " + exactBytes(node.logical)) }.width(min: 85, ideal: 100)
       TableColumn("Блоки", value: \.allocated) { node in Text(node.target != nil ? "—" : (node.complete ? "" : "≥ ") + bytes(node.allocated)).monospacedDigit().help("Учтённый вклад: " + exactBytes(node.allocated)) }.width(min: 85, ideal: 100)
       TableColumn("Статус") { node in Text(node.state).font(.caption).help(node.state) }.width(min: 100, ideal: 160)
      }
     }.frame(minWidth: 450)
     VStack(alignment: .leading, spacing: 10) {
      Text("Карта пространства").font(.headline)
      Treemap(nodes: model.tiles) { model.navigate($0); model.tab = 0 }.frame(minHeight: 220)
      Text("Площадь = учтённый логический размер. После 79 элементов — группа «Остальные» с переходом. Нулевые, ссылки и неизвестные размеры — в полной таблице. Карта частичного обхода не описывает весь диск.").font(.caption).foregroundStyle(.secondary)
     }.padding(.leading, 12).frame(minWidth: 290)
    // Reserve a usable independently scrolling table; the page scrolls when needed.
    }.frame(height: max(360, viewport.height * 0.4))
    HStack {
     Text("\(result.files) файлов · \(result.symlinks) ссылок · \(result.hardlinks) hardlink · \(result.aliases) повторов каталогов · \(model.elapsed)").font(.caption)
     Button("Ошибки: \(result.errors)") { model.showIssues = true }
      .popover(isPresented: $model.showIssues) {
       ScrollView { LazyVStack(alignment: .leading) {
        Text("Недоступные / изменившиеся пути").font(.headline)
        ForEach(Array(result.issues.enumerated()), id: \.offset) { _, issue in Text("\(issue.path)\n\(issue.message)").textSelection(.enabled).padding(.bottom, 8) }
        if result.issues.isEmpty { Text("Ошибок чтения не зарегистрировано") }
       }.padding() }.frame(width: 650, height: 400)
      }
     Spacer()
     Text(result.status).font(.caption.bold()).foregroundStyle(result.root.complete ? Color.secondary : Color.orange)
    }
    if let path = model.selected {
     HStack { Text(path).font(.caption).lineLimit(1).truncationMode(.middle).textSelection(.enabled); Spacer(); Button("Показать в Finder") { model.reveal(path) } }.frame(height: 24)
    }
   } else {
    HStack(spacing: 12) {
     Image(systemName: model.scanning ? "externaldrive.badge.timemachine" : "folder.badge.questionmark").font(.system(size: 30)).foregroundStyle(.cyan.opacity(0.7))
     VStack(alignment: .leading, spacing: 3) {
      Text(model.scanning ? "Изучаем метаданные…" : "Выберите папку для анализа").font(.headline)
      Text("Анализ папок ничего не удаляет. Очистка кэшей — отдельно, с подтверждением.").font(.caption).foregroundStyle(.secondary)
     }
     Spacer(minLength: 0)
     Button { model.choose() } label: { Label("Выбрать папку", systemImage: "folder.badge.plus") }
    }.padding(10).background(InstrumentTheme.panel, in: RoundedRectangle(cornerRadius: 12))
   }
   Text("Анализ — только чтение; очистка 3 кэшей — с подтверждением · APFS-клоны и общие блоки не позволяют оценить освобождаемое место · Сеть по интерфейсам · Скорость диска и ватты: Н/Д")
    .font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
  }.padding(14).frame(maxWidth: .infinity)
 }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
 var status: ResourceStatusController?
 @objc func showAbout(_ sender: Any?) {
  MainActor.assumeIsolated { NSApplication.shared.orderFrontStandardAboutPanel(options: [.applicationVersion: "1.0.5"]) }
 }
 func applicationWillTerminate(_ notification: Notification) { MainActor.assumeIsolated { InternetTestWindow.shared.stop(); DiagnosticsWindow.shared.stop(); UpdateMenu.shared.stop(); status?.stop() } }
 func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
if CommandLine.arguments.contains("--self-check") {
 exit(runOfflineSelfCheck())
} else if CommandLine.arguments.contains("--server-snapshot") {
 printServerSnapshot()
} else if CommandLine.arguments.contains("--check-caches") {
 for report in CacheService().audit() {
  print("\(report.id.name)\t\(report.path)\t\(report.bytes.map(String.init) ?? "unknown") B\t\(report.error ?? report.disabledReason ?? (report.present ? "present" : "absent"))")
 }
} else if CommandLine.arguments.contains("--snapshot") {
 let sampler = ResourceSampler()
 _ = sampler.sample(volume: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
 Thread.sleep(forTimeInterval: 1)
 let sample = sampler.sample(volume: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
 print(sample.summary); print(sample.diskDetail)
} else if let index = CommandLine.arguments.firstIndex(of: "--scan"), CommandLine.arguments.count > index + 1 {
 let result = MacdirCore.Scanner.scan(URL(fileURLWithPath: CommandLine.arguments[index + 1]))
 print("logical=\(result.root.logical) allocated=\(result.root.allocated) files=\(result.files) symlinks=\(result.symlinks) errors=\(result.errors) limited=\(result.limited) complete=\(result.root.complete) aliases=\(result.aliases)")
 print(result.status)
 for child in result.root.children { print("\(child.path)\t\(child.logical) B\t\(child.state)") }
 for issue in result.issues { print("ERROR \(issue.path): \(issue.message)") }
} else {
 MainActor.assumeIsolated {
 let app = NSApplication.shared
 let delegate = AppDelegate()
 app.delegate = delegate
 app.setActivationPolicy(.regular)
 let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1180, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
 window.title = "diakitw — пространство и ресурсы"
 window.isReleasedWhenClosed = false
 window.contentMinSize = NSSize(width: 800, height: 540)
 let model = Model()
 window.contentView = NSHostingView(rootView: MacdirRootView(model: model))
 window.center(); window.makeKeyAndOrderFront(nil)
 delegate.status = ResourceStatusController(model: model, mainWindow: window)
 let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
 let appMenu = NSMenu(); appItem.submenu = appMenu
 DesktopActions.shared.addItems(to: appMenu)
 UpdateMenu.shared.addItems(to: appMenu)
 appMenu.addItem(withTitle: "О diakitw", action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "").target = delegate

 appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Завершить diakitw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
 app.mainMenu = menu
 UpdateMenu.shared.start()
 app.activate(ignoringOtherApps: true)
 withExtendedLifetime(delegate) { app.run() }
 }
}
