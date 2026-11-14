import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError("FAIL: \(message)") }
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a-b) < 0.000001 }
check(near(Dial.point(fraction: 0).x, -1), "zero is left")
check(near(Dial.point(fraction: 0.5).y, -1), "half is top")
check(near(Dial.point(fraction: 1).x, 1), "full is right")
for i in 0...100 {
    let p = Dial.point(fraction: Double(i)/100)
    check(p.y <= 0.000001, "upper semicircle only")
    check(near(p.x*p.x + p.y*p.y, 1), "true circular radius")
}
check(Dial.fraction(nil, total: 100) == nil, "unknown no needle")
check(Dial.fraction(1, total: 0) == nil, "zero denominator")
check(Dial.fraction(.nan, total: 1) == nil, "NaN unknown")
check(Dial.fraction(1, total: .infinity) == nil, "infinite total unknown")
check(Dial.fraction(-1, total: 10) == nil, "negative unknown")
check(Dial.fraction(200, total: 100) == 1, "needle saturation")
check(Dial.band(0.2) == .green, "20 inclusive")
check(Dial.band(0.200001) == .blue, "above20")
check(Dial.band(0.8) == .blue, "80 inclusive")
check(Dial.band(0.800001) == .red, "above80")
check(Dial.band(1, battery: true) == .green, "full battery green")
check(Dial.band(nil) == .unknown, "unknown neutral")
check(Dial.speedScale(101) == 200, "adaptive scale")
check(Dial.speedScale(nil) == 100, "initial display scale")
for width in [112.0,145,180] {
    let g = Dial.geometry(width: width, height: 105)
    for step in 0...100 {
        for p in Dial.needle(fraction: Double(step)/100, radius: g.radius) {
            check(g.centerY+p.y <= 105-18, "tail above label band")
            check(p.y <= g.tailClearance+0.000001, "full sweep clearance")
        }
    }
}
let reference: [(Double, Double)] = [(-99,0),(0,-10),(21,-4),(21,4),(0,10)]
for f in [0.0,0.125,0.25,0.5,0.75,0.875,1.0] {
    let points = Dial.needle(fraction: f, radius: 114)
    check(points.count == 5, "five-point straight tail")
    let a = Double.pi*f
    for (p, q) in zip(points, reference) {
        check(near(p.x,q.0*cos(a)-q.1*sin(a)), "rotated polygon x")
        check(near(p.y,q.0*sin(a)+q.1*cos(a)), "rotated polygon y")
    }
}
for f: Double? in [nil, .nan, -.infinity, -1, 1.1] {
    check(Dial.needle(fraction: f, radius: 114).isEmpty, "unknown no polygon")
}
print("PASS: \(checks) geometry/presentation checks")
