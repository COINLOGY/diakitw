import Foundation

public struct DiagnosticStage: Codable, Identifiable {
 public let id: UUID
 public let mode: String
 public let limits: DiagnosticLimits
 public init(mode: String, limits: DiagnosticLimits) { id = UUID(); self.mode = mode; self.limits = limits }
}
public struct DiagnosticPlan: Codable {
 public let presetID: String
 public let stages: [DiagnosticStage]
 public init(presetID: String, modes: [String], limits: DiagnosticLimits) {
  self.presetID = presetID
  stages = ["cpu", "ram", "gpu"].filter { modes.contains($0) }.map { DiagnosticStage(mode: $0, limits: limits) }
 }
 public static func preset(_ id: String) -> DiagnosticPlan {
  DiagnosticPlan(presetID: id, modes: id == "memory" ? ["ram"] : id == "graphics" ? ["gpu"] : ["cpu", "ram", "gpu"], limits: DiagnosticLimits(seconds: id == "memory" ? 10 : 5, duty: 10, mebibytes: id == "memory" ? 32 : 16))
 }
 public var workSeconds: Int { stages.reduce(0) { $0 + $1.limits.seconds } }
 // Per stage: runner timeout +1s, escalation 0.3s, polling/scheduling allowance 0.2s.
 // OS scheduling/driver hangs cannot be given a strict wall-clock guarantee.
 public var waitBudget: Double { Double(workSeconds) + Double(stages.count) * 1.5 }
}
public struct DiagnosticSequence {
 public let plan: DiagnosticPlan
 public let deadline: Double
 public private(set) var stopReason: String?
 private var index = 0
 private var active: UUID?
 public init(plan: DiagnosticPlan, now: Double) { self.plan = plan; deadline = now + plan.waitBudget }
 public mutating func next(now: Double, cancelled: Bool, thermal: Bool) -> DiagnosticStage? {
  guard active == nil, stopReason == nil else { return nil }
  if cancelled { stopReason = "cancelled"; return nil }
  if thermal { stopReason = "thermal"; return nil }
  if now >= deadline { stopReason = "timeout"; return nil }
  guard index < plan.stages.count else { return nil }
  let stage = plan.stages[index]; active = stage.id; return stage
 }
 @discardableResult public mutating func complete(id: UUID, succeeded: Bool) -> Bool {
  guard active == id else { return false }
  active = nil; index += 1
  if !succeeded { stopReason = "previous_stage_not_completed" }
  return true
 }
}


// Explicit allowlist: never persist raw worker stdout/stderr or environment.
public struct DiagnosticWorkerFacts: Codable {
 public let mode: String, status: String
 public let batches: Int, verified: Int, errors: Int, allocatedBytes: Int
 public let checksum: String, elapsed: Double, device: String
 var valid: Bool { ["cpu", "ram", "gpu"].contains(mode) && batches >= 0 && verified >= 0 && errors >= 0 && allocatedBytes >= 0 && elapsed.isFinite && elapsed >= 0 && UInt64(checksum) != nil }
}
public struct DiagnosticRunReport: Codable, Identifiable {
 public var id: UUID { stage.id }
 public let stage: DiagnosticStage
 public let recordedAt: Date
 public let elapsed: Double
 public let runnerReason: String
 public let exitCode: Int32?
 public let worker: DiagnosticWorkerFacts?
 public let outcome: String
 public let text: String
 public init(stage: DiagnosticStage, reason: InternetProcess.Reason, exitCode: Int32, data: Data, elapsed: Double) {
  self.stage = stage; recordedAt = Date(); self.elapsed = max(0, elapsed); runnerReason = reason.rawValue; self.exitCode = exitCode
  let decoded = try? JSONDecoder().decode(DiagnosticWorkerFacts.self, from: data)
  worker = decoded.flatMap { $0.valid && $0.mode == stage.mode ? $0 : nil }
  let clean = worker.flatMap { try? JSONEncoder().encode($0) } ?? Data()
  let summary = DiagnosticSummary.make(mode: stage.mode, limits: stage.limits, reason: reason, exitCode: exitCode, data: clean, elapsed: elapsed)
  outcome = summary.status.rawValue; text = summary.text
 }
 public init(stage: DiagnosticStage, skipped: String) {
  self.stage = stage; recordedAt = Date(); elapsed = 0; runnerReason = skipped; exitCode = nil; worker = nil; outcome = "skipped"
  text = "\(stage.mode.uppercased()): skipped — \(skipped). Не запускался; счётчики неизвестны."
 }
}
public struct DiagnosticSessionReport: Codable, Identifiable {
 public let schemaVersion: Int
 public let product: String
 public let id: UUID
 public let createdAt: Date
 public let plan: DiagnosticPlan
 public let model: String, os: String, architecture: String
 public let appleCode: String
 public let appleCodeSource: String
 public var runs: [DiagnosticRunReport]
 public let limitations: String
 public let notSelected: [String]
 public init(plan: DiagnosticPlan, model: String, os: String, architecture: String, appleCode: String, runs: [DiagnosticRunReport] = []) {
  schemaVersion = 1; product = "diakitw"; id = UUID(); createdAt = Date(); self.plan = plan; self.model = model; self.os = os; self.architecture = architecture
  self.appleCode = appleCode; appleCodeSource = "user_reported"; self.runs = runs
  notSelected = ["cpu", "ram", "gpu"].filter { mode in !plan.stages.contains { $0.mode == mode } }
  limitations = "RAM: известное ограничение алгоритма v1 — период адресного шаблона 256 байт, индекс локален для чанка; смена AA/55 при неполном чанке не гарантирует полный проход. Полные проходы и уникальные проверенные байты не измеряются. Только виртуальный буфер, возможны cache/compression/swap, не MemTest/ECC. CPU: один целочисленный поток, не все ядра/инструкции. GPU: только default Metal compute/readback, не рендер/VRAM/FurMark; Intel discrete runtime не проверен. ThermalState — не температура. Уже отправленную GPU-команду нельзя отозвать. Не проверяются диск, экран, порты, периферия, автономность. Это не сертификат исправности и не исключает периодические неисправности."
 }
 public var text: String {
  "diakitw · протокол v\(schemaVersion) · \(id)\n\(ISO8601DateFormatter().string(from: createdAt))\nМодель: \(model) · OS: \(os) · архитектура процесса: \(architecture)\nPreset: \(plan.presetID); нагрузка суммарно \(plan.workSeconds) с; бюджет ожидания \(plan.waitBudget) с (плановый предел; задержки ОС не гарантируются).\nnot_selected: \(notSelected.joined(separator: ", "))\nApple Diagnostics: \(appleCode.isEmpty ? "не указан" : appleCode) [\(appleCodeSource)]\n\n" + runs.map(\.text).joined(separator: "\n\n———\n\n") + "\n\nОграничения: " + limitations
 }
 public func json() throws -> Data {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
  return try encoder.encode(self)
 }
}

public struct DiagnosticBatch {
 public var checksum: UInt64 = 0
 public var operations = 0
 public var errors = 0
 public var cancelled = false
}
public enum DiagnosticWork {
 public static func cpuMatches(checksum: UInt64, seed: UInt64, count: Int) -> Bool { checksum == expectedCPU(seed: seed, count: count) }
 @inline(never) public static func cpu(seed: UInt64, count: Int, cancelled: () -> Bool) -> DiagnosticBatch {
  var r = DiagnosticBatch()
  for i in 0..<max(0, min(count, 16384)) {
   if i % 256 == 0 && cancelled() { r.cancelled = true; break }
   let x = UInt64(i) &+ seed
   r.checksum = r.checksum &+ (x &* x); r.operations += 1
  }
  return r
 }
 public static func expectedCPU(seed: UInt64, count: Int) -> UInt64 {
  let n = UInt64(max(0, min(count, 16384)))
  guard n > 0 else { return 0 }
  return n &* seed &* seed &+ seed &* n &* (n - 1) &+ n &* (n - 1) &* (2 * n - 1) / 6
 }
 public static func pattern(_ index: Int, seed: UInt8) -> UInt8 { UInt8(truncatingIfNeeded: index &* 31) ^ seed }
 public static func fill(_ bytes: UnsafeMutableBufferPointer<UInt8>, seed: UInt8, cancelled: () -> Bool) -> Bool {
  for i in bytes.indices {
   if i % 4096 == 0 && cancelled() { return false }
   bytes[i] = pattern(i, seed: seed)
  }
  return true
 }
 public static func verify(_ bytes: UnsafeMutableBufferPointer<UInt8>, seed: UInt8, cancelled: () -> Bool) -> DiagnosticBatch {
  var r = DiagnosticBatch()
  for i in bytes.indices {
   if i % 4096 == 0 && cancelled() { r.cancelled = true; break }
   if bytes[i] != pattern(i, seed: seed) { r.errors += 1 }
   r.operations += 1
  }
  return r
 }
}

public struct DiagnosticLimits: Codable {
 public let seconds: Int
 public let duty: Int
 public let mebibytes: Int
 public init(seconds: Int = 5, duty: Int = 10, mebibytes: Int = 16) {
  self.seconds = min(30, max(1, seconds))
  self.duty = min(25, max(1, duty))
  self.mebibytes = min(64, max(1, mebibytes))
 }
 public static func allowedBytes(requested: Int, available: UInt64) -> Int {
  Int(min(UInt64(max(0, min(requested, 64 * 1048576))), available / 8))
 }
}
