import SwiftUI
import UIKit
import Darwin

@MainActor final class Monitor: ObservableObject {
    @Published var appRAM: Double?
    @Published var diskTotal: Double?
    @Published var diskUsed: Double?
    @Published var charge: Double?
    @Published var power = "Н/Д"
    var ip: String { geo?.ip ?? "Н/Д" }
    var country: String { geo?.country ?? "Н/Д" }
    @Published var geo: NetworkPolicy.Egress?
    @Published var ipDate: Date?
    @Published var ipStatus = "Ожидание"
    @Published var download: Double?
    @Published var upload: Double?
    @Published var latencyMS: Double?
    @Published var speedStatus = "Тест ещё не запускался"
    @Published var running = false
    let physicalRAM = Double(ProcessInfo.processInfo.physicalMemory)
    private var sampler: Task<Void, Never>?
    private var lookup: Task<Void, Never>?
    private var speedTask: Task<Void, Never>?
    private var generation = UUID()
    private var speedID = UUID()
    private var lastLookup: TimeInterval = -.infinity
    private var foreground = false

    // Internal injection seam for offline behavioral tests; production always uses bounded HTTPS.
    private let speedFetch: (URLRequest, Int) async throws -> Data
    init(speedFetch: @escaping (URLRequest, Int) async throws -> Data = {
        try await BoundedTransfer.fetch($0, cap: $1)
    }) { self.speedFetch = speedFetch }

    func setForeground(_ active: Bool) {
        guard active != foreground else { return }
        foreground = active
        generation = UUID()
        sampler?.cancel(); lookup?.cancel()
        if !active { cancelSpeed(); geo = nil; ipDate = nil; ipStatus = "Приостановлено"; return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        let token = generation
        sampler = Task { [weak self] in
            while !Task.isCancelled {
                // Do not keep the model alive through the polling sleep.
                do {
                    guard let self, self.generation == token else { return }
                    self.sample()
                }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            }
        }
        lookup = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 1_500_000_000) } catch { return }
            while !Task.isCancelled {
                do {
                    guard let self, self.generation == token else { return }
                    // Survives rapid foreground changes; max one lookup per 60 seconds.
                    if ProcessInfo.processInfo.systemUptime - self.lastLookup >= 60 {
                        self.lastLookup = ProcessInfo.processInfo.systemUptime
                        await self.refreshIP(token)
                    }
                }
                do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { return }
            }
        }
    }
    private func sample() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        appRAM = result == KERN_SUCCESS ? Double(info.resident_size) : nil
        if let values = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = values[.systemSize] as? NSNumber, let free = values[.systemFreeSize] as? NSNumber,
           total.doubleValue > 0, free.doubleValue >= 0, free.doubleValue <= total.doubleValue {
            diskTotal = total.doubleValue
            diskUsed = total.doubleValue - free.doubleValue
        } else { diskTotal = nil; diskUsed = nil }
        let device = UIDevice.current
        charge = device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil
        switch device.batteryState {
        case .charging: power = "Заряжается"
        case .full: power = "Питание подключено"
        case .unplugged: power = "От батареи"
        default: power = "Состояние недоступно"
        }
    }
    private func refreshIP(_ token: UUID) async {
        ipStatus = "Обновление…"
        do {
            let result: NetworkPolicy.Egress
            do {
                let data = try await BoundedTransfer.fetch(URLRequest(url: NetworkPolicy.egressURL), cap: 4096)
                result = try NetworkPolicy.proxy(data)
            } catch {
                try Task.checkCancellation()
                guard foreground, generation == token else { return }
                let data = try await BoundedTransfer.fetch(URLRequest(url: NetworkPolicy.fallbackURL), cap: 4096)
                result = try NetworkPolicy.egress(data)
            }
            guard !Task.isCancelled, foreground, generation == token else { return }
            geo = result; ipDate = Date(); ipStatus = result.source + " · выход в интернет"
        } catch {
            guard !Task.isCancelled, foreground, generation == token else { return }
            geo = nil; ipDate = nil; ipStatus = "IP недоступен"
        }
    }
    func startSpeed() {
        guard foreground, !running else { return }
        running = true; download = nil; upload = nil; latencyMS = nil
        speedID = UUID(); let token = speedID
        speedStatus = "PING · HTTP…"
        speedTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.speedID == token { self.running = false; self.speedTask = nil } }
            do {
                // Failure of the latency probe leaves Н/Д, but does not fabricate a zero
                // or prevent the independent throughput measurements.
                do {
                    let start = ProcessInfo.processInfo.systemUptime
                    _ = try await self.speedFetch(URLRequest(url: NetworkPolicy.latencyURL), 4096)
                    guard !Task.isCancelled, self.speedID == token else { return }
                    self.latencyMS = NetworkPolicy.latency(seconds: ProcessInfo.processInfo.systemUptime - start)
                } catch {
                    try Task.checkCancellation()
                    guard self.speedID == token else { return }
                }
                self.speedStatus = "↓ Загрузка 8 MiB…"
                var request = URLRequest(url: NetworkPolicy.downloadURL)
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                let start = ProcessInfo.processInfo.systemUptime
                let data = try await self.speedFetch(request, NetworkPolicy.downloadBytes)
                guard data.count == NetworkPolicy.downloadBytes else { throw URLError(.cannotDecodeContentData) }
                guard !Task.isCancelled, self.speedID == token else { return }
                self.download = NetworkPolicy.rate(bytes: data.count, seconds: ProcessInfo.processInfo.systemUptime - start)
                self.speedStatus = "↑ Отправка 2 MiB…"
                var post = URLRequest(url: NetworkPolicy.uploadURL)
                post.httpMethod = "POST"
                post.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                // Synthetic data only, no user files, no payload files on disk.
                post.httpBody = Data(repeating: 0xA5, count: NetworkPolicy.uploadBytes)
                let uploadStart = ProcessInfo.processInfo.systemUptime
                _ = try await self.speedFetch(post, 4096)
                guard !Task.isCancelled, self.speedID == token else { return }
                self.upload = NetworkPolicy.rate(bytes: NetworkPolicy.uploadBytes, seconds: ProcessInfo.processInfo.systemUptime - uploadStart)
                self.speedStatus = "Готово • средняя скорость запроса"
            } catch {
                guard self.speedID == token else { return }
                self.speedStatus = Task.isCancelled ? "Отменено" : "Ошибка сети • завершённые показания сохранены"
            }
        }
    }
    func cancelSpeed() {
        guard running else { return }
        speedID = UUID(); speedTask?.cancel(); speedTask = nil
        running = false; speedStatus = "Отменено • частичный тест"
    }
}
