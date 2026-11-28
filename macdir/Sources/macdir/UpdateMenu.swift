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
    private var prompt: NSPanel?
    func addItems(to menu: NSMenu) {
        let entry = menu.addItem(withTitle: "Проверить обновления…", action: #selector(show), keyEquivalent: "")
        entry.target = self; entries.append(entry)
    }
    func start() {
        subscription = checker.$offer.sink { [weak self] value in
            self?.receive(value)
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification, NSApplication.didHideNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    if note.name != NSApplication.didBecomeActiveNotification { self?.prompt?.close(); self?.prompt = nil }
                    self?.checker.setForeground(note.name == NSApplication.didBecomeActiveNotification)
                }
            })
        }
        checker.setForeground(NSApp.isActive)
    }
    func stop() {
        checker.setForeground(false); checker.cancel()
        prompt?.close(); prompt = nil
        subscription?.cancel(); subscription = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers = []
    }
    private func receive(_ value: UpdateContract.Offer?) {
        for entry in entries { entry.title = value.map { "Доступна diakitw \($0.version)…" } ?? "Проверить обновления…" }
        guard let offer = value else { prompt?.close(); prompt = nil; return }
        // Manual checks display their results in the updates window, not in a second prompt.
        guard NSApp.isActive, window?.isVisible != true, prompt?.isVisible != true,
              UpdateOfferPromptPolicy.shouldShow(version: offer.version, build: offer.build, defaults: .standard) else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 124),
                            styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Обновление diakitw"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: UpdateOfferPrompt(version: offer.version,
            details: { [weak self] in self?.prompt?.close(); self?.show() },
            later: { [weak self] in self?.prompt?.close(); self?.checker.later() }))
        let area = (NSApp.mainWindow?.screen ?? NSScreen.main)?.visibleFrame
        if let area { panel.setFrameOrigin(NSPoint(x: area.maxX - panel.frame.width - 24,
                                                  y: area.maxY - panel.frame.height - 24)) }
        panel.orderFront(nil)
        prompt = panel
        if panel.isVisible {
            UpdateOfferPromptPolicy.markShown(version: offer.version, build: offer.build, defaults: .standard)
        }
    }
    @objc func show() {
        prompt?.close(); prompt = nil
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 330), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "diakitw · Обновления"; w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: UpdatePane(checker: checker)); w.center(); window = w
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        checker.check()
    }
}

private struct UpdateOfferPrompt: View {
    let version: String
    let details: () -> Void
    let later: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Доступна diakitw \(version)").font(.headline)
            Text("Подробности и скачивание — в окне обновлений. Установка вручную.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Подробнее", action: details)
                Button("Позже", action: later)
            }
        }.padding(14).frame(width: 310)
    }
}

private struct UpdatePane: View {
    @ObservedObject var checker: UpdateChecker
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("diakitw 1.0.7 (107)").font(.headline)
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
            Text("Проверка при каждом новом запуске; при дальнейшей работе активного приложения — раз в 24 ч. GitHub получает обычный HTTPS-запрос без метрик и параметров. Скачивание — только в браузере; установка вручную. Подпись и хеш скачанного файла здесь не проверяются. Без автозамены и перезапуска.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(width: 454)
        .onDisappear { checker.cancel() }
    }
}
