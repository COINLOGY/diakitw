import Foundation
import Darwin

public struct CacheTarget: Hashable, Sendable {
 public let rawValue: String
 public init?(rawValue: String) {
  guard !rawValue.isEmpty, rawValue != ".", rawValue != "..", !rawValue.contains("/"), !rawValue.contains("\0") else { return nil }
  self.rawValue = rawValue
 }
 public static let comet = CacheTarget(rawValue: "Comet")!
 public static let wechat = CacheTarget(rawValue: "com.tencent.xinWeChat")!
 public static let atlas = CacheTarget(rawValue: "com.openai.atlas")!
 public var name: String { rawValue }
 public var relativePath: String { "Library/Caches/" + rawValue }
}
public struct CacheReport: Identifiable, Sendable {
 public var id: CacheTarget
 public var path: String
 public var bytes: Int64? = nil
 public var present = false
 public var error: String? = nil
 public var disabledReason: String? = nil
 fileprivate var measuredFiles: [String: Int64] = [:]
 public static func eligibleBytes(_ reports: [CacheReport]) -> Int64 {
  var files: [String: Int64] = [:]
  for report in reports where report.selectable && report.bytes != nil {
   files.merge(report.measuredFiles, uniquingKeysWith: max)
  }
  return files.values.reduce(0, +)
 }
 public var selectable: Bool { present && error == nil && disabledReason == nil }
}
public struct CacheSelection: Sendable {
 public private(set) var ids: Set<CacheTarget> = []
 public init() {}
 public mutating func set(_ id: CacheTarget, selected: Bool) {
  if selected { ids.insert(id) } else { ids.remove(id) }
 }
 public func targets(in reports: [CacheReport]) -> [CacheTarget] {
  reports.filter { $0.selectable && ids.contains($0.id) }.map(\.id)
 }
}
public struct CacheCleanupResult: Sendable {
 public let target: CacheTarget
 public let error: String?
}
private struct CacheFailure: LocalizedError {
 let message: String
 var errorDescription: String? { message }
}
public struct CacheService: @unchecked Sendable {
 private let home: URL
 private let processes: () throws -> [String]
 public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, processes: @escaping () throws -> [String] = CacheService.liveProcesses) {
  self.home = home; self.processes = processes
 }
 public static func liveProcesses() throws -> [String] {
  let p = Process(); let pipe = Pipe()
  p.executableURL = URL(fileURLWithPath: "/bin/ps"); p.arguments = ["-axo", "command="]
  p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
  try p.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
  guard p.terminationStatus == 0, let text = String(data: data, encoding: .utf8), !text.isEmpty else { throw CacheFailure(message: "Не удалось проверить процессы; очистка запрещена") }
  return text.components(separatedBy: .newlines)
 }
 private func failure(_ context: String) -> CacheFailure { CacheFailure(message: context + ": " + String(cString: strerror(errno))) }
 // Open each path component without following links, including the home ancestors.
 private func openDirectory(_ path: String) throws -> Int32? {
  guard path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { throw CacheFailure(message: "Недопустимый путь") }
  var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
  guard fd >= 0 else { throw failure("Открытие корня") }
  for part in path.split(separator: "/") {
   let next = openat(fd, String(part), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
   let saved = errno; close(fd); errno = saved
   if next < 0 { if errno == ENOENT { return nil }; throw failure("Небезопасный или недоступный путь " + path) }
   fd = next
  }
  return fd
 }
 private func names(_ fd: Int32) throws -> [String] {
  let copy = openat(fd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
  guard copy >= 0 else { throw failure("Чтение каталога") }
  guard let stream = fdopendir(copy) else { close(copy); throw failure("Чтение каталога") }
  defer { closedir(stream) }
  var result: [String] = []
  while true {
   errno = 0
   guard let entry = readdir(stream) else { if errno != 0 { throw failure("Перечисление каталога") }; break }
   let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) } }
   if name != "." && name != ".." { result.append(name) }
  }
  return result
 }
 private func walk(_ fd: Int32, device: dev_t) throws -> Int64 {
  var files: [String: Int64] = [:]
  return try walk(fd, device: device, files: &files)
 }
 private func walk(_ fd: Int32, device: dev_t, files: inout [String: Int64]) throws -> Int64 {
  var total: Int64 = 0
  for name in try names(fd) {
   var st = stat()
   guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { throw failure(name) }
   guard st.st_dev == device else { throw CacheFailure(message: "Другой том: " + name) }
   let type = st.st_mode & S_IFMT
   if type == S_IFDIR {
    let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard child >= 0 else { throw failure(name) }; defer { close(child) }
    total += try walk(child, device: device, files: &files)
   } else if type == S_IFREG {
    let key = "\(st.st_dev):\(st.st_ino)"
    if files[key] == nil { total += st.st_size; files[key] = st.st_size }
   }
   else { throw CacheFailure(message: "Ссылка или специальный файл; операция запрещена: " + name) }
  }
  return total
 }
 // Only application-bundle metadata is read; no profiles or private app data.
 private typealias Owner = (id: String, names: [String], tokens: [String])
 private func installedOwners() -> [Owner] {
  let fm = FileManager.default
  let roots = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
  var owners: [(id: String, names: [String], tokens: [String])] = []
  func visit(_ root: URL, depth: Int) {
   guard depth < 5, let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return }
   for url in children {
    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]), values.isDirectory == true, values.isSymbolicLink != true else { continue }
    if url.pathExtension.lowercased() != "app" { visit(url, depth: depth + 1); continue }
    guard let contents = try? openDirectory(url.appendingPathComponent("Contents").path) else { continue }
    defer { close(contents) }
    let metadata = openat(contents, "Info.plist", O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    guard metadata >= 0 else { continue }
    let handle = FileHandle(fileDescriptor: metadata, closeOnDealloc: true)
    var st = stat()
    guard fstat(metadata, &st) == 0, st.st_mode & S_IFMT == S_IFREG, st.st_size <= 1_048_576,
          let data = try? handle.read(upToCount: 1_048_576),
          let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
          plist["CFBundlePackageType"] as? String == "APPL",
          let id = plist["CFBundleIdentifier"] as? String, !id.isEmpty,
          !id.lowercased().hasPrefix("com.apple."),
          let executable = plist["CFBundleExecutable"] as? String, !executable.isEmpty else { continue }
    let names = [url.deletingPathExtension().lastPathComponent, plist["CFBundleName"] as? String, plist["CFBundleDisplayName"] as? String].compactMap { $0 }.map { $0.lowercased() }
    let tokens = ([url.path, id, executable] + names).map { $0.lowercased() }.filter { $0.count >= 3 }
    owners.append((id.lowercased(), names, tokens))
   }
  }
  for root in roots { visit(root, depth: 0) }
  return owners
 }
 private func ensureIdle(_ target: CacheTarget, owners: [Owner]) throws {
  var tokens: [String]
  switch target {
  case .comet: tokens = ["comet", "perplexity"]
  case .wechat: tokens = ["wechat", "xinwechat"]
  case .atlas: tokens = ["atlas", "com.openai"]
  default:
   let key = target.rawValue.lowercased()
   guard !key.hasPrefix("com.apple."), !key.hasPrefix("system"), !key.hasPrefix("com.apple") else {
    throw CacheFailure(message: "Защищённый системный кэш; очистка запрещена.")
   }
   // Shared Google directory: require installed Chrome, block every Google process.
   let aliases: [String: [String]] = ["google": ["com.google.chrome"], "chrome": ["com.google.chrome"],
    "dia": ["company.thebrowser.dia"], "firefox": ["org.mozilla.firefox"],
    "opera": ["com.operasoftware.opera"], "yandex": ["ru.yandex.desktop.yandex-browser"],
    "signal": ["org.whispersystems.signal-desktop"], "cmux": ["com.cmuxterm.app"]]
   let matches = owners.filter { $0.id == key || $0.names.contains(key) || (aliases[key]?.contains($0.id) == true) }
   guard !matches.isEmpty else { throw CacheFailure(message: "Владелец и фоновые процессы не определены надёжно; удаление заблокировано.") }
   tokens = matches.flatMap(\.tokens)
   if key == "google" { tokens += ["google", "chrome", "keystone"] }
  }
  for line in try processes() {
   let lower = line.lowercased()
   if let token = tokens.first(where: { lower.contains($0) }) {
    throw CacheFailure(message: "Заблокировано: процесс владельца (признак «\(token)»). Закройте приложение и его помощники, затем нажмите «Обновить проверку».")
   }
   // Apple's knowledge-index daemon is not an application updater. Exempt
   // only this exact executable + argument boundary, after owner checks.
   // Other unowned updaters remain fail-closed; never display raw arguments.
   let spotlight = "/usr/libexec/spotlightknowledged.updater"
   if lower == spotlight || lower.hasPrefix(spotlight + " ") { continue }
   if let token = ["sparkle", "autoupdate", "updater", "shipit"].first(where: { lower.contains($0) }) {
    throw CacheFailure(message: "Заблокировано: обнаружен обновлятор (признак «\(token)»), его владелец может быть другим приложением. Дождитесь завершения обновления и нажмите «Обновить проверку».")
   }
  }
 }
 public func cleanup(_ target: CacheTarget, confirmed: Bool) throws {
  guard confirmed else { throw CacheFailure(message: "Требуется явное подтверждение") }
  let owners = installedOwners()
  try ensureIdle(target, owners: owners)
  let path = home.appendingPathComponent(target.relativePath).path
  guard let fd = try openDirectory(path) else { return }
  defer { close(fd) }
  var root = stat(); guard fstat(fd, &root) == 0 else { throw failure(path) }
  _ = try walk(fd, device: root.st_dev) // Full safety preflight before any mutation.
  try erase(fd, device: root.st_dev, target: target, owners: owners)
  // Keep the direct-child root; remove only its contents.
 }
 public func cleanupSelected(_ targets: [CacheTarget], confirmed: Bool) -> [CacheCleanupResult] {
  var seen: Set<CacheTarget> = []
  return targets.filter { seen.insert($0).inserted }.map { target in
   do { try cleanup(target, confirmed: confirmed); return CacheCleanupResult(target: target, error: nil) }
   catch { return CacheCleanupResult(target: target, error: error.localizedDescription) }
  }
 }
 private func erase(_ fd: Int32, device: dev_t, target: CacheTarget, owners: [Owner]) throws {
  for name in try names(fd) {
   try ensureIdle(target, owners: owners) // Recheck immediately before each mutation, not only at confirmation.
   var st = stat()
   guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { throw failure(name) }
   guard st.st_dev == device else { throw CacheFailure(message: "Другой том: " + name) }
   let type = st.st_mode & S_IFMT
   if type == S_IFDIR {
    let child = openat(fd, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard child >= 0 else { throw failure(name) }; defer { close(child) }
    var opened = stat(); guard fstat(child, &opened) == 0, opened.st_ino == st.st_ino, opened.st_dev == device else { throw CacheFailure(message: "Каталог изменился: " + name) }
    try erase(child, device: device, target: target, owners: owners)
    try ensureIdle(target, owners: owners)
    guard unlinkat(fd, name, AT_REMOVEDIR) == 0 else { throw failure(name) }
   } else if type == S_IFREG {
    guard unlinkat(fd, name, 0) == 0 else { throw failure(name) }
   } else { throw CacheFailure(message: "Ссылка или специальный файл; операция запрещена: " + name) }
  }
 }
 public func audit() -> [CacheReport] {
  let base = home.appendingPathComponent("Library/Caches").path
  let targets: [CacheTarget]
  do {
   guard let fd = try openDirectory(base) else { return [] }
   defer { close(fd) }
   targets = try names(fd).sorted().compactMap { name in
    var st = stat()
    guard fstatat(fd, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else { throw failure(name) }
    // Regular top-level files are not application cache directories. Links
    // remain visible as blocked entries, never traversed.
    guard st.st_mode & S_IFMT != S_IFREG else { return nil }
    return CacheTarget(rawValue: name)
   }
  } catch {
   return [CacheReport(id: .comet, path: base, error: error.localizedDescription)]
  }
  let owners = installedOwners()
  return targets.map { target in
   var report = CacheReport(id: target, path: home.appendingPathComponent(target.relativePath).path)
   do {
    guard let fd = try openDirectory(report.path) else { report.bytes = 0; return report }
    defer { close(fd) }; report.present = true
    var st = stat(); guard fstat(fd, &st) == 0 else { throw failure(report.path) }
    report.bytes = try walk(fd, device: st.st_dev, files: &report.measuredFiles)
    do { try ensureIdle(target, owners: owners) } catch { report.disabledReason = error.localizedDescription }
   } catch { report.error = error.localizedDescription }
   return report
  }
 }
}
