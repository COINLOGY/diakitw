import Foundation
@main struct Checks {
 static func main() {
  for width in [136.0, 160, 240, 400] { for height in [100.0, 120, 160] {
   let g = GaugeGeometry(width: width, height: height)
   assert(g.radius <= 60 && g.radius > 0)
   assert(g.center.y + 22 <= height)
   for i in 0..<3 {
    let box = g.labelBox(i)
    assert(abs(box.midX - g.center.x) <= g.radius)
    assert(box.minX >= 0 && box.maxX <= width && box.minY >= 0 && box.maxY <= height)
    for j in 0..<i { assert(!box.intersects(g.labelBox(j))) }
   }
   for i in 0...100 {
    let a = GaugeScale.angle(fraction: Double(i)/100) * .pi/180
    assert(g.center.y + sin(a)*g.radius <= g.center.y + 0.00001)
   }
  } }
  print("PASS shared gauge geometry: 12 proposals, disjoint label boxes, upper-half angles")
 }
}
