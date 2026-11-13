import Foundation

/// GeoJS documented HTTPS schema. Egress approximation, never device/GPS position.
public struct EgressLocation {
 public let ip: String
 public let country: String?
 public let city: String?
 public let latitude: Double?
 public let longitude: Double?
 public var summary: String { [country, city].compactMap { $0 }.joined(separator: " · ") }
 public static func clean(_ value: String?) -> String? {
  guard let value, value.count <= 160 else { return nil }
  let result = String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && $0.properties.generalCategory != .format }).trimmingCharacters(in: .whitespacesAndNewlines)
  return result.isEmpty || result == "Unknown" ? nil : result
 }
 public static func decode(_ data: Data, status: Int) -> EgressLocation? {
  struct Reply: Decodable { let ip: String; let country: String?; let city: String?; let latitude: String?; let longitude: String? }
  guard status == 200, data.count <= 16384, let r = try? JSONDecoder().decode(Reply.self, from: data), let ip = MacIdentity.validAddress(r.ip) else { return nil }
  let lat = r.latitude.flatMap(Double.init), lon = r.longitude.flatMap(Double.init)
  let valid = lat.map { $0.isFinite && (-90...90).contains($0) } == true && lon.map { $0.isFinite && (-180...180).contains($0) } == true
  return EgressLocation(ip: ip, country: clean(r.country), city: clean(r.city), latitude: valid ? lat : nil, longitude: valid ? lon : nil)
 }
 /// EMCx's bounded 2ip response is one atomic caller-IP/location observation.
 /// Nullable geography is valid: never invent a country or merge fallback fields.
 public static func decodeProxy(_ data: Data, status: Int) -> EgressLocation? {
  struct Reply: Decodable { let ip: String; let country: String?; let city: String?; let lat: Double?; let lon: Double? }
  guard status == 200, data.count <= 16384, let r = try? JSONDecoder().decode(Reply.self, from: data), let ip = MacIdentity.validAddress(r.ip) else { return nil }
  let valid = r.lat.map { $0.isFinite && (-90...90).contains($0) } == true && r.lon.map { $0.isFinite && (-180...180).contains($0) } == true
  return EgressLocation(ip: ip, country: clean(r.country), city: clean(r.city), latitude: valid ? r.lat : nil, longitude: valid ? r.lon : nil)
 }
 public var mapURL: URL? {
  var url = URLComponents(); url.scheme = "https"; url.host = "maps.apple.com"; url.path = "/"
  if let latitude, let longitude {
   url.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"), URLQueryItem(name: "q", value: "Приблизительный выход в интернет (не GPS)")]
  } else if let country {
   url.queryItems = [URLQueryItem(name: "q", value: country)]
  } else { return nil }
  return url.url
 }
}
