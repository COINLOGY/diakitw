import Foundation
@main struct GeoChecks {
 static func main() {
  func parse(_ extra: String = "") -> EgressLocation? {
   EgressLocation.decode(Data(("{\"ip\":\"2001:db8:1234:5678:abcd:efab:1234:5678\",\"country\":\"United Kingdom\",\"city\":\"A & B\"" + extra + "}").utf8), status: 200)
  }
  let country = parse()!
  precondition(country.country == "United Kingdom" && country.city == "A & B")
  precondition(country.summary == "United Kingdom · A & B", "No flag without an atomic ISO country code")
  precondition(parse(",\"country_code\":\"GB\"")!.summary == "🇬🇧 United Kingdom · A & B", "GeoJS country_code flag beside country")
  let proxy = EgressLocation.decodeProxy(Data(#"{"ip":"203.0.113.5","country":"Germany","city":"Berlin","code":"DE"}"#.utf8), status: 200)!
  precondition(proxy.summary == "🇩🇪 Germany · Berlin" && proxy.flag == "🇩🇪", "Validated VPN exit flag for status bar")
  for code in ["ZZ", "UK", "DE\n", "de", "D", "DEU", "🇩🇪"] {
   let raw = Data("{\"ip\":\"203.0.113.5\",\"country\":\"Germany\",\"code\":\"\(code.replacingOccurrences(of: "\n", with: "\\n"))\"}".utf8)
   precondition(EgressLocation.decodeProxy(raw, status: 200)?.summary == "Germany", "Invalid ISO code must not display a flag: \(code)")
  }
  precondition(EgressLocation.decodeProxy(Data(#"{"ip":"203.0.113.5","code":"DE"}"#.utf8), status: 200)?.summary == "", "No flag without a country")
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
