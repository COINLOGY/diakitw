import AppKit

@main struct RenderStatus {
 static func main() throws {
  _ = NSApplication.shared
  let output = URL(fileURLWithPath: CommandLine.arguments[1])
  let example = [" 28.1%", " 79.3%", "  8.3G", " 65.2%", "↓ 88.8K", "↑  7.6K"]
  var alternate = example
  alternate[3] = " 81.3G"
  alternate[4] = "↓999.9M"
  alternate[5] = "↑  0.0M"
  let variants = [example] + StatusTypography.templates + [alternate,
   ["  0.0%", "100.0%", "  0.0G", "  7.3G", "↓  0.0K", "↑100.0M"]]
  let width = StatusTypography.fixedWidth
  precondition(StatusTypography.numericFont.pointSize == 13)
  precondition(StatusTypography.numericFont.fontName.contains("Semibold"))
  precondition(width < 380, "Must remain compact, not consume the system menu width")
  let measured = variants.map { StatusTypography.title($0).size() }
  FileHandle.standardError.write(Data("METRICS width=\(width) sizes=\(measured) font=\(StatusTypography.numericFont.fontName)\n".utf8))
  for size in measured {
   precondition(size.height <= 22 && size.width + 16 <= width)
   precondition(abs(size.width - measured[0].width) < 0.01, "Magnitude, overflow, unit or disk mode shifted fields")
  }
  for mask in 0..<64 {
   let indices = (0..<6).filter { mask & (1 << $0) != 0 }
   let reserved = StatusTypography.width(indices: indices)
   if indices.isEmpty { precondition(reserved == 28); continue }
   let widths = variants.map { fields in StatusTypography.title(indices.map { fields[$0] }).size().width }
   precondition(widths.allSatisfy { abs($0 - widths[0]) < 0.01 && $0 + 16 <= reserved })
  }
  let colors: [NSColor] = [.systemBlue, .systemBlue, .systemBlue, .systemBlue,
    NSColor(srgbRed: 0.65, green: 0.90, blue: 0.25, alpha: 1),
    NSColor(srgbRed: 0.30, green: 0.75, blue: 1, alpha: 1)]
  for dark in [false, true] {
   let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: 44, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
   bitmap.size = NSSize(width: width, height: 22)
   NSGraphicsContext.saveGraphicsState()
   NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
   let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
   appearance.performAsCurrentDrawingAppearance {
    (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.94, alpha: 1)).setFill()
    NSRect(x: 0, y: 0, width: width, height: 22).fill()
    let title = StatusTypography.title(example, colors: colors)
    title.draw(at: NSPoint(x: (width - title.size().width) / 2, y: (22 - title.size().height) / 2))
   }
   NSGraphicsContext.restoreGraphicsState()
   try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(dark ? "status-dark.png" : "status-light.png"))
  }
  let report = "PASS: menu fixture; numeric=\(StatusTypography.numericFont.fontName) \(StatusTypography.numericFont.pointSize)pt; prefix=9pt; arrows=10pt; fixed item width=\(width)pt; measured title=\(measured[0]); row=22pt; all \(variants.count) magnitude/unit/overflow/disk variants equal width. Offscreen fixture, not installed menu capture.\n"
  print(report)
  try report.write(to: output.appendingPathComponent("metrics.txt"), atomically: true, encoding: .utf8)
 }
}
