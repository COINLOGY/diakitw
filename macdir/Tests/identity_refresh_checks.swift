import Foundation
@main struct Checks {
 static func main() {
  var periodic = IdentityRefreshPolicy()
  precondition((0..<3600).filter { periodic.take(now: Double($0)) }.count == 60)
  var background = IdentityRefreshPolicy()
  for second in 0..<3600 { precondition(!background.take(now: Double(second), foreground: false)) }
  precondition(background.take(now: 3600, foreground: true))
  var p = IdentityRefreshPolicy()
  precondition(p.take(now: 0))
  p.changed(now: 1)
  for second in 2..<60 { precondition(!p.take(now: Double(second)), "VPN/refocus must retain 60-second minimum") }
  precondition(p.take(now: 60))
  precondition(!p.take(now: 119)); precondition(p.take(now: 120))
  p.changed(now: 180); p.changed(now: 181)
  precondition(!p.take(now: 182)); precondition(p.take(now: 183))
  var storm = IdentityRefreshPolicy()
  var requests: [Int] = []
  for second in 0..<3600 {
   if second % 3 == 0 { storm.changed(now: Double(second)) }
   if storm.take(now: Double(second), foreground: second % 5 != 0) { requests.append(second) }
  }
  precondition(requests.count <= 60)
  for (a,b) in zip(requests, requests.dropFirst()) { precondition(b-a >= 60) }
  print("PASS foreground/debounce/periodic policy: 60 s retained through VPN/refocus storm; zero background requests")
 }
}
