import Foundation
@main struct LiveUpdateCheck {
 static func main() async throws {
  let feed = try await UpdateTransport.fetch()
  for platform in ["macos-arm64", "macos-x86_64"] {
   for channel in ["stable", "preview"] {
    guard let offer = try UpdateContract.select(feed, channel: channel, platform: platform, current: "0.5.5", currentBuild: 55) else { fatalError("missing offer: \(platform) / \(channel)") }
    precondition(offer.version == "0.5.6" && offer.build == 56)
    precondition(offer.url.lastPathComponent == "diakitw-0.5.6-\(platform).dmg")
    let same = try UpdateContract.select(feed, channel: channel, platform: platform, current: "0.5.6", currentBuild: 56)
    precondition(same == nil)
    print("PASS live update: \(platform) / \(channel) → \(offer.version) (\(offer.build))")
   }
  }
 }
}
