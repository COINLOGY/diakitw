import Foundation
import Darwin

public final class ServerCancellation: @unchecked Sendable {
 private let lock = NSLock(); private var cancelled = false; private var group: pid_t?
 public init() {}
 public func cancel() { lock.lock(); defer { lock.unlock() }; cancelled = true; if let group { _ = kill(-group, SIGKILL) } }
 public var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
 fileprivate func launch(_ body: (inout pid_t) -> Int32) -> (Int32, pid_t) {
  lock.lock(); defer { lock.unlock() }; guard !cancelled else { return (ECANCELED, 0) }
  var pid: pid_t = 0; let code = body(&pid); if code == 0 { group = pid }; return (code, pid)
 }
 fileprivate func clear() { lock.lock(); group = nil; lock.unlock() }
}

/// Independent process group; no inherited environment except SSH_AUTH_SOCK in key mode.
public enum ServerSSHProcess {
 public enum Reason { case finished, cancelled, timeout, outputLimit, launchFailed }
 public struct Output { public var stdout = Data(); public var stderr = Data(); public var status: Int32 = -1; public var reason: Reason = .launchFailed }
 public static func run(executable: String, arguments: [String], input: Data, environment: [String: String] = [:], timeout: Double = 20, cancellation: ServerCancellation) -> Output {
  var result = Output()
  guard !cancellation.isCancelled else { result.reason = .cancelled; return result }
  guard timeout.isFinite, timeout > 0, timeout <= 120, input.count <= 65536 else { return result }
  let out = Pipe(), err = Pipe(), stdin = Pipe(); var inputClosed = false
  defer { out.fileHandleForReading.closeFile(); out.fileHandleForWriting.closeFile(); err.fileHandleForReading.closeFile(); err.fileHandleForWriting.closeFile(); stdin.fileHandleForReading.closeFile(); if !inputClosed { stdin.fileHandleForWriting.closeFile() } }
  var actions: posix_spawn_file_actions_t?; var attrs: posix_spawnattr_t?
  guard posix_spawn_file_actions_init(&actions) == 0 else { return result }
  defer { posix_spawn_file_actions_destroy(&actions) }
  guard posix_spawnattr_init(&attrs) == 0 else { return result }
  defer { posix_spawnattr_destroy(&attrs) }
  guard posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
        posix_spawnattr_setpgroup(&attrs, 0) == 0,
        posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, STDIN_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, out.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&actions, err.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0 else { return result }
  var safeEnv = ["LC_ALL": "C", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
  for key in ["SSH_ASKPASS", "SSH_ASKPASS_REQUIRE", "DISPLAY", "MACDIR_SSH_ID", "MACDIR_SSH_TARGET", "MACDIR_SSH_PORT", "MACDIR_SSH_REF"] { safeEnv[key] = environment[key] }
  if environment["SSH_ASKPASS"] == nil { safeEnv["SSH_AUTH_SOCK"] = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] }
  let args = ([executable] + arguments).map { strdup($0) } + [nil]
  let env = safeEnv.map { strdup($0.key + "=" + $0.value) } + [nil]
  defer { args.forEach { free($0) }; env.forEach { free($0) } }
  let (code, pid) = cancellation.launch { pid in
   args.withUnsafeBufferPointer { a in env.withUnsafeBufferPointer { e in
    posix_spawn(&pid, executable, &actions, &attrs, UnsafeMutablePointer(mutating: a.baseAddress!), UnsafeMutablePointer(mutating: e.baseAddress!))
   } }
  }
  guard code == 0 else { if code == ECANCELED { result.reason = .cancelled }; return result }
  out.fileHandleForWriting.closeFile(); err.fileHandleForWriting.closeFile(); stdin.fileHandleForReading.closeFile()
  let ofd = out.fileHandleForReading.fileDescriptor, efd = err.fileHandleForReading.fileDescriptor, ifd = stdin.fileHandleForWriting.fileDescriptor
  for fd in [ofd, efd, ifd] { _ = fcntl(fd, F_SETFL, O_NONBLOCK) }; _ = fcntl(ifd, F_SETNOSIGPIPE, 1)
  let start = ProcessInfo.processInfo.systemUptime
  var stopped: Double?; var reaped = false; var status: Int32 = 0; var sent = 0
  result.reason = .finished
  defer { _ = kill(-pid, SIGKILL); cancellation.clear(); if !reaped { while waitpid(pid, &status, 0) < 0 && errno == EINTR {} } }
  func drain(_ fd: Int32, _ data: inout Data) -> Bool {
   var bytes = [UInt8](repeating: 0, count: 4096); var overflow = false
   for _ in 0..<16 {
    let n = Darwin.read(fd, &bytes, bytes.count); if n <= 0 { break }
    let room = max(0, 65536 - data.count); data.append(contentsOf: bytes.prefix(min(n, room))); if n > room { overflow = true }
   }; return overflow
  }
  while true {
   if !inputClosed {
    if sent < input.count {
     let n = input.withUnsafeBytes { Darwin.write(ifd, $0.baseAddress!.advanced(by: sent), min(4096, input.count - sent)) }
     if n > 0 { sent += n } else if n < 0 && errno != EAGAIN && errno != EINTR { sent = input.count }
    }
    if sent == input.count { stdin.fileHandleForWriting.closeFile(); inputClosed = true }
   }
   let overOut = drain(ofd, &result.stdout), overErr = drain(efd, &result.stderr)
   let elapsed = ProcessInfo.processInfo.systemUptime - start
   if stopped == nil {
    if cancellation.isCancelled { result.reason = .cancelled; stopped = elapsed }
    else if overOut || overErr { result.reason = .outputLimit; stopped = elapsed }
    else if elapsed >= timeout { result.reason = .timeout; stopped = elapsed }
    if stopped != nil { _ = kill(-pid, SIGTERM) }
   }
   let waited = waitpid(pid, &status, WNOHANG)
   if waited == pid || (waited == -1 && errno == ECHILD) {
    reaped = true
    let finalOut = drain(ofd, &result.stdout), finalErr = drain(efd, &result.stderr)
    if (finalOut || finalErr) && result.reason == .finished { result.reason = .outputLimit }
    result.status = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f); return result
   }
   if let stopped, elapsed - stopped >= 0.3 { _ = kill(-pid, SIGKILL) }
   Thread.sleep(forTimeInterval: 0.01)
  }
 }
}
