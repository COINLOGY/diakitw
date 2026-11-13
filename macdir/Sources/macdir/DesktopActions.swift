import AppKit

@MainActor final class DesktopActions: NSObject {
 static let shared = DesktopActions()
 private let resolve: (String) -> URL?
 private let launch: (URL) -> Void
 private let openURL: (URL) -> Void
 init(resolve: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
      launch: @escaping (URL) -> Void = { NSWorkspace.shared.openApplication(at: $0, configuration: NSWorkspace.OpenConfiguration()) { _, error in if error != nil { DispatchQueue.main.async { NSSound.beep() } } } },
      openURL: @escaping (URL) -> Void = { if !NSWorkspace.shared.open($0) { NSSound.beep() } }) {
  self.resolve = resolve; self.launch = launch; self.openURL = openURL
 }
 func addItems(to menu: NSMenu) {
  let terminal = menu.addItem(withTitle: "Терминал", action: #selector(terminal), keyEquivalent: "")
  terminal.target = self
  let processes = menu.addItem(withTitle: "Мониторинг системы (процессы)", action: #selector(processes), keyEquivalent: "")
  processes.target = self
  processes.toolTip = "Для наиболее загруженных процессов выберите CPU и нажмите столбец % CPU. Сортировку задаёт пользователь."
 }
 @objc func terminal() { launchRegistered("com.apple.Terminal") }
 @objc func processes() { launchRegistered("com.apple.ActivityMonitor") }
 private func launchRegistered(_ id: String) {
  guard let url = resolve(id) else { NSSound.beep(); return }
  launch(url)
 }
 func openMap(_ url: URL) {
  guard url.scheme == "https", url.host == "maps.apple.com", url.user == nil, url.password == nil, url.port == nil else { return }
  openURL(url)
 }
}
