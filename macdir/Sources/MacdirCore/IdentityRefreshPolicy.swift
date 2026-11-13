import Foundation

/// Monotonic seconds; coalesce route/foreground changes, never hammer the service.
public struct IdentityRefreshPolicy {
 private var last: Double?
 private var pending: Double?
 public init() {}
 public mutating func changed(now: Double) { pending = now + 2 }
 public mutating func take(now: Double, foreground: Bool = true) -> Bool {
  guard foreground else { return false }
  guard let last else { self.last = now; pending = nil; return true }
  guard now >= last + 60 else { return false }
  if let pending {
   guard now >= pending else { return false }
  } else if now < last + 60 { return false }
  self.last = now; pending = nil
  return true
 }
}
