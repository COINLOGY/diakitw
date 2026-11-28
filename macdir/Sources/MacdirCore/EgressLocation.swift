import Foundation

/// GeoJS documented HTTPS schema. Egress approximation, never device/GPS position.
public struct EgressLocation {
 public let ip: String
 public let country: String?
 public let countryCode: String?
 public let city: String?
 public let latitude: Double?
 public let longitude: Double?
 /// Only a validated ISO 3166-1 alpha-2 code from this same response can produce a flag.
 public static func validCountryCode(_ value: String?) -> String? {
  guard let value, value.utf8.count == 2,
        value.utf8.allSatisfy({ (65...90).contains($0) }),
        Locale.Region.isoRegions.contains(where: { $0.identifier == value }) else { return nil }
  return value
 }
 public var flag: String? {
   guard country != nil, let countryCode, let first = countryCode.unicodeScalars.first,
         let second = countryCode.unicodeScalars.dropFirst().first,
         let a = Unicode.Scalar(127397 + first.value), let b = Unicode.Scalar(127397 + second.value) else { return nil }
   return "\(String(a))\(String(b))"
  }
  /// Страна с флагом: только проверенный ISO-код из того же ответа даёт флаг.
 public var labeledCountry: String? {
  country.map { name -> String in
   guard let countryCode, let first = countryCode.unicodeScalars.first,
         let second = countryCode.unicodeScalars.dropFirst().first,
         let a = Unicode.Scalar(127397 + first.value), let b = Unicode.Scalar(127397 + second.value) else { return name }
   return "\(String(a))\(String(b)) \(name)"
  }
 }
 public var summary: String {
  [labeledCountry, city].compactMap { $0 }.joined(separator: " · ")
 }
 /// То же, но с адресом выхода сразу после страны: в меню видно, какой
 /// именно узел даёт эту страну, и не приходится гадать по флагу.
 public var summaryWithAddress: String {
  [labeledCountry, ip, city].compactMap { $0 }.joined(separator: " · ")
 }
 public static func clean(_ value: String?) -> String? {
  guard let value, value.count <= 160 else { return nil }
  let result = String(value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && $0.properties.generalCategory != .format }).trimmingCharacters(in: .whitespacesAndNewlines)
  return result.isEmpty || result == "Unknown" ? nil : result
 }
 public static func decode(_ data: Data, status: Int) -> EgressLocation? {
  struct Reply: Decodable { let ip: String; let country: String?; let country_code: String?; let city: String?; let latitude: String?; let longitude: String? }
  guard status == 200, data.count <= 16384, let r = try? JSONDecoder().decode(Reply.self, from: data), let ip = MacIdentity.validAddress(r.ip) else { return nil }
  let lat = r.latitude.flatMap(Double.init), lon = r.longitude.flatMap(Double.init)
  let valid = lat.map { $0.isFinite && (-90...90).contains($0) } == true && lon.map { $0.isFinite && (-180...180).contains($0) } == true
  return EgressLocation(ip: ip, country: clean(r.country), countryCode: validCountryCode(r.country_code), city: clean(r.city), latitude: valid ? lat : nil, longitude: valid ? lon : nil)
 }
 /// EMCx's bounded 2ip response is one atomic caller-IP/location observation.
 /// Nullable geography is valid: never invent a country or merge fallback fields.
 public static func decodeProxy(_ data: Data, status: Int) -> EgressLocation? {
  struct Reply: Decodable { let ip: String; let country: String?; let code: String?; let city: String?; let lat: Double?; let lon: Double? }
  guard status == 200, data.count <= 16384, let r = try? JSONDecoder().decode(Reply.self, from: data), let ip = MacIdentity.validAddress(r.ip) else { return nil }
  let valid = r.lat.map { $0.isFinite && (-90...90).contains($0) } == true && r.lon.map { $0.isFinite && (-180...180).contains($0) } == true
  return EgressLocation(ip: ip, country: clean(r.country), countryCode: validCountryCode(r.code), city: clean(r.city), latitude: valid ? r.lat : nil, longitude: valid ? r.lon : nil)
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
