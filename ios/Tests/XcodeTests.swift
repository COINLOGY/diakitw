import XCTest

final class CoreTests: XCTestCase {
    func testUpdatesRejectMalformedFeedAndDowngrade() throws {
        XCTAssertThrowsError(try UpdateContract.select(Data("<html>404</html>".utf8), channel: "preview", platform: "ios-unsigned"))
        XCTAssertNil(try UpdateContract.select(Data(#"{"schema":1,"releases":[]}"#.utf8), channel: "preview", platform: "ios-unsigned"))
        XCTAssertTrue(try UpdateContract.Version("0.5.10") > UpdateContract.Version("0.5.4"))
        XCTAssertThrowsError(try UpdateContract.assetURL("http://github.com/COINLOGY/diakitw/releases/download/v0.5.4/file.zip", version: "0.5.4"))
    }
    func testHTTPLatencyReport() {
        XCTAssertEqual(NetworkPolicy.latency(seconds: 0.025), 25)
        for seconds in [0.0, -1, .nan, .infinity] {
            XCTAssertNil(NetworkPolicy.latency(seconds: seconds))
        }
        XCTAssertEqual(NetworkPolicy.latencyReport(25), "PING · HTTP: 25.0 мс · не ICMP")
        for value in [nil, .nan, .infinity, -1, 0] as [Double?] {
            XCTAssertEqual(NetworkPolicy.latencyReport(value), "PING · HTTP: Н/Д · не ICMP")
        }
    }
    @MainActor func testSingleStartAndCompletedReport() async throws {
        var calls: [URL] = []
        let model = Monitor(speedFetch: { request, _ in
            calls.append(request.url!)
            try await Task.sleep(nanoseconds: 1_000_000)
            return request.url == NetworkPolicy.downloadURL ? Data(count: NetworkPolicy.downloadBytes) : Data()
        })
        model.setForeground(true)
        XCTAssertFalse(model.running)
        XCTAssertTrue(calls.isEmpty, "Opening the view must not start a speed run")
        model.latencyMS = 999
        model.startSpeed(); model.startSpeed()
        XCTAssertNil(model.latencyMS, "A new run must clear the previous result")
        XCTAssertTrue(model.running)
        for _ in 0..<200 where model.running { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.running)
        XCTAssertEqual(calls, [NetworkPolicy.latencyURL, NetworkPolicy.downloadURL, NetworkPolicy.uploadURL])
        XCTAssertNotNil(model.latencyMS)
        XCTAssertNotNil(model.download); XCTAssertNotNil(model.upload)
        XCTAssertTrue(NetworkPolicy.latencyReport(model.latencyMS).contains("мс"))
        model.setForeground(false)
    }
    @MainActor func testLatencyFailureIsUnknownButSpeedMayComplete() async throws {
        let model = Monitor(speedFetch: { request, _ in
            if request.url == NetworkPolicy.latencyURL { throw URLError(.timedOut) }
            return request.url == NetworkPolicy.downloadURL ? Data(count: NetworkPolicy.downloadBytes) : Data()
        })
        model.setForeground(true); model.startSpeed()
        for _ in 0..<200 where model.running { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.running)
        XCTAssertNil(model.latencyMS); XCTAssertNotNil(model.upload)
        XCTAssertTrue(NetworkPolicy.latencyReport(model.latencyMS).contains("Н/Д"))
        model.setForeground(false)
    }
    @MainActor func testFailedRunDoesNotInventMeasurements() async throws {
        let model = Monitor(speedFetch: { _, _ in throw URLError(.notConnectedToInternet) })
        model.setForeground(true); model.startSpeed()
        for _ in 0..<200 where model.running { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.running)
        XCTAssertNil(model.latencyMS); XCTAssertNil(model.download); XCTAssertNil(model.upload)
        XCTAssertTrue(model.speedStatus.contains("Ошибка"))
        model.setForeground(false)
    }
    @MainActor func testCancelAndBackgroundDiscardLateLatency() async throws {
        for background in [false, true] {
            var calls = 0
            let model = Monitor(speedFetch: { _, _ in
                calls += 1
                // Deliberately ignore cancellation: the generation guard must still win.
                try? await Task.sleep(nanoseconds: 200_000_000)
                return Data()
            })
            model.setForeground(true); model.startSpeed()
            for _ in 0..<100 where calls == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
            if background { model.setForeground(false) } else { model.cancelSpeed() }
            try await Task.sleep(nanoseconds: 20_000_000)
            XCTAssertEqual(calls, 1)
            XCTAssertFalse(model.running); XCTAssertNil(model.latencyMS)
            XCTAssertNil(model.download); XCTAssertNil(model.upload)
            XCTAssertTrue(model.speedStatus.contains("Отменено"))
            model.setForeground(false)
        }
    }
    func testUpperSemicircle() {
        XCTAssertEqual(Dial.point(fraction: 0).x, -1, accuracy: 0.000001)
        XCTAssertEqual(Dial.point(fraction: 0.5).y, -1, accuracy: 0.000001)
        XCTAssertEqual(Dial.point(fraction: 1).x, 1, accuracy: 0.000001)
        for i in 0...100 {
            let p = Dial.point(fraction: Double(i)/100)
            XCTAssertLessThanOrEqual(p.y, 0.000001)
            XCTAssertEqual(p.x*p.x+p.y*p.y, 1, accuracy: 0.000001)
        }
    }
    func testMissingDoesNotBecomeZero() {
        XCTAssertNil(Dial.fraction(nil, total: 100))
        XCTAssertNil(Dial.fraction(.nan, total: 100))
        XCTAssertNil(Dial.fraction(1, total: 0))
    }
    func testBands() {
        XCTAssertEqual(Dial.band(0.2), .green)
        XCTAssertEqual(Dial.band(0.8), .blue)
        XCTAssertEqual(Dial.band(0.81), .red)
        XCTAssertEqual(Dial.band(1, battery: true), .green)
    }
    func testRateAndBudgets() {
        XCTAssertEqual(NetworkPolicy.rate(bytes: 1_000_000, seconds: 1), 8)
        XCTAssertNil(NetworkPolicy.rate(bytes: 1, seconds: 0))
        XCTAssertNil(NetworkPolicy.rate(bytes: 1, seconds: .leastNonzeroMagnitude))
        XCTAssertEqual(NetworkPolicy.downloadBytes, 8*1024*1024)
        XCTAssertEqual(NetworkPolicy.uploadBytes, 2*1024*1024)
    }
    func testEgressParsing() throws {
        let parsed = try NetworkPolicy.egress(Data("{\"ip\":\"2001:db8::1\",\"country\":\"FI\"}".utf8))
        XCTAssertEqual(parsed.country, "FI")
        XCTAssertThrowsError(try NetworkPolicy.egress(Data("{}".utf8)))
    }
}
