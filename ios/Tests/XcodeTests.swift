import XCTest

final class CoreTests: XCTestCase {
    func testUpdatesRejectMalformedFeedAndDowngrade() throws {
        XCTAssertThrowsError(try UpdateContract.select(Data("<html>404</html>".utf8), channel: "preview", platform: "ios-unsigned"))
        XCTAssertNil(try UpdateContract.select(Data(#"{"schema":1,"releases":[]}"#.utf8), channel: "preview", platform: "ios-unsigned"))
        XCTAssertTrue(try UpdateContract.Version("0.5.10") > UpdateContract.Version("0.5.4"))
        XCTAssertThrowsError(try UpdateContract.assetURL("http://github.com/COINLOGY/diakitw/releases/download/v0.5.4/file.zip", version: "0.5.4"))
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
