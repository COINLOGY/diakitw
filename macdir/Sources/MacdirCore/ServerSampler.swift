import Foundation
import Darwin

public struct ServerConfig: Codable, Identifiable {
 public let id: String; public let name: String; public let target: String; public let identityFile: String?; public let role: String
 public let domain: String?; public let ipAddress: String?
 public enum Authentication: String, Codable { case key, password }
 public let authentication: Authentication
 public let port: Int
 public let passwordReference: String?
 private enum CodingKeys: String, CodingKey { case id, name, target, identityFile, role, domain, ipAddress, authentication, port, passwordReference }
 public init(from decoder: Decoder) throws {
  let c = try decoder.container(keyedBy: CodingKeys.self)
  id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
  target = try c.decode(String.self, forKey: .target); role = try c.decode(String.self, forKey: .role)
  identityFile = try c.decodeIfPresent(String.self, forKey: .identityFile)
  domain = try c.decodeIfPresent(String.self, forKey: .domain); ipAddress = try c.decodeIfPresent(String.self, forKey: .ipAddress)
  authentication = try c.decodeIfPresent(Authentication.self, forKey: .authentication) ?? .key
  port = try c.contains(.port) ? c.decode(Int.self, forKey: .port) : 22
  passwordReference = try c.decodeIfPresent(String.self, forKey: .passwordReference)
 }
 public static func parsePort(_ text: String) throws -> Int {
  guard !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }), let port = Int(text), (1...65535).contains(port) else { throw ServerError.config }; return port
 }
 public var headerAddress: String {
  let parts = [domain, ipAddress].compactMap { $0 }.filter { !$0.isEmpty }
  return parts.isEmpty ? String(target.split(separator: "@").last ?? "") : parts.joined(separator: " · ")
 }
 public init(id: String, name: String, target: String, identityFile: String?, role: String, domain: String? = nil, ipAddress: String? = nil, authentication: Authentication = .key, port: Int = 22, passwordReference: String? = nil) { self.id = id; self.name = name; self.target = target; self.identityFile = identityFile; self.role = role; self.domain = domain; self.ipAddress = ipAddress; self.authentication = authentication; self.port = port; self.passwordReference = passwordReference }
 public static var configURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/macdir/servers.json") }
 public static func load() throws -> [Self] { try decode(Data(contentsOf: configURL)) }
 public static func decode(_ data: Data) throws -> [Self] {
  guard data.count <= 65536, let list = try? JSONDecoder().decode([Self].self, from: data), list.count <= 16, Set(list.map(\.id)).count == list.count else { throw ServerError.config }
  for c in list { _ = try c.sshArguments() }; return list
 }
 public func sshArguments(specs: Bool = false) throws -> [String] {
  guard target.range(of: "\\A[A-Za-z0-9_][A-Za-z0-9_.-]*@[A-Za-z0-9][A-Za-z0-9.-]*\\z", options: .regularExpression) != nil, ["bot", "agent"].contains(role), !id.isEmpty, id.count <= 64, !name.isEmpty, name.count <= 80, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw ServerError.config }
  guard (1...65535).contains(port) else { throw ServerError.config }
  if let passwordReference, UUID(uuidString: passwordReference) == nil { throw ServerError.config }
  var args = ["-T", "-p", String(port), authentication == .key ? "-oBatchMode=yes" : "-oBatchMode=no", "-oStrictHostKeyChecking=yes", "-oConnectTimeout=8", "-oServerAliveInterval=5", "-oServerAliveCountMax=1", "-oForwardAgent=no", "-oClearAllForwardings=yes", "-oControlMaster=no", "-oControlPath=none"]
  if authentication == .password {
   // Ignore user ssh config: no proxy/local commands can inherit askpass access.
   args = ["-F", "/dev/null"] + args + ["-oPreferredAuthentications=password", "-oPasswordAuthentication=yes", "-oPubkeyAuthentication=no", "-oKbdInteractiveAuthentication=no", "-oNumberOfPasswordPrompts=1", "-oPermitLocalCommand=no"]
  }
  if let identityFile, authentication == .key {
   guard identityFile.hasPrefix("/"), !identityFile.contains("\n"), !identityFile.contains("\0") else { throw ServerError.config }
   args += ["-i", identityFile, "-oIdentitiesOnly=yes"]
  }
  return args + [target, "python3 - " + role + (specs ? " specs" : "")]
 }
}
public enum ServerSampler {
 public static func classify(_ stderr: String) -> ServerError {
  let s = stderr.lowercased()
  if s.contains("host key verification failed") || s.contains("host identification has changed") { return .hostKey }
  if s.contains("permission denied") || s.contains("authentication failed") { return .denied }
  return .unavailable
 }
 // Blocking worker primitive: callers dispatch off the main actor.
 public static func sample(_ config: ServerConfig, probe: Data, specs: Bool = false, cancellation: ServerCancellation = ServerCancellation()) -> Result<ServerTelemetry, ServerError> {
  do {
   let args = try config.sshArguments(specs: specs)
   guard !probe.isEmpty, probe.count <= 65536 else { return .failure(.probe) }
   var environment: [String: String] = [:]
   if config.authentication == .password {
    environment = try ServerAskpass.environment(config: config, helper: ServerAskpass.helperPath)
    guard FileManager.default.isExecutableFile(atPath: ServerAskpass.helperPath) else { return .failure(.askpass) }
   }
   let output = ServerSSHProcess.run(executable: "/usr/bin/ssh", arguments: args, input: probe, environment: environment, cancellation: cancellation)
   switch output.reason {
   case .finished: break
   case .cancelled: return .failure(.cancelled)
   case .timeout: return .failure(.timeout)
   case .outputLimit: return .failure(.payload)
   case .launchFailed: return .failure(.unavailable)
   }
   guard output.status == 0 else { return .failure(classify(String(decoding: output.stderr, as: UTF8.self))) }
   return .success(try ServerTelemetry.decode(output.stdout))
  } catch let error as ServerError { return .failure(error) } catch is ServerCredentialError { return .failure(.credential) } catch { return .failure(.payload) }
 }
 public static func bundledProbe() throws -> Data {
  guard let url = Bundle.main.url(forResource: "server_probe", withExtension: "py"), let data = try? Data(contentsOf: url), !data.isEmpty, data.count <= 65536 else { throw ServerError.probe }; return data
 }

}
public enum BoundedServerProcess {
 public struct Output { public let stdout: Data; public let stderr: Data; public let status: Int32 }
 public static func run(executable: String, arguments: [String], input: Data, timeout: Double = 20) throws -> Output {
  let process = Process(); let out = Pipe(); let err = Pipe(); let stdin = Pipe()
  process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
  process.standardOutput = out; process.standardError = err; process.standardInput = stdin
  do { try process.run() } catch { throw ServerError.unavailable }
  out.fileHandleForWriting.closeFile(); err.fileHandleForWriting.closeFile(); stdin.fileHandleForReading.closeFile()
  let o = out.fileHandleForReading.fileDescriptor; let e = err.fileHandleForReading.fileDescriptor; let i = stdin.fileHandleForWriting.fileDescriptor
  for fd in [o, e, i] { _ = fcntl(fd, F_SETFL, O_NONBLOCK) }
  _ = fcntl(i, F_SETNOSIGPIPE, 1)
  var inputClosed = false
  defer { out.fileHandleForReading.closeFile(); err.fileHandleForReading.closeFile(); if !inputClosed { stdin.fileHandleForWriting.closeFile() } }
  var stdout = Data(); var stderr = Data(); var sent = 0; var overflow = false
  let start = ProcessInfo.processInfo.systemUptime
  var stopped: Double?
  func drain(_ fd: Int32, _ data: inout Data) {
   var buffer = [UInt8](repeating: 0, count: 4096)
   for _ in 0..<32 {
    let n = Darwin.read(fd, &buffer, buffer.count)
    if n <= 0 { break }
    let remaining = max(0, 65536 - data.count)
    data.append(contentsOf: buffer.prefix(min(n, remaining)))
    if n > remaining { overflow = true }
   }
  }
  while true {
   drain(o, &stdout); drain(e, &stderr)
   if !inputClosed {
    if sent < input.count {
     let n = input.withUnsafeBytes { raw in Darwin.write(i, raw.baseAddress!.advanced(by: sent), min(4096, input.count - sent)) }
     if n > 0 { sent += n } else if n < 0 && errno != EAGAIN && errno != EINTR { sent = input.count }
    }
    if sent == input.count { stdin.fileHandleForWriting.closeFile(); inputClosed = true }
   }
   if !process.isRunning { drain(o, &stdout); drain(e, &stderr); break }
   let elapsed = ProcessInfo.processInfo.systemUptime - start
   if stopped == nil && (elapsed >= timeout || overflow) { stopped = elapsed; process.terminate() }
   if let stopped, elapsed - stopped >= 1 { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
   if let stopped, elapsed - stopped >= 2 { throw overflow ? ServerError.payload : ServerError.timeout }
   Thread.sleep(forTimeInterval: 0.01)
  }
  if overflow { throw ServerError.payload }
  if stopped != nil { throw ServerError.timeout }
  return Output(stdout: stdout, stderr: stderr, status: process.terminationStatus)
 }
}
