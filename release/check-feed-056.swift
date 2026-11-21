import Foundation
@main struct FeedCheck056 {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let manifestData = try Data(contentsOf: URL(fileURLWithPath: "manifest.json"))
  let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
  let rows = manifest["platforms"] as! [[String: Any]]
  func row(_ id: String) -> [String: Any] { rows.first { $0["id"] as? String == id }! }
  func details(_ id: String) -> (Int, String) {
   let r = row(id)
   return (r["size_bytes"] as! Int, r["sha256"] as! String)
  }
  let cur = row("mac-silicon")
  let cv = cur["version"] as! String
  let cb = cur["build"] as! Int
  let expected: [String: (Int, String)] = [
   "macos-arm64": details("mac-silicon"),
   "macos-x86_64": details("mac-intel")
  ]
  for platform in ["macos-arm64", "macos-x86_64"] {
   let stable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(stable?.version == "0.5.6" && stable?.build == 56)
   precondition(stable?.url.lastPathComponent == "diakitw-0.5.6-\(platform).dmg")
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview?.version == cv && preview?.build == cb)
   precondition(preview?.url.lastPathComponent == "diakitw-\(cv)-\(platform).dmg")
   precondition(preview?.size == expected[platform]!.0 && preview?.sha256 == expected[platform]!.1)
   let currentStable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.6", currentBuild: 56)
   let oldPreview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "1.0.2", currentBuild: 102)
   let currentPreview = try UpdateContract.select(data, channel: "preview", platform: platform, current: cv, currentBuild: cb)
   precondition(oldPreview?.version == cv)
   precondition(currentStable == nil && currentPreview == nil)
  }
  for platform in ["windows-x64", "linux-x64"] {
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview?.version == cv && preview?.build == cb)
   let stable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(stable == nil)
  }
  for platform in ["android", "ios-unsigned"] {
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview == nil)
  }
  let oldAndroid = try UpdateContract.select(data, channel: "stable", platform: "android", current: "0.5.4", currentBuild: 54)
  precondition(oldAndroid?.version == "0.5.5")
  print("PASS: v1 preview \(cv)/\(cb) desktop+macOS, stable 0.5.6, no Android/iOS preview")
 }
}
