// Fixture-only rendering: no model, worker, scan, telemetry or networking.
import AppKit
import SwiftUI
import MacdirCore

@main struct RenderDiagnostics {
 @MainActor static func main() throws {
  _ = NSApplication.shared
  for kind in DiagnosticKind.allCases {
   func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
   let rgb = kind.rgb
   let luminance = 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
   let contrast = 1.05 / (luminance + 0.05)
   precondition(contrast >= 4.5, "white text contrast")
   precondition(NSImage(systemSymbolName: kind.icon, accessibilityDescription: nil) != nil, "available icon")
   print("\(kind.rawValue): contrast \(contrast)")
  }
  for dark in [false, true] {
   for width in [572.0, 760.0] {
    for (suffix, reason, code) in [("completed", InternetProcess.Reason.finished, Int32(0)), ("thermal", .finished, 75)] {
     let data = Data(#"{"mode":"ram","status":"completed","batches":4,"verified":262144,"errors":0,"allocatedBytes":1048576,"checksum":"0","elapsed":0.8,"device":""}"#.utf8)
     let report = DiagnosticSummary.make(mode: "ram", limits: DiagnosticLimits(seconds: 1, duty: 1, mebibytes: 1), reason: reason, exitCode: code, data: suffix == "completed" ? data : Data(), elapsed: 0.85)
     let content = VStack(alignment: .leading, spacing: 16) {
      Text("Диагностика · синтетический fixture").font(.title2.bold())
      HStack { ForEach(DiagnosticKind.allCases, id: \.self) { kind in DiagnosticButton(kind: kind, action: {}) } }
      HStack { ForEach(DiagnosticKind.allCases, id: \.self) { kind in DiagnosticButton(kind: kind, action: {}).disabled(true) } }
      Text(report.text).font(.system(.body, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
     }.padding(24).frame(width: width).foregroundStyle(dark ? Color.white : Color.black)
      .background(dark ? Color(white: 0.12) : .white).environment(\.colorScheme, dark ? .dark : .light)
     let renderer = ImageRenderer(content: content); renderer.scale = 2
     guard let image = renderer.cgImage else { fatalError("render failed") }
     let bitmap = NSBitmapImageRep(cgImage: image)
     let path = "evidence/diakitw-0.5.6/\(suffix)-\(dark ? "dark" : "light")-\(Int(width)).png"
     try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
     print(path)
    }
   }
  }
 }
}
