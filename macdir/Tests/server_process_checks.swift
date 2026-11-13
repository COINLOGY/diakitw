import Foundation
import Darwin
import MacdirCore
func check(_ b: @autoclosure () -> Bool, _ label: String) { guard b() else { fatalError(label) }; print("PASS: " + label) }
let token = ServerCancellation()
let result = ServerSSHProcess.run(executable: "/bin/cat", arguments: [], input: Data("probe-fixture".utf8), timeout: 2, cancellation: token)
check(String(decoding: result.stdout, as: UTF8.self) == "probe-fixture" && result.status == 0, "probe stdin forwarded")
let cancelled = ServerCancellation()
DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { cancelled.cancel() }
let start = ProcessInfo.processInfo.systemUptime
let stopped = ServerSSHProcess.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; sleep 30 & printf '%s\\n' $$ $!; wait"], input: Data(), timeout: 2, cancellation: cancelled)
check(stopped.reason == .cancelled && ProcessInfo.processInfo.systemUptime - start < 2, "cancellation kills owned group")
let pids = String(decoding: stopped.stdout, as: UTF8.self).split(whereSeparator: { $0.isWhitespace }).compactMap { Int32($0) }
check(pids.count == 2, "fixture reports parent and descendant")
for pid in pids {
 for _ in 0..<100 where kill(pid, 0) == 0 { Thread.sleep(forTimeInterval: 0.01) }
 check(kill(pid, 0) == -1 && errno == ESRCH, "cancel leaves no owned descendant")
}
let timeout = ServerSSHProcess.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; while :; do :; done"], input: Data(), timeout: 0.1, cancellation: ServerCancellation())
check(timeout.reason == .timeout, "hard timeout")
let flooded = ServerSSHProcess.run(executable: "/usr/bin/yes", arguments: [], input: Data(), timeout: 2, cancellation: ServerCancellation())
check(flooded.reason == .outputLimit && flooded.stdout.count <= 65536, "output cap")
let fixtureRoot = URL(fileURLWithPath: CommandLine.arguments[1])
let config = ServerConfig(id: "fixture", name: "Fixture", target: "user@example.invalid", identityFile: nil, role: "bot", authentication: .password, passwordReference: UUID().uuidString)
var env = try ServerAskpass.environment(config: config, helper: fixtureRoot.appendingPathComponent("ssh_fake_askpass.sh").path)
env["SECRET_MUST_NOT_PASS"] = "synthetic-test-only"
let fake = ServerSSHProcess.run(executable: "/bin/sh", arguments: [fixtureRoot.appendingPathComponent("ssh_fake.sh").path], input: Data("probe-fixture".utf8), environment: env, timeout: 2, cancellation: ServerCancellation())
check(fake.status == 0 && fake.stdout == Data("probe-fixture".utf8) && fake.stderr.isEmpty, "fake SSH askpass exchange without secret diagnostics")
check(!String(decoding: fake.stdout + fake.stderr, as: UTF8.self).contains("synthetic-test-only"), "no password leaks into captured output")
let cleanEnv = ServerSSHProcess.run(executable: "/usr/bin/env", arguments: [], input: Data(), environment: env, timeout: 2, cancellation: ServerCancellation())
check(!String(decoding: cleanEnv.stdout, as: UTF8.self).contains("synthetic-test-only"), "child environment allowlist excludes secrets")
print("SSH process fixtures passed; no remote contact")
