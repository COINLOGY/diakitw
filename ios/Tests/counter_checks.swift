import Foundation
@main struct CounterChecks {
    static func main() {
        precondition(NetworkPolicy.counterDelta(old: 100, new: 300, seconds: 1) == 200)
        precondition(NetworkPolicy.counterDelta(old: 100, new: 100, seconds: 1) == 0)
        precondition(NetworkPolicy.counterDelta(old: UInt32.max - 10, new: 20, seconds: 1) == 31)
        precondition(NetworkPolicy.counterDelta(old: 500, new: 10, seconds: 1) == nil)
        precondition(NetworkPolicy.counterDelta(old: 100, new: 101, seconds: 0) == nil)
        precondition(NetworkPolicy.counterDelta(old: 0xC0000000, new: 0x3FFFFFFF, seconds: 0.000001) == nil)
        print("PASS: iOS interface byte delta handles idle, wrap and reset")
    }
}
