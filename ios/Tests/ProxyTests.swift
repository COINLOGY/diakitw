import Foundation
@main struct ProxyTests {
 static func main() throws {
  let rich = #"{"ip":"203.0.113.2","code":"FI","country":"Finland","city":"Helsinki","region":"Uusimaa","timezone":"Europe/Helsinki","lat":60.17,"lon":24.94,"asn":{"id":64496,"name":"Example","hosting":false}}"#
  let r = try NetworkPolicy.proxy(Data(rich.utf8))
  precondition(r.ip == "203.0.113.2" && r.country == "FI" && r.city == "Helsinki" && r.latitude == 60.17 && r.asn == "AS64496")
  let missing = try NetworkPolicy.proxy(Data(#"{"ip":"2001:db8::1","code":null,"city":null,"lat":null,"lon":null,"asn":null}"#.utf8))
  precondition(missing.country == "Н/Д" && missing.latitude == nil && missing.longitude == nil && missing.city == nil)
  for body in [#"{"ip":"host.invalid","code":"FI"}"#, #"{"ip":"fe80::1%en0","code":"FI"}"#, #"{"ip":"203.0.113.2","code":"ZZ"}"#, #"{"ip":"203.0.113.2","code":"FI","lat":true,"lon":1}"#, #"{"ip":"203.0.113.2","code":"FI","lat":91,"lon":1}"#, #"{"ip":"203.0.113.2","code":"FI","asn":{"id":1.2}}"#, #"{"ip":"203.0.113.2","code":"FI","city":"Bad\nCity"}"#] {
   do { _ = try NetworkPolicy.proxy(Data(body.utf8)); fatalError("accepted invalid proxy fixture") } catch {}
  }
  let partial = try NetworkPolicy.proxy(Data(#"{"ip":"203.0.113.2","code":"FI","lat":1}"#.utf8))
  precondition(partial.latitude == nil && partial.longitude == nil)
  print("PASS proxy rich/null/partial/invalid atomic schema fixtures")
 }
}
