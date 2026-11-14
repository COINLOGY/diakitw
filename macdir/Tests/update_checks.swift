import Foundation

private func require(_ ok: Bool, _ label: String) { if !ok { fatalError(label) } }
private func rejects(_ label: String, _ f: () throws -> Void) { do { try f(); fatalError("accepted " + label) } catch {} }
private func fixture(version: String = "0.5.4", build: Any = 54, channel: String = "preview", platform: String = "macos-arm64", url: String? = nil, schema: Any = 1, size: Any = 100, hash: String = String(repeating: "a", count: 64), notes: String = "Тест: только браузер") throws -> Data {
    let file = platform == "ios-unsigned" ? "ios-UNSIGNED-device.app.zip" : "\(platform).dmg"
    return try JSONSerialization.data(withJSONObject: ["schema": schema, "releases": [["version": version, "build": build, "channel": channel, "notes": notes, "assets": [platform: ["url": url ?? "https://github.com/COINLOGY/diakitw/releases/download/v\(version)/diakitw-\(version)-\(file)", "size": size, "sha256": hash]]]]])
}
final class FixtureProtocol: URLProtocol {
    static var mode = "ok"
    static var requests = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        require(request.url == UpdateContract.endpoint, "fixed endpoint")
        require(request.httpBody == nil && request.url?.query == nil, "no private payload")
        require(request.value(forHTTPHeaderField: "Cookie") == nil, "no cookies")
        if Self.mode == "timeout" { client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return }
        if Self.mode == "hang" { return }
        let code = Self.mode == "404" ? 404 : Self.mode == "redirect" ? 302 : 200
        let data = Self.mode == "cap" ? Data(repeating: 32, count: UpdateContract.cap + 1) : try! fixture()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct UpdateChecks {
    @MainActor static func main() async throws {
        func select(_ d: Data, channel: String = "preview", platform: String = "macos-arm64", current: String = "0.5.3", build: Int = 53) throws -> UpdateContract.Offer? {
            try UpdateContract.select(d, channel: channel, platform: platform, current: current, currentBuild: build)
        }
        require(UpdateContract.version == "0.5.6" && UpdateContract.build == 56, "numeric Mac identity")
        rejects("letter version") { _ = try UpdateContract.Version("0.5.5a") }
        let candidate = try fixture(version: "0.5.5", build: 55)
        require(try select(candidate, current: "0.5.4", build: 54)?.version == "0.5.5", "0.5.4 -> 0.5.5")
        require(try UpdateContract.select(candidate, channel: "preview", platform: "macos-arm64") == nil, "shipped current -> none")
        require(try UpdateContract.select(fixture(), channel: "preview", platform: "macos-arm64") == nil, "shipped rejects old feed")
        let data = try fixture()
        require(try select(data)?.version == "0.5.4", "old -> offer")
        require(try select(data, current: "0.5.4", build: 54) == nil, "current -> none")
        require(try select(data, current: "0.6.0", build: 1) == nil, "no downgrade")
        require(try select(data, platform: "macos-x86_64") == nil, "no wrong-arch fallback")
        require(try select(data, channel: "stable") == nil, "stable rejects preview")
        require(try select(fixture(channel: "stable"), channel: "preview") == nil, "same channel only")
        require(try select(fixture(version: "0.5.10"))?.version == "0.5.10", "numeric semver")
        require(try select(fixture(build: 55), current: "0.5.4", build: 54)?.build == 55, "newer same-version build")
        require(try select(fixture(platform: "ios-unsigned"), platform: "ios-unsigned")?.releasePage.absoluteString == "https://github.com/COINLOGY/diakitw/releases/tag/v0.5.4", "iOS release page only")
        for s in ["0.5", "0.5.4-beta", "01.5.4", "-1.2.3", "1.2.3\n"] { rejects("semver") { _ = try UpdateContract.Version(s) } }
        for b in [-1, true, 1.5, "54"] as [Any] { rejects("build") { _ = try select(fixture(build: b)) } }
        for s in [2, true, "1"] as [Any] { rejects("schema") { _ = try select(fixture(schema: s)) } }
        for size in [0, -1, true, 1.5, "100"] as [Any] { rejects("size") { _ = try select(fixture(size: size)) } }
        for hash in ["", "abc", String(repeating: "z", count: 64), String(repeating: "a", count: 64) + "\n"] { rejects("hash") { _ = try select(fixture(hash: hash)) } }
        for notes in ["<b>html</b>", String(repeating: "a", count: 2001), "bad\u{0001}"] { rejects("notes") { _ = try select(fixture(notes: notes)) } }
        let good = "https://github.com/COINLOGY/diakitw/releases/download/v0.5.4/diakitw-0.5.4-macos-arm64.dmg"
        for u in [good+"?x=1", good+"#a", good.replacingOccurrences(of: "https:", with: "http:"), good.replacingOccurrences(of: "github.com", with: "github.com.evil.invalid"), good.replacingOccurrences(of: "github.com", with: "user@github.com"), good.replacingOccurrences(of: "/diakitw-", with: "/../diakitw-"), good.replacingOccurrences(of: "arm64.dmg", with: "arm64%2edmg"), good.replacingOccurrences(of: "v0.5.4", with: "v0.5.3"), good+"\n"] { rejects("URL") { _ = try select(fixture(url: u)) } }
        rejects("filename") { _ = try select(fixture(url: good.replacingOccurrences(of: "arm64.dmg", with: "x86_64.dmg"))) }
        rejects("cap") { _ = try select(Data(repeating: 32, count: UpdateContract.cap+1)) }
        rejects("HTML") { _ = try select(Data("<html>404</html>".utf8)) }
        print("PASS parser: old/current/build/downgrade/arch/channels/iOS/schema/URLs/cap")

        let suite = "diakitw-update-fixture-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var time = Date(timeIntervalSince1970: 100_000), calls = 0
        var continuation: CheckedContinuation<Data, Error>?
        let checker = UpdateChecker(defaults: defaults, platform: "macos-arm64", current: "0.5.3", currentBuild: 53, now: { time }, load: { calls += 1; return data })
        func settle(_ c: UpdateChecker) async {
            for _ in 0..<300 { if !c.checking { return }; try? await Task.sleep(nanoseconds: 10_000_000) }
            fatalError("checker stuck")
        }
        require(checker.channel == "preview", "default preview")
        checker.setForeground(true); await settle(checker)
        require(calls == 1 && checker.offer != nil, "automatic startup offer")
        checker.check(); require(calls == 1, "manual 60s throttle")
        time.addTimeInterval(61); checker.check(manual: false); require(calls == 1, "24h auto throttle")
        checker.check(); await settle(checker); require(calls == 2, "manual after 60")
        checker.later(); require(checker.offer == nil, "Later hides offer")
        checker.choose("stable")
        let readback = UpdateChecker(defaults: defaults)
        require(readback.channel == "stable", "persisted stable readback")
        checker.setForeground(false)
        time.addTimeInterval(86401); checker.setForeground(true); await settle(checker)
        require(checker.offer == nil && calls == 3, "stable never preview")
        checker.setForeground(false)
        defaults.removePersistentDomain(forName: suite)
        var failures = 0
        let failed = UpdateChecker(defaults: defaults, now: { time }, load: { failures += 1; throw URLError(.timedOut) })
        failed.setForeground(true); await settle(failed)
        require(failed.status.contains("Не удалось") && failed.offer == nil, "timeout is error, not current")
        time.addTimeInterval(61); failed.check(manual: false); require(failures == 1, "failure 1h cooldown")
        failed.check(); await settle(failed); require(failures == 2, "manual retry 60s")
        time.addTimeInterval(3601); failed.check(manual: false); await settle(failed); require(failures == 3, "auto retry after 1h")
        failed.setForeground(false)
        defaults.removePersistentDomain(forName: suite)
        let delayed = UpdateChecker(defaults: defaults, platform: "macos-arm64", current: "0.5.3", currentBuild: 53, now: { time }, load: { try await withCheckedThrowingContinuation { continuation = $0 } })
        delayed.setForeground(true)
        for _ in 0..<100 where continuation == nil { try? await Task.sleep(nanoseconds: 1_000_000) }
        require(continuation != nil, "delayed request started")
        delayed.check(); require(delayed.checking, "no overlap")
        delayed.setForeground(false); require(!delayed.checking, "hidden cancels")
        continuation?.resume(returning: data)
        try? await Task.sleep(nanoseconds: 30_000_000)
        require(delayed.offer == nil && delayed.status == "Проверка отменена", "late aborted result rejected")
        print("PASS lifecycle: foreground/24h/60s/1h/no overlap/Later/persistence/cancel/late")
        for mode in ["ok", "404", "redirect", "cap", "timeout", "hang"] {
            let watchdog = Task { try? await Task.sleep(nanoseconds: 13_000_000_000); if !Task.isCancelled { fatalError("transport exceeded whole-request deadline") } }
            defer { watchdog.cancel() }
            FixtureProtocol.mode = mode
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FixtureProtocol.self]
            do {
                let result = try await UpdateTransport.fetch(configuration: config)
                let actual = try select(result)
                let expected = try select(data)
                require(mode == "ok" && actual == expected, "unexpected transport success " + mode)
            } catch { require(mode != "ok", "transport fixture failed " + String(describing: error)) }
            require(config.httpCookieStorage == nil && config.urlCache == nil && config.timeoutIntervalForResource == 10, "ephemeral bounds")
        }
        print("PASS transport: injected URLProtocol only; success/404/302/cap/timeout; no live network")
    }
}
