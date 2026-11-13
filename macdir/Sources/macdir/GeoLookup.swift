import Foundation
import MacdirCore

final class GeoLookup: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
 func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
 static func fetch() async -> EgressLocation? {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.timeoutIntervalForRequest = 8
  configuration.timeoutIntervalForResource = 8
  configuration.httpShouldSetCookies = false
  configuration.httpCookieStorage = nil
  configuration.urlCredentialStorage = nil
  configuration.urlCache = nil
  configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
  let session = URLSession(configuration: configuration, delegate: GeoLookup(), delegateQueue: nil)
  defer { session.invalidateAndCancel() }
  // No lookup parameter, API token or caller-supplied IP. Each attempt is
  // independently bounded; the existing provider runs only on primary failure.
  for endpoint in ["https://aia.emcx.pro/diakitw-api/geo", "https://get.geojs.io/v1/ip/geo.json"] {
   guard !Task.isCancelled else { return nil }
   do {
    let (bytes, response) = try await session.bytes(from: URL(string: endpoint)!)
    guard (response as? HTTPURLResponse)?.statusCode == 200, response.expectedContentLength <= 16384 else { continue }
    var data = Data()
    for try await byte in bytes {
     try Task.checkCancellation()
     guard data.count < 16384 else { throw URLError(.dataLengthExceedsMaximum) }
     data.append(byte)
    }
    try Task.checkCancellation()
    let location = endpoint == "https://aia.emcx.pro/diakitw-api/geo"
     ? EgressLocation.decodeProxy(data, status: 200) : EgressLocation.decode(data, status: 200)
    if let location { return location }
   } catch { if Task.isCancelled { return nil } }
  }
  return nil
 }
}
