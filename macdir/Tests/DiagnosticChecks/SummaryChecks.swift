import Foundation
import MacdirCore

func summaryChecks() {
 let payload = Data(#"{"mode":"cpu","status":"completed","batches":2,"verified":32768,"errors":0,"allocatedBytes":0,"checksum":"1234","elapsed":0.75,"device":""}"#.utf8)
 let report = DiagnosticSummary.make(mode: "cpu", limits: DiagnosticLimits(), reason: .finished, exitCode: 0, data: payload, elapsed: 0.9)
 check(report.status == .completed, "completed outcome")
 check(report.text.contains("32768") && report.text.contains("1234") && report.text.contains("0.75"), "actual worker metrics")
 check(report.text.contains("Вывод:") && report.text.contains("не доказывает исправность"), "bounded conclusion")
 check(report.text.contains("5 с") && report.text.contains("10%"), "requested settings")
 check(DiagnosticSummary.make(mode: "ram", limits: DiagnosticLimits(), reason: .finished, exitCode: 0, data: payload, elapsed: 1).status == .error, "mode mismatch fails closed")
 for (reason, code, expected) in [(InternetProcess.Reason.cancelled, Int32(137), DiagnosticStatus.cancelled), (.timeout, 143, .timeout), (.finished, 75, .thermal), (.finished, 76, .timeout), (.finished, 69, .unavailable), (.launchFailed, -1, .unavailable), (.finished, 74, .parentExited), (.outputLimit, 0, .error), (.finished, 70, .error)] {
  let stopped = DiagnosticSummary.make(mode: "cpu", limits: DiagnosticLimits(), reason: reason, exitCode: code, data: Data(), elapsed: 0.2)
  check(stopped.status == expected, "stop reason \(reason) / \(code)")
  check(stopped.text.contains("неизвестен") && !stopped.text.contains("ошибок 0"), "missing metrics never zero")
  check(stopped.text.contains("Причина:"), "explicit reason")
 }
 for mode in ["cpu", "ram", "gpu"] {
  for (worker, code, errors, verified, expected) in [("completed", 0, 0, 10, DiagnosticStatus.completed), ("verification-error", 70, 1, 10, .error), ("no-work", 70, 0, 0, .error), ("completed", 0, 1, 10, .error), ("completed", 0, 0, 0, .error), ("unexpected", 0, 0, 10, .error)] {
   let data = try! JSONSerialization.data(withJSONObject: ["mode": mode, "status": worker, "batches": 1, "verified": verified, "errors": errors, "allocatedBytes": 1024, "checksum": "42", "elapsed": 0.25, "device": "fixture"])
   let report = DiagnosticSummary.make(mode: mode, limits: DiagnosticLimits(), reason: .finished, exitCode: Int32(code), data: data, elapsed: 0.3)
   check(report.status == expected, "worker outcome")
   if mode == "ram" { check(report.text.contains("только выделенного буфера") && !report.text.contains("Checksum (сумма)"), "RAM honest scope / no uncomputed checksum") }
   if mode == "gpu" { check(report.text.contains("не полный тест VRAM") && report.text.contains("readback"), "GPU scope") }
   if verified == 0 { check(report.text.contains("проверки не выполнены"), "no-work distinct") }
   if errors > 0 { check(report.text.contains("Обнаружены несовпадения"), "evidence-specific error conclusion") }
  }
 }
 let malformed = DiagnosticSummary.make(mode: "cpu", limits: DiagnosticLimits(), reason: .finished, exitCode: 0, data: Data("{}".utf8), elapsed: 0)
 check(malformed.status == .error, "malformed fails closed")
 for thermal in [false, true] {
  let report = DiagnosticSummary.notStarted(mode: "ram", limits: DiagnosticLimits(), thermal: thermal)
  check(report.status == (thermal ? .thermal : .unavailable), "preflight status")
  check(report.text.contains("не выполнялись") && !report.text.contains("exit:") && report.text.contains("Время: не запускался"), "preflight has no fabricated process result")
 }
 print("Diagnostic summary all statuses / scopes fixtures PASS")
}
