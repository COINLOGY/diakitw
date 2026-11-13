import Foundation
import Darwin
import MacdirCore
func check(_ ok: @autoclosure () -> Bool, _ message: String) { if !ok() { print("FAIL: " + message); exit(1) } }
let q = InternetQuality.decode(Data(#"{"dl_throughput":260188416,"ul_throughput":64775664,"responsiveness":219.356,"test_endpoint":"defra1-edge-fx-009.aaplimg.com","interface_name":"en0"}"#.utf8))
check(q.downloadMbps == 260.188416 && q.uploadMbps == 64.775664, "bits/s to decimal Mbps")
check(q.endpoint == "defra1-edge-fx-009.aaplimg.com", "actual endpoint")
for json in ["broken", "[]", "{\"dl_throughput\":true}", "{\"dl_throughput\":-1}", "{\"dl_throughput\":1e300}", "{\"dl_throughput\":\"NaN\"}"] {
 check(InternetQuality.decode(Data(json.utf8)).downloadMbps == nil, "invalid throughput")
}
check(InternetQuality.decode(Data(#"{"ul_throughput":0}"#.utf8)).uploadMbps == 0, "measured zero")
check(InternetQuality.decode(Data(#"{"ul_throughput":0}"#.utf8)).downloadMbps == nil, "partial JSON")
let ping = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=56 time=10.000 ms\n64 bytes from 1.1.1.1: icmp_seq=1 ttl=56 time=14.000 ms\n64 bytes from 1.1.1.1: icmp_seq=3 ttl=56 time=12.000 ms\n4 packets transmitted, 3 packets received, 25.0% packet loss"
let p = InternetLatency.parse(ping)
check(p.mean == 12 && p.jitter == 3 && p.lossPercent == 25 && p.samples.count == 3, "ping sample math")
check(InternetLatency.parse("time=NaN ms\ntime=-1 ms\ntime=inf ms").mean == nil, "malformed ping")
check(InternetLatency.parse("64 bytes from 1.1.1.1: icmp_seq=0 ttl=56 time=10.000 ms").lossPercent == nil, "no invented loss")
check(InternetLatency.parse("2 packets transmitted, 0 packets received, 100.0% packet loss").lossPercent == 100, "total ICMP loss")
check(InternetLatency.parse("1 packets transmitted, 2 packets received, 0.0% packet loss").lossPercent == nil, "invalid counts")
let erroredQuality = InternetQuality.decode(Data(#"{"error_code":-1009,"error_domain":"NSURLErrorDomain","dl_throughput":123456,"ul_throughput":7890}"#.utf8))
check(erroredQuality.downloadMbps == nil && erroredQuality.uploadMbps == nil, "backend error cannot masquerade as successful throughput")
print("PASS JSON/latency")
let token = InternetCancellation()
let fixtureDirectory = FileManager.default.currentDirectoryPath
let fixtureBefore = try FileManager.default.contentsOfDirectory(atPath: fixtureDirectory).sorted()
let normal = InternetProcess.run(executable: "/bin/echo", arguments: ["fixture"], timeout: 2, cancellation: token)
check(normal.status == 0 && String(decoding: normal.stdout, as: UTF8.self) == "fixture\n", "native process output")
let cancelled = InternetCancellation(); cancelled.cancel()
check(InternetProcess.run(executable: "/bin/sleep", arguments: ["10"], timeout: 2, cancellation: cancelled).reason == .cancelled, "pre-cancel")
let start = ProcessInfo.processInfo.systemUptime
let timeout = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; sleep 20 & wait"], timeout: 0.2, cancellation: token)
check(timeout.reason == .timeout && ProcessInfo.processInfo.systemUptime - start < 3, "timeout kills group")
let flood = InternetProcess.run(executable: "/usr/bin/yes", arguments: [], timeout: 2, cancellation: token)
check(flood.reason == .outputLimit && flood.stdout.count <= 262144, "output bounded")
let active = InternetCancellation()
DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { active.cancel() }
check(InternetProcess.run(executable: "/bin/sleep", arguments: ["20"], timeout: 3, cancellation: active).reason == .cancelled, "active cancellation")
check(InternetProcess.run(executable: "/nonexistent/macdir-fixture", arguments: [], timeout: 1, cancellation: token).reason == .launchFailed, "missing executable")
print("PASS bounded process/cancel fixtures")
let shutdown = InternetCancellation()
var group: pid_t = 0
_ = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "printf '%s\\n' $$; sleep 20 & wait"], timeout: 2, cancellation: shutdown, progress: { data in
 if group == 0, let pid = Int32(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) {
  group = pid; shutdown.cancel()
  // Simulate shutdown where worker cannot return to its polling loop.
  Thread.sleep(forTimeInterval: 0.1)
  var status: Int32 = 0
  check(waitpid(pid, &status, WNOHANG) == pid, "cancellation must signal synchronously")
 }
})
check(group > 0, "fixture started")
check((try? FileManager.default.contentsOfDirectory(atPath: fixtureDirectory).sorted()) == fixtureBefore, "success/failure/cancel/flood: no payload artifacts")
let failed = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "printf error >&2; exit 7"], timeout: 2, cancellation: InternetCancellation())
check(failed.status == 7 && String(decoding: failed.stderr, as: UTF8.self) == "error", "nonzero exit preserves bounded stderr")
let stderrFlood = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "exec /usr/bin/yes >&2"], timeout: 2, cancellation: InternetCancellation())
check(stderrFlood.reason == .outputLimit && stderrFlood.stderr.count <= 262144, "stderr bounded")
check(InternetLatency.parse("64 bytes from 1.1.1.1: icmp_seq=0 ttl=56 time=10.000 ms").jitter == nil, "one RTT is not jitter")
check(InternetQuality.decode(Data(repeating: 32, count: 262145)).downloadMbps == nil, "oversized JSON")
check(InternetQuality.decode(Data(#"{"dl_throughput":1e999}"#.utf8)).downloadMbps == nil, "nonfinite JSON")
print("PASS immediate shutdown cancellation")
let childRun = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "sleep 20 >/dev/null 2>&1 & printf '%s\\n' $!"], timeout: 2, cancellation: InternetCancellation())
let childPID = Int32(String(decoding: childRun.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))!
Thread.sleep(forTimeInterval: 0.2)
check(kill(childPID, 0) == -1 && errno == ESRCH, "orphan descendant removed on normal parent exit")
let cwd = FileManager.default.currentDirectoryPath
let before = try FileManager.default.contentsOfDirectory(atPath: cwd).sorted()
for args in [["-c", "printf ok"], ["-c", "exit 7"], ["-c", "sleep 2"]] {
 _ = InternetProcess.run(executable: "/bin/sh", arguments: args, timeout: 0.1, cancellation: InternetCancellation())
}
check((try? FileManager.default.contentsOfDirectory(atPath: cwd).sorted()) == before, "no working-directory payload artifacts")
for cancelDuringRun in [false, true] {
 let owned = InternetCancellation()
 if cancelDuringRun { DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { owned.cancel() } }
 let tree = InternetProcess.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; sleep 20 & printf '%s\\n' $!; wait"], timeout: 0.4, cancellation: owned)
 check(tree.reason == (cancelDuringRun ? .cancelled : .timeout), "tree termination reason")
 guard let descendant = Int32(String(decoding: tree.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) else { fatalError("missing fixture child PID") }
 Thread.sleep(forTimeInterval: 0.2)
 check(kill(descendant, 0) == -1 && errno == ESRCH, "TERM-resistant process tree leaves no child after timeout/cancel")
}
check((try? FileManager.default.contentsOfDirectory(atPath: cwd).sorted()) == before, "all offline exits leave no working-directory payloads")
print("PASS orphan/timeout/cancel descendants absent; no payload artifacts; stdout/stderr each <=262144 bytes")
if CommandLine.arguments.contains("--live") {
 let pingOutput = InternetProcess.run(executable: "/sbin/ping", arguments: ["-n", "-c", "8", "-W", "1000", "-t", "10", "1.1.1.1"], timeout: 12, cancellation: InternetCancellation())
 let latency = InternetLatency.parse(String(decoding: pingOutput.stdout, as: UTF8.self))
 print("LIVE ICMP status=\(pingOutput.status) reason=\(pingOutput.reason) samples=\(latency.samples) mean_ms=\(String(describing: latency.mean)) jitter_ms=\(String(describing: latency.jitter)) loss_percent=\(String(describing: latency.lossPercent))")
 let output = InternetProcess.run(executable: "/usr/bin/networkQuality", arguments: ["-c", "-M", "20"], timeout: 25, cancellation: InternetCancellation())
 let quality = InternetQuality.decode(output.stdout)
 print("LIVE speed status=\(output.status) reason=\(output.reason) stdout_bytes=\(output.stdout.count) stderr_bytes=\(output.stderr.count) download_Mbps=\(String(describing: quality.downloadMbps)) upload_Mbps=\(String(describing: quality.uploadMbps)) RPM=\(String(describing: quality.responsiveness)) endpoint=\(quality.endpoint ?? "unknown") interface=\(quality.interface ?? "unknown")")
 check(output.reason == .finished && output.status == 0 && quality.downloadMbps != nil && quality.uploadMbps != nil, "live speed acceptance")
 check(pingOutput.status == 0 && latency.samples.count >= 2 && latency.lossPercent != nil, "live ICMP acceptance")
 check((try? FileManager.default.contentsOfDirectory(atPath: cwd).sorted()) == before, "no live working-directory payload artifacts")
}

