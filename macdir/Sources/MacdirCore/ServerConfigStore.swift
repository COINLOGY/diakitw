import Foundation
import Darwin

/// No credentials are read or copied. JSON objects retain unrecognised fields.
public struct ServerConfigStore {
 public struct Snapshot {
  public let configs: [ServerConfig]
  fileprivate let data: Data?
 }
 public enum Failure: String, Error, LocalizedError {
  case unsafe = "Небезопасный путь конфигурации: ссылки, права или владелец."
  case invalid = "Некорректный servers.json. Исправьте файл вручную; он не перезаписан."
  case changed = "Конфигурация изменилась. Обновите список и повторите действие."
  case io = "Не удалось сохранить конфигурацию. Проверьте доступ и свободное место."
  public var errorDescription: String? { rawValue }
 }
 public let url: URL
 public init(url: URL = ServerConfig.configURL) { self.url = url }
 public func load() throws -> Snapshot {
  guard let fd = try directory(create: false) else { return Snapshot(configs: [], data: nil) }
  defer { close(fd) }
  return try snapshot(read(fd))
 }
 public func add(_ config: ServerConfig, expected: Snapshot) throws -> Snapshot {
  _ = try config.sshArguments()
  var objects = try objects(expected.data)
  objects.append(try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any])
  return try save(objects, expected: expected)
 }
 public func update(_ config: ServerConfig, expected: Snapshot) throws -> Snapshot {
  _ = try config.sshArguments()
  var objects = try objects(expected.data)
  guard let index = objects.firstIndex(where: { $0["id"] as? String == config.id }) else { throw Failure.changed }
  let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any]
  for key in ["id", "name", "target", "identityFile", "role", "domain", "ipAddress", "authentication", "port", "passwordReference"] { objects[index][key] = encoded[key] }
  return try save(objects, expected: expected)
 }
 public func remove(id: String, expected: Snapshot) throws -> Snapshot {
  var objects = try objects(expected.data)
  guard objects.contains(where: { $0["id"] as? String == id }) else { throw Failure.changed }
  objects.removeAll { $0["id"] as? String == id }
  return try save(objects, expected: expected)
 }
 private func objects(_ data: Data?) throws -> [[String: Any]] {
  guard let data else { return [] }
  guard let value = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw Failure.invalid }
  return value
 }
 private func snapshot(_ data: Data?) throws -> Snapshot {
  guard let data else { return Snapshot(configs: [], data: nil) }
  guard let configs = try? ServerConfig.decode(data) else { throw Failure.invalid }
  return Snapshot(configs: configs, data: data)
 }
 private func directory(create: Bool) throws -> Int32? {
  guard url.isFileURL, url.path.hasPrefix("/"), !url.pathComponents.contains("..") else { throw Failure.unsafe }
  var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
  guard fd >= 0 else { throw Failure.io }
  do {
   for component in url.deletingLastPathComponent().pathComponents.dropFirst() {
    var next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    if next < 0 && errno == ENOENT {
     if !create { close(fd); return nil }
     guard mkdirat(fd, component, 0o700) == 0 || errno == EEXIST else { throw Failure.io }
     next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    }
    guard next >= 0 else { throw Failure.unsafe }
    var info = stat()
    guard fstat(next, &info) == 0, (info.st_uid == getuid() || info.st_uid == 0), info.st_mode & 0o022 == 0 else { close(next); throw Failure.unsafe }
    close(fd); fd = next
   }
   var info = stat()
   guard fstat(fd, &info) == 0, info.st_uid == getuid() else { throw Failure.unsafe }
   return fd
  } catch { close(fd); throw error }
 }
 private func read(_ directory: Int32) throws -> Data? {
  let fd = openat(directory, url.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
  if fd < 0 && errno == ENOENT { return nil }
  guard fd >= 0 else { throw Failure.unsafe }
  defer { close(fd) }
  var info = stat()
  guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid(), info.st_nlink == 1, info.st_size <= 65536 else { throw Failure.unsafe }
  var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
  while true {
   let n = Darwin.read(fd, &buffer, buffer.count)
   if n < 0 && errno == EINTR { continue }
   guard n >= 0 else { throw Failure.io }
   if n == 0 { break }
   data.append(contentsOf: buffer.prefix(n))
   guard data.count <= 65536 else { throw Failure.invalid }
  }
  return data
 }
 private func save(_ objects: [[String: Any]], expected: Snapshot) throws -> Snapshot {
  let data = try JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])
  let result = try snapshot(data) // validate the complete list, including duplicate IDs and limits
  guard let dir = try directory(create: true) else { throw Failure.io }
  defer { close(dir) }
  guard flock(dir, LOCK_EX | LOCK_NB) == 0 else { throw Failure.changed }
  defer { flock(dir, LOCK_UN) }
  guard try read(dir) == expected.data else { throw Failure.changed }
  let temporary = ".servers-\(UUID().uuidString).tmp"
  let fd = openat(dir, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
  guard fd >= 0 else { throw Failure.io }
  defer { close(fd); unlinkat(dir, temporary, 0) }
  guard fchmod(fd, 0o600) == 0 else { throw Failure.io }
  try data.withUnsafeBytes { bytes in
   var offset = 0
   while offset < bytes.count {
    let n = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
    if n < 0 && errno == EINTR { continue }
    guard n > 0 else { throw Failure.io }
    offset += n
   }
  }
  guard fsync(fd) == 0 else { throw Failure.io }
  guard try read(dir) == expected.data else { throw Failure.changed }
  guard renameat(dir, temporary, dir, url.lastPathComponent) == 0 else { throw Failure.io }
  // Rename is the commit point. Read back the exact anchored target before publishing.
  guard try read(dir) == data else { throw Failure.changed }
  return result
 }
}
