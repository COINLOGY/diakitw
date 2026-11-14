import Foundation
@main struct FeedCheck {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  for platform in ["macos-arm64", "macos-x86_64", "windows-x64", "linux-x64", "android"] {
   let old = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.3", currentBuild: 53)
   precondition(old?.version == "0.5.4")
   let current = try UpdateContract.select(data, channel: "preview", platform: platform)
   precondition(current == nil)
   let newer = try UpdateContract.select(data, channel: "preview", platform: platform, current: "0.5.5", currentBuild: 55)
   precondition(newer == nil)
   let stable = try UpdateContract.select(data, channel: "stable", platform: platform, current: "0.5.3", currentBuild: 53)
   precondition(stable == nil)
  }
  let ios = try UpdateContract.select(data, channel: "preview", platform: "ios-unsigned", current: "0.5.3", currentBuild: 53)
  precondition(ios == nil)
  print("Swift actual shared manifest PASS: older/current/newer/stable; no unsigned iOS offer")
 }
}
