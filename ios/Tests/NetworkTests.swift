import Foundation

@main struct NetworkTests {
    static func main() async throws {
        precondition(NetworkPolicy.downloadBytes == 8 * 1024 * 1024)
        precondition(NetworkPolicy.uploadBytes == 2 * 1024 * 1024)
        precondition(NetworkPolicy.rate(bytes: 1_000_000, seconds: 1) == 8)
        precondition(NetworkPolicy.rate(bytes: 0, seconds: 1) == nil)
        precondition(NetworkPolicy.rate(bytes: 1, seconds: 0) == nil)
        precondition(NetworkPolicy.rate(bytes: 1, seconds: .nan) == nil)
        guard NetworkPolicy.rate(bytes: 1, seconds: .leastNonzeroMagnitude) == nil else {
            print("FAIL: overflowing rate must be unknown, not infinity"); exit(1)
        }
        guard NetworkPolicy.egressURL.absoluteString == "https://aia.emcx.pro/diakitw-api/geo" else {
            print("FAIL: approved primary proxy absent"); exit(1)
        }
        let good = Data("{\"ip\":\"203.0.113.2\",\"country_code\":\"DE\"}".utf8)
        let parsed = try NetworkPolicy.egress(good)
        precondition(parsed.ip == "203.0.113.2")
        for text in ["{}", "{\"ip\":\"example.com\",\"country_code\":\"DE\"}", "{\"ip\":\"127.0.0.1%en0\",\"country_code\":\"DE\"}"] {
            do { _ = try NetworkPolicy.egress(Data(text.utf8)); fatalError("accepted invalid egress") } catch {}
        }
        print("PASS: network budgets, rates, strict egress parser")
    }
}
