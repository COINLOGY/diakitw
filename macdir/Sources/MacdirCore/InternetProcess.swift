import Foundation
import Darwin

public final class InternetCancellation: @unchecked Sendable {
 private let lock = NSLock(); private var value = false; private var group: pid_t?
 public init() {}
 // Signal synchronously: app termination may not leave time for the worker loop.
 public func cancel() { lock.lock(); value = true; if let group { _ = kill(-group, SIGKILL) }; lock.unlock() }
 public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
 fileprivate func launch(_ body: (inout pid_t) -> Int32) -> (Int32, pid_t) {
  lock.lock(); defer { lock.unlock() }
  guard !value else { return (ECANCELED, 0) }
  var pid: pid_t = 0; let code = body(&pid)
  if code == 0 { group = pid }; return (code, pid)
 }
 fileprivate func clear() { lock.lock(); group = nil; lock.unlock() }
}

// No downloaded/uploaded files: only bounded diagnostic pipes in memory.
// A new process group is established atomically at spawn, before children can run.
public enum InternetProcess {
 public enum Reason: String { case finished, cancelled, timeout, outputLimit, launchFailed }
 public struct Output {
  public var stdout = Data(); public var stderr = Data(); public var status: Int32 = -1
  public var reason: Reason = .launchFailed
 }
 public static func run(executable: String, arguments: [String], timeout: Double, cancellation: InternetCancellation, progress: (Data) -> Void = { _ in }) -> Output {
  var result = Output()
  guard !cancellation.isCancelled else { result.reason = .cancelled; return result }
  guard timeout.isFinite, timeout > 0, timeout <= 120 else { return result }
  let out = Pipe(), err = Pipe()
  defer { out.fileHandleForReading.closeFile(); out.fileHandleForWriting.closeFile(); err.fileHandleForReading.closeFile(); err.fileHandleForWriting.closeFile() }
  let ofd = out.fileHandleForReading.fileDescriptor, efd = err.fileHandleForReading.fileDescriptor
  var actions: posix_spawn_file_actions_t?; var attrs: posix_spawnattr_t?
  guard posix_spawn_file_actions_init(&actions) == 0 else { return result }
  defer { posix_spawn_file_actions_destroy(&actions) }
  guard posix_spawnattr_init(&attrs) == 0 else { return result }
  defer { posix_spawnattr_destroy(&attrs) }
  guard posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
        posix_spawnattr_setpgroup(&attrs, 0) == 0,
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
        posix_spawn_file_actions_adddup2(&actions, out.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, err.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0 else { return result }
  let args = ([executable] + arguments).map { strdup($0) } + [nil]
  // Stable English machine output. Do not copy secrets from the app environment.
  let env = [strdup("LC_ALL=C"), strdup("PATH=/usr/bin:/bin:/usr/sbin:/sbin"), nil]
  defer { args.forEach { free($0) }; env.forEach { free($0) } }
  let (code, pid) = cancellation.launch { pid in
   args.withUnsafeBufferPointer { a in env.withUnsafeBufferPointer { e in
    posix_spawn(&pid, executable, &actions, &attrs, UnsafeMutablePointer(mutating: a.baseAddress!), UnsafeMutablePointer(mutating: e.baseAddress!))
   } }
  }
  guard code == 0 else { if code == ECANCELED { result.reason = .cancelled }; return result }
  out.fileHandleForWriting.closeFile(); err.fileHandleForWriting.closeFile()
  for fd in [ofd, efd] { _ = fcntl(fd, F_SETFL, O_NONBLOCK) }
  result.reason = .finished
  let start = ProcessInfo.processInfo.systemUptime
  var stopped: Double?; var reaped = false; var waitStatus: Int32 = 0
  defer {
   // Also clean up inherited-pipe descendants after an early parent exit.
   _ = kill(-pid, SIGKILL)
   cancellation.clear()
   if !reaped { while waitpid(pid, &waitStatus, 0) < 0 && errno == EINTR {} }
  }
  func drain(_ fd: Int32, _ data: inout Data) -> Bool {
   var bytes = [UInt8](repeating: 0, count: 4096); var overflow = false
   for _ in 0..<16 {
    let n = Darwin.read(fd, &bytes, bytes.count); if n <= 0 { break }
    let room = max(0, 262144 - data.count)
    data.append(contentsOf: bytes.prefix(min(n, room)))
    if n > room { overflow = true }
   }
   return overflow
  }
  var lastProgress = -1.0
  while true {
   let overOut = drain(ofd, &result.stdout); let overErr = drain(efd, &result.stderr)
   let elapsed = ProcessInfo.processInfo.systemUptime - start
   if elapsed - lastProgress >= 0.2 { progress(result.stdout); lastProgress = elapsed }
   if stopped == nil {
    if cancellation.isCancelled { result.reason = .cancelled; stopped = elapsed }
    else if overOut || overErr { result.reason = .outputLimit; stopped = elapsed }
    else if elapsed >= timeout { result.reason = .timeout; stopped = elapsed }
    if stopped != nil { _ = kill(-pid, SIGTERM) }
   }
   let waited = waitpid(pid, &waitStatus, WNOHANG)
   if waited == pid || (waited == -1 && errno == ECHILD) {
    reaped = true
    let finalOut = drain(ofd, &result.stdout); let finalErr = drain(efd, &result.stderr)
    if (finalOut || finalErr) && result.reason == .finished { result.reason = .outputLimit }
    result.status = (waitStatus & 0x7f) == 0 ? (waitStatus >> 8) & 0xff : 128 + (waitStatus & 0x7f)
    progress(result.stdout); return result
   }
   if let stopped, elapsed - stopped >= 0.3 { _ = kill(-pid, SIGKILL) }
   Thread.sleep(forTimeInterval: 0.01)
  }
 }
}
