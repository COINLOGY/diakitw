import Foundation

enum Dial {
    enum Band { case green, blue, red, unknown }
    static func geometry(width: Double, height: Double) -> (radius: Double, centerY: Double, tailClearance: Double) {
        let radius = max(0, min((width-36)/2, (height-40)/(1+hypot(21,4)/114)))
        return (radius, radius+22, radius*hypot(21,4)/114)
    }
    // Approved expressive-v4 straight-tail SVG, offsets from pivot (150,146).
    static func needle(fraction: Double?, radius: Double) -> [(x: Double, y: Double)] {
        guard let f = fraction, f.isFinite, (0...1).contains(f), radius.isFinite, radius > 0 else { return [] }
        let a = Double.pi*f, scale = radius/114
        let points: [(Double, Double)] = [(-99,0),(0,-10),(21,-4),(21,4),(0,10)]
        return points.map { x,y in ((x*cos(a)-y*sin(a))*scale, (x*sin(a)+y*cos(a))*scale) }
    }
    static func point(fraction: Double) -> (x: Double, y: Double) {
        let f = fraction.isFinite ? min(1, max(0, fraction)) : 0
        let angle = Double.pi * (1 - f)
        return (cos(angle), -sin(angle))
    }
    static func fraction(_ value: Double?, total: Double) -> Double? {
        guard let value, value.isFinite, value >= 0, total.isFinite, total > 0 else { return nil }
        return min(1, value / total)
    }
    static func band(_ fraction: Double?, battery: Bool = false) -> Band {
        guard let fraction, fraction.isFinite, fraction >= 0 else { return .unknown }
        if fraction <= 0.2 { return battery ? .red : .green }
        if fraction <= 0.8 { return .blue }
        return battery ? .green : .red
    }
    static func speedScale(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 100 else { return 100 }
        return pow(10, ceil(log10(value / 100))) * 100 / (value <= pow(10, ceil(log10(value / 100))) * 20 ? 5 : 1)
    }
}
