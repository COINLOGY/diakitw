import Foundation
import AppKit
import MacdirCore

/// Finite in-memory fixtures + reads of this bundle only. No Model, samplers,
/// NSApplication, scan, process launch, preferences, cache writes or networking.
func runOfflineSelfCheck() -> Int32 {
 guard CommandLine.arguments.count == 2 else {
  print("SELF-CHECK FAIL: use --self-check alone")
  return 64
 }
 let fixtures: [(String, Bool)] = [
  ("network delta", Rates.perSecond(old: 100, new: 300, seconds: 2) == 100),
  ("counter reset", Rates.perSecond(old: 300, new: 100, seconds: 2) == nil),
  ("CPU delta", Rates.cpu(old: [10, 10, 70, 10], new: [30, 20, 130, 20]) == 40),
  ("gauge boundaries", GaugeScale.band(0.2) == .green && GaugeScale.band(0.8) == .blue && GaugeScale.band(0.81) == .red),
  ("missing telemetry", GaugeScale.fraction(nil, maximum: 100) == nil),
  ("network format", NetworkPresentation(1024).compact == "001.0K"),
  ("JSON runtime", (try? JSONSerialization.jsonObject(with: Data("{\"fixture\":true}".utf8))) is [String: Any])
 ]
 for (name, passed) in fixtures where !passed {
  print("SELF-CHECK FAIL: \(name)"); return 1
 }
 guard Bundle.main.bundleIdentifier == "local.emcx.macdir",
       let icon = Bundle.main.url(forResource: "macdir", withExtension: "icns"),
       let probe = Bundle.main.url(forResource: "server_probe", withExtension: "py"),
       let iconData = try? Data(contentsOf: icon), iconData.count < 4_194_304,
       NSImage(data: iconData) != nil,
       let probeData = try? Data(contentsOf: probe), !probeData.isEmpty, probeData.count < 1_048_576 else {
  print("SELF-CHECK FAIL: bundle resources"); return 1
 }
 #if arch(x86_64)
 let architecture = "x86_64"
 #elseif arch(arm64)
 let architecture = "arm64"
 #else
 let architecture = "other"
 #endif
 print("SELF-CHECK PASS: \(architecture); offline fixtures=\(fixtures.count); bundle resources=2; no GUI/scan/network/cache writes")
 return 0
}
