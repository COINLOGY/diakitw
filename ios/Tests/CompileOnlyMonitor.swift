// Compile-only macOS SwiftUI shim. Never included in the iOS application.
// Does not produce telemetry evidence or screenshots.
import Foundation
import Combine
@MainActor final class Monitor: ObservableObject {
    @Published var appRAM: Double?
    @Published var diskTotal: Double?
    @Published var diskUsed: Double?
    @Published var charge: Double?
    @Published var power = "Н/Д"
    @Published var ip = "Н/Д"
    @Published var country = "Н/Д"
    @Published var ipDate: Date?
    @Published var ipStatus = "Fixture"
    @Published var download: Double?
    @Published var upload: Double?
    @Published var speedStatus = "Fixture"
    @Published var running = false
    let physicalRAM: Double = 0
    func setForeground(_ active: Bool) {}
    func cancelSpeed() {}
    func startSpeed() {}
}
