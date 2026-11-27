
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
// Each style runs in a fresh process. AppleShowScrollBars is supplied through
// NSArgumentDomain (launch arguments), before AppKit or SwiftUI initialization.
let styleName = CommandLine.arguments[2]
let requestedStyle: NSScroller.Style? = styleName == "overlay" ? .overlay : (styleName == "legacy" ? .legacy : nil)
MainActor.assumeIsolated {
 let preferredStyle = NSScroller.preferredScrollerStyle
 if let requestedStyle, preferredStyle != requestedStyle {
  print("FAIL: preferred scroller style", styleName, "actual", preferredStyle.rawValue)
  exit(1)
 }
 print("STYLE", styleName, "preferred", preferredStyle.rawValue)
 let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
 app.appearance = NSAppearance(named: .darkAqua)
 let output = URL(fileURLWithPath: CommandLine.arguments[1])
 var failures: [String] = []
 func fillsHorizontally(_ actual: CGRect, _ available: CGRect) -> Bool {
  abs(actual.minX - available.minX) <= 1 && abs(actual.maxX - available.maxX) <= 1
 }
 // Negative control: the original 17-point underfill must still be rejected.
 let control = CGRect(x: 22, y: 0, width: 1379, height: 112)
 if !fillsHorizontally(control, control) || fillsHorizontally(control.insetBy(dx: 17, dy: 0), control) {
  failures.append("horizontal-fill negative control failed")
 }
 let geometryNode = FileNode(path: "/Synthetic/geometry", isDirectory: true); geometryNode.logical = 1
 let treemap = Treemap(nodes: [geometryNode], action: { _ in })
 if !treemap.boxes([geometryNode][...], CGRect(x: 0, y: 0, width: -1, height: 0)).isEmpty { failures.append("degenerate treemap must have no cells") }
 for dark in [true, false] {
 app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

 for (width, height) in [(1440, 1200), (2532, 1200), (1440, 1000), (1180, 800), (1060, 740), (1060, 580), (800, 540), (800, 1400)] {
  let model = Model()
  model.computerName = "Fixture Mac — синтетические данные"
  model.selectedInterface = "fixture0"
  model.egressLocation = EgressLocation.decode(Data(#"{"ip":"2001:db8:1234:5678:abcd:efab:1234:5678","country_code":"GB","country":"Fixture — United Kingdom of Great Britain and Northern Ireland","city":"Fixture — Newcastle upon Tyne & a deliberately long city name","latitude":"54.9","longitude":"-1.6"}"#.utf8), status: 200)
  model.externalAddress = model.egressLocation?.ip
  if model.egressLocation?.flag != "🇬🇧" { failures.append("fixture country flag not derived from verified code") }
  model.snapshot.cpu = 41; model.snapshot.memoryTotal = 8*1024*1024*1024; model.snapshot.memoryUsed = 6*1024*1024*1024
  model.snapshot.swap = 3*1024*1024*1024; model.snapshot.swapTotal = 4*1024*1024*1024
  model.snapshot.diskTotal = 256*1024*1024*1024; model.snapshot.diskFree = 80*1024*1024*1024
  model.snapshot.diskType = "apfs"; model.snapshot.diskMount = "/"; model.snapshot.diskMeasured = Date(timeIntervalSince1970: 1_700_000_000)
  model.snapshot.batteryPercent = 24; model.snapshot.batteryCycles = 1227; model.snapshot.power = "От аккумулятора"
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
  let view = ContentView(model: model).layoutProbe("hostRoot").coordinateSpace(name: "layoutHost").environment(\.colorScheme, dark ? .dark : .light).onPreferenceChange(LayoutFramesKey.self) { layoutFrames = $0 }
  let host = NSHostingView(rootView: view)
  host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
  window.contentView = host; host.frame = NSRect(x: 0, y: 0, width: width, height: height)
  window.orderFront(nil) // Offscreen at (-10000,-10000); never activates the app.
  for _ in 0..<8 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
  let size = "\(width)x\(height)-\(dark ? "dark" : "light")" + (styleName == "system" ? "" : "-" + styleName)
  func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
  let scrolls = descendants(host).compactMap { $0 as? NSScrollView }
  if let requestedStyle, let outer = scrolls.first {
   if outer.scrollerStyle != requestedStyle { failures.append(size+": requested scrollbar style not exercised") }
  }
  // Named SwiftUI root and AppKit conversions share the hosting view's flipped bounds.
  if !host.isFlipped || layoutFrames["hostRoot"] != host.bounds { failures.append(size+": coordinate-space calibration failed") }
  if let outer = scrolls.first, let document = outer.documentView {
   let clipInHost = outer.contentView.convert(outer.contentView.bounds, to: host)
   let documentInHost = document.convert(document.bounds, to: host)
   let scrollInHost = outer.convert(outer.bounds, to: host)
   print("GEOMETRY", size, "host", host.bounds, "scroll", scrollInHost, "clip", clipInHost, "document", documentInHost, "gutter", scrollInHost.width - clipInHost.width, "style", outer.scrollerStyle.rawValue, "vertical", outer.hasVerticalScroller, "row", String(describing: layoutFrames["gaugeRow"]), "content", String(describing: layoutFrames["dashboardContent"]), "swiftDocument", String(describing: layoutFrames["dashboardDocument"]))
   if let swiftDocument = layoutFrames["dashboardDocument"], let content = layoutFrames["dashboardContent"], let row = layoutFrames["gaugeRow"] {
    if !fillsHorizontally(documentInHost, clipInHost) || !fillsHorizontally(swiftDocument, documentInHost) || abs(swiftDocument.minY - documentInHost.minY) > 1 || abs(swiftDocument.height - documentInHost.height) > 1 { failures.append(size+": document/clip coordinate calibration failed") }
    // Production dashboard has .padding(14); available width comes from the actual clip.
    let available = clipInHost.insetBy(dx: 14, dy: 0)
    if !fillsHorizontally(content, available) || !fillsHorizontally(row, available) { failures.append(size+": dashboard/grid must fill actual available content") }
    let resources = ["resource-cpu", "resource-memory", "resource-swap", "disk-gauge"].compactMap { layoutFrames[$0] }
    if resources.count != 4 { failures.append(size+": missing one of four resource cards") }
    else {
     let occupied = resources.reduce(CGRect.null) { $0.union($1) }
     if abs(occupied.minX - row.minX) > 2 || abs(occupied.maxX - row.maxX) > 2 { failures.append(size+": four resource cards do not fill row") }
     for (index, rect) in resources.enumerated() {
      if rect.width < 140 || abs(rect.minY - resources[0].minY) > 2 || abs(rect.height - resources[0].height) > 2 || rect.height < 120 || rect.height > 200 { failures.append(size+": resource card not uniform or aligned \(index)") }
      if index > 0 && abs(rect.minX - resources[index-1].maxX - 8) > 2 { failures.append(size+": resource card spacing changed \(index)") }
     }
    }
   } else { failures.append(size+": missing content geometry probes") }
  } else { failures.append(size+": missing geometry scroll view") }

  if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
   host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
   saveFixture(bitmap, to: output.appendingPathComponent(size+".png"), dark: dark)
  } else { failures.append(size+": no bitmap") }
  print(size, layoutFrames)
  if host.bounds.width != CGFloat(width) || host.bounds.height != CGFloat(height) { failures.append(size+": host exceeds requested size") }
  // Native geometry across intermediate and small viewport sizes, both appearances, all three scrollbar styles.
  if let cpu = layoutFrames["resource-cpu"], let memory = layoutFrames["resource-memory"],
     let swap = layoutFrames["resource-swap"], let disk = layoutFrames["disk-gauge"],
     let row = layoutFrames["gaugeRow"], let rx = layoutFrames["network-rx"],
     let tx = layoutFrames["network-tx"], let chart = layoutFrames["chart"],
     let table = layoutFrames["table"], let map = layoutFrames["map"],
     let picker = layoutFrames["viewPicker"] {
   if !(cpu.minX < memory.minX && memory.minX < swap.minX && swap.minX < disk.minX) ||
      abs(cpu.minY - disk.minY) > 2 || cpu.minY < row.minY - 2 || disk.maxY > row.maxY + 2 ||
      row.maxY > min(rx.minY, tx.minY, chart.minY) + 2 ||
      max(rx.maxY, tx.maxY, chart.maxY) > min(table.minY, map.minY) + 2 ||
      table.intersection(map).width > 1 || table.height < 300 || map.height < 300 {
    failures.append(size+": resource/network/folder order or lower panels overlap")
   }
   if abs(rx.minY - tx.minY) > 2 || abs(rx.minY - chart.minY) > 2 ||
      abs(rx.width - tx.width) > 3 || abs(rx.height - chart.height) > 3 ||
      rx.height < 120 || rx.width < 150 || chart.width < rx.width * 1.5 ||
      abs(tx.minX - rx.maxX - 8) > 2 || abs(chart.minX - tx.maxX - 8) > 2 ||
      max(disk.maxX, chart.maxX) > CGFloat(width) || min(disk.minX, rx.minX) < 0 {
    failures.append(size+": network row must be a uniform compact strip")
   }
   if picker.minY < chart.maxY - 2 || chart.height < 140 {
    failures.append(size+": chart controls or height invalid")
   }
  } else { failures.append(size+": missing dashboard section probes") }
  // Native offscreen geometry: row-major order and no horizontal clipping at 800px.
  let buttons = (0..<7).compactMap { layoutFrames["toolbar-\($0)"] }
  if buttons.count != 7 { failures.append(size+": toolbar buttons missing") }
  else {
   for (i, rect) in buttons.enumerated() {
    if rect.minX < 0 || rect.maxX > CGFloat(width) || rect.minY < 0 || rect.width < 70 || rect.height < 15 { failures.append(size+": toolbar button \(i) clipped") }
    if i > 0 && !(rect.minY > buttons[i-1].minY + 2 || (abs(rect.minY - buttons[i-1].minY) <= 2 && rect.minX > buttons[i-1].minX)) { failures.append(size+": toolbar order changed at \(i)") }
   }
   if width == 800 && !buttons.contains(where: { $0.minY > buttons[0].minY + 2 }) { failures.append(size+": narrow toolbar did not wrap") }
  }
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
 if styleName != "system" {
  for failure in failures { print("FAIL", failure) }
  print(failures.isEmpty ? "PASS: rendered first-page layout " + styleName : "FAIL: rendered first-page layout " + styleName)
  exit(failures.isEmpty ? 0 : 1)
 }
 // Root zoom path also renders at small and intermediate widths; no SSH or disk scan.
 for width in [800, 1060, 1180] {
  let rootModel = Model()
  layoutFrames = [:]
  let zoomView = MacdirRootView(model: rootModel).frame(width: CGFloat(width), height: 600)
   .coordinateSpace(name: "layoutHost")
   .onPreferenceChange(LayoutFramesKey.self) { layoutFrames = $0 }
  let root = NSHostingView(rootView: zoomView)
  let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: CGFloat(width), height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
  window.contentView = root; window.orderFront(nil)
  for _ in 0..<8 { root.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
  if root.bounds.width != CGFloat(width) { failures.append("zoom root exceeds viewport \(width)") }
  if let dashboard = layoutFrames["zoom-dashboard"], let marker = layoutFrames["zoom-marker"],
     let toolbar = layoutFrames["zoom-toolbar"] {
   let expected = WindowZoom.fit(width: Double(width), height: 600 - Double(toolbar.height),
     minimumWidth: 1180, minimumHeight: 800)
   if abs(marker.width - CGFloat(100 * expected)) > 2 || dashboard.minX < -2 ||
      dashboard.maxX > CGFloat(width) + 2 || dashboard.minY < toolbar.maxY - 2 ||
      dashboard.minY >= 600 || dashboard.width <= 0 {
    failures.append("zoom dashboard clipped or scale incorrect \(width)")
   }
  } else { failures.append("zoom dashboard clipped: missing native probes \(width)") }
  if let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
   root.effectiveAppearance.performAsCurrentDrawingAppearance { root.cacheDisplay(in: root.bounds, to: bitmap) }
   saveFixture(bitmap, to: output.appendingPathComponent("zoom-root-\(width).png"))
  } else { failures.append("zoom root no bitmap \(width)") }
  window.contentView = nil; rootModel.stop()
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
    ForEach(0..<2) { _ in ServerHostPanel(config: config, state: state, hardware: sample, hardwareLabel: "Fixture", now: 1000, busy: false, interval: 30, selection: .constant("fixture0")) }
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
  // Fleet overview: two in-memory servers, no SSH or saved configuration.
  let fleetSecond = try! JSONDecoder().decode(ServerConfig.self, from: Data(#"{"id":"fixture-2","name":"Fixture server 2 — синтетические данные","target":"fixture2@example.invalid","role":"bot"}"#.utf8))
  for dark in [true, false] {
   for width in [1060, 1180, 1440] {
    let servers = ServersModel()
    servers.configs = [config, fleetSecond]
    for (index, server) in servers.configs.enumerated() {
     var state = ServerState()
     let started = Date().timeIntervalSince1970 - 330
     for tick in 0..<12 {
      let payload: [String: Any] = ["schema":1, "sampled_at":started + Double(tick) * 30,
       "cpu_percent": 15 + index * 20, "memory_total":8589934592, "memory_available":2147483648,
       "swap_total":4294967296, "swap_free":3221225472,
       "disk_total":274877906944, "disk_free":206158430208,
       "network":[["name":"eth0", "rx_bytes_per_second":4000 + tick * 850, "tx_bytes_per_second":1200 + tick * 210]]]
      let data = try! JSONSerialization.data(withJSONObject: payload)
      state.accept(.success(try! ServerTelemetry.decode(data)))
     }
     servers.states[server.id] = state
    }
    layoutFrames = [:]
    let view = ServerPanel(model: servers).frame(width: CGFloat(width), height: 780)
     .environment(\.colorScheme, dark ? .dark : .light)
     .coordinateSpace(name: "layoutHost")
     .onPreferenceChange(LayoutFramesKey.self) { layoutFrames = $0 }
    let host = NSHostingView(rootView: view); host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: CGFloat(width), height: 780), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; window.orderFront(nil)
    for _ in 0..<10 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.04)) }
    let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.effectiveAppearance.performAsCurrentDrawingAppearance { host.cacheDisplay(in: host.bounds, to: bitmap) }
    saveFixture(bitmap, to: output.appendingPathComponent("fleet-\(width)-\(dark ? "dark" : "light").png"), dark: dark)
    for server in servers.configs {
     let prefix = "fleet-" + server.id + "-"
     for label in ["cpu", "ram", "swap", "disk"] {
      if let frame = layoutFrames[prefix + label] {
       if abs(frame.width - frame.height) > 1 || frame.width > 109 || frame.width < 71 {
        failures.append("fleet square gauge " + server.id + " " + label + " " +
         String(Int(frame.width)) + "x" + String(Int(frame.height)))
       }
      } else { failures.append("fleet missing gauge " + server.id + " " + label) }
     }
     if let load = layoutFrames[prefix + "load"], let chart = layoutFrames[prefix + "network"], let row = layoutFrames[prefix + "row"] {
      if load.minX < row.minX || chart.maxX > row.maxX + 2 || load.maxX > chart.minX + 2 || chart.width < 80 || load.width < 80 {
       failures.append("fleet load/network order, visibility or overlap " + server.id +
        " row=\(Int(row.minX))...\(Int(row.maxX)) load=\(Int(load.minX))...\(Int(load.maxX))w\(Int(load.width)) chart=\(Int(chart.minX))...\(Int(chart.maxX))w\(Int(chart.width))")
      }
     } else { failures.append("fleet load/network geometry missing " + server.id) }
    }
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
    InternetSpeedGauge(title: "Fixture DL", direction: "↓", value: 845.23, color: InstrumentTheme.lime)
    InternetSpeedGauge(title: "Fixture UL", direction: "↑", value: 125.67, color: InstrumentTheme.cyan)
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
