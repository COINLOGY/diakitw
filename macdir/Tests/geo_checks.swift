import Foundation
@main struct GeoChecks {
 static func main() {
  func parse(_ extra: String = "") -> EgressLocation? {
   EgressLocation.decode(Data(("{\"ip\":\"2001:db8:1234:5678:abcd:efab:1234:5678\",\"country\":\"United Kingdom\",\"city\":\"A & B\"" + extra + "}").utf8), status: 200)
  }
  let country = parse()!
  precondition(country.country == "United Kingdom" && country.city == "A & B")
  precondition(country.mapURL!.host == "maps.apple.com")
  precondition(URLComponents(url: country.mapURL!, resolvingAgainstBaseURL: false)!.queryItems!.first!.value == "United Kingdom")
  let located = parse(",\"latitude\":\"51.5\",\"longitude\":\"-0.1\"")!
  precondition(located.mapURL!.absoluteString.contains("ll=51.5,-0.1"))
  for bad in ["nan", "inf", "91", "-91"] {
   precondition(parse(",\"latitude\":\"\(bad)\",\"longitude\":\"1\"")!.latitude == nil)
  }
  precondition(parse(",\"latitude\":\"1\",\"longitude\":\"181\"")!.longitude == nil)
  precondition(EgressLocation.decode(Data("{\"ip\":\"evil.com\"}".utf8), status: 200) == nil)
  precondition(EgressLocation.decode(Data(repeating: 32, count: 16385), status: 200) == nil)
  precondition(EgressLocation.decode(Data("{}".utf8), status: 429) == nil)
  precondition(EgressLocation.clean("X\n\u{202e}Y") == "XY")
  precondition(EgressLocation.clean(String(repeating: "a", count: 161)) == nil)
  print("PASS geo parser: literal IPv6, encoding, country-only, finite bounds, body/status, controls")
 }
}
