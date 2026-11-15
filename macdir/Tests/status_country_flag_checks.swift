import AppKit
@main struct StatusCountryFlagChecks {
 static func main() {
  _ = NSApplication.shared
  let variants = StatusTypography.templates + [[" 54.4%"," 79.8%","  5.9G"," 78.9%"," 39.2K↓"," 11.2K↑"]]
  for mask in 0..<64 {
   let indices=(0..<6).filter { mask & (1 << $0) != 0 }
   let width=StatusTypography.width(indices: indices, includingFlag: true)
   for fields in variants {
    for flag in ["🇩🇪","🇫🇮","🌐"] {
     let title=StatusTypography.title(indices.map { fields[$0] }, flag: flag)
     precondition(title.string.hasSuffix(flag), "Country must trail all metrics")
     precondition(title.size().width + 16 <= width, "Country flag must fit fixed status item width")
    }
   }
  }
  print("PASS trailing country flag: fixed width across 64 metric visibility masks and changing locations")
 }
}
