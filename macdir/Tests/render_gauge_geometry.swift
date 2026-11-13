import SwiftUI
import AppKit
import MacdirCore

@main struct GaugeRasterChecks {
 @MainActor static func main() throws {
  let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
  let output = URL(fileURLWithPath: CommandLine.arguments[1])
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
  var failures = 0
  for (width, height) in ([(100.0, 88.0)] + [136.0, 160.0, 240.0, 400.0].flatMap({ w in [100.0, 120.0, 160.0].map { (w, $0) } })) {
   for dark in [true, false] { for scale in [1.0, 2.0] {
    for (name, fraction, neutral) in [("cpu", Optional(0.5), false), ("zero", Optional(0.0), false), ("full", Optional(1.0), false), ("quarter", Optional(0.25), false), ("three-quarter", Optional(0.75), false), ("network", Optional(0.8), true), ("unknown", nil, false)] {
     app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
     let view = NeedleGauge(fraction: fraction, neutral: neutral, upperLabel: "10 MiB/с").frame(width: width, height: height).environment(\.colorScheme, dark ? .dark : .light)
     let renderer = ImageRenderer(content: view); renderer.scale = scale
     guard let image = renderer.cgImage else { fatalError("No raster") }
     let bitmap = NSBitmapImageRep(cgImage: image)
     let filename = "\(name)-\(Int(width))x\(Int(height))-\(dark ? "dark" : "light")-\(Int(scale))x.png"
     try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
     // Central lower region excludes all three label boxes and the pivot.
     // A true upper semicircle has no paint here; the old 40/20 loop does.
     let geometry = GaugeGeometry(width: width, height: height)
     let baseline = geometry.center.y
     let pivotPaint = bitmap.colorAt(x: Int(geometry.center.x*scale), y: Int(baseline*scale))!.alphaComponent > 0.1
     if pivotPaint != (fraction != nil) { print("FAIL pivot / unknown needle", filename); failures += 1 }
     if let fraction {
      let angle = GaugeScale.angle(fraction: fraction) * .pi / 180
      let distance = (geometry.radius - 18) * 0.65
      let x = Int((geometry.center.x + cos(angle)*distance)*scale)
      let y = Int((baseline + sin(angle)*distance)*scale)
      if bitmap.colorAt(x: x, y: y)!.alphaComponent < 0.1 { print("FAIL needle direction", filename); failures += 1 }
     }
     if fraction == 0.5 {
      let tailY = baseline + (geometry.radius - 16) / 99 * 17
      let tail = bitmap.colorAt(x: Int(geometry.center.x*scale), y: Int(tailY*scale))!
      if tail.alphaComponent < 0.1 { print("FAIL approved straight tail absent", filename); failures += 1 }
     }
     let needle = InstrumentNeedle(fraction: fraction ?? -1).path(in: CGRect(x: 0, y: 0, width: width, height: height))
     let needleEdge = needle.strokedPath(StrokeStyle(lineWidth: 2 / scale))
     var painted = 0
     for y in Int((baseline + 5)*scale)..<Int(height*scale) {
      for x in 0..<Int(width*scale) {
       let point = CGPoint(x: Double(x)/scale, y: Double(y)/scale)
       if (0..<3).contains(where: { geometry.labelBox($0).insetBy(dx: -1, dy: -1).contains(point) }) { continue }
       // Exempt only the actual five-vertex needle and a one-pixel AA edge,
       // never a blanket lower strip that could conceal a full-circle regression.
       if needle.contains(point) || needleEdge.contains(point) { continue }
       if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.1 { painted += 1 }
      }
     }
     if painted > 0 { print("FAIL lower semicircle", filename, painted); failures += 1 }
    }
   } }
  }
  print("Raster failures:", failures)
  exit(failures == 0 ? 0 : 1)
 }
}
