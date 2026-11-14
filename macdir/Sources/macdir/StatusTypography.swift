import AppKit

/// Shared with offscreen fixtures. Width changes only on explicit visibility changes.
enum StatusTypography {
 static let numericFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
 static let prefixFont = NSFont.systemFont(ofSize: 9, weight: .medium)
 static let arrowFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
 static let templates = [
  ["000.0%", "000.0%", "000.0G", "000.0%", "000.0M↓", "000.0M↑"],
  ["+++.+%", "+++.+G", "+++.+G", "+++.+G", "+++.+M↓", "+++.+M↑"]
 ]
 static let fixedWidth = width(indices: Array(0..<6))
 static func width(indices: [Int]) -> CGFloat {
  guard !indices.isEmpty else { return 28 }
  return ceil(templates.map { template in title(indices.map { template[$0] }).size().width }.max()! + 16)
 }
 static func title(_ fields: [String], colors: [NSColor] = []) -> NSAttributedString {
  let result = NSMutableAttributedString(string: "")
  for (index, field) in fields.enumerated() {
   let color = colors.indices.contains(index) ? colors[index] : .labelColor
   if index > 0 { result.append(NSAttributedString(string: " ", attributes: [.font: numericFont])) }
   let arrow = field.hasSuffix("↓") || field.hasSuffix("↑")
   result.append(NSAttributedString(string: arrow ? String(field.dropLast()) : field, attributes: [.font: numericFont, .foregroundColor: color]))
   if arrow { result.append(NSAttributedString(string: String(field.suffix(1)), attributes: [.font: arrowFont, .foregroundColor: color])) }
  }
  return result
 }
}
