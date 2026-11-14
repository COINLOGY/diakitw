
// Appended only to a test copy of main.swift; never shipped in the app.
var layoutFrames: [String: CGRect] = [:]
func saveFixture(_ bitmap: NSBitmapImageRep, to url: URL, dark: Bool = true) {
 let image = bitmap.cgImage!
 let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
 context.setFillColor(dark ? CGColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1) : CGColor(gray: 0.96, alpha: 1))
 context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
 context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
 try! NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
}
struct LayoutFramesKey: PreferenceKey {
 static var defaultValue: [String: CGRect] = [:]
 static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, b in b }) }
}
extension View {
 func layoutProbe(_ name: String) -> some View {
  background(GeometryReader { geo in Color.clear.preference(key: LayoutFramesKey.self, value: [name: geo.frame(in: .named("layoutHost"))]) })
 }
}
MainActor.assumeIsolated {
 let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
 app.appearance = NSAppearance(named: .darkAqua)
 let output = URL(fileURLWithPath: CommandLine.arguments[1])
 var failures: [String] = []
 let geometryNode = FileNode(path: "/Synthetic/geometry", isDirectory: true); geometryNode.logical = 1
 let treemap = Treemap(nodes: [geometryNode], action: { _ in })
 if !treemap.boxes([geometryNode][...], CGRect(x: 0, y: 0, width: -1, height: 0)).isEmpty { failures.append("degenerate treemap must have no cells") }
 for dark in [true, false] {
 app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
 for (width, height) in [(1440, 1200), (1440, 1000), (1180, 800), (1060, 740), (1060, 580), (800, 540), (800, 1400)] {
  let model = Model()
  model.computerName = "Fixture Mac — синтетические данные"
  model.selectedInterface = "fixture0"
  model.egressLocation = EgressLocation.decode(Data(#"{"ip":"2001:db8:1234:5678:abcd:efab:1234:5678","country":"Fixture — United Kingdom of Great Britain and Northern Ireland","city":"Fixture — Newcastle upon Tyne & a deliberately long city name","latitude":"54.9","longitude":"-1.6"}"#.utf8), status: 200)
  model.externalAddress = model.egressLocation?.ip
  model.snapshot.cpu = 41; model.snapshot.memoryTotal = 8*1024*1024*1024; model.snapshot.memoryUsed = 6*1024*1024*1024
  model.snapshot.swap = 3*1024*1024*1024; model.snapshot.swapTotal = 4*1024*1024*1024
  model.snapshot.diskTotal = 256*1024*1024*1024; model.snapshot.diskFree = 80*1024*1024*1024
  model.snapshot.batteryPercent = 24; model.snapshot.power = "От аккумулятора"
  model.snapshot.networks = [NetworkRate(name: "fixture0", received: 32000, sent: 18000)]
  for i in 0...60 { model.trafficHistory.append(interface: "fixture0", time: Double(i), received: (sin(Double(i)/4)+1.2)*12000, sent: (cos(Double(i)/7)+1.1)*9000) }
  let root = FileNode(path: "/Synthetic", isDirectory: true)
  root.children = (0..<40).map { i in
   let n = FileNode(path: "/Synthetic/Folder-\(i)", isDirectory: true)
   n.logical = Int64(40-i)*1024*1024*1024; n.allocated = n.logical/2; n.complete = true; n.state = "Обследовано"; return n
  }
  root.logical = root.children.reduce(0) { $0+$1.logical }; root.complete = true
  model.current = root; model.crumbs = [root]; model.rows = root.children; model.tiles = Array(root.children.prefix(8))
  model.result = ScanResult(root: root); model.elapsed = "2.0 с"
  layoutFrames = [:]
  let view = MacdirRootView(model: model).layoutProbe("hostRoot").coordinateSpace(name: "layoutHost").environment(\.colorScheme, dark ? .dark : .light).onPreferenceChange(LayoutFramesKey.self) { layoutFrames = $0 }
  let host = NSHostingView(rootView: view)
  host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
  window.contentView = host; host.frame = NSRect(x: 0, y: 0, width: width, height: height)
  window.orderFront(nil) // Offscreen at (-10000,-10000); never activates the app.
  for _ in 0..<8 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
  let size = "\(width)x\(height)-\(dark ? "dark" : "light")"
  func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
  let scrolls = descendants(host).compactMap { $0 as? NSScrollView }
  // Named SwiftUI root and AppKit conversions share the hosting view's flipped bounds.
  if !host.isFlipped || layoutFrames["hostRoot"] != host.bounds { failures.append(size+": coordinate-space calibration failed") }
  if let outer = scrolls.first, let document = outer.documentView {
   let clipInHost = outer.contentView.convert(outer.contentView.bounds, to: host)
   let documentInHost = document.convert(document.bounds, to: host)
   let scrollInHost = outer.convert(outer.bounds, to: host)
   print("GEOMETRY", size, "host", host.bounds, "scroll", scrollInHost, "clip", clipInHost, "document", documentInHost, "gutter", scrollInHost.width - clipInHost.width, "style", outer.scrollerStyle.rawValue, "vertical", outer.hasVerticalScroller, "row", String(describing: layoutFrames["gaugeRow"]), "content", String(describing: layoutFrames["dashboardContent"]), "swiftDocument", String(describing: layoutFrames["dashboardDocument"]))
  } else { failures.append(size+": missing geometry scroll view") }

  if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
   host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
   saveFixture(bitmap, to: output.appendingPathComponent(size+".png"), dark: dark)
  } else { failures.append(size+": no bitmap") }
  print(size, layoutFrames)
  if host.bounds.width != CGFloat(width) || host.bounds.height != CGFloat(height) { failures.append(size+": host exceeds requested size") }
  if let chart = layoutFrames["chart"], let picker = layoutFrames["viewPicker"], let map = layoutFrames["map"], let table = layoutFrames["table"], let numbers = layoutFrames["numbers"] {
   if chart.height < 84 || chart.maxY > picker.minY || chart.maxY > map.minY || numbers.maxY > picker.minY { failures.append(size+": traffic overlaps lower content") }
   if table.height < 300 || map.height < 300 { failures.append(size+": lower panels compressed") }
   if table.intersection(map).width > 1 { failures.append(size+": table and map overlap") }
   if width <= 800 && chart.minY < numbers.maxY { failures.append(size+": narrow chart must be below numbers") }
   if width >= 1180 && chart.minX < numbers.maxX { failures.append(size+": wide chart must follow numbers") }
   let gauges = layoutFrames.filter { $0.key.hasPrefix("gauge-") }.map(\.value)
   if gauges.count != 6 || gauges.contains(where: { $0.width < 230 || abs($0.height - 112) > 1 || $0.maxY > min(numbers.minY, chart.minY) }) { failures.append(size+": gauges compressed or overlapping traffic") }
   if width >= 1180 && abs((gauges.map(\.maxX).max() ?? 0) - CGFloat(width - 22)) > 1 { failures.append(size+": gauges must fill the available row") }
  } else { failures.append(size+": missing geometry probes") }
  if let table = descendants(host).compactMap({ $0 as? NSTableView }).first, let tableScroll = table.enclosingScrollView {
   table.scrollRowToVisible(39)
   if tableScroll.contentView.bounds.minY <= 0 { failures.append(size+": table cannot scroll to last row") }
   table.scrollRowToVisible(0)
  } else { failures.append(size+": missing native table") }
  if let outer = scrolls.first, let document = outer.documentView {

   outer.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - outer.contentView.bounds.height)))
   outer.reflectScrolledClipView(outer.contentView)
   for _ in 0..<4 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
   if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
    host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
    saveFixture(bitmap, to: output.appendingPathComponent(size+"-bottom.png"), dark: dark)
   }
   if let bitmap = document.bitmapImageRepForCachingDisplay(in: document.bounds) {
    document.effectiveAppearance.performAsCurrentDrawingAppearance { document.cacheDisplay(in: document.bounds, to: bitmap) }
    saveFixture(bitmap, to: output.appendingPathComponent(size+"-full.png"), dark: dark)
   }
   if let table = layoutFrames["table"], table.minY >= CGFloat(height) || table.maxY <= 36 { failures.append(size+": table unreachable after scrolling") }
   print(size, "scroll views", scrolls.count, "outer offset", outer.contentView.bounds.origin)
  } else { failures.append(size+": missing page scroll view") }
  window.contentView = nil
 }
 }
 // Actual server panel, in-memory telemetry only; no ServersModel or SSH.
 let config = try! JSONDecoder().decode(ServerConfig.self, from: Data(#"{"id":"fixture","name":"Fixture server — синтетические данные","target":"fixture@example.invalid","role":"agent"}"#.utf8))
 for dark in [true, false] {
  for (label, total, free, expected) in [("used", 4294967296.0, 1073741824.0, "75.0 %"), ("zero", 0.0, 0.0, "Н/Д")] {
   let data = try! JSONSerialization.data(withJSONObject: ["schema":1, "sampled_at":1000, "cpu_percent":41, "memory_total":8589934592, "memory_available":2147483648, "swap_total":total, "swap_free":free, "disk_total":274877906944, "disk_free":85899345920])
   let sample = try! ServerTelemetry.decode(data)
   var state = ServerState(); state.accept(.success(sample))
   if measuredPercent(sample.swapUsed, sample.swapTotal) != expected { failures.append("server swap percentage " + label) }
   if total == 0 && GaugeScale.fraction(sample.swapUsed, maximum: sample.swapTotal) != nil { failures.append("zero server swap needle") }
   if measuredPair(sample.swapUsed, sample.swapTotal) != (total == 0 ? "0.0 из 0.0 GiB" : "3.0 из 4.0 GiB") { failures.append("server swap pair") }
   let view = VStack(spacing: 16) {
    ForEach(0..<2) { _ in ServerHostPanel(config: config, state: state, hardware: sample, hardwareLabel: "Fixture", now: 1000, busy: false, selection: .constant("fixture0")) }
   }.padding().environment(\.colorScheme, dark ? .dark : .light)
   let host = NSHostingView(rootView: view); host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
   let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1060, height: 1100), styleMask: [.borderless], backing: .buffered, defer: false)
   window.contentView = host; window.orderFront(nil)
   for _ in 0..<8 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
   let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
   host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
   saveFixture(bitmap, to: output.appendingPathComponent("server-\(label)-\(dark ? "dark" : "light").png"), dark: dark)
   window.contentView = nil
  }
 }
 // Internet UI fixtures: models do not start traffic without explicit Start.
 for dark in [true, false] {
  app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  app.appearance!.performAsCurrentDrawingAppearance {
   func luminance(_ color: Color) -> Double {
    let c = NSColor(color).usingColorSpace(.sRGB)!
    func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
   }
   let bg = luminance(InstrumentTheme.panel)
   for ink in [InstrumentTheme.lime, InstrumentTheme.cyan, InstrumentTheme.red] {
    let fg = luminance(ink); let contrast = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05)
    if contrast < 4.5 { failures.append("instrument number contrast below 4.5: \(contrast)") }
   }
  }
  let views: [(String, AnyView, Int, Int)] = [
   ("internet-idle", AnyView(InternetTestView(model: InternetTestModel())), 700, 600),
   ("internet-measured", AnyView(HStack {
    InternetSpeedGauge(title: "↓ Fixture DL", value: 845.23, color: InstrumentTheme.lime)
    InternetSpeedGauge(title: "↑ Fixture UL", value: 125.67, color: InstrumentTheme.cyan)
   }.padding()), 700, 280),
   ("battery-unknown", AnyView(HStack {
    GaugeTile(symbol: "bolt.fill", title: "FULL", value: "100 %", detail: "Fixture", fraction: 1, battery: true)
    GaugeTile(symbol: "bolt.fill", title: "LOW", value: "10 %", detail: "Fixture", fraction: 0.1, battery: true)
    GaugeTile(symbol: "cpu", title: "UNKNOWN", value: "Н/Д", detail: "Fixture", fraction: nil)
   }.padding()), 550, 280)
  ]
  for (name, content, width, height) in views {
   let host = NSHostingView(rootView: content.environment(\.colorScheme, dark ? .dark : .light))
   host.appearance = app.appearance
   let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
   window.contentView = host; window.orderFront(nil)
   for _ in 0..<8 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
   if host.bounds.width != CGFloat(width) { failures.append(name + " exceeds width") }
   let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
   host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
   saveFixture(bitmap, to: output.appendingPathComponent(name + (dark ? "-dark.png" : "-light.png")), dark: dark)
   window.contentView = nil
  }
 }
 // Actual font bounds at the smallest supported tile width: disjoint endpoint/midpoint labels.
 for width in [136.0, 149.0, 176.0, 220.0] {
  let geometry = GaugeGeometry(width: width, height: 120)
  var boxes: [CGRect] = []
  for (i, label) in ["0%", "50%", "100%"].enumerated() {
   let size = (label as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)])
   let box = geometry.labelBox(i)
   if size.width > box.width || size.height > box.height { failures.append("text exceeds reserved box") }
   let rect = box
   if rect.minX < 0 || rect.maxX > width || rect.minY < 0 || rect.maxY > 120 || boxes.contains(where: { $0.intersects(rect) }) { failures.append("endpoint/midpoint labels overlap or clip") }
   boxes.append(rect)
  }
 }
 for failure in failures { print("FAIL", failure) }
 print(failures.isEmpty ? "PASS: rendered first-page layout" : "FAIL: rendered first-page layout")
 exit(failures.isEmpty ? 0 : 1)
}
