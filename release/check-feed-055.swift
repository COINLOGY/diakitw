import Foundation
@main struct FeedCheck055 {
 static func main() throws {
  let data = try Data(contentsOf: URL(fileURLWithPath: "release/fixtures/v1-0.5.5.json"))
  for p in ["macos-arm64", "macos-x86_64", "windows-x64", "linux-x64", "android"] {
   let old = try UpdateContract.select(data, channel: "stable", platform: p, current: "0.5.4", currentBuild: 54)
   precondition(old?.version == "0.5.5" && old?.build == 55)
   precondition(old!.notes.contains("uninstall") && old!.notes.contains("данные"))
   for (v,b) in [("0.5.5",55),("0.5.6",56)] {
    let offer = try UpdateContract.select(data, channel: "stable", platform: p, current: v, currentBuild: b)
    precondition(offer == nil)
   }
   let preview = try UpdateContract.select(data, channel: "preview", platform: p, current: "0.5.4", currentBuild: 54)
   precondition(preview == nil)
  }
  let ios = try UpdateContract.select(data, channel: "stable", platform: "ios-unsigned", current: "0.5.4", currentBuild: 54)
  precondition(ios == nil)
  print("PASS Swift exact final five-platform feed: old/current/newer/channel/migration; no iOS offer")
 }
}
