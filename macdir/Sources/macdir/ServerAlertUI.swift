import SwiftUI
import MacdirCore

/// Кнопка-режим: включённая подсвечена акцентом, выключенная читается как контур.
/// Один вид для всех переключателей, чтобы состояние было видно с первого взгляда.
struct ModeChip: View {
 let title: String
 let systemImage: String?
 let isOn: Bool
 let action: () -> Void

 init(title: String, systemImage: String? = nil, isOn: Bool, action: @escaping () -> Void) {
  self.title = title
  self.systemImage = systemImage
  self.isOn = isOn
  self.action = action
 }

 var body: some View {
  Button(action: action) {
   HStack(spacing: 4) {
    if let systemImage {
     Image(systemName: systemImage).font(.system(size: 9, weight: .semibold))
    }
    Text(title).font(.system(size: 11, weight: isOn ? .semibold : .regular)).lineLimit(1)
   }
   .padding(.horizontal, 8).padding(.vertical, 3)
   .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
   .background(Capsule().fill(isOn ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.07)))
   .overlay(Capsule().strokeBorder(isOn ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.25),
                                   lineWidth: isOn ? 1.2 : 0.5))
  }
  .buttonStyle(.plain)
  .accessibilityAddTraits(isOn ? [.isSelected] : [])
  .help(isOn ? "Режим включён" : "Нажмите, чтобы включить")
 }
}

/// Настройка порогов оповещений.
struct ServerAlertSettingsSheet: View {
 @ObservedObject var model: ServersModel
 @Environment(\.dismiss) private var dismiss

 var body: some View {
  VStack(alignment: .leading, spacing: 14) {
   Text("Оповещения").font(.headline)
   Text(model.alertsAuthorized
        ? "Уведомления macOS разрешены. События приходят, даже когда окно закрыто."
        : "Уведомления macOS не разрешены. Разрешите их в Системных настройках → Уведомления → diakitw.")
    .font(.caption).foregroundStyle(model.alertsAuthorized ? Color.secondary : Color.orange)
    .fixedSize(horizontal: false, vertical: true)

   Divider()

   Toggle("Сервер не отвечает", isOn: binding(\.offlineEnabled))
   Stepper("Подряд неудачных замеров: \(model.alertSettings.offlinePolls)",
           value: binding(\.offlinePolls), in: 2...12)
    .disabled(!model.alertSettings.offlineEnabled)
    .font(.caption)

   Toggle("Перегрузка процессора", isOn: binding(\.cpuEnabled))
   HStack(spacing: 8) {
    Text("Порог").font(.caption)
    Slider(value: binding(\.cpuThreshold), in: 50...100, step: 5)
    Text("\(Int(model.alertSettings.cpuThreshold)) %")
     .font(.caption.monospacedDigit()).frame(width: 44, alignment: .trailing)
   }.disabled(!model.alertSettings.cpuEnabled)
   Stepper("Подряд замеров выше порога: \(model.alertSettings.cpuPolls)",
           value: binding(\.cpuPolls), in: 2...30)
    .disabled(!model.alertSettings.cpuEnabled)
    .font(.caption)

   Toggle("Мало места на диске", isOn: binding(\.diskEnabled))
   HStack(spacing: 8) {
    Text("Свободно ниже").font(.caption)
    Slider(value: binding(\.diskFreeThreshold), in: 1...50, step: 1)
    Text("\(Int(model.alertSettings.diskFreeThreshold)) %")
     .font(.caption.monospacedDigit()).frame(width: 44, alignment: .trailing)
   }.disabled(!model.alertSettings.diskEnabled)

   Divider()

   Text("Тревога снимается сама: связь восстановилась, нагрузка спала, место освободилось. Повторов нет — событие только на переходе.")
    .font(.caption2).foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)

   HStack {
    Button("Проверить") { model.sendTestAlert() }
    Spacer()
    Button("Готово") { dismiss() }.keyboardShortcut(.defaultAction)
   }
  }
  .padding(20)
  .frame(width: 470)
  .onAppear { model.requestNotifications() }
 }
}

extension ServerAlertSettingsSheet {
 /// Любое изменение сразу сохраняется: отдельной кнопки «применить» нет.
 private func binding<T>(_ keyPath: WritableKeyPath<ServerAlertSettings, T>) -> Binding<T> {
  Binding(get: { model.alertSettings[keyPath: keyPath] },
          set: { value in
           var settings = model.alertSettings
           settings[keyPath: keyPath] = value
           model.applyAlerts(settings)
          })
 }
}
