import Foundation
import MacdirCore

@main struct BatteryCycleChecks {
 static func main() {
  precondition(BatteryCycles.validated(nil) == nil)
  precondition(BatteryCycles.validated(NSNumber(value: 0)) == 0)
  precondition(BatteryCycles.validated(NSNumber(value: 1227)) == 1227)
  precondition(BatteryCycles.validated(NSNumber(value: -1)) == nil)
  precondition(BatteryCycles.validated(NSNumber(value: 100001)) == nil)
  precondition(BatteryCycles.validated(NSNumber(value: 12.5)) == nil)
  // CI runners without an internal Mac battery legitimately return nil.
  let cycles = BatteryCycles.read()
  precondition(cycles == nil || (0...100000).contains(cycles!))
  print("PASS battery cycle validation and platform query")
 }
}
