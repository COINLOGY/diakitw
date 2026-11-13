import Foundation
import MacdirCore
var count = 0
func check(_ ok: @autoclosure () -> Bool, _ name: String) { if !ok() { print("FAIL: \(name)"); exit(1) }; count += 1; print("PASS: \(name)") }
check(!MacIdentity.localComputerName().isEmpty, "computer name without DNS")
func sample(_ text: String) throws -> ServerTelemetry { try ServerTelemetry.decode(Data(text.utf8)) }
let empty = try sample("{\"schema\":1}")
check(empty.cpuPercent == nil && empty.memoryUsed == nil && empty.network.isEmpty, "missing metrics unknown")
let good = try sample("{\"schema\":1,\"sampled_at\":1000,\"cpu_percent\":25,\"memory_total\":100,\"memory_available\":60,\"swap_total\":0,\"swap_free\":0,\"disk_total\":200,\"disk_free\":50}")
check(good.memoryUsed == 40 && good.diskUsed == 150 && good.swapUsed == 0, "explicit used formulas")
check(good.isFresh(now: 1090) && !good.isFresh(now: 1091) && !good.isFresh(now: 999), "90 second freshness and future rejected")
let bad = try sample("{\"schema\":1,\"cpu_percent\":101,\"memory_total\":10,\"memory_available\":11,\"disk_total\":-1,\"uptime_seconds\":\"NaN\"}")
check(bad.cpuPercent == nil && bad.memoryUsed == nil && bad.diskUsed == nil && bad.uptimeSeconds == nil, "invalid bounds unknown")
check((try? sample("{\"schema\":2}")) == nil, "schema must match")
let config = try ServerConfig.decode(Data("[{\"id\":\"example\",\"name\":\"Example\",\"target\":\"root@example.org\",\"role\":\"bot\"}]".utf8))[0]
let addressed = try ServerConfig.decode(Data("[{\"id\":\"example\",\"name\":\"Example\",\"target\":\"root@192.0.2.10\",\"role\":\"bot\",\"domain\":\"server.example.com\",\"ipAddress\":\"192.0.2.10\"}]".utf8))[0]
check(addressed.headerAddress == "server.example.com · 192.0.2.10", "domain and IP in server header")
check(config.headerAddress == "example.org", "legacy address falls back to SSH host")
check(try! config.sshArguments(specs: true).last == "python3 - bot specs", "allowlisted daily specs command")
check(try! config.sshArguments().suffix(2) == ["root@example.org", "python3 - bot"], "fixed remote command")
for target in ["-oProxyCommand=x", "root@x;id", "root@x y", "root@$(id)", "root@x\n"] {
 let c = ServerConfig(id: "a", name: "A", target: target, identityFile: nil, role: "bot")
 check((try? c.sshArguments()) == nil, "reject SSH injection")
}
check((try? ServerConfig(id: "a", name: "A", target: "root@x", identityFile: nil, role: "bot;id").sshArguments()) == nil, "reject role injection")
let key = ServerConfig(id: "a", name: "A", target: "root@x", identityFile: "/local/key file", role: "agent")
check(try! key.sshArguments().contains("/local/key file"), "identity path single argument")
check(ServerSampler.classify("Permission denied: secret") == .denied && ServerSampler.classify("REMOTE HOST IDENTIFICATION HAS CHANGED!") == .hostKey && ServerSampler.classify("secret log") == .unavailable, "sanitized errors")
var state = ServerState()
state.accept(.success(good))
check(state.current(now: 1001)?.cpuPercent == 25, "success current")
state.accept(.failure(.denied))
check(state.current(now: 1002) == nil && state.lastSuccess?.cpuPercent == 25, "failure clears current retains separate last success")
let networking = try sample("{\"schema\":1,\"services\":[{\"name\":\"hermes\",\"state\":\"running\"}],\"network\":[{\"name\":\"br-a\"},{\"name\":\"lo\"},{\"name\":\"ens3\"}]}")
check(networking.preferredInterface == "ens3" && networking.services.first?.state == "running", "physical network and container running")
for _ in 0..<100 { state.accept(.success(good)) }
check(state.cpuHistory.count == 60, "bounded real CPU history")
let output = try BoundedServerProcess.run(executable: "/bin/cat", arguments: [], input: Data("fixture".utf8))
check(String(decoding: output.stdout, as: UTF8.self) == "fixture", "process stdin drained")
let start = ProcessInfo.processInfo.systemUptime
let timed = try? BoundedServerProcess.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; while :; do :; done"], input: Data(), timeout: 0.1)
check(timed == nil && ProcessInfo.processInfo.systemUptime - start < 4, "terminate then kill bounded local fixture")
let flooded = try? BoundedServerProcess.run(executable: "/usr/bin/yes", arguments: [], input: Data())
check(flooded == nil, "output capped")
check(MacIdentity.validAddress("192.168.1.5") == "192.168.1.5", "Mac IPv4 literal")
check(MacIdentity.validAddress("2001:db8::5") == "2001:db8::5", "Mac IPv6 literal")
for value in ["", "example.org", "999.1.1.1", "1.2.3", "::gg", "1.2.3.4\n", "1.2.3.4\0junk", "fe80::1%en0", "127.0.0.1", "::1", "0.0.0.0", "::", "::ffff:127.0.0.1"] {
 check(MacIdentity.validAddress(value) == nil, "reject malformed/unspecified/loopback IP")
}
let addresses = ["en0": ["192.168.1.5", "2001:db8::5", "127.0.0.1", "bad"], "utun3": ["10.0.0.2"]]
check(MacIdentity.internalText(addresses, interface: "en0") == "en0 · 192.168.1.5 · 2001:db8::5", "selected interface IPv4 and IPv6")
check(MacIdentity.internalText(addresses, interface: "utun3") == "utun3 · 10.0.0.2", "selection changes immediately without previous interface")
check(MacIdentity.internalText(addresses, interface: "en9") == "en9 · Недоступен", "unknown interface explicit unavailable")
check(MacIdentity.computerName(localized: nil, fallback: "mac.local") == "mac.local", "computer name fallback")
check(MacIdentity.computerName(localized: "Mac Studio", fallback: "mac.local") == "Mac Studio", "localized computer name")
check(MacIdentity.externalAddress(Data(#"{"ip":"2001:db8::5"}"#.utf8), status: 200) == "2001:db8::5", "external JSON validated IPv6")
for payload in [#"{"ip":"bad"}"#, #"{}"#, #"{"ip":"127.0.0.1"}"#, "broken"] {
 check(MacIdentity.externalAddress(Data(payload.utf8), status: 200) == nil, "invalid external response clears value")
}
check(MacIdentity.externalAddress(Data(#"{"ip":"1.2.3.4"}"#.utf8), status: 500) == nil, "HTTP failure unavailable")
let hardware = try sample(#"{"schema":1,"sampled_at":1000,"cpu_count":4,"memory_total":8589934592,"disk_total":85899345920}"#)
check(hardware.cpuCount == 4, "logical CPU count decoded")
check(empty.cpuCount == nil, "legacy payload CPU count unknown")
for value in ["null", "0", "-1", "1.5", "true", "\"4\""] {
 let invalid = try sample("{\"schema\":1,\"cpu_count\":\(value)}")
 check(invalid.cpuCount == nil, "invalid logical CPU count unknown")
}
check(ServerTelemetry.hardwareSummary(hardware) == "vCPU 4 · RAM 8.0 GiB · Диск / 80.0 GiB", "hardware header totals in binary GiB")
check(ServerTelemetry.hardwareSummary(empty) == "vCPU Н/Д · RAM Н/Д · Диск / Н/Д", "missing hardware unknown")
var hardwareState = ServerState()
hardwareState.accept(.success(hardware))
check(ServerTelemetry.hardwareSummary(hardwareState.current(now: 1091)) == "vCPU Н/Д · RAM Н/Д · Диск / Н/Д", "stale hardware unknown")
hardwareState.accept(.failure(.timeout))
check(ServerTelemetry.hardwareSummary(hardwareState.current(now: 1001)) == "vCPU Н/Д · RAM Н/Д · Диск / Н/Д", "failed hardware unknown")
let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("macdir-hardware-\(UUID().uuidString).json")
var cache = ServerHardwareCache(url: cacheURL)
check(cache.needsRefresh(config, now: 1000), "first hardware fetch due")
var specCalls = 0
for now in stride(from: 1000.0, to: 87400.0, by: 30.0) {
 if cache.needsRefresh(config, now: now) { specCalls += 1; cache.record(config, sample: hardware, now: now) }
}
check(specCalls == 1, "30s polling requests specs once before 24h")
cache.record(config, sample: hardware, now: 1000)
check(!cache.needsRefresh(config, now: 87399) && cache.needsRefresh(config, now: 87400), "hardware successful 24h TTL")
cache = ServerHardwareCache(url: cacheURL)
check(!cache.needsRefresh(config, now: 2000), "hardware TTL persisted")
check(cache.needsRefresh(addressed, now: 2000), "hardware cache isolated by target")
cache.record(config, sample: nil, now: 87400)
check(!cache.needsRefresh(config, now: 87401) && cache.needsRefresh(config, now: 89200), "failed hardware 30min retry")
check(cache.snapshot(config)?.cpuCount == 4 && cache.measuredAt(config) == 1000, "failure retains dated hardware")
check(cache.label(config, now: 87401).contains("устарели"), "stale cache explicit label")
try Data("broken".utf8).write(to: cacheURL)
cache = ServerHardwareCache(url: cacheURL)
check(cache.needsRefresh(config, now: 1000) && cache.snapshot(config) == nil, "malformed cache unknown and due")
print("\(count) server checks passed")
