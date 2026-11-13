import Foundation
import MacdirCore

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
check(DiagnosticLimits(seconds: 999, duty: 99, mebibytes: 999).seconds == 30, "time cap")
check(DiagnosticLimits(seconds: 0, duty: 0, mebibytes: 0).seconds == 1, "minimum")
check(DiagnosticLimits(seconds: 2, duty: 99, mebibytes: 999).duty == 25, "duty cap")
check(DiagnosticLimits(seconds: 2, duty: 10, mebibytes: 999).mebibytes == 64, "RAM cap")
check(DiagnosticLimits.allowedBytes(requested: 64 * 1048576, available: 16 * 1048576) == 2 * 1048576, "available memory cap")
check(DiagnosticLimits.allowedBytes(requested: 1048576, available: 0) == 0, "unknown available fails closed")
print("Diagnostic limit fixtures PASS")
summaryChecks()
suiteChecks()
check(DiagnosticWork.cpu(seed: 7, count: 128, cancelled: { false }).checksum == DiagnosticWork.expectedCPU(seed: 7, count: 128), "CPU reference")
check(DiagnosticWork.cpu(seed: 7, count: 128, cancelled: { true }).cancelled, "CPU pre-cancel")
var calls = 0
let partial = DiagnosticWork.cpu(seed: 7, count: 16384, cancelled: { calls += 1; return calls > 1 })
check(partial.cancelled && partial.operations < 16384, "CPU mid-cancel")
var bytes = [UInt8](repeating: 0, count: 8192)
bytes.withUnsafeMutableBufferPointer { p in
 check(DiagnosticWork.fill(p, seed: 3, cancelled: { false }), "RAM fill")
 let valid = DiagnosticWork.verify(p, seed: 3, cancelled: { false })
 check(valid.errors == 0 && valid.operations == 8192 && !valid.cancelled, "RAM verify bytes")
 p[4000] ^= 1
 check(DiagnosticWork.verify(p, seed: 3, cancelled: { false }).errors == 1, "RAM corruption")
 check(DiagnosticWork.verify(p, seed: 3, cancelled: { true }).cancelled, "RAM pre-cancel")
 var calls = 0
 let r = DiagnosticWork.verify(p, seed: 3, cancelled: { calls += 1; return calls > 1 })
 check(r.cancelled && r.operations == 4096, "RAM mid-cancel")
 check(!DiagnosticWork.fill(p, seed: 0, cancelled: { true }), "RAM fill cancellation")
}
print("CPU / RAM deterministic fixtures PASS")
check(!DiagnosticWork.cpuMatches(checksum: 1, seed: 7, count: 128), "CPU checksum error detected")
check(DiagnosticWork.cpuMatches(checksum: 810944, seed: 7, count: 128), "CPU independent known vector")
