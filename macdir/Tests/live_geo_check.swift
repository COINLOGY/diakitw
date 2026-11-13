import Foundation
@main struct LiveGeoCheck {
 static func main() async {
  if let location = await GeoLookup.fetch() {
   let evidence: [String: Any] = ["success":true,"ip_valid":MacIdentity.validAddress(location.ip) != nil,"country_present":location.country != nil,"city_present":location.city != nil,"coordinates_present":location.latitude != nil && location.longitude != nil,"map_allowlisted":location.mapURL?.host == "maps.apple.com"]
   print(String(data: try! JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]), encoding: .utf8)!)
  } else { print("{\"success\":false,\"reason\":\"provider unavailable or rejected bounded response\"}"); exit(1) }
 }
}
