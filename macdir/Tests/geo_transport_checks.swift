import Foundation
import MacdirCore

final class MockGeoProtocol: URLProtocol, @unchecked Sendable {
 static let proxy = "https://aia.emcx.pro/diakitw-api/geo"
 static let fallback = "https://get.geojs.io/v1/ip/geo.json"
 static var payload = Data()
 static var status = 200
 static var fallbackPayload = Data(#"{"ip":"198.51.100.7","country":"Fallback"}"#.utf8)
 static var fallbackStatus = 200
 static var stalls = false
 static var stops = 0
 static var urls: [String] = []
 override class func canInit(with request: URLRequest) -> Bool { true }
 override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
 override func startLoading() {
  let url = request.url!.absoluteString
  precondition([Self.proxy, Self.fallback].contains(url))
  precondition(request.httpMethod == "GET" && request.url?.query == nil)
  precondition(request.value(forHTTPHeaderField: "Authorization") == nil && request.value(forHTTPHeaderField: "Cookie") == nil)
  Self.urls.append(url)
  guard !Self.stalls else { return }
  let primary = url == Self.proxy
  client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: primary ? Self.status : Self.fallbackStatus, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
  client?.urlProtocol(self, didLoad: primary ? Self.payload : Self.fallbackPayload)
  client?.urlProtocolDidFinishLoading(self)
 }
 override func stopLoading() { Self.stops += 1 }
}
@main struct TransportChecks {
 static func main() async {
  MockGeoProtocol.payload = Data(#"{"ip":"203.0.113.5","country":"Fixture","city":"City","lat":51.5,"lon":-0.1,"region":null,"code":"GB","timezone":null,"asn":{"id":64500,"name":"Fixture ASN","hosting":null}}"#.utf8)
  let good = await GeoLookup.fetch()
  precondition(good?.ip == "203.0.113.5", "Primary atomic proxy result required")
  precondition(good?.latitude == 51.5 && good?.longitude == -0.1)
  precondition(MockGeoProtocol.urls == [MockGeoProtocol.proxy], "Success must not send a fallback request")
  MockGeoProtocol.urls = []; MockGeoProtocol.status = 429
  let fallback = await GeoLookup.fetch()
  precondition(fallback?.ip == "198.51.100.7" && fallback?.country == "Fallback" && fallback?.city == nil && fallback?.latitude == nil)
  precondition(MockGeoProtocol.urls == [MockGeoProtocol.proxy, MockGeoProtocol.fallback])
  MockGeoProtocol.fallbackStatus = 503
  let unavailable = await GeoLookup.fetch(); precondition(unavailable == nil)
  MockGeoProtocol.status = 200; MockGeoProtocol.payload = Data(repeating: 65, count: 16385)
  let oversized = await GeoLookup.fetch(); precondition(oversized == nil)
  MockGeoProtocol.status = 302
  let redirect = await GeoLookup.fetch(); precondition(redirect == nil)
  MockGeoProtocol.status = 200
  MockGeoProtocol.payload = Data(#"{"ip":"2001:db8::1","city":null,"country":null,"lat":null,"lon":null,"asn":null}"#.utf8)
  MockGeoProtocol.urls = []
  let nullable = await GeoLookup.fetch()
  precondition(nullable?.ip == "2001:db8::1" && nullable?.country == nil && nullable?.latitude == nil && nullable?.mapURL == nil)
  precondition(MockGeoProtocol.urls == [MockGeoProtocol.proxy], "Missing optional geography is not proxy failure")
  MockGeoProtocol.urls = []; MockGeoProtocol.stalls = true
  let task = Task { await GeoLookup.fetch() }
  try? await Task.sleep(for: .milliseconds(100)); task.cancel()
  let cancelled = await task.value
  precondition(cancelled == nil && MockGeoProtocol.stops > 0)
  precondition(MockGeoProtocol.urls == [MockGeoProtocol.proxy], "Cancellation must not start fallback")
  print("PASS offline URLSession: atomic proxy, no token/query/cookie, no success fallback, failure-only atomic fallback, nullable fields, HTTP/redirect/body cap, cancellation without fallback")
 }
}
