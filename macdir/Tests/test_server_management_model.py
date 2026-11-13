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
    model = model.replace('ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), specs: true, cancellation: cancellation)', 'try Fake.sample()')
    model = model.replace('ServerSampler.sample(config, probe: try ServerSampler.bundledProbe(), cancellation: cancellation)', 'try Fake.sample()')
    assert 'ServerSampler.sample(' not in model, 'fixture must never contact real SSH'
    model = model.replace('ServerPasswordStore.', 'FakeCredentials.')
    (root / 'Model.swift').write_text(model)
    fixture = r'''
import Foundation
@MainActor enum FakeCredentials {
 static var entries: [String: String] = [:]
 static func save(_ password: String, for c: ServerConfig, helper: String) throws { entries[c.passwordReference!] = password }
 static func delete(_ c: ServerConfig) throws { if let ref = c.passwordReference { entries[ref] = nil } }
}
final class Fake {
 static let lock = NSLock()
 static var count = 0
 static let old = DispatchSemaphore(value: 0)
 static let new = DispatchSemaphore(value: 0)
 static func calls() -> Int { lock.lock(); defer { lock.unlock() }; return count }
 static func sample() throws -> Result<ServerTelemetry, ServerError> {
  lock.lock(); count += 1; let n = count; lock.unlock()
  _ = (n <= 2 ? old : new).wait(timeout: .now() + 10)
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
  precondition(Fake.calls() == 4)
  Fake.old.signal(); Fake.old.signal()
  try await Task.sleep(for: .milliseconds(100))
  precondition(model.states[c.id] == nil && model.inFlight.contains(c.id), "old completion cannot reset new in-flight task")
  precondition(!FileManager.default.fileExists(atPath: "CACHE"), "removed hardware completion cannot persist")
  Fake.new.signal(); Fake.new.signal()
  for _ in 0..<100 where !model.inFlight.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
  precondition(model.states[c.id]?.error == .denied && model.inFlight.isEmpty)
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
    subprocess.run(['swiftc', *map(str, sources), str(root / 'Model.swift'), str(root / 'Checks.swift'), '-o', str(root / 'checks')], check=True)
    subprocess.run([str(root / 'checks')], check=True, timeout=20)
