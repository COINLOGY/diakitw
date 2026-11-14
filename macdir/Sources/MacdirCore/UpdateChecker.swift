// Shared byte-for-byte with ios/Sources/UpdateChecker.swift. Browser-only stage.
import Foundation
import Combine
import CoreFoundation
#if os(macOS)
import Darwin
#endif

public enum UpdateContract {
    public static let endpoint = URL(string: "https://coinlogy.github.io/diakitw/updates/v1.json")!
    public static let cap = 32 * 1024
    public static let version = "0.5.4"
    public static let build = 54
    public enum Failure: Error { case invalid, http, oversized }
    public struct Version: Comparable, Equatable {
        let parts: [Int]
        public init(_ text: String) throws {
            guard text.range(of: #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil else { throw Failure.invalid }
            let values = text.split(separator: ".").compactMap { Int($0) }
            guard values.count == 3 else { throw Failure.invalid }; parts = values
        }
        public static func < (a: Self, b: Self) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
    }
    public struct Offer: Equatable {
        public let version: String
        public let build: Int
        public let notes: String
        public let url: URL
        public let size: Int
        public let sha256: String
        public var releasePage: URL { URL(string: "https://github.com/COINLOGY/diakitw/releases/tag/v" + version)! }
    }
    static func integer(_ value: Any?) throws -> Int {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              !["d", "f"].contains(String(cString: n.objCType)),
              let result = Int(n.stringValue), result >= 0, result <= 9_007_199_254_740_991 else { throw Failure.invalid }
        return result
    }
    public static func assetURL(_ text: String, version: String) throws -> URL {
        _ = try Version(version)
        let prefix = "https://github.com/COINLOGY/diakitw/releases/download/v\(version)/"
        guard text.hasPrefix(prefix) else { throw Failure.invalid }
        let name = String(text.dropFirst(prefix.count))
        guard name.utf8.count <= 180, name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil,
              !name.contains(".."), let u = URL(string: text), u.absoluteString == text,
              u.query == nil, u.fragment == nil, u.user == nil, u.password == nil, u.port == nil else { throw Failure.invalid }
        return u
    }
    public static var platform: String {
        #if os(iOS)
        return "ios-unsigned"
        #elseif os(macOS)
        // hw.optional.arm64 identifies the hardware even under Rosetta.
        var arm: Int32 = 0; var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &arm, &size, nil, 0) == 0 && arm == 1 { return "macos-arm64" }
        return "macos-x86_64"
        #else
        return "unsupported"
        #endif
    }
    public static func select(_ data: Data, channel: String, platform: String,
                              current: String = version, currentBuild: Int = build) throws -> Offer? {
        guard data.count <= cap else { throw Failure.oversized }
        guard ["stable", "preview"].contains(channel), currentBuild >= 0,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              try integer(root["schema"]) == 1,
              let releases = root["releases"] as? [[String: Any]], releases.count <= 64 else { throw Failure.invalid }
        let installed = try Version(current)
        var chosen: Offer?
        for r in releases {
            guard let text = r["version"] as? String, let c = r["channel"] as? String,
                  ["stable", "preview"].contains(c), let notes = r["notes"] as? String,
                  notes.utf8.count <= 2000, !notes.contains("<"), !notes.contains(">"),
                  !notes.unicodeScalars.contains(where: { ($0.value < 32 && $0 != "\n" && $0 != "\t") || (0x7f...0x9f).contains($0.value) }),
                  let assets = r["assets"] as? [String: Any], assets.count <= 6 else { throw Failure.invalid }
            let v = try Version(text), b = try integer(r["build"])
            var selected: Offer?
            for (key, raw) in assets {
                guard ["macos-arm64", "macos-x86_64", "windows-x64", "linux-x64", "android", "ios-unsigned"].contains(key),
                      let a = raw as? [String: Any], let u = a["url"] as? String,
                      let hash = a["sha256"] as? String, hash.utf8.count == 64,
                      hash.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil else { throw Failure.invalid }
                let size = try integer(a["size"]), url = try assetURL(u, version: text)
                guard size > 0 else { throw Failure.invalid }
                if key == platform {
                    let expected: String?
                    switch key {
                    case "macos-arm64", "macos-x86_64": expected = "diakitw-\(text)-\(key).dmg"
                    case "ios-unsigned": expected = "diakitw-\(text)-ios-UNSIGNED-device.app.zip"
                    default: expected = nil
                    }
                    guard expected == nil || url.lastPathComponent == expected else { throw Failure.invalid }
                    selected = Offer(version: text, build: b, notes: notes, url: url, size: size, sha256: hash)
                }
            }
            guard c == channel, v > installed || (v == installed && b > currentBuild), let candidate = selected else { continue }
            if let prior = chosen {
                let pv = try Version(prior.version)
                if v > pv || (v == pv && b > prior.build) { chosen = candidate }
            } else { chosen = candidate }
        }
        return chosen
    }
}

private final class UpdateSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust { completionHandler(.performDefaultHandling, nil) }
        else { completionHandler(.cancelAuthenticationChallenge, nil) }
    }
}
public enum UpdateTransport {
    // Optional configuration is an internal fixture seam, never controlled by user data.
    static func fetch(configuration: URLSessionConfiguration = .ephemeral) async throws -> Data {
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: UpdateSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: UpdateContract.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw UpdateContract.Failure.http }
        guard response.expectedContentLength <= UpdateContract.cap else { throw UpdateContract.Failure.oversized }
        var data = Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < UpdateContract.cap else { throw UpdateContract.Failure.oversized }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }
    public static func fetch() async throws -> Data { try await fetch(configuration: .ephemeral) }
}

@MainActor public final class UpdateChecker: ObservableObject {
    @Published public private(set) var offer: UpdateContract.Offer?
    @Published public private(set) var status = "Обновления ещё не проверялись"
    @Published public private(set) var checking = false
    @Published public private(set) var channel: String
    private let defaults: UserDefaults
    private let now: () -> Date
    private let load: () async throws -> Data
    private let platform: String
    private let current: String
    private let currentBuild: Int
    private var task: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var generation = 0
    private var foreground = false
    public init(defaults: UserDefaults = .standard, platform: String = UpdateContract.platform,
                current: String = UpdateContract.version, currentBuild: Int = UpdateContract.build,
                now: @escaping () -> Date = Date.init,
                load: @escaping () async throws -> Data = { try await UpdateTransport.fetch() }) {
        self.defaults = defaults; self.platform = platform; self.current = current; self.currentBuild = currentBuild
        self.now = now; self.load = load
        channel = defaults.string(forKey: "diakitw.update.channel") == "stable" ? "stable" : "preview"
    }
    deinit { task?.cancel(); timer?.cancel() }
    public func choose(_ value: String) {
        guard ["stable", "preview"].contains(value), value != channel else { return }
        cancel(); channel = value; defaults.set(value, forKey: "diakitw.update.channel")
        offer = nil; status = "Канал изменён. Нажмите «Проверить обновления»."
    }
    public func setForeground(_ active: Bool) {
        guard foreground != active else { return }; foreground = active
        if !active { timer?.cancel(); timer = nil; cancel(); return }
        check(manual: false)
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { return }
                self?.check(manual: false)
            }
        }
    }
    public func cancel() {
        generation += 1; task?.cancel(); task = nil
        if checking { status = "Проверка отменена" }; checking = false
    }
    public func later() { cancel(); offer = nil; status = "Напоминание скрыто; следующая автопроверка — не раньше чем через 24 ч"; defaults.set(now(), forKey: "diakitw.update.success." + channel) }
    public func check(manual: Bool = true) {
        guard !checking, foreground || manual else { return }
        let date = now()
        func elapsed(_ key: String) -> TimeInterval { defaults.object(forKey: key).flatMap { $0 as? Date }.map { date.timeIntervalSince($0) } ?? .infinity }
        guard elapsed("diakitw.update.attempt") >= 60 else {
            if manual { status = "Повторная проверка доступна через 60 с после предыдущей" }; return
        }
        if !manual && (elapsed("diakitw.update.success." + channel) < 86400 || elapsed("diakitw.update.failure") < 3600) { return }
        defaults.set(date, forKey: "diakitw.update.attempt")
        checking = true; status = "Проверка обновлений…"; offer = nil
        generation += 1; let id = generation
        let fetch = load, chosen = channel, platform = platform, current = current, build = currentBuild
        task = Task { [weak self] in
            do {
                let data = try await fetch()
                try Task.checkCancellation()
                // Bounded 32 KiB parsing; transport is asynchronous, never a blocking URL read.
                let found = try UpdateContract.select(data, channel: chosen, platform: platform, current: current, currentBuild: build)
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.offer = found; self.checking = false; self.task = nil
                self.status = found.map { "Доступна diakitw \($0.version) (\($0.build))" } ?? "Нет более новой совместимой версии в канале \(chosen)"
                self.defaults.set(self.now(), forKey: "diakitw.update.success." + chosen)
                self.defaults.removeObject(forKey: "diakitw.update.failure")
            } catch {
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.checking = false; self.task = nil
                self.status = "Не удалось проверить обновления: сеть или некорректный манифест. Это не означает, что версия актуальна."
                self.defaults.set(self.now(), forKey: "diakitw.update.failure")
            }
        }
    }
}
