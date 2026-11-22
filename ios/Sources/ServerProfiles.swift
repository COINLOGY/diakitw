import Foundation

// Profile metadata only. No credential, host-key approval, connection or telemetry is stored.
struct ServerProfiles {
    struct Profile: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var host: String
        var port: Int
        var login: String
    }
    struct Draft {
        var name: String
        var host: String
        var port: Int
        var login: String
    }
    struct Row {
        let profile: Profile
        let cpu = "Н/Д"
        let ram = "Н/Д"
        let swap = "Н/Д"
        let disk = "Н/Д"
    }
    enum ValidationError: Error { case invalidInput }
    static let supportsSSH = false
    private static let key = "serverProfiles.v1"
    private let defaults: UserDefaults
    private(set) var profiles: [Profile]
    var selection: UUID?
    var selected: Profile? { profiles.first { $0.id == selection } }
    var rows: [Row] { profiles.map(Row.init) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        profiles = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Profile].self, from: $0) } ?? []
    }

    static func validate(name: String, host: String, port: String, login: String) throws -> Draft {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let login = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let domain = host.count <= 253 && labels.allSatisfy { label in
            !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
            label.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-").contains($0) }
        }
        let ipv6 = host.contains(":") && host.count <= 39 && host.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdefABCDEF:").contains($0)
        } && host.filter { $0 == ":" }.count >= 2
        guard !name.isEmpty, name.count <= 80, domain || ipv6,
              !login.isEmpty, login.count <= 64,
              login.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-").contains($0) }),
              !port.isEmpty, port.allSatisfy({ $0.isASCII && $0.isNumber }),
              let portNumber = Int(port), (1...65535).contains(portNumber) else { throw ValidationError.invalidInput }
        return Draft(name: name, host: host, port: portNumber, login: login)
    }

    @discardableResult mutating func save(_ draft: Draft, id: UUID? = nil) -> UUID {
        let key = id.flatMap { existing in profiles.first { $0.id == existing }?.id } ?? UUID()
        let profile = Profile(id: key, name: draft.name, host: draft.host, port: draft.port, login: draft.login)
        if let index = profiles.firstIndex(where: { $0.id == key }) { profiles[index] = profile }
        else { profiles.append(profile) }
        defaults.set(try? JSONEncoder().encode(profiles), forKey: Self.key)
        selection = key
        return key
    }
}
