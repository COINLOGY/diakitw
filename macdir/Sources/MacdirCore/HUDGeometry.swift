import CoreGraphics

public enum HUDGeometry {
 public static func frame(in visibleFrame: CGRect) -> CGRect {
  let width = min(800, max(0, visibleFrame.width - 24))
  let height = min(50, max(0, visibleFrame.height - 16))
  return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.maxY - height - 8, width: width, height: height)
 }
}
