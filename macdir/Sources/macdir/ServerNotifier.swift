import Foundation
import UserNotifications

/// Локальные уведомления macOS. Приложение само сообщает о проблеме,
/// поэтому не нужно держать окно открытым, чтобы узнать о падении сервера.
final class ServerNotifier {
 static let shared = ServerNotifier()

 private(set) var authorized = false
 private var requested = false

 /// Спрашивает разрешение один раз; отказ не блокирует мониторинг.
 func requestAuthorizationIfNeeded() {
  guard !requested else { return }
  requested = true
  let center = UNUserNotificationCenter.current()
  center.getNotificationSettings { settings in
   switch settings.authorizationStatus {
   case .notDetermined:
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
     DispatchQueue.main.async { ServerNotifier.shared.authorized = granted }
    }
   case .authorized, .provisional, .ephemeral:
    DispatchQueue.main.async { ServerNotifier.shared.authorized = true }
   default:
    DispatchQueue.main.async { ServerNotifier.shared.authorized = false }
   }
  }
 }

 /// Публикует событие. Идентификатор уникален по времени, чтобы macOS
 /// не склеивал разные тревоги в одну.
 func post(_ alert: ServerAlert) {
  let content = UNMutableNotificationContent()
  content.title = alert.title
  content.body = alert.body
  if alert.kind.isProblem { content.sound = .default }
  let identifier = alert.serverID + ":" + alert.kind.rawValue + ":" + String(Int(Date().timeIntervalSince1970))
  let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
  UNUserNotificationCenter.current().add(request)
 }
}
