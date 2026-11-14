"""Exercise the actual model in an isolated source fixture; never SSH or user config.
Run with an explicit owned scratch directory argument.
"""
from pathlib import Path

import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
scratch = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='server-model-', dir=scratch) as directory:
    root = Path(directory)
    model = (project / 'Sources/macdir/ServerPanel.swift').read_text().split('struct MacdirRootView: View')[0]
    model = model.replace('import MacdirCore', '')
    model = model.replace('private let store = ServerConfigStore()', f'private let store = ServerConfigStore(url: URL(fileURLWithPath: "{root}/servers.json"))')
    model = model.replace('ServerHardwareCache()', f'ServerHardwareCache(url: URL(fileURLWithPath: "{root}/hardware.json"))')
    model = model.replace('ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), specs: true, cancellation: cancellation)', 'try await Fake.sample()')
    model = model.replace('ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), cancellation: cancellation)', 'try await Fake.sample()')
    assert 'ServerSampler.sample(' not in model, 'fixture must never contact real SSH'
    model = model.replace('ServerPasswordStore.', 'FakeCredentials.')
    # Observe actual actor-side delivery, not a sleep guessed to allow completion.
    assert model.count('}.value') == 2
    model = model.replace('}.value', '}.value\n    Delivery.count += 1')
    (root / 'Model.swift').write_text(model)
    fixture = r'''
import Foundation
@MainActor enum FakeCredentials {
 static var entries: [String: String] = [:]
 static func save(_ password: String, for c: ServerConfig, helper: String) throws { entries[c.passwordReference!] = password }
 static func delete(_ c: ServerConfig) throws { if let ref = c.passwordReference { entries[ref] = nil } }
}
@MainActor enum Delivery { static var count = 0 }
final class Fake {
 static func trace(_ message: String) { FileHandle.standardError.write(Data(("SERVER-MODEL " + message + "\n").utf8)) }
 static let lock = NSLock()
 static var count = 0
 static var pending: [Int: CheckedContinuation<Void, Never>] = [:]
 static func calls() -> Int { lock.lock(); defer { lock.unlock() }; return count }
 static func release(_ ids: [Int]) {
  lock.lock()
  let ready = ids.map { pending.removeValue(forKey: $0)! }
  lock.unlock()
  ready.forEach { $0.resume() }
 }
 static func sample() async throws -> Result<ServerTelemetry, ServerError> {
  // Suspend the task without occupying a cooperative executor thread. Cancellation
  // deliberately does not release it: stale results must reach the generation guard.
  await withCheckedContinuation { continuation in
   lock.lock(); count += 1; let n = count; pending[n] = continuation; lock.unlock()
   trace("started \(n)")
  }
  return .failure(.denied)
 }
}
@main struct Checks {
 @MainActor static func main() async throws {
  let url = URL(fileURLWithPath: "CONFIG")
  let store = ServerConfigStore(url: url)
  let c = ServerConfig(id: "same", name: "Fixture", target: "user@example.org", identityFile: nil, role: "bot")
  _ = try store.add(c, expected: store.load())
  let model = ServersModel()
  model.setVisible(true)
  for _ in 0..<100 where Fake.calls() < 2 { try await Task.sleep(for: .milliseconds(10)) }
  precondition(Fake.calls() == 2 && model.inFlight.contains(c.id))
  model.setVisible(true); model.reload(); model.refresh()
  try await Task.sleep(for: .milliseconds(50))
  precondition(Fake.calls() == 2, "no overlap or timer reset on unchanged reload")
  model.removeServer(c)
  precondition(model.configs.isEmpty && model.inFlight.isEmpty)
  _ = try store.add(c, expected: store.load()) // deliberately re-use ID
  model.reload(); model.refresh()
  for _ in 0..<100 where Fake.calls() < 4 { try await Task.sleep(for: .milliseconds(10)) }
  precondition(Fake.calls() == 4 && Delivery.count == 0, "both generations started before either completes")
  Fake.trace("both generations suspended calls=\(Fake.calls()) delivered=\(Delivery.count)")
  Fake.release([1, 2])
  for _ in 0..<100 where Delivery.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
  precondition(Delivery.count == 2, "both old completions reached actual model")
  precondition(model.states[c.id] == nil && model.inFlight.contains(c.id), "old completion cannot reset new in-flight task")
  precondition(!FileManager.default.fileExists(atPath: "CACHE"), "removed hardware completion cannot persist")
  model.refresh()
  try await Task.sleep(for: .milliseconds(50))
  precondition(Fake.calls() == 4, "stale live and hardware completions cannot clear new overlap guards")
  Fake.trace("old delivered=\(Delivery.count) new still gated; no stale publication/cache/overlap")
  Fake.release([3, 4])
  for _ in 0..<100 where Delivery.count < 4 { try await Task.sleep(for: .milliseconds(10)) }
  precondition(Delivery.count == 4 && model.states[c.id]?.error == .denied && model.inFlight.isEmpty)
  precondition(FileManager.default.fileExists(atPath: "CACHE"), "current hardware completion persists")
  model.setVisible(false)
  model.beginAdd(); model.draftName = "Second"; model.draftTarget = "user@second.example"; model.addServer()
  precondition(model.configs.count == 2 && !model.adding)
  precondition(Fake.calls() == 4, "hidden panel cannot start requests")
  model.removeServer(c)
  precondition(model.configs.count == 1 && model.states[c.id] == nil)
  let second = model.configs[0]
  model.beginEdit(second); model.draftAuthentication = .password; model.draftPassword = "synthetic-only-1"; model.draftPort = "2222"; model.addServer()
  precondition(model.configs[0].port == 2222 && model.configs[0].authentication == .password && FakeCredentials.entries.count == 1)
  precondition(model.draftPassword.isEmpty)
  let passwordConfig = model.configs[0]
  model.beginEdit(passwordConfig); model.draftName = "Renamed"; model.addServer()
  precondition(model.configs[0].name == "Renamed" && model.configs[0].passwordReference == passwordConfig.passwordReference)
  model.beginEdit(model.configs[0]); model.draftPort = "2200"; model.addServer()
  precondition(model.adding && model.managementError != nil && model.configs[0].port == 2222, "changed endpoint requires password re-entry")
  model.draftPassword = "synthetic-only-2"; model.addServer()
  precondition(!model.adding && model.configs[0].port == 2200 && FakeCredentials.entries.count == 1)
  precondition(FakeCredentials.entries[passwordConfig.passwordReference!] == nil, "old own password deleted")
  let storedText = try String(contentsOf: url, encoding: .utf8)
  precondition(!storedText.contains("synthetic-only"), "no password in JSON")
  model.beginEdit(model.configs[0]); model.draftPassword = "synthetic-only-3"
  _ = try store.add(c, expected: store.load()) // stale UI snapshot
  model.addServer()
  precondition(model.managementError != nil && FakeCredentials.entries.count == 1, "new credential rolled back after config conflict")
  model.reload(); let own = model.configs.first { $0.id == second.id }!
  model.beginEdit(own); model.draftAuthentication = .key; model.addServer()
  precondition(FakeCredentials.entries.isEmpty, "switch to key deletes own prior password")
  precondition(Fake.calls() == 4, "settings fixtures never contact server")
  print("PASS password settings edit/retain/rebind/replace/rollback/key switch with in-memory credentials")
  print("PASS model add/remove, unchanged reload overlap, removed/readded ID stale live+hardware results, hidden polling")
 }
}
'''.replace('CONFIG', str(root / 'servers.json')).replace('CACHE', str(root / 'hardware.json'))

    (root / 'Checks.swift').write_text(fixture)
    sources = [project / 'Sources/MacdirCore' / name for name in ['MetricPresentation.swift', 'ServerSampler.swift', 'ServerTelemetry.swift', 'ServerConfigStore.swift', 'ServerHardwareCache.swift', 'ServerPassword.swift', 'ServerSSHProcess.swift']]
    subprocess.run(['swiftc', '-j', '2', *map(str, sources), str(root / 'Model.swift'), str(root / 'Checks.swift'), '-o', str(root / 'checks')], check=True)
    subprocess.run([str(root / 'checks')], check=True, timeout=20)
