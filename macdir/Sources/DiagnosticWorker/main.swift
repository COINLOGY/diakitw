import Foundation
import Darwin
import Metal
import MacdirCore

// Dedicated executable: no GUI, network, filesystem scan or persistence.
let a = CommandLine.arguments
 guard a.count == 6, ["cpu", "ram", "gpu"].contains(a[1]),
 let seconds = Int(a[2]), (1...30).contains(seconds),
 let duty = Int(a[3]), (1...25).contains(duty),
 let mib = Int(a[4]), (1...64).contains(mib),
 let parent = Int32(a[5]), parent > 1, getppid() == parent else { exit(64) }
let start = ProcessInfo.processInfo.systemUptime
let deadline = start + Double(seconds)
// This thread also bounds pipeline compilation and blocked driver calls. Parent runner
// provides a second kill deadline. A submitted Metal command cannot be recalled.
DispatchQueue.global(qos: .utility).async {
 while true {
  if getppid() != parent { _exit(74) }
  let thermal = ProcessInfo.processInfo.thermalState
  if thermal == .serious || thermal == .critical { _exit(75) }
  if ProcessInfo.processInfo.systemUptime >= deadline + 0.8 { _exit(76) }
  usleep(20_000)
 }
}
func stop() -> Bool {
 let thermal = ProcessInfo.processInfo.thermalState
 if thermal == .serious || thermal == .critical { _exit(75) }
 return ProcessInfo.processInfo.systemUptime >= deadline
}
func rest(since: Double) {
 let busy = ProcessInfo.processInfo.systemUptime - since
 let until = min(deadline, ProcessInfo.processInfo.systemUptime + max(0.001, busy * Double(100-duty) / Double(duty)))
 while ProcessInfo.processInfo.systemUptime < until && !stop() { usleep(1000) }
}
func availableBytes() -> UInt64 {
 var stats = vm_statistics64(); var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
 let status = withUnsafeMutablePointer(to: &stats) { p in
  p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
 }
 guard status == KERN_SUCCESS else { return 0 }
 return UInt64(stats.free_count) * UInt64(vm_kernel_page_size)
}
var batches = 0, verified = 0, errors = 0, allocated = 0
var checksum: UInt64 = 0
var deviceName = ""
func finish(_ status: String, code: Int32) -> Never {
 let result: [String: Any] = ["mode": a[1], "status": status, "batches": batches, "verified": verified, "errors": errors, "allocatedBytes": allocated, "checksum": String(checksum), "elapsed": ProcessInfo.processInfo.systemUptime-start, "device": deviceName]
 if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
 exit(code)
}
if stop() { finish("timeout-before-work", code: 76) }
switch a[1] {
case "cpu":
 while !stop() {
  let t = ProcessInfo.processInfo.systemUptime
  let seed = UInt64(batches % 256)
  let r = DiagnosticWork.cpu(seed: seed, count: 16384, cancelled: stop)
  if r.cancelled { break }
  if !DiagnosticWork.cpuMatches(checksum: r.checksum, seed: seed, count: 16384) { errors += 1 }
  checksum = checksum &+ r.checksum; verified += r.operations; batches += 1
  if errors > 0 { break }
  rest(since: t)
 }
case "ram":
 let requestedBytes = DiagnosticLimits.allowedBytes(requested: mib * 1048576, available: availableBytes())
 guard requestedBytes >= 65536, let memory = malloc(requestedBytes) else { finish("unavailable-memory", code: 69) }
 allocated = requestedBytes
 defer { free(memory) }
 let pointer = memory.bindMemory(to: UInt8.self, capacity: allocated)
 var offset = 0
 while !stop() {
  let t = ProcessInfo.processInfo.systemUptime
  let chunk = UnsafeMutableBufferPointer(start: pointer.advanced(by: offset), count: min(65536, allocated-offset))
  let seed: UInt8 = (batches / max(1, allocated/65536)) % 2 == 0 ? 0xAA : 0x55
  if !DiagnosticWork.fill(chunk, seed: seed, cancelled: stop) { break }
  let r = DiagnosticWork.verify(chunk, seed: seed, cancelled: stop)
  verified += r.operations; errors += r.errors
  if r.cancelled { break }
  batches += 1; offset += chunk.count; if offset == allocated { offset = 0 }
  if errors > 0 { break }
  rest(since: t)
 }
case "gpu":
 guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { finish("unavailable-metal", code: 69) }
 deviceName = device.name
 let source = """
 #include <metal_stdlib>
 using namespace metal;
 kernel void bounded(device uint *out [[buffer(0)]], constant uint &seed [[buffer(1)]], uint i [[thread_position_in_grid]]) {
   uint x = i + seed;
   for (uint j=0; j<256; ++j) { x = x * 1664525u + 1013904223u; }
   out[i] = x;
 }
 """
 guard let library = try? device.makeLibrary(source: source, options: nil), let function = library.makeFunction(name: "bounded"),
       let pipeline = try? device.makeComputePipelineState(function: function),
       let buffer = device.makeBuffer(length: 4096 * 4, options: .storageModeShared) else { finish("unavailable-metal-pipeline", code: 69) }
 allocated = buffer.length
 // Independent affine reference for 256 LCG steps, evaluated once on CPU.
 var multiplier: UInt32 = 1, increment: UInt32 = 0
 for _ in 0..<256 { multiplier = multiplier &* 1664525; increment = increment &* 1664525 &+ 1013904223 }
 while !stop() {
  let t = ProcessInfo.processInfo.systemUptime
  guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else { finish("metal-encode-error", code: 70) }
  var seed = UInt32(truncatingIfNeeded: batches)
  encoder.setComputePipelineState(pipeline); encoder.setBuffer(buffer, offset: 0, index: 0)
  encoder.setBytes(&seed, length: 4, index: 1)
  encoder.dispatchThreads(MTLSize(width: 4096, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: min(64, pipeline.maxTotalThreadsPerThreadgroup), height: 1, depth: 1))
  encoder.endEncoding(); command.commit()
  while command.status != .completed && command.status != .error {
   if stop() { finish("timeout-pending-gpu", code: 76) }
   usleep(1000)
  }
  if command.status == .error { finish("metal-command-error", code: 70) }
  let p = buffer.contents().bindMemory(to: UInt32.self, capacity: 4096)
  for i in 0..<4096 {
   let expected = (UInt32(i) &+ seed) &* multiplier &+ increment
   if p[i] != expected { errors += 1 }
   checksum = checksum &+ UInt64(p[i]); verified += 1
  }
  batches += 1
  if errors > 0 { break }
  rest(since: t)
 }
default: exit(64)
}
finish(errors > 0 ? "verification-error" : (verified > 0 ? "completed" : "no-work"), code: errors > 0 || verified == 0 ? 70 : 0)
