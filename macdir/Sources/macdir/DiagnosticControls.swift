import SwiftUI

enum DiagnosticKind: String, CaseIterable {
 case cpu, ram, gpu
 var title: String { self == .gpu ? "GPU Metal" : rawValue.uppercased() }
 var icon: String { switch self { case .cpu: return "cpu"; case .ram: return "memorychip"; case .gpu: return "display" } }
 // Fixed dark fills keep white labels readable in both appearances; not health bands.
 var rgb: (Double, Double, Double) {
  switch self { case .cpu: return (0.125, 0.345, 0.627); case .ram: return (0.078, 0.392, 0.278); case .gpu: return (0.412, 0.247, 0.627) }
 }
 var color: Color { let c = rgb; return Color(red: c.0, green: c.1, blue: c.2) }
}
struct DiagnosticButton: View {
 let kind: DiagnosticKind
 let action: () -> Void
 var body: some View {
  Button(action: action) { Label(kind.title, systemImage: kind.icon).font(.system(size: 13, weight: .semibold)).frame(minWidth: 86) }
   .buttonStyle(DiagnosticButtonStyle(kind: kind))
   .accessibilityLabel("Запустить тест \(kind.title)")
 }
}
private struct DiagnosticButtonStyle: ButtonStyle {
 let kind: DiagnosticKind
 @Environment(\.isEnabled) private var enabled
 func makeBody(configuration: Configuration) -> some View {
  configuration.label.padding(.horizontal, 12).padding(.vertical, 10)
   .foregroundStyle(.white)
   .background(enabled ? kind.color : Color(white: 0.36), in: RoundedRectangle(cornerRadius: 8))
   .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(configuration.isPressed ? 0.8 : 0.2), lineWidth: configuration.isPressed ? 2 : 1))
 }
}
