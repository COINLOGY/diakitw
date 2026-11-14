import AppKit
import SwiftUI
import Combine
import MacdirCore

@MainActor final class UpdateMenu: NSObject {
    static let shared = UpdateMenu()
    let checker = UpdateChecker()
    private var entries: [NSMenuItem] = []
    private var subscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var window: NSWindow?
    func addItems(to menu: NSMenu) {
        let entry = menu.addItem(withTitle: "Проверить обновления…", action: #selector(show), keyEquivalent: "")
        entry.target = self; entries.append(entry)
    }
    func start() {
        subscription = checker.$offer.sink { [weak self] value in
            for entry in self?.entries ?? [] { entry.title = value.map { "Доступна diakitw \($0.version)…" } ?? "Проверить обновления…" }
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification, NSApplication.didHideNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.checker.setForeground(note.name == NSApplication.didBecomeActiveNotification) }
            })
        }
        checker.setForeground(NSApp.isActive)
    }
    func stop() {
        checker.setForeground(false); checker.cancel()
        subscription?.cancel(); subscription = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers = []
    }
    @objc func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 330), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "diakitw · Обновления"; w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: UpdatePane(checker: checker)); w.center(); window = w
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        checker.check()
    }
}

private struct UpdatePane: View {
    @ObservedObject var checker: UpdateChecker
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("diakitw 0.5.5a (55)").font(.headline)
            Picker("Канал", selection: Binding(get: { checker.channel }, set: { checker.choose($0) })) {
                Text("Preview").tag("preview"); Text("Stable").tag("stable")
            }.pickerStyle(.segmented)
            Text(checker.status).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let offer = checker.offer {
                ScrollView { Text(verbatim: offer.notes).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 70)
                HStack {
                    Button("Скачать в браузере") { NSWorkspace.shared.open(offer.url) }
                    Button("Позже") { checker.later() }
                }
            }
            Button("Проверить обновления") { checker.check() }.disabled(checker.checking)
            Text("Проверка при активном приложении: раз в 24 ч. GitHub получает обычный HTTPS-запрос без метрик и параметров. Скачивание — только в браузере; установка вручную. Подпись и хеш скачанного файла здесь не проверяются. Без автозамены и перезапуска.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(width: 454)
        .onDisappear { checker.cancel() }
    }
}
