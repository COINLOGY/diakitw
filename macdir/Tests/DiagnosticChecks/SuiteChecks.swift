import Foundation
import MacdirCore

func suiteChecks() {
 let plan = DiagnosticPlan.preset("quick")
 check(plan.stages.map(\.mode) == ["cpu", "ram", "gpu"], "explicit sequence")
 check(plan.workSeconds == 15 && plan.waitBudget == 19.5, "total includes runner cleanup allowance")
 var suite = DiagnosticSequence(plan: plan, now: 100)
 let first = suite.next(now: 100, cancelled: false, thermal: false)!
 check(suite.next(now: 100, cancelled: false, thermal: false) == nil, "one active helper")
 check(!suite.complete(id: UUID(), succeeded: true), "reject stale completion")
 check(suite.complete(id: first.id, succeeded: true), "accept current")
 check(suite.next(now: 101, cancelled: true, thermal: false) == nil && suite.stopReason == "cancelled", "cancel between stages")
 for cause in ["error", "thermal", "timeout"] {
  var s = DiagnosticSequence(plan: plan, now: 0)
  if cause == "error" { let r = s.next(now: 0, cancelled: false, thermal: false)!; _ = s.complete(id: r.id, succeeded: false) }
  check(s.next(now: cause == "timeout" ? 20 : 1, cancelled: false, thermal: cause == "thermal") == nil, "stop suite: \(cause)")
 }
 let stage = plan.stages[0]
 let data = Data("{\"mode\":\"cpu\",\"status\":\"completed\",\"batches\":1,\"verified\":128,\"errors\":0,\"allocatedBytes\":0,\"checksum\":\"810944\",\"elapsed\":0.01,\"device\":\"\",\"secret\":\"DO_NOT_EXPORT\"}".utf8)
 let run = DiagnosticRunReport(stage: stage, reason: .finished, exitCode: 0, data: data, elapsed: 0.02)
 check(run.outcome == DiagnosticStatus.completed.rawValue && run.worker?.verified == 128, "typed facts")
 let report = DiagnosticSessionReport(plan: plan, model: "fixture-model", os: "fixture-os", architecture: "arm64", appleCode: "ADP000", runs: [run])
 let json = String(data: try! report.json(), encoding: .utf8)!
 let object = try! JSONSerialization.jsonObject(with: report.json()) as! [String: Any]
 check(object["product"] as? String == "diakitw" && report.text.hasPrefix("diakitw ·"), "export product identity")
 check(!json.contains("DO_NOT_EXPORT") && json.contains("fixture-model") && report.text.contains("128"), "allowlisted export and shared facts")
 check(report.text.contains("256") && report.text.contains("user_reported"), "RAM limitation and manual provenance")
 let manual = DiagnosticSessionReport(plan: plan, model: "fixture", os: "fixture", architecture: "arm64", appleCode: "adp000")
 check(manual.appleCode == "adp000", "preserve manual identifier, never silently repair")
 for payload in [Data(), Data("{}".utf8), Data("null".utf8)] {
  check(DiagnosticRunReport(stage: stage, reason: .finished, exitCode: 0, data: payload, elapsed: 0).outcome != DiagnosticStatus.completed.rawValue, "invalid never pass")
 }
 print("Diagnostic sequence / export fixtures PASS")
}
