import Foundation
import MacdirCore
func check(_ b: @autoclosure () -> Bool, _ label: String) { guard b() else { fatalError(label) }; print("PASS: " + label) }
let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("auth-edit-" + UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let url = root.appendingPathComponent("servers.json")
try Data(#"[{"id":"fixture","name":"Old","target":"test@example.invalid","role":"bot","identityFile":"/old/key","future":{"keep":true}}]"#.utf8).write(to: url)
let store = ServerConfigStore(url: url); let initial = try store.load()
let edited = ServerConfig(id: "fixture", name: "Edited", target: "test@example.invalid", identityFile: nil, role: "agent", authentication: .password, port: 65535)
let result = try store.update(edited, expected: initial)
check(result.configs.count == 1 && result.configs[0].port == 65535, "edit keeps id and changes endpoint")
let objects = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [[String: Any]]
check(objects[0]["future"] != nil && objects[0]["identityFile"] == nil, "edit preserves unknown fields and clears removed fields")
check((try? store.update(edited, expected: initial)) == nil, "stale edit rejected")
print("Edit checks passed at " + root.path)
