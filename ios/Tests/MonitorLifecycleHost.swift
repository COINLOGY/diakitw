// Host-only UIKit and transport substitutes; NOT an iOS SDK/runtime test.
import Foundation

@MainActor final class UIDevice {
    static let current = UIDevice()
    enum BatteryState { case charging, full, unplugged, unknown }
    var isBatteryMonitoringEnabled = false
    var batteryLevel: Float = -1
    var batteryState = BatteryState.unknown
}
@MainActor enum BoundedTransfer {
    static var calls = 0
    static var failPrimary = false
    static var delay: UInt64 = 1_000_000
    static func fetch(_ request: URLRequest, cap: Int) async throws -> Data {
        try Task.checkCancellation()
        calls += 1
        try await Task.sleep(nanoseconds: delay)
        if request.url == NetworkPolicy.egressURL {
            if failPrimary { throw URLError(.badServerResponse) }
            return Data(#"{"ip":"203.0.113.1","code":"DE","city":"Berlin"}"#.utf8)
        }
        return Data(#"{"ip":"198.51.100.1","country":"US"}"#.utf8)
    }
}
final class WeakMonitor {
    weak var value: Monitor?
    init(_ value: Monitor?) { self.value = value }
}
@main struct MonitorLifecycleHost {
    @MainActor static func main() async throws {
        var model: Monitor? = Monitor()
        let released = WeakMonitor(model)
        model?.setForeground(true)
        try await Task.sleep(nanoseconds: 100_000_000)
        guard BoundedTransfer.calls == 0 else { print("FAIL: no foreground debounce"); exit(1) }
        for _ in 0..<300 {
            if model?.ip == "203.0.113.1" { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        guard model?.ip == "203.0.113.1", model?.country == "DE" else {
            print("FAIL: fixture IP did not complete"); exit(1)
        }
        model = nil
        try await Task.sleep(nanoseconds: 30_000_000)
        guard released.value == nil else {
            print("FAIL: polling task retains Monitor across sleep after owner releases it"); exit(1)
        }
        print("PASS: Monitor is released between polling samples (host substitutes, no network)")
        let active = Monitor()
        active.startSpeed()
        precondition(!active.running, "inactive model must refuse speed test")
        let before = BoundedTransfer.calls
        active.setForeground(true)
        active.setForeground(true)
        for _ in 0..<300 {
            if active.ip == "203.0.113.1" { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(active.ip == "203.0.113.1")
        precondition(BoundedTransfer.calls == before + 1, "foreground must not duplicate lookup")
        precondition(!active.running && active.download == nil && active.upload == nil,
                     "foreground must not start speed test")
        active.startSpeed()
        precondition(active.running)
        active.setForeground(false)
        try await Task.sleep(nanoseconds: 30_000_000)
        precondition(!active.running && active.ip == "Н/Д" && active.ipDate == nil)
        precondition(active.download == nil && active.upload == nil,
                     "cancelled speed test must not publish stale readings")
        active.setForeground(true)
        try await Task.sleep(nanoseconds: 30_000_000)
        precondition(BoundedTransfer.calls == before + 1, "resume must retain lookup cooldown")
        active.setForeground(false)
        BoundedTransfer.failPrimary = true
        let fallback = Monitor(); let count = BoundedTransfer.calls
        fallback.setForeground(true)
        for _ in 0..<300 {
            if fallback.ip == "198.51.100.1" { break }; try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(fallback.ip == "198.51.100.1" && fallback.country == "US" && BoundedTransfer.calls == count+2, "fallback must replace the whole snapshot")
        fallback.setForeground(false)
        BoundedTransfer.delay = 100_000_000
        let cancelled = Monitor(); let beforeCancel = BoundedTransfer.calls
        cancelled.setForeground(true)
        for _ in 0..<300 {
            if BoundedTransfer.calls > beforeCancel { break }; try await Task.sleep(nanoseconds: 10_000_000)
        }
        cancelled.setForeground(false)
        try await Task.sleep(nanoseconds: 150_000_000)
        precondition(cancelled.ip == "Н/Д" && BoundedTransfer.calls == beforeCancel+1, "cancel must not fallback or publish")
        print("PASS: primary/fallback/cancel fixtures")
        print("PASS: inactive start, idempotent foreground, no automatic speed test, background cancellation/clearing, cooldown (host substitutes)")
    }
}
