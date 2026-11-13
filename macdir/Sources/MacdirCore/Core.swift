import Foundation
import Darwin

// Mutated only on the scanner's serial worker; published after traversal finishes.
public final class FileNode: Identifiable, @unchecked Sendable {
 public var id: String { path }
 public let path: String
 public var name: String { label ?? URL(fileURLWithPath: path).lastPathComponent }
 public var label: String?
 public var isDirectory: Bool
 public var logical: Int64 = 0
 public var allocated: Int64 = 0
 public var children: [FileNode] = []
 public var state = "Не обследовано"
 public var target: String?
 public var complete = false
 public init(path: String, isDirectory: Bool) { self.path = path; self.isDirectory = isDirectory }
 public var sizeText: String { state == "Не обследовано" ? "Неизвестно" : complete ? bytes(logical) : "≥ " + bytes(logical) }
}
public struct ScanIssue: Identifiable, Sendable {
 public var id: String { path }
 public let path: String
 public let message: String
}
public struct ScanResult: Sendable {
 public var root: FileNode
 public var currentPath = ""
 public var elapsedSeconds: TimeInterval = 0
 public var files = 0
 public var symlinks = 0
 public var errors = 0
 public var hardlinks = 0
 public var aliases = 0
 public var cancelled = false
 public var limited = false
 public var issues: [ScanIssue] = []
 public var status: String { cancelled ? "НЕПОЛНЫЙ: остановлено" : errors > 0 ? "НЕПОЛНЫЙ: ошибки доступа/чтения" : "Обход завершён (не атомарный снимок)" }
}
/// Display-only grouping. All entries remain accessible in the directory table.
public func mapNodes(_ nodes: [FileNode]) -> [FileNode] {
 let positive = nodes.filter { $0.logical > 0 }.sorted { $0.logical > $1.logical }
 guard positive.count > 80 else { return positive }
 let others = FileNode(path: "macdir:others:" + (nodes.first?.path ?? ""), isDirectory: true)
 others.children = Array(positive.dropFirst(79))
 others.label = "Остальные (\(others.children.count))"
 others.logical = others.children.reduce(0) { $0 + $1.logical }
 others.allocated = others.children.reduce(0) { $0 + $1.allocated }
 others.complete = others.children.allSatisfy { $0.complete }
 others.state = "Группа карты, не каталог"
 return Array(positive.prefix(79)) + [others]
}
public enum Scanner {
 // limit is retained for source compatibility, but is no longer a traversal cap.
 public static func scan(_ url: URL, limit: Int = .max, cancelled: () -> Bool = { false }, progress: ((ScanResult) -> Void)? = nil) -> ScanResult {
  let root = FileNode(path: url.standardizedFileURL.path, isDirectory: true)
  var result = ScanResult(root: root)
  let started = ProcessInfo.processInfo.systemUptime
  var directories: [String: String] = [:]
  var files: [String: String] = [:]
  var topPaths = Set<String>()
  var activeTop: String?
  var totals: [String: (Int64, Int64)] = [:]
  var lastProgress = Date.distantPast
  func publish(_ force: Bool = false) {
   result.elapsedSeconds = ProcessInfo.processInfo.systemUptime - started
   guard let progress, force || Date().timeIntervalSince(lastProgress) >= 0.5 else { return }
   lastProgress = Date()
   let copy = FileNode(path: root.path, isDirectory: true)
   copy.children = root.children.map { original in
    let child = FileNode(path: original.path, isDirectory: original.isDirectory)
    child.target = original.target; child.complete = original.complete; child.state = original.state
    if original.state == "Каталог" { child.complete = false }
    if let total = totals[original.path], !child.complete {
     child.logical = total.0; child.allocated = total.1; child.state = "Подсчёт…"
    } else { child.logical = original.logical; child.allocated = original.allocated }
    return child
   }
   copy.logical = copy.children.reduce(0) { $0 + $1.logical }
   copy.allocated = copy.children.reduce(0) { $0 + $1.allocated }
   copy.complete = root.complete && copy.children.allSatisfy { $0.complete }
   copy.state = copy.complete ? "Обследовано" : "Подсчёт…"
   var frame = result; frame.root = copy; progress(frame)
  }
  func issue(_ node: FileNode, _ message: String) {
   result.errors += 1; result.issues.append(ScanIssue(path: node.path, message: message)); node.state = message
  }
  // Explicit enter/exit frames avoid recursive traversal and recursive aggregation.
  var stack: [(FileNode, Bool)] = [(root, false)]
  while let (node, exiting) = stack.popLast() {
   result.currentPath = node.path
   defer { publish() }
   if !exiting && topPaths.contains(node.path) { activeTop = node.path; totals[node.path] = (0, 0) }
   if exiting {
    node.logical = node.children.reduce(0) { $0 + $1.logical }
    node.allocated = node.children.reduce(0) { $0 + $1.allocated }
    node.complete = node.complete && node.children.allSatisfy { $0.complete }
    if node.state == "Каталог" { node.state = node.complete ? "Обследовано" : "Частично / неизвестно" }
    continue
   }
   // Always enumerate the selected directory's immediate names, even on cancel.
   if cancelled() && node !== root { result.cancelled = true; continue }
   var info = stat()
   guard lstat(node.path, &info) == 0 else { issue(node, String(cString: strerror(errno))); continue }
   let kind = info.st_mode & S_IFMT
   let key = "\(info.st_dev):\(info.st_ino)"
   node.isDirectory = kind == S_IFDIR
   if kind == S_IFDIR {
    if let original = directories[key] {
     result.aliases += 1; node.target = original; node.state = "Повтор каталога → \(original)"; node.complete = true; continue
    }
    directories[key] = node.path
    guard let stream = opendir(node.path) else { issue(node, String(cString: strerror(errno))); continue }
    node.complete = true; node.state = "Каталог"
    while true {
     errno = 0
     guard let entry = readdir(stream) else {
      if errno != 0 { node.complete = false; issue(node, String(cString: strerror(errno))) }
      break
     }
     let name = withUnsafePointer(to: &entry.pointee.d_name) {
      $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
     }
     if name == "." || name == ".." { continue }
     let path = (node.path as NSString).appendingPathComponent(name)
     node.children.append(FileNode(path: path, isDirectory: entry.pointee.d_type == UInt8(DT_DIR)))
    }
    closedir(stream)
    if node === root { topPaths = Set(node.children.map(\.path)) }
    // Visible firmlink paths win over /System/Volumes/Data aliases on a root scan.
    if node === root && root.path == "/" {
     node.children.sort { ($0.name == "System" ? 1 : 0, $0.name) < ($1.name == "System" ? 1 : 0, $1.name) }
    }
    stack.append((node, true))
    if cancelled() { result.cancelled = true; node.complete = false }
    else { for child in node.children.reversed() { stack.append((child, false)) } }
   } else if kind == S_IFLNK {
    result.symlinks += 1
    node.target = try? FileManager.default.destinationOfSymbolicLink(atPath: node.path)
    node.state = "Ссылка (не обходится) → \(node.target ?? "цель недоступна")"
    node.complete = true
   } else if kind == S_IFREG {
    result.files += 1; node.complete = true
    if let original = files[key] {
     result.hardlinks += 1; node.target = original; node.state = "Hardlink: учтён в \(original)"
    } else {
     // Only multiply-linked files need a dedup entry: bounded extra memory for ordinary files.
     if info.st_nlink > 1 { files[key] = node.path }
     node.logical = info.st_size; node.allocated = Int64(info.st_blocks) * 512; node.state = "Файл"
     if let key = activeTop {
      let previous = totals[key] ?? (0, 0)
      totals[key] = (previous.0 + node.logical, previous.1 + node.allocated)
     }
    }
   } else { node.complete = true; node.state = "Специальный объект (не читается)" }
  }
  publish(true)
  return result
 }
}
