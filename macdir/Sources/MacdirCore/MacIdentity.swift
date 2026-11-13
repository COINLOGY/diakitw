import Foundation
import Darwin
import SystemConfiguration

public enum MacIdentity {
 public static func localComputerName() -> String {
  if let name = SCDynamicStoreCopyComputerName(nil, nil) as String?, !name.isEmpty { return name }
  var buffer = [CChar](repeating: 0, count: 256)
  if gethostname(&buffer, buffer.count) == 0 { return String(cString: buffer) }
  return "Недоступно"
 }
 public static func computerName(localized: String?, fallback: String) -> String {
  localized.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
 }
 public static func internalText(_ addresses: [String: [String]], interface: String) -> String {
  let valid = (addresses[interface] ?? []).compactMap(validAddress)
  return interface + " · " + (valid.isEmpty ? "Недоступен" : valid.joined(separator: " · "))
 }
 public static func externalAddress(_ data: Data, status: Int) -> String? {
  struct Reply: Decodable { let ip: String }
  guard status == 200, data.count <= 1024,
        let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return nil }
  return validAddress(reply.ip)
 }

 /// Numeric literals only. Never invoke DNS; reject loopback and unspecified.
 public static func validAddress(_ value: String?) -> String? {
  guard let value, !value.isEmpty, value.utf8.count <= 45,
        value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) || $0 == 46 || $0 == 58 }) else { return nil }
  var v4 = in_addr()
  if inet_pton(AF_INET, value, &v4) == 1 {
   let n = UInt32(bigEndian: v4.s_addr)
   return n == 0 || n >> 24 == 127 || n >> 28 == 14 || n == UInt32.max ? nil : value
  }
  var v6 = in6_addr()
  guard inet_pton(AF_INET6, value, &v6) == 1 else { return nil }
  let octets = withUnsafeBytes(of: &v6) { Array($0) }
  if octets.prefix(15).allSatisfy({ $0 == 0 }) && octets[15] <= 1 || octets[0] == 255 { return nil }
  if octets.prefix(10).allSatisfy({ $0 == 0 }) && octets[10] == 255 && octets[11] == 255 {
   guard validAddress(octets.suffix(4).map(String.init).joined(separator: ".")) != nil else { return nil }
  }
  return value
 }
}
