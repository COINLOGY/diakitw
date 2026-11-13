import Foundation

public enum DiagnosticStatus: String, CaseIterable {
 case completed = "Завершено", error = "Ошибка", cancelled = "Отменено"
 case thermal = "Остановлено: нагрев", timeout = "Тайм-аут", unavailable = "Недоступно"
 case parentExited = "Остановлено: завершён родитель"
}
private struct DiagnosticResult: Decodable {
 let mode: String, status: String
 let batches: Int, verified: Int, errors: Int, allocatedBytes: Int
 let checksum: String, elapsed: Double, device: String
 func valid(for requested: String) -> Bool {
  mode == requested && ["cpu", "ram", "gpu"].contains(mode) && batches >= 0 && verified >= 0 && errors >= 0 && allocatedBytes >= 0 && elapsed.isFinite && elapsed >= 0 && UInt64(checksum) != nil
 }
}
public struct DiagnosticSummary {
 public let status: DiagnosticStatus
 public let text: String
 public static func notStarted(mode: String, limits: DiagnosticLimits, thermal: Bool) -> DiagnosticSummary {
  let status: DiagnosticStatus = thermal ? .thermal : .unavailable
  let cause = thermal ? "thermalState serious/critical до старта" : "DiagnosticWorker отсутствует"
  return DiagnosticSummary(status: status, text: "Тест: \(mode.uppercased())\n\nНастройки: бюджет \(limits.seconds) с; целевой duty \(limits.duty)% (не измеренная загрузка); лимит RAM \(limits.mebibytes) МиБ.\n\nСтатус: \(status.rawValue) · не запущено\n\nПричина: \(cause)\n\nВремя: не запускался. Проверки не выполнялись; счётчиков/checksum нет.\n\nВывод: данных для заключения об оборудовании нет.")
 }
 public static func make(mode: String, limits: DiagnosticLimits, reason: InternetProcess.Reason, exitCode: Int32, data: Data, elapsed: Double) -> DiagnosticSummary {
  let decoded = try? JSONDecoder().decode(DiagnosticResult.self, from: data)
  let r = decoded.flatMap { $0.valid(for: mode) ? $0 : nil }
  let status: DiagnosticStatus
  let explanation: String
  switch reason {
  case .cancelled: status = .cancelled; explanation = "Отмена пользователем / закрытие окна; worker остановлен."
  case .timeout: status = .timeout; explanation = "Внешний предел ожидания процесса."
  case .launchFailed: status = .unavailable; explanation = "Рабочий процесс не запущен."
  case .outputLimit: status = .error; explanation = "Превышен лимит вывода worker."
  case .finished:
   switch exitCode {
   case 75: status = .thermal; explanation = "thermalState serious/critical; это не измерение температуры."
   case 76: status = .timeout; explanation = "Watchdog / незавершённая команда GPU / бюджет до начала работы."
   case 69: status = .unavailable; explanation = "Недостаточно доступной памяти либо недоступны Metal/ядро."
   case 74: status = .parentExited; explanation = "Watchdog обнаружил завершение родителя."
   case 0 where r?.status == "completed" && (r?.verified ?? 0) > 0 && r?.errors == 0:
    status = .completed; explanation = "Worker подтвердил завершение ограниченной проверки."
   default: status = .error; explanation = r == nil ? "Отсутствующий, повреждённый или несоответствующий тесту отчёт." : "Ошибка проверки либо неполный/противоречивый отчёт worker."
   }
  }
  let name = mode == "ram" ? "RAM · частичная проверка буфера" : (mode == "gpu" ? "GPU · Metal compute" : "CPU · один поток")
  let scope = mode == "ram" ? "Запись шаблонов AA/55 с адресной составляющей и чтение только выделенного буфера; байты включают повторные проверки. Не вся RAM, не загрузочный MemTest и не проверка ECC." : (mode == "gpu" ? "Вычисления Metal и сравнение UInt32 readback с независимым эталоном CPU. Не FurMark, не графический рендер/видеодекодер и не полный тест VRAM." : "Целочисленные суммы квадратов одного потока; сравнение checksum каждого пакета с независимой формулой. Не все ядра и не все инструкции CPU.")
  let settings = "Бюджет: \(limits.seconds) с · целевой duty: \(limits.duty)% (не измеренная загрузка)" + (mode == "ram" ? " · RAM ≤ \(limits.mebibytes) МиБ и 1/8 свободных страниц" : "")
  var lines = ["Тест: \(name)", "Настройки: \(settings)", "Статус: \(status.rawValue)", "Время запуска/ожидания: \(format(elapsed)) с (монотонные часы)"]
  lines.append("Причина: \(explanation) [runner: \(reason.rawValue), exit: \(exitCode)]")
  if let r {
   if r.verified == 0 { lines.append("Подтверждённые проверки не выполнены (проверено 0); это не успешный тест.") }
   lines.append("Время worker: \(format(r.elapsed)) с")
   lines.append("Что проверялось: \(scope)")
   let unit = mode == "ram" ? "байт (с повторениями)" : (mode == "gpu" ? "значений UInt32 readback" : "слагаемых checksum")
   lines.append("Факты worker: пакетов \(r.batches); проверено \(r.verified) \(unit); ошибок \(r.errors).")
   if mode != "cpu" { lines.append("Выделенный буфер: \(r.allocatedBytes) байт (не объём уникально проверенной памяти).") }
   if mode != "ram" { lines.append("Checksum (сумма): \(r.checksum)") }
   if !r.device.isEmpty { lines.append("Устройство: \(r.device)") }
   lines.append("Ответ worker: \(r.status)")
  } else {
   lines.append("Счётчики, checksum и время worker: нет достоверного отчёта; объём выполненных проверок неизвестен.")
   lines.append("Область выбранного теста (не подтверждение выполнения): \(scope)")
  }
  let conclusion: String
  if (r?.errors ?? 0) > 0 { conclusion = "Обнаружены несовпадения в выполненных проверках. Это повод для дополнительной диагностики, не определение неисправного компонента." }
  else if status == .completed { conclusion = "В выполненном объёме ошибок не обнаружено. Ограниченный тест не доказывает исправность оборудования." }
  else { conclusion = "Тест не завершён успешно; данных для вывода об исправности недостаточно." }
  lines.append("Вывод: " + conclusion)
  return DiagnosticSummary(status: status, text: lines.joined(separator: "\n\n"))
 }
 private static func format(_ value: Double) -> String { value.isFinite && value >= 0 ? String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value) : "Н/Д" }
}
