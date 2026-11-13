import AppKit
import Combine
import MacdirCore

/// Native menu-bar item, not a floating window. Ordering belongs to macOS.
@MainActor final class ResourceStatusController: NSObject, NSMenuDelegate {
 private var item: NSStatusItem?
 private let model: Model
 private weak var mainWindow: NSWindow?
 private var subscription: AnyCancellable?
 private var diskMode = StatusPresentation.diskMode()
 private var diskToggle: NSMenuItem?
 private var ramMode = StatusPresentation.ramMode()
 private var ramToggle: NSMenuItem?
 private var visibilityToggles: [NSMenuItem] = []
 private var visibleIndices: [Int] { StatusPresentation.Metric.allCases.indices.filter { StatusPresentation.visible(StatusPresentation.Metric.allCases[$0]) } }
 private let details = (0..<8).map { _ in NSMenuItem(title: "", action: nil, keyEquivalent: "") }
 init(model: Model, mainWindow: NSWindow) {
  self.model = model; self.mainWindow = mainWindow
  super.init()
  // Size once from the same mixed typography used to draw every sample.
  let statusWidth = StatusTypography.width(indices: visibleIndices)
  let status = NSStatusBar.system.statusItem(withLength: statusWidth)
  item = status
  let menu = NSMenu(); menu.autoenablesItems = false; menu.delegate = self
  DesktopActions.shared.addItems(to: menu)
  menu.addItem(.separator())
  for detail in details { detail.isEnabled = false; menu.addItem(detail) }
  menu.addItem(.separator())
  let toggle = menu.addItem(withTitle: "Диск: свободно GiB вместо занятого %", action: #selector(toggleDiskMode), keyEquivalent: "")
  toggle.target = self; diskToggle = toggle
  let ram = menu.addItem(withTitle: "RAM: использовано GiB вместо %", action: #selector(toggleRAMMode), keyEquivalent: "")
  ram.target = self; ramToggle = ram
  menu.addItem(.separator())
  for (index, name) in ["CPU · процессор", "RAM · память", "SW · подкачка", "Диск", "↓ RX · приём", "↑ TX · передача"].enumerated() {
   let entry = menu.addItem(withTitle: "Показывать: " + name, action: #selector(toggleVisibility(_:)), keyEquivalent: "")
   entry.tag = index; entry.target = self; visibilityToggles.append(entry)
  }
  menu.addItem(.separator())
  let open = menu.addItem(withTitle: "Открыть diakitw", action: #selector(openMain), keyEquivalent: "")
  open.target = self
  menu.addItem(withTitle: "Завершить diakitw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
  status.menu = menu
  subscription = model.$snapshot.combineLatest(model.$selectedInterface).sink { [weak self] snapshot, interface in
   self?.update(snapshot, interface: interface)
  }
 }
 func stop() {
  subscription?.cancel(); subscription = nil
  if let item { NSStatusBar.system.removeStatusItem(item) }; item = nil
 }
 @objc private func openMain() {
  mainWindow?.deminiaturize(nil); mainWindow?.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
 }
 func menuWillOpen(_ menu: NSMenu) { update(model.snapshot, interface: model.selectedInterface) }
 @objc private func toggleDiskMode() {
  diskMode = diskMode == .occupied ? .free : .occupied
  StatusPresentation.saveDiskMode(diskMode)
  update(model.snapshot, interface: model.selectedInterface)
 }
 @objc private func toggleRAMMode() {
  ramMode = ramMode == .percent ? .used : .percent
  StatusPresentation.saveRAMMode(ramMode)
  update(model.snapshot, interface: model.selectedInterface)
 }
 @objc private func toggleVisibility(_ sender: NSMenuItem) {
  let metric = StatusPresentation.Metric.allCases[sender.tag]
  StatusPresentation.saveVisible(!StatusPresentation.visible(metric), metric: metric)
  item?.length = StatusTypography.width(indices: visibleIndices)
  update(model.snapshot, interface: model.selectedInterface)
 }
 private func update(_ s: ResourceSnapshot, interface: String) {
  var colors: [NSColor] = []
  let segments = StatusPresentation.segments(s, interface: interface, diskMode: diskMode, ramMode: ramMode)
  diskToggle?.state = diskMode == .free ? .on : .off
  ramToggle?.state = ramMode == .used ? .on : .off
  for entry in visibilityToggles { entry.state = visibleIndices.contains(entry.tag) ? .on : .off }
  for (index, segment) in segments.enumerated() {
   var color: NSColor
   switch segment.band {
   case .green: color = .systemGreen
   case .blue: color = .systemBlue
   case .red: color = .systemRed
   case .unknown: color = .secondaryLabelColor
   }
   if segment.band != .unknown && index == 4 { color = NSColor(srgbRed: 0.65, green: 0.90, blue: 0.25, alpha: 1) }
   if segment.band != .unknown && index == 5 { color = NSColor(srgbRed: 0.30, green: 0.75, blue: 1.0, alpha: 1) }
   colors.append(color)
  }
  // Fixed geometry and font: live values never resize neighboring menu items.
  let indices = visibleIndices
  item?.button?.image = indices.isEmpty ? NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "diakitw — открыть меню") : nil
  item?.button?.attributedTitle = StatusTypography.title(indices.map { segments[$0].text }, colors: indices.map { colors[$0] })
  let n = s.networks.first { $0.name == interface }
  func rateDetail(_ value: Double?) -> String {
   return NetworkPresentation(value).text
  }
  let lines = [
   "CPU: " + MetricPresentation.percent(s.cpu) + " · \(ProcessInfo.processInfo.processorCount) логических ядер",
   "RAM: " + MetricPresentation.capacity(s.memoryUsed, total: s.memoryTotal),
   "SWAP: " + MetricPresentation.size(s.swap) + " · выделено сейчас " + MetricPresentation.size(s.swapTotal),
   "DSK · пул APFS: " + MetricPresentation.capacity(s.diskOccupied, total: s.diskTotal) + " · свободно " + MetricPresentation.size(s.diskFree),
   "↓ RX · \(interface): \(rateDetail(n?.received))",
   "↑ TX · \(interface): \(rateDetail(n?.sent))",
   "G = GiB · K = KiB/с · M = MiB/с · 000.0 · диск GiB: \(diskMode == .free ? "свободно" : "занято") · серые нули: нет замера · +: переполнение",
   "Порядок значков: удерживайте ⌘ и перетащите"
  ]
  for (detail, text) in zip(details, lines) { detail.title = text }
  item?.button?.toolTip = lines.prefix(6).joined(separator: "\n")
  item?.button?.setAccessibilityLabel("diakitw: " + lines.prefix(6).joined(separator: "; "))
 }
}
