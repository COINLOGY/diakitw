import Foundation
@main struct Checks {
 static func main() {
  precondition(InternetDialScale.maximum(nil) == 100)
  precondition(InternetDialScale.maximum(0) == 100)
  precondition(InternetDialScale.maximum(101) == 200)
  precondition(InternetDialScale.maximum(501) == 1000)
  precondition(InternetDialScale.maximum(.nan) == 100)
  precondition(InternetDialScale.maximum(.infinity) == 100)
  precondition(InternetDialScale.maximum(-1) == 100)
  precondition(InternetDialScale.maximum(2500) == 5000)
  print("PASS adaptive Mbps drawing ranges, no capacity percentage")
 }
}
