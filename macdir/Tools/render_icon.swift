import AppKit
import Foundation
let input = CommandLine.arguments[1]
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let image = NSImage(contentsOfFile: input) else { fatalError("Cannot load selected SVG") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
 for scale in [1, 2] {
  let pixels = size * scale
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = NSSize(width: pixels, height: pixels)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
  try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
 }
}
print("Rendered selected SVG into 10 icon representations")
