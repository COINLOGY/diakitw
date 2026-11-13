import Foundation
import Darwin

@main struct ServerConfigStoreChecks {
 static func verify(_ condition: Bool) { precondition(condition) }
 static func main() throws {
  precondition(CommandLine.arguments.count == 2, "Supply an owned, absolute, no-symlink scratch directory")
  let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).appendingPathComponent("server-management-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ServerConfigStore(url: root.appendingPathComponent("macdir/servers.json"))
  let initial = try store.load()
  verify(initial.configs.isEmpty)
  let c = ServerConfig(id: "new", name: "Fixture", target: "user@example.org", identityFile: nil, role: "agent")
  let saved = try store.add(c, expected: initial)
  verify(saved.configs.map(\.id) == ["new"])
  let permissions = try FileManager.default.attributesOfItem(atPath: store.url.path)[.posixPermissions] as! NSNumber
  verify(permissions.intValue == 0o600)
  print("PASS append and private atomic save")
  func rejects(_ label: String, _ action: () throws -> Void) {
   do { try action(); fatalError("accepted: \(label)") } catch { print("PASS \(label)") }
  }
  rejects("stale snapshot") { _ = try store.add(c, expected: initial) }
  rejects("duplicate ID") { _ = try store.add(c, expected: saved) }
  let preserved = Data(#"[{"id":"legacy","name":"Legacy","target":"user@old.example","role":"bot","identityFile":"/fixture/key","domain":"old.example","ipAddress":"192.0.2.1","future":{"flag":true,"values":[1,"x",null]}}]"#.utf8)
  try preserved.write(to: store.url)
  let legacy = try store.load()
  let appended = try store.add(c, expected: legacy)
  let removed = try store.remove(id: c.id, expected: appended)
  let object = try JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as! NSArray
  verify(object == (try JSONSerialization.jsonObject(with: preserved) as! NSArray))
  verify(removed.configs.map(\.id) == ["legacy"])
  print("PASS remove preserves every unknown and optional field")
  let before = try Data(contentsOf: store.url)
  let invalid = ServerConfig(id: "bad", name: "Bad", target: "user@host;touch", identityFile: nil, role: "agent")
  rejects("invalid append") { _ = try store.add(invalid, expected: removed) }
  verify(try Data(contentsOf: store.url) == before)
  try Data("broken".utf8).write(to: store.url)
  rejects("malformed config load") { _ = try store.load() }
  rejects("malformed config never overwritten") { _ = try store.add(c, expected: removed) }
  verify(try String(contentsOf: store.url, encoding: .utf8) == "broken")
  try FileManager.default.removeItem(at: store.url)
  let outside = root.appendingPathComponent("sentinel")
  try before.write(to: outside)
  try FileManager.default.createSymbolicLink(at: store.url, withDestinationURL: outside)
  rejects("target symlink load") { _ = try store.load() }
  rejects("target symlink save") { _ = try store.add(c, expected: initial) }
  verify(try Data(contentsOf: outside) == before)
  let link = root.appendingPathComponent("link")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("macdir"))
  rejects("parent symlink") { _ = try ServerConfigStore(url: link.appendingPathComponent("servers.json")).load() }
  let blocked = ServerConfigStore(url: root.appendingPathComponent("blocked/servers.json"))
  let empty = try blocked.load()
  try Data().write(to: root.appendingPathComponent("blocked"))
  rejects("atomic parent failure") { _ = try blocked.add(c, expected: empty) }
  verify(try Data(contentsOf: outside) == before)
  let temporary = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("macdir").path)
  verify(!temporary.contains { $0.hasPrefix(".servers-") })
  print("PASS no temporary leftovers or outside mutation")
  try FileManager.default.removeItem(at: store.url)
  try before.write(to: store.url)
  let stable = try store.load()
  let parent = store.url.deletingLastPathComponent().path
  chmod(parent, 0o500)
  rejects("permission failure preserves original") { _ = try store.add(c, expected: stable) }
  chmod(parent, 0o700)
  verify(try Data(contentsOf: store.url) == before)
  let remaining = try store.remove(id: "legacy", expected: stable)
  let reloaded = try store.load()
  verify(remaining.configs.isEmpty && reloaded.configs.isEmpty)
  print("PASS final removal saves empty array")
 }
}
