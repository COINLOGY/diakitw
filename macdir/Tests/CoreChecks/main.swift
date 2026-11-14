import Foundation
import CoreGraphics
import MacdirCore
var count = 0
func check(_ value: @autoclosure () -> Bool, _ name: String) {
 if !value() { print("FAIL: \(name)"); exit(1) }; count += 1; print("PASS: \(name)")
}
let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"]!).appendingPathComponent("macdir-test-" + UUID().uuidString)
try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: dir) }
try Data(repeating: 42, count: 100).write(to: dir.appendingPathComponent("a"))
try Data(repeating: 1, count: 50).write(to: dir.appendingPathComponent("sub/b"))
try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("loop").path, withDestinationPath: dir.path)
let result = Scanner.scan(dir)
check(result.root.logical == 150, "logical totals")
check(result.files == 2, "file count")
check(result.symlinks == 1, "symlink not followed")
check(result.errors == 0, "readable fixture")
try FileManager.default.linkItem(at: dir.appendingPathComponent("a"), to: dir.appendingPathComponent("hard"))
let linked = Scanner.scan(dir)
check(linked.root.logical == 150 && linked.hardlinks == 1, "hardlinks counted once")
check(Scanner.scan(dir, cancelled: { true }).cancelled, "cancellation")
let uncapped = Scanner.scan(dir, limit: 1)
check(!uncapped.limited && uncapped.root.logical == 150, "legacy limit no longer truncates traversal")
let stopped = Scanner.scan(dir, cancelled: { true })
check(stopped.root.children.count == linked.root.children.count, "cancel preserves immediate children")
check(Scanner.scan(dir.appendingPathComponent("absent")).errors == 1, "missing path error")
check(Rates.perSecond(old: 100, new: 300, seconds: 2) == 100, "network delta")
check(Rates.perSecond(old: 300, new: 100, seconds: 2) == nil, "counter reset")
check(Rates.perSecond(old: 100, new: 300, seconds: 0) == nil, "invalid interval")
check(Rates.cpu(old: [10, 10, 70, 10], new: [30, 20, 130, 20]) == 40, "CPU delta")
check(Rates.cpu(old: [10, 10, 70, 10], new: [10, 10, 70, 10]) == nil, "unchanged CPU counters unavailable, not idle")
check(Rates.cpu(old: [10, 10, 70, 10], new: [10, 10, 80, 10]) == 0, "CPU idle delta")
check(Rates.cpu(old: [10, 10, 70, 10], new: [20, 20, 70, 20]) == 100, "CPU busy delta includes nice")
check(Rates.cpu(old: [10, 10, 70, 10], new: [9, 20, 80, 20]) == nil, "CPU counter reset")
check(Rates.cpu(old: [10], new: [20]) == nil, "invalid CPU counters")
let sampler = ResourceSampler()
check(sampler.sample(volume: dir).cpu == nil, "first CPU sample needs baseline")
// Mach may return identical counters after 150 ms. Match the app's actual
// one-second sampling interval; a zero delta must remain unavailable, not 0%.
Thread.sleep(forTimeInterval: 1)
let sample = sampler.sample(volume: dir)
check(sample.cpu != nil && sample.cpu! >= 0 && sample.cpu! <= 100, "live CPU sample")
check(sample.memoryUsed != nil && sample.memoryUsed! > 0, "live memory sample")
check(sample.diskTotal != nil && sample.diskTotal! > 0, "selected volume capacity")
check(!sample.power.isEmpty, "power source sample")
print(sample.summary)
check(bytes(0) == "0 Б", "Russian zero size")
check(bytes(nil) == "Н/Д", "unavailable size")
let denied = dir.appendingPathComponent("denied")
try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
let deniedResult = Scanner.scan(dir)
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path)
check(deniedResult.errors == 1, "unreadable directory counted")
check(bytes(1_073_741_824) == "1.00 GiB", "binary units explicitly GiB")
check(deniedResult.issues.contains { $0.path == denied.path }, "error names unreadable directory")
check(!deniedResult.root.complete, "error propagates incomplete total")
check(!stopped.root.complete && stopped.root.children.allSatisfy { !$0.complete }, "cancelled sizes unknown not empty")
check(linked.root.children.first { $0.name == "loop" }?.target == dir.path, "link target retained")
let deep = dir.appendingPathComponent("deep")
var leaf = deep
for _ in 0..<120 { leaf.appendPathComponent("d") }
try FileManager.default.createDirectory(at: leaf, withIntermediateDirectories: true)
try Data(repeating: 0, count: 7).write(to: leaf.appendingPathComponent("leaf"))
check(Scanner.scan(deep, limit: 2).root.logical == 7, "deep traversal exceeds legacy threshold")
check(exactBytes(1_073_741_824) == "1073741824 Б (1.00 GiB)", "exact unrounded bytes")
var fs = statfs()
check(statfs(dir.path, &fs) == 0, "OS statfs succeeds")
let expectedTotal = Int64(fs.f_blocks) * Int64(fs.f_bsize)
check(sample.diskTotal == expectedTotal, "capacity matches statfs bytes")
check(sample.diskVolumeUsed != nil && sample.diskOccupied! + sample.diskFree! == sample.diskTotal!, "same snapshot occupied plus free equals capacity")
let mapInput = (0..<100).map { i in
 let n = FileNode(path: "/fixture/\(i)", isDirectory: false); n.logical = 1; n.complete = true; return n
}
let mapped = mapNodes(mapInput)
check(mapped.count == 80 && mapped.reduce(0) { $0 + $1.logical } == 100, "treemap Others preserves all bytes")
check(mapped.last?.children.count == 21, "Others offers navigation to omitted entries")
let wide = dir.appendingPathComponent("wide")
try FileManager.default.createDirectory(at: wide.appendingPathComponent("early"), withIntermediateDirectories: true)
for i in 0..<1000 { try Data([1]).write(to: wide.appendingPathComponent("early/f\(i)")) }
try Data([1, 2, 3]).write(to: wide.appendingPathComponent("later"))
let wideResult = Scanner.scan(wide, limit: 10)
check(wideResult.files == 1001 && wideResult.root.logical == 1003 && wideResult.root.complete, "large subtree and later sibling fully visited past old configured cap")
check(wideResult.root.children.count == 2, "later sibling retained")
var polls = 0
let partial = Scanner.scan(wide, cancelled: { polls += 1; return polls > 20 })
check(partial.cancelled && !partial.root.complete && partial.root.children.count == 2, "mid-traversal cancellation preserves root list and partial state")
check(stopped.root.children.allSatisfy { $0.sizeText == "Неизвестно" }, "unvisited displayed unknown")
let df = Process(); let dfPipe = Pipe()
df.executableURL = URL(fileURLWithPath: "/bin/df"); df.arguments = ["-k", dir.path]; df.standardOutput = dfPipe
try df.run()
let dfText = String(data: dfPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
df.waitUntilExit()
let dfFields = dfText.split(separator: "\n").last!.split(whereSeparator: { $0.isWhitespace })
let dfUsed = Int64(dfFields[2])! * 1024
let volumeSample = sampler.sample(volume: dir)
check(volumeSample.diskVolumeUsed != nil && abs(volumeSample.diskVolumeUsed! - dfUsed) < 16 * 1024 * 1024, "APFS selected volume used matches df, not container occupied")
check(GaugeScale.fraction(50, maximum: 100) == 0.5, "gauge midpoint")
check(GaugeScale.fraction(nil, maximum: 100) == nil, "missing needle")
check(GaugeScale.fraction(1, maximum: nil) == nil, "missing scale")
check(GaugeScale.fraction(.nan, maximum: 100) == nil && GaugeScale.fraction(.infinity, maximum: 100) == nil, "nonfinite telemetry")
check(GaugeScale.fraction(1, maximum: .infinity) == nil && GaugeScale.fraction(1, maximum: .nan) == nil, "nonfinite scale")
check(GaugeScale.fraction(-1, maximum: 100) == nil, "negative telemetry unavailable")
check(GaugeScale.fraction(1, maximum: 0) == nil && GaugeScale.fraction(1, maximum: -1) == nil, "invalid denominator")
check(GaugeScale.fraction(0, maximum: 100) == 0 && GaugeScale.fraction(100, maximum: 100) == 1, "gauge endpoints")
check(GaugeScale.fraction(200, maximum: 100) == 1, "gauge clamps overflow")
check(GaugeScale.angle(fraction: 0) == -180 && GaugeScale.angle(fraction: 0.5) == -90 && GaugeScale.angle(fraction: 1) == 0, "needle left top right")
check(ResourceSnapshot().batteryPercent == nil, "no battery is unavailable")
check(GaugeScale.band(0) == .green && GaugeScale.band(0.2) == .green, "green through twenty percent")
check(GaugeScale.band(0.200001) == .blue && GaugeScale.band(0.8) == .blue, "blue through eighty percent")
check(GaugeScale.band(0.800001) == .red && GaugeScale.band(1) == .red, "red above eighty percent")
check(GaugeScale.band(nil) == .unknown && GaugeScale.band(.nan) == .unknown && GaugeScale.band(.infinity) == .unknown && GaugeScale.band(-0.1) == .unknown && GaugeScale.band(1.1) == .unknown, "invalid bands neutral")
var statusSample = ResourceSnapshot()
statusSample.cpu = 20; statusSample.memoryUsed = 8 * 1_073_741_824; statusSample.memoryTotal = 16 * 1_073_741_824
statusSample.swap = 1_073_741_824; statusSample.swapTotal = 1_073_741_824
let segments = StatusPresentation.segments(statusSample, interface: "missing")
print("STATUS FORMAT: " + segments.map(\.text).joined(separator: "  "))
check(segments.map(\.text).joined(separator: "  ") == " 20.0%   50.0%    1.0G    0.0%  ↓  0.0K  ↑  0.0K", "fixed width native status title")
check(segments[0].band == .green && segments[1].band == .blue && segments[2].band == .red, "status shares exact gauge color bands")
for (value, expected) in [(0.0, "  0.0%"), (7.3, "  7.3%"), (100, "100.0%")] {
 var sample = ResourceSnapshot(); sample.cpu = value
 let field = StatusPresentation.segments(sample, interface: "missing")[0].text
 check(field == expected && field.count == 6 && Array(field)[3] == ".", "space-padded CPU decimal alignment")
}
check(StatusPresentation.segments(statusSample, interface: "missing", ramMode: .used)[1].text == "  8.0G", "RAM GiB mode keeps width and unit")
var swapFixture = ResourceSnapshot()
for (used, expected): (Int64, GaugeScale.Band) in [(0, .green), (200, .green), (201, .blue), (800, .blue), (801, .red), (1000, .red)] {
 swapFixture.swap = used; swapFixture.swapTotal = 1000
 check(StatusPresentation.segments(swapFixture, interface: "missing")[2].band == expected, "swap menu utilization boundary")
}
swapFixture.swap = 0; swapFixture.swapTotal = 0
check(StatusPresentation.segments(swapFixture, interface: "missing")[2].band == .unknown, "zero allocated swap menu neutral")
check(MetricPresentation.utilization(0, total: 0) == "Н/Д" && GaugeScale.fraction(0, maximum: 0) == nil, "zero swap has no percent or needle")
var diskStatus = ResourceSnapshot()
diskStatus.diskTotal = 1000; diskStatus.diskFree = 125
let preferenceSuite = "macdir-test-" + UUID().uuidString
let preferences = UserDefaults(suiteName: preferenceSuite)!
defer { preferences.removePersistentDomain(forName: preferenceSuite) }
check(StatusPresentation.diskMode(defaults: preferences) == .occupied, "disk default occupancy")
StatusPresentation.saveDiskMode(.free, defaults: preferences)
check(StatusPresentation.diskMode(defaults: UserDefaults(suiteName: preferenceSuite)!) == .free, "disk mode persists")
var freeStatus = ResourceSnapshot(); freeStatus.diskTotal = 100 * 1_073_741_824; freeStatus.diskFree = 12 * 1_073_741_824
let freeSegment = StatusPresentation.segments(freeStatus, interface: "en0", diskMode: .free)[3]
check(freeSegment.text == " 12.0G" && freeSegment.band == .red, "free GiB fourth with occupancy color")
check(StatusPresentation.segments(ResourceSnapshot(), interface: "en0", diskMode: .free)[3].text == "  0.0G", "missing free fixed placeholder")
let diskSegment = StatusPresentation.segments(diskStatus, interface: "en0")[3]
check(diskSegment.text == " 87.5%" && diskSegment.band == .red, "disk menu occupancy format and color")
check(StatusPresentation.segments(ResourceSnapshot(), interface: "en0").allSatisfy { $0.band == .unknown }, "unknown status is neutral")
check(StatusPresentation.rate(1024) == "  1.0K" && StatusPresentation.rate(5.2 * 1024) == "  5.2K", "fixed binary network rates rounded")
check(StatusPresentation.rate(nil) == "  0.0K" && StatusPresentation.rate(.nan) == "  0.0K" && StatusPresentation.rate(-1) == "  0.0K", "missing rate placeholder")
check(StatusPresentation.rate(1e20) == "+++.+M", "overflow preserves width")
check(StatusPresentation.rate(999.94 * 1024) == "999.9K" && StatusPresentation.rate(999.95 * 1024) == "  1.0M", "switch when rounding would overflow KiB")
check(StatusPresentation.rate(12.36 * 1_048_576) == " 12.4M", "MiB rounding and padding")
check(StatusPresentation.rate(0) == "  0.0K" && StatusPresentation.rate(1) == "  0.0K", "zero and sub KiB rates")
for rate: Double? in [nil, -1, .nan, .infinity, 0, 1, 999.95 * 1024, 999.95 * 1_048_576, 1e300] {
 check(StatusPresentation.rate(rate).count == 6, "network status field constant width")
 let presented = NetworkPresentation(rate)
 check(presented.number.count == 5 && presented.text == presented.displayNumber + " " + presented.unit + "/с", "main network number and units fixed width")
 if rate == nil || !(rate!.isFinite) || rate! < 0 {
  check(!presented.available && presented.number == "  Н/Д", "main unknown stays unavailable, not zero")
 }
}
check(NetworkPresentation(999.95 * 1_048_576).number == "+++.+", "MiB rounding carry fixed overflow")
check(NetworkPresentation(5.2 * 1024).number == "005.2" && NetworkPresentation(5.2 * 1024).unit == "KiB", "separate number and binary unit")
check(GaugeScale.batteryBand(1) == .green && GaugeScale.batteryBand(0.81) == .green, "high battery green")
check(GaugeScale.batteryBand(0.8) == .blue && GaugeScale.batteryBand(0.21) == .blue, "middle battery blue")
check(GaugeScale.batteryBand(0.2) == .red && GaugeScale.batteryBand(0) == .red, "low battery red")
check(GaugeScale.batteryBand(nil) == .unknown, "missing battery neutral")
check(MetricPresentation.number(7.25) == "7.2", "main measurement has no leading zeros")
check(MetricPresentation.number(1234.5) == "1234.5", "details preserve large measurements")
check(MetricPresentation.number(.nan) == "Н/Д" && MetricPresentation.number(-1) == "Н/Д", "invalid measurement unavailable")
check(MetricPresentation.capacity(8 * 1_073_741_824, total: 16 * 1_073_741_824) == "50.0 % · 8.0 из 16.0 GiB", "capacity percent and actual used total")
check(MetricPresentation.capacity(0, total: 0) == "Н/Д · 0.0 из 0.0 GiB", "zero allocation has no defined percentage")
check(MetricPresentation.scalePercent(20 * 1_048_576) == "200.0 % шкалы 10.0 MiB/с", "network percentage is unclamped labelled display scale")
check(MetricPresentation.battery(35) == "35%" && MetricPresentation.battery(nil) == "Н/Д", "integer battery and unknown")
check(MetricPresentation.powerState("От аккумулятора · 35.0 %") == "От аккумулятора", "battery detail without duplicate percent")
check(NetworkPresentation(5.2 * 1024).displayNumber == "5.2", "main rates unpadded")
check(StatusPresentation.ramMode(defaults: preferences) == .percent, "RAM default percent")
StatusPresentation.saveRAMMode(.used, defaults: preferences)
check(StatusPresentation.ramMode(defaults: UserDefaults(suiteName: preferenceSuite)!) == .used, "RAM mode persists")
check(StatusPresentation.segments(statusSample, interface: "", ramMode: .used)[1].text == "008.0G", "RAM used mode single padded value")
for metric in StatusPresentation.Metric.allCases {
 check(StatusPresentation.visible(metric, defaults: preferences), "visibility defaults on")
 StatusPresentation.saveVisible(false, metric: metric, defaults: preferences)
 check(!StatusPresentation.visible(metric, defaults: UserDefaults(suiteName: preferenceSuite)!), "individual hidden state persists")
 StatusPresentation.saveVisible(true, metric: metric, defaults: preferences)
 check(StatusPresentation.visible(metric, defaults: preferences), "visibility restored")
}
print("\(count) checks passed")
let rootPreview = Scanner.scan(URL(fileURLWithPath: "/"), cancelled: { true })
var progressFrames: [ScanResult] = []
let progressResult = Scanner.scan(dir, progress: { progressFrames.append($0) })
check(!progressFrames.isEmpty, "scanner publishes size progress before return")
check(progressFrames.last!.root.logical == progressResult.root.logical, "progress sizes match final result")
check(progressFrames.last!.elapsedSeconds >= progressFrames.first!.elapsedSeconds && progressFrames.last!.currentPath.hasPrefix(dir.path), "progress carries monotonic elapsed and current path")
check(progressFrames.last!.files == progressResult.files && progressFrames.first!.files == 0, "progress carries live file count")
check(progressFrames.first!.root !== progressResult.root, "progress snapshot is independent of worker mutation")
let liveDir = dir.appendingPathComponent("live-progress")
try FileManager.default.createDirectory(at: liveDir.appendingPathComponent("folder"), withIntermediateDirectories: true)
for index in 0..<4 { try Data(repeating: 1, count: 100).write(to: liveDir.appendingPathComponent("folder/\(index)")) }
var partialSizes: [Int64] = []
_ = Scanner.scan(liveDir, cancelled: { Thread.sleep(forTimeInterval: 0.26); return false }, progress: { frame in
 if let folder = frame.root.children.first, !folder.complete { partialSizes.append(folder.logical) }
})
check(partialSizes.contains { $0 > 0 && $0 < 400 }, "folder size grows before subtree completes")
check(rootPreview.root.children.contains { $0.name == "Users" && $0.isDirectory }, "root preview exposes Users before recursion")
check(rootPreview.root.children.allSatisfy { $0.state == "Не обследовано" }, "root preview does not recurse or invent sizes")
print("Root preview: \(rootPreview.root.children.count) entries; \(count) checks passed")
