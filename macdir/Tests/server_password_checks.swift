import Foundation
import MacdirCore
func check(_ b: @autoclosure () -> Bool, _ label: String) { guard b() else { fatalError(label) }; print("PASS: " + label) }
let config = ServerConfig(id: "fixture", name: "Fixture", target: "user@example.invalid", identityFile: nil, role: "bot", authentication: .password, passwordReference: UUID().uuidString)
let secret = Data("synthetic-test-only".utf8)
var reads = 0
let response = try ServerAskpass.response(prompt: "user@example.invalid's password: ", config: config) { _ in reads += 1; return secret }
check(response == secret + Data([10]), "password response uses pipe bytes")
for prompt in ["Enter passphrase for key:", "Are you sure you want to continue connecting (yes/no)?", "New password:", "Password:"] {
 check((try? ServerAskpass.response(prompt: prompt, config: config) { _ in reads += 1; return secret }) == nil, "reject non-password prompt")
}
check(reads == 1, "rejected prompts never access credential store")
check((try? ServerAskpass.response(prompt: "user@example.invalid's password: ", config: config) { _ in Data("bad\nvalue".utf8) }) == nil, "reject multiline password")
let env = try ServerAskpass.environment(config: config, helper: "/fixture/helper")
check(!env.values.contains("synthetic-test-only"), "environment contains references only")
print("Password contract checks passed; no Keychain access")
