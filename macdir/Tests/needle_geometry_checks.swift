import Foundation

@main struct NeedleChecks {
 static func main() {
  for (width, height) in [(100.0, 88.0), (136, 100), (160, 120), (240, 160), (400, 100)] {
   let g = GaugeGeometry(width: width, height: height)
   for fraction in stride(from: 0.0, through: 1.0, by: 0.01) {
    let points = g.needlePoints(fraction: fraction)
    assert(points.count == 5, "Approved v2 is a five-vertex straight-tail polygon")
    let s = (g.radius - 16) / 99
    let a = fraction * .pi
    let expected = [(-99.0, 0.0), (0, -8), (21, -4), (21, 4), (0, 8)]
    for (point, source) in zip(points, expected) {
     let x = g.center.x + (source.0 * cos(a) - source.1 * sin(a)) * s
     let y = g.center.y + (source.0 * sin(a) + source.1 * cos(a)) * s
     assert(hypot(point.x-x, point.y-y) < 0.000001, "Exact v2 proportions, not fork")
     assert(point.x >= 0 && point.x <= width && point.y >= 0 && point.y <= height)
     for i in 0..<3 { assert(!g.labelBox(i).contains(point), "Needle must clear labels") }
    }
    assert(hypot(points[0].x-g.center.x, points[0].y-g.center.y) <= g.radius-15)
   }
   for invalid: Double? in [nil, .nan, .infinity, -0.1, 1.1] {
    assert(g.needlePoints(fraction: invalid).isEmpty, "Unknown has no needle")
   }
   let midpoint = g.needlePoints(fraction: 0.5)
   assert(midpoint[2].y > g.center.y && midpoint[3].y > g.center.y, "Reserve straight tail below baseline")
  }
  print("PASS exact v2 straight-tail geometry: 5 sizes × 101 angles, endpoints/midpoint, unknown, bounds and label clearance")
 }
}
