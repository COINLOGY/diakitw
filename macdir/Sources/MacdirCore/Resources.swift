import Foundation
import Darwin
import IOKit.ps

public func bytes(_ value: Int64?) -> String {
 guard let value else { return "Н/Д" }
 if value == 0 { return "0 Б" }
 let units = ["Б", "KiB", "MiB", "GiB", "TiB", "PiB"]
 var number = Double(value); var index = 0
 while abs(number) >= 1024 && index < units.count - 1 { number /= 1024; index += 1 }
 return index == 0 ? "\(value) Б" : String(format: "%.2f %@", locale: Locale(identifier: "en_US_POSIX"), number, units[index])
}
public func exactBytes(_ value: Int64?) -> String {
 guard let value else { return "Н/Д" }
 return "\(value) Б (\(bytes(value)))"
}
public struct NetworkRate: Sendable, Identifiable {
 public var id: String { name }
 public let name: String
 public let received: Double?
 public let sent: Double?
}
public struct ResourceSnapshot: Sendable {
 public var cpu: Double?
 public var memoryUsed: Int64?
 public var memoryTotal: Int64 = Int64(ProcessInfo.processInfo.physicalMemory)
 public var compressed: Int64?
 public var swap: Int64?
 public var swapTotal: Int64?
 public var diskTotal: Int64?
 public var diskFree: Int64?
 public var diskVolumeUsed: Int64?
 public var diskOccupied: Int64? { guard let diskTotal, let diskFree else { return nil }; return diskTotal - diskFree }
 public var diskMount = "Н/Д"
 public var diskType = "Н/Д"
 public var diskMeasured: Date?
 public var diskDetail: String {
  "statfs · \(diskType) · \(diskMount)\nЁмкость: \(exactBytes(diskTotal))\nСвободно (без purgeable): \(exactBytes(diskFree))\nЁмкость − свободно (APFS: общий пул, не один том): \(exactBytes(diskOccupied))\nЗанято выбранным томом (df Used): \(exactBytes(diskVolumeUsed))\nFinder доступно с purgeable: Н/Д\nЗамер: \(diskMeasured?.description ?? "Н/Д")"
 }
 public var networks: [NetworkRate] = []
 /// Monotonic time used for network counter deltas, not UI delivery time.
 public var networkSampleTime: Double?
 public var interfaceAddresses: [String: [String]] = [:]
 public var power = "Н/Д"
 public var batteryPercent: Double?
 public var summary: String {
  "CPU: \(cpu.map { String(format: "%.1f%%", $0) } ?? "Н/Д"); RAM active+wired+compressed: \(bytes(memoryUsed))/\(bytes(memoryTotal)); compressed: \(bytes(compressed)); swap: \(bytes(swap)); disk free: \(bytes(diskFree))/\(bytes(diskTotal)); power: \(power); network: " + networks.map { "\($0.name) ↓\($0.received.map { String(format: "%.0f B/s", $0) } ?? "Н/Д") ↑\($0.sent.map { String(format: "%.0f B/s", $0) } ?? "Н/Д")" }.joined(separator: ", ")
 }
 public init() {}
}
/// Use from one serial executor; deltas belong to this sampler.
public final class ResourceSampler: @unchecked Sendable {
 private let lock = NSLock()
 private var priorCPU: [UInt64]?
 private var priorNetwork: [String: (UInt64, UInt64)] = [:]
 private var priorTime: Double?
 public init() {}
 public func sample(volume: URL?) -> ResourceSnapshot {
  lock.lock(); defer { lock.unlock() }
  var s = ResourceSnapshot()
  var cpu = host_cpu_load_info()
  var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
  let host = mach_host_self()
  defer { mach_port_deallocate(mach_task_self_, host) }
  let status = withUnsafeMutablePointer(to: &cpu) { p in p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) } }
  if status == KERN_SUCCESS {
   let ticks = [cpu.cpu_ticks.0, cpu.cpu_ticks.1, cpu.cpu_ticks.2, cpu.cpu_ticks.3].map(UInt64.init)
   if let old = priorCPU { s.cpu = Rates.cpu(old: old, new: ticks) }; priorCPU = ticks
  }
  var vm = vm_statistics64()
  count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
  let vmStatus = withUnsafeMutablePointer(to: &vm) { p in p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) } }
  if vmStatus == KERN_SUCCESS {
   let page = Int64(vm_kernel_page_size)
   s.compressed = Int64(vm.compressor_page_count) * page
   s.memoryUsed = (Int64(vm.active_count) + Int64(vm.wire_count) + Int64(vm.compressor_page_count)) * page
  }
  var swap = xsw_usage(); var size = MemoryLayout<xsw_usage>.size
  if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
   s.swap = Int64(swap.xsu_used)
   s.swapTotal = Int64(swap.xsu_total)
  }
  if let volume {
   var fs = statfs()
   if statfs(volume.path, &fs) == 0 {
    let block = Int64(fs.f_bsize)
    s.diskTotal = Int64(fs.f_blocks) * block
    s.diskFree = Int64(fs.f_bavail) * block
    // APFS f_bfree is shared-container free, not the volume's own usage.
    // getattrlist packs attributes on 4-byte boundaries after the UInt32 length.
    var request = attrlist()
    request.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
    request.volattr = UInt32(ATTR_VOL_INFO) | UInt32(ATTR_VOL_SPACEUSED)
    var buffer = [UInt8](repeating: 0, count: 12)
    let status = buffer.withUnsafeMutableBytes { raw in
     getattrlist(volume.path, &request, raw.baseAddress!, raw.count, 0)
    }
    if status == 0 {
     s.diskVolumeUsed = buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
    }
    s.diskMount = withUnsafePointer(to: &fs.f_mntonname) { $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) } }
    s.diskType = withUnsafePointer(to: &fs.f_fstypename) { $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) } }
    s.diskMeasured = Date()
   }
  }
  let now = ProcessInfo.processInfo.systemUptime
  s.networkSampleTime = now
  var current: [String: (UInt64, UInt64)] = [:]
  var addresses: UnsafeMutablePointer<ifaddrs>?
  if getifaddrs(&addresses) == 0 {
   defer { freeifaddrs(addresses) }
   var cursor = addresses
   while let p = cursor {
    let item = p.pointee; cursor = item.ifa_next
    guard let addr = item.ifa_addr,
          item.ifa_flags & UInt32(IFF_LOOPBACK) == 0, item.ifa_flags & UInt32(IFF_UP) != 0 else { continue }
    let family = Int32(addr.pointee.sa_family)
    let name = String(cString: item.ifa_name)
    var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
    var numeric: String?
    if family == AF_INET {
     var value = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
     if inet_ntop(AF_INET, &value, &buffer, socklen_t(buffer.count)) != nil { numeric = String(cString: buffer) }
    } else if family == AF_INET6 {
     var value = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr
     if inet_ntop(AF_INET6, &value, &buffer, socklen_t(buffer.count)) != nil { numeric = String(cString: buffer) }
    }
    if let value = MacIdentity.validAddress(numeric), !(s.interfaceAddresses[name] ?? []).contains(value) {
     s.interfaceAddresses[name, default: []].append(value)
    }
    guard family == AF_LINK, let data = item.ifa_data else { continue }
    let info = data.assumingMemoryBound(to: if_data.self).pointee
    current[String(cString: item.ifa_name)] = (UInt64(info.ifi_ibytes), UInt64(info.ifi_obytes))
   }
  }
  for name in current.keys.sorted() {
   let pair = current[name]!
   let dt = priorTime.map { now - $0 } ?? 0
   let old = priorNetwork[name]
   s.networks.append(NetworkRate(name: name, received: old.flatMap { Rates.perSecond(old: $0.0, new: pair.0, seconds: dt) }, sent: old.flatMap { Rates.perSecond(old: $0.1, new: pair.1, seconds: dt) }))
  }
  s.networks.sort {
   let left = ($0.received ?? 0) + ($0.sent ?? 0)
   let right = ($1.received ?? 0) + ($1.sent ?? 0)
   return left == right ? $0.name < $1.name : left > right
  }
  priorTime = now; priorNetwork = current
  if let unmanaged = IOPSCopyPowerSourcesInfo() {
   let blob = unmanaged.takeRetainedValue()
   if let source = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String? {
    s.power = source == "AC Power" ? "От сети" : source == "Battery Power" ? "От аккумулятора" : source
   }
   if let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
    for item in list {
     if let d = IOPSGetPowerSourceDescription(blob, item)?.takeUnretainedValue() as? [String: Any],
        let capacity = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 {
      if d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
         let fraction = GaugeScale.fraction(Double(capacity), maximum: Double(max)) {
       s.batteryPercent = fraction * 100
      }
      s.power += " · " + MetricPresentation.percent(Double(capacity) * 100 / Double(max))
      if d[kIOPSIsChargingKey] as? Bool == true { s.power += " · зарядка" }
     }
    }
   }
  }
  return s
 }
}
