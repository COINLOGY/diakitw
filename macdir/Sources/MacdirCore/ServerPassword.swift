import Foundation
import Security
import Darwin

public enum ServerCredentialError: String, Error, LocalizedError {
 case missing = "Пароль не сохранён или Связка ключей недоступна. Введите пароль в настройках сервера."
 case helper = "SSH Askpass отсутствует. Требуется полная сборка приложения."
 case invalid = "Пароль должен быть непустым, до 4096 байт, без NUL и переводов строк."
 case save = "Не удалось сохранить пароль в Связке ключей. Конфигурация не изменена."
 public var errorDescription: String? { rawValue }
}

/// Only this app's service and exact server/endpoint/reference tuple is addressable.
/// No password is returned to the UI or serialized in server configuration.
public enum ServerPasswordStore {
 public static let service = "pro.emcx.macdir.ssh-password.v1"
 private static func query(_ c: ServerConfig) throws -> [String: Any] {
  _ = try c.sshArguments()
  guard let ref = c.passwordReference, UUID(uuidString: ref) != nil else { throw ServerCredentialError.missing }
  return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
          kSecAttrAccount as String: c.id + "|" + c.target + "|" + String(c.port) + "|" + ref,
          kSecAttrSynchronizable as String: false]
 }
 public static func validate(_ data: Data) throws {
  guard !data.isEmpty, data.count <= 4096, !data.contains(0), !data.contains(10), !data.contains(13) else { throw ServerCredentialError.invalid }
 }
 public static func read(_ c: ServerConfig) throws -> Data {
  var q = try query(c); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
  q[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
  var value: CFTypeRef?
  guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { throw ServerCredentialError.missing }
  try validate(data); return data
 }
 public static func save(_ password: String, for c: ServerConfig, helper: String) throws {
  let data = Data(password.utf8); try validate(data)
  // Create-only random references make JSON failure rollback safe; never overwrite old credentials.
  var q = try query(c)
  var app: SecTrustedApplication?; var askpass: SecTrustedApplication?; var access: SecAccess?
  guard FileManager.default.isExecutableFile(atPath: helper),
        SecTrustedApplicationCreateFromPath(nil, &app) == errSecSuccess,
        SecTrustedApplicationCreateFromPath(helper, &askpass) == errSecSuccess,
        let app, let askpass,
        SecAccessCreate("diakitw SSH password" as CFString, [app, askpass] as CFArray, &access) == errSecSuccess, let access else { throw ServerCredentialError.helper }
  q[kSecAttrAccess as String] = access
  q[kSecValueData as String] = data
  q[kSecAttrLabel as String] = "diakitw SSH · " + c.name
  q[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
  guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw ServerCredentialError.save }
  // Exact target readback verifies the write; no logs, no security CLI subprocess.
  guard (try? read(c)) == data else { try? delete(c); throw ServerCredentialError.save }
 }
 public static func delete(_ c: ServerConfig) throws {
  guard c.passwordReference != nil else { return }
  var q = try query(c); q[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
  let status = SecItemDelete(q as CFDictionary)
  guard status == errSecSuccess || status == errSecItemNotFound else { throw ServerCredentialError.save }
  var verify = try query(c); verify[kSecReturnAttributes as String] = true; verify[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
  guard SecItemCopyMatching(verify as CFDictionary, nil) == errSecItemNotFound else { throw ServerCredentialError.save }
 }
}

public enum ServerAskpass {
 public static var helperPath: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ServerAskpass").path }
 public static func environment(config: ServerConfig, helper: String) throws -> [String: String] {
  _ = try config.sshArguments()
  guard config.authentication == .password, let ref = config.passwordReference, UUID(uuidString: ref) != nil else { throw ServerCredentialError.missing }
  return ["SSH_ASKPASS": helper, "SSH_ASKPASS_REQUIRE": "force", "DISPLAY": "macdir:0",
          "MACDIR_SSH_ID": config.id, "MACDIR_SSH_TARGET": config.target, "MACDIR_SSH_PORT": String(config.port), "MACDIR_SSH_REF": ref]
 }
 public static func response(prompt: String, config: ServerConfig, read: (ServerConfig) throws -> Data) throws -> Data {
  _ = try config.sshArguments()
  guard config.authentication == .password, prompt == config.target + "'s password: " else { throw ServerCredentialError.missing }
  let data = try read(config); try ServerPasswordStore.validate(data)
  return data + Data([10])
 }
 /// Actual executable entry: no terminal/file output, only OpenSSH's inherited anonymous pipe.
 public static func run() -> Int32 {
  _ = alarm(8)
  var limit = rlimit(rlim_cur: 0, rlim_max: 0); _ = setrlimit(RLIMIT_CORE, &limit)
  var path = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
  var info = stat()
  guard CommandLine.arguments.count == 2,
        proc_pidpath(getppid(), &path, UInt32(path.count)) > 0, String(cString: path) == "/usr/bin/ssh",
        fstat(STDOUT_FILENO, &info) == 0, info.st_mode & S_IFMT == S_IFIFO else { return 1 }
  let e = ProcessInfo.processInfo.environment
  guard let id = e["MACDIR_SSH_ID"], let target = e["MACDIR_SSH_TARGET"], let p = e["MACDIR_SSH_PORT"], let port = try? ServerConfig.parsePort(p), let ref = e["MACDIR_SSH_REF"] else { return 1 }
  let c = ServerConfig(id: id, name: "SSH", target: target, identityFile: nil, role: "bot", authentication: .password, port: port, passwordReference: ref)
  do {
   var response = try response(prompt: CommandLine.arguments[1], config: c, read: ServerPasswordStore.read)
   defer { response.resetBytes(in: 0..<response.count) }
   let success = response.withUnsafeBytes { bytes -> Bool in
    var sent = 0
    while sent < bytes.count {
     let n = Darwin.write(STDOUT_FILENO, bytes.baseAddress!.advanced(by: sent), bytes.count - sent)
     if n < 0 && errno == EINTR { continue }; if n <= 0 { return false }; sent += n
    }; return true
   }
   return success ? 0 : 1
  } catch { return 1 }
 }
}
