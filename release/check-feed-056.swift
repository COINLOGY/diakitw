import Foundation
@main struct FeedCheck056 {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let expected: [String: (Int, String)] = [
   "macos-arm64": (1593991, "6dee475414c194d69e3635f22445c4cb027ca8868a7c3e99f01d6b20a6dbc1ba"),
   "macos-x86_64": (1723342, "c72df7c6de13bc0205e65b2ab8389990e67fffbc967b34a10799e4dd878c0a74")
  ]
  for platform in ["macos-arm64", "macos-x86_64"] {
   for channel in ["stable", "preview"] {
    let offer = try UpdateContract.select(data, channel: channel, platform: platform, current: "0.5.5", currentBuild: 55)
    precondition(offer?.version == "0.5.6" && offer?.build == 56)
    precondition(offer?.url.lastPathComponent == "diakitw-0.5.6-\(platform).dmg")
    precondition(offer?.size == expected[platform]!.0 && offer?.sha256 == expected[platform]!.1)
    let same = try UpdateContract.select(data, channel: channel, platform: platform, current: "0.5.6", currentBuild: 56)
    precondition(same == nil)
   }
  }
  for platform in ["windows-x64", "linux-x64", "android"] {
   let same = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(same == nil)
   let old = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.4", currentBuild: 54)
   precondition(old?.version == "0.5.5")
  }
  let ios = try UpdateContract.select(data, channel: "stable", platform: "ios-unsigned", current: "0.5.5", currentBuild: 55)
  precondition(ios == nil)
  print("PASS: macOS 0.5.6 in both channels, other platforms unchanged")
 }
}
