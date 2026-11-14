import Foundation

final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        if path == "/wait" { return }
        let status = path == "/error" ? 503 : 200
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 42, count: path == "/large" ? 20 : 4))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct TransportTests {
    static func main() async throws {
        func config() -> URLSessionConfiguration {
            let c = URLSessionConfiguration.ephemeral
            c.protocolClasses = [FixtureProtocol.self]
            return c
        }
        func request(_ path: String) -> URLRequest { URLRequest(url: URL(string: "https://fixture.invalid" + path)!) }
        do {
            _ = try await BoundedTransfer.fetch(URLRequest(url: URL(string: "http://fixture.invalid/ok")!), cap: 10, configuration: config())
            print("FAIL: cleartext accepted"); exit(1)
        } catch {}
        let ok = try await BoundedTransfer.fetch(request("/ok"), cap: 10, configuration: config())
        precondition(ok.count == 4)
        for path in ["/large", "/error"] {
            do { _ = try await BoundedTransfer.fetch(request(path), cap: 10, configuration: config()); fatalError("accepted \(path)") } catch {}
        }
        let run = Task { try await BoundedTransfer.fetch(request("/wait"), cap: 10, configuration: config()) }
        try await Task.sleep(nanoseconds: 20_000_000)
        run.cancel()
        do { _ = try await run.value; fatalError("cancel ignored") } catch {}
        let alreadyCancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await BoundedTransfer.fetch(request("/ok"), cap: 10, configuration: config())
        }
        alreadyCancelled.cancel()
        do { _ = try await alreadyCancelled.value; fatalError("pre-cancel ignored") } catch {}
        let timeoutStart = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await BoundedTransfer.fetch(request("/wait"), cap: 10, configuration: config())
            fatalError("stalled request escaped deadline")
        } catch {
            let elapsed = ProcessInfo.processInfo.systemUptime - timeoutStart
            FileHandle.standardError.write(Data("Stalled fixture ended after \(elapsed)s: \(error)\n".utf8))
            precondition((error as? URLError)?.code == .timedOut, "stalled request must report timeout")
            precondition(elapsed >= 11 && elapsed < 25, "deadline outside bounded range")
        }
        print("PASS: bounded transport success, cap, HTTP failure, active/pre-cancellation, stalled-request deadline")
    }
}
