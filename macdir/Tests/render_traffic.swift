// Offscreen deterministic rendering fixtures, never production telemetry.
import AppKit
import SwiftUI
import MacdirCore

@main struct RenderTraffic {
 @MainActor static func main() throws {
  _ = NSApplication.shared
  var history = TrafficHistory()
  for i in 0...60 {
   history.append(interface: "fixture", time: Double(i),
     received: (25...28).contains(i) ? nil : (sin(Double(i) / 4) + 1.2) * 12000,
     sent: (cos(Double(i) / 7) + 1.1) * 9000)
  }
  for dark in [false, true] {
   for width in [280.0, 600.0] {
    let chart = TrafficChart(history: history, range: .constant(.minute))
     .padding(10).frame(width: width + 20).background(dark ? Color.black : Color.white)
     .environment(\.colorScheme, dark ? .dark : .light)
    let renderer = ImageRenderer(content: chart)
    renderer.scale = 2
    guard let cg = renderer.cgImage else { fatalError("No rendered image") }
    let bitmap = NSBitmapImageRep(cgImage: cg)
    let data = bitmap.representation(using: .png, properties: [:])!
    let path = "evidence/traffic-\(dark ? "dark" : "light")-\(Int(width)).png"
    try data.write(to: URL(fileURLWithPath: path)); print(path)
   }
  }
 }
}
