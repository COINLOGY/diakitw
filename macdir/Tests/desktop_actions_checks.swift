import AppKit
@main struct Checks {
 @MainActor static func main() {
  let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
  var calls: [String] = []
  let actions = DesktopActions(resolve: { id in calls.append(id); return URL(fileURLWithPath: "/fixture/" + id + ".app") }, launch: { url in calls.append(url.lastPathComponent) }, openURL: { url in calls.append(url.host!) })
  precondition(calls.isEmpty)
  let menu = NSMenu(); actions.addItems(to: menu)
  precondition(menu.items.map(\.title) == ["Терминал", "Мониторинг системы (процессы)"])
  for item in menu.items { precondition(app.sendAction(item.action!, to: item.target, from: item)) }
  precondition(calls == ["com.apple.Terminal", "com.apple.Terminal.app", "com.apple.ActivityMonitor", "com.apple.ActivityMonitor.app"])
  actions.openMap(URL(string: "https://evil.invalid/")!)
  precondition(calls.count == 4)
  actions.openMap(URL(string: "https://maps.apple.com/?q=A%26B")!)
  precondition(calls.last == "maps.apple.com")
  for id in ["com.apple.Terminal", "com.apple.ActivityMonitor"] {
   guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), Bundle(url: url)?.bundleIdentifier == id else { fatalError("Missing registered app " + id) }
   print("REGISTERED (not launched):", id, url.path)
  }
  print("PASS menu invocation with mocked launch and map allowlist; no auto-launch")
 }
}
