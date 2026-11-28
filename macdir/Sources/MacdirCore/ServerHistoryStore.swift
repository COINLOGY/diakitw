import Foundation

/// История графиков на диске: после перезапуска линии продолжаются, а не
/// начинаются с пустого места. Файл на сервер, рядом с `servers.json`,
/// атомарная запись, только владелец (0600), жёсткие границы на чтении —
/// повреждённый или подменённый файл просто игнорируется.
public enum ServerHistoryStore {
 public static let maxBytes = 1_048_576
 public static let maxPoints = ServerState.historyLimit

 public static func directory() throws -> URL {
  let url = FileManager.default.homeDirectoryForCurrentUser
   .appendingPathComponent("Library/Application Support/macdir/history", isDirectory: true)
  var isDirectory: ObjCBool = false
  if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
   guard isDirectory.boolValue else { throw ServerError.config }
  } else {
   try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  }
  return url
 }

 /// Имя файла из идентификатора сервера: только безопасные символы.
 public static func url(for id: String) -> URL? {
  let safe = String(id.unicodeScalars.map { scalar -> Character in
   let allowed = CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
   return allowed ? Character(scalar) : "_"
  })
  guard !safe.isEmpty, safe.count <= 64, let directory = try? directory() else { return nil }
  return directory.appendingPathComponent(safe + ".json")
 }

 public static func load(_ id: String, now: Double = Date().timeIntervalSince1970) -> ServerState.Snapshot? {
  guard let url = url(for: id), let data = try? Data(contentsOf: url), !data.isEmpty, data.count <= maxBytes else { return nil }
  guard let snapshot = try? JSONDecoder().decode(ServerState.Snapshot.self, from: data) else { return nil }
  guard snapshot.savedAt.isFinite, snapshot.savedAt <= now + 3600,
        snapshot.load.count <= maxPoints,
        snapshot.traffic.values.allSatisfy({ $0.count <= maxPoints }) else { return nil }
  return snapshot
 }

 @discardableResult
 public static func save(_ snapshot: ServerState.Snapshot, id: String) -> Bool {
  guard let url = url(for: id) else { return false }
  guard let data = try? JSONEncoder().encode(snapshot), data.count <= maxBytes else { return false }
  let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString)")
  do {
   try data.write(to: temporary, options: [.atomic, .completeFileProtection])
   try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
   _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary, backupItemName: nil, options: [.usingNewMetadataOnly])
   return true
  } catch {
   try? FileManager.default.removeItem(at: temporary)
   return false
  }
 }

 public static func remove(_ id: String) {
  guard let url = url(for: id) else { return }
  try? FileManager.default.removeItem(at: url)
 }

 /// Удаляет файлы истории, которых нет среди известных серверов: запись могла
 /// быть удалена, пока приложение было закрыто, и её файл остался бы навсегда.
 @discardableResult
 public static func prune(keeping ids: Set<String>) -> Int {
  guard let directory = try? directory(),
        let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return 0 }
  let keep = Set(ids.compactMap { url(for: $0)?.lastPathComponent })
  var removed = 0
  for file in files where file.pathExtension == "json" && !keep.contains(file.lastPathComponent) {
   if (try? FileManager.default.removeItem(at: file)) != nil { removed += 1 }
  }
  return removed
 }
}
