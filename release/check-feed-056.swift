import Foundation
@main struct FeedCheck056 {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let expected: [String: (Int, String)] = [
   "macos-arm64": (1609755, "f72578912576dac5bf579936c99c1b9446a3dcd29f140d51a3557a049fe4631c"),
   "macos-x86_64": (1725258, "a83f20a32c01012a1dd6cb87ff88c2e3ea3b254ef4633f05b86eab04e89effab")
  ]
  for platform in ["macos-arm64", "macos-x86_64"] {
   let stable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(stable?.version == "0.5.6" && stable?.build == 56)
   precondition(stable?.url.lastPathComponent == "diakitw-0.5.6-\(platform).dmg")
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview?.version == "1.0.1" && preview?.build == 101)
   precondition(preview?.url.lastPathComponent == "diakitw-1.0.1-\(platform).dmg")
   precondition(preview?.size == expected[platform]!.0 && preview?.sha256 == expected[platform]!.1)
   let currentStable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.6", currentBuild: 56)
   let currentPreview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "1.0.1", currentBuild: 101)
   precondition(currentStable == nil && currentPreview == nil)
  }
  for platform in ["windows-x64", "linux-x64"] {
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview?.version == "1.0.1" && preview?.build == 101)
   let stable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(stable == nil)
  }
  for platform in ["android", "ios-unsigned"] {
   let preview = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(preview == nil)
  }
  let oldAndroid = try UpdateContract.select(data, channel: "stable", platform: "android", current: "0.5.4", currentBuild: 54)
  precondition(oldAndroid?.version == "0.5.5")
  print("PASS: macOS preview 1.0.1, stable 0.5.6, no Android/iOS preview in v1")
 }
}
