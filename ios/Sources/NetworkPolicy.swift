import Foundation
import CoreFoundation
import Darwin

enum NetworkPolicy {
    static let downloadBytes = 8 * 1024 * 1024
    static let uploadBytes = 2 * 1024 * 1024
    static let egressURL = URL(string: "https://aia.emcx.pro/diakitw-api/geo")!
    static let fallbackURL = URL(string: "https://api.country.is/")!
    static let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=8388608")!
    static let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    static func rate(bytes: Int, seconds: Double) -> Double? {
        guard bytes > 0, seconds.isFinite, seconds > 0 else { return nil }
        let result = Double(bytes) * 8 / seconds / 1_000_000
        return result.isFinite ? result : nil
    }
    struct Egress {
        let ip: String; let country: String
        var city: String? = nil; var region: String? = nil; var timezone: String? = nil
        var latitude: Double? = nil; var longitude: Double? = nil
        var asn: String? = nil; var provider: String? = nil
        var source = "api.country.is"
    }
    static func proxy(_ data: Data) throws -> Egress {
        guard data.count <= 4096,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw URLError(.cannotParseResponse) }
        func text(_ key: String, _ object: [String: Any]) throws -> String? {
            guard let value = object[key], !(value is NSNull) else { return nil }
            guard let s = value as? String, s.count <= 256,
                  !s.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || $0.properties.generalCategory == .format }) else { throw URLError(.cannotParseResponse) }
            return s.isEmpty ? nil : s
        }
        let code = try text("code", json)
        if let code, !Locale.Region.isoRegions.contains(where: { $0.identifier == code }) { throw URLError(.cannotParseResponse) }
        // Reuse strict literal IP validation; geography is never merged across responses.
        let base = try JSONSerialization.data(withJSONObject: ["ip": json["ip"] ?? NSNull(), "country_code": code ?? ""])
        let identity = try egress(base)
        func coordinate(_ key: String, _ bound: Double) throws -> Double? {
            guard let raw = json[key], !(raw is NSNull) else { return nil }
            guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite, abs(n.doubleValue) <= bound else { throw URLError(.cannotParseResponse) }
            return n.doubleValue
        }
        let lat = try coordinate("lat", 90), lon = try coordinate("lon", 180)
        var result = Egress(ip: identity.ip, country: code ?? "Н/Д")
        result.city = try text("city", json); result.region = try text("region", json)
        result.timezone = try text("timezone", json); _ = try text("country", json)
        if lat != nil && lon != nil { result.latitude = lat; result.longitude = lon }
        if let raw = json["asn"], !(raw is NSNull) {
            guard let a = raw as? [String: Any] else { throw URLError(.cannotParseResponse) }
            result.provider = try text("name", a)
            if let id = a["id"], !(id is NSNull) {
                guard let n = id as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite,
                      n.doubleValue.rounded() == n.doubleValue, (0...4294967295).contains(n.doubleValue) else { throw URLError(.cannotParseResponse) }
                result.asn = "AS\(n.uint64Value)"
            }
            if let hosting = a["hosting"], !(hosting is NSNull), CFGetTypeID(hosting as CFTypeRef) != CFBooleanGetTypeID() { throw URLError(.cannotParseResponse) }
        }
        result.source = "2ip через EMCx"
        return result
    }
    static func egress(_ data: Data) throws -> Egress {
        guard data.count <= 4096,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ip = json["ip"] as? String,
              ip.unicodeScalars.allSatisfy({ "0123456789abcdefABCDEF:.".unicodeScalars.contains($0) }) else { throw URLError(.cannotParseResponse) }
        var v4 = in_addr(); var v6 = in6_addr()
        guard inet_pton(AF_INET, ip, &v4) == 1 || inet_pton(AF_INET6, ip, &v6) == 1 else { throw URLError(.cannotParseResponse) }
        let raw = (json["country"] ?? json["country_code"]) as? String
        let country = raw.flatMap { $0.count == 2 && $0.utf8.allSatisfy { (65...90).contains($0) } ? $0 : nil }
        return Egress(ip: ip, country: country ?? "Н/Д")
    }
}
