import Foundation
import MacdirCore

@main struct FleetTrafficChecks {
 static func sample(_ time: Double, _ rx: Double, _ tx: Double, interface: String = "eth0") throws -> ServerTelemetry {
  let payload: [String: Any] = ["schema": 1, "sampled_at": time, "cpu_percent": 20,
   "network": [["name": interface, "rx_bytes_per_second": rx, "tx_bytes_per_second": tx]]]
  return try ServerTelemetry.decode(JSONSerialization.data(withJSONObject: payload))
 }
 static func main() throws {
  let now = Date().timeIntervalSince1970
  var state = ServerState()
  state.accept(.success(try sample(now, 800, 120)))
  assert(state.trafficHistory.count == 1)
  assert(state.trafficHistory[0]?.interface == "eth0")
  assert(state.trafficHistory[0]?.received == 800 && state.trafficHistory[0]?.sent == 120)
  assert(state.trafficHistory[0]?.sampledAt == now)
  assert(state.trafficHistory[0]?.hasMeasurement == true)
  let first = state.trafficHistory[0]!
  let contiguous = try sample(now + 30, 810, 121)
  var contiguousState = ServerState(); contiguousState.accept(.success(contiguous))
  assert(contiguousState.trafficHistory[0]!.follows(first))
  var gapState = ServerState(); gapState.accept(.success(try sample(now + 60, 810, 121)))
  assert(!gapState.trafficHistory[0]!.follows(first))
  var missing = ServerState()
  let noRate = try ServerTelemetry.decode(JSONSerialization.data(withJSONObject: ["schema":1,"sampled_at":now,"network":[["name":"eth0"]]]))
  missing.accept(.success(noRate))
  assert(missing.trafficHistory[0]?.hasMeasurement == false)
  state.accept(.failure(.timeout))
  assert(state.trafficHistory.count == 2 && state.trafficHistory[1] == nil)
  assert(state.current(now: now) == nil)
  state.accept(.success(try sample(now, 42, 11, interface: "en0")))
  assert(state.trafficHistory[2]?.interface == "en0")
  assert(state.current(now: now) != nil)
  // Замеры должны идти во времени: окно истории теперь часовое, и одинаковые
  // метки времени не отбрасываются — проверяем именно ограничение окна.
  for i in 0..<200 { state.accept(.success(try sample(now + Double(i) * 30, Double(i), Double(i)))) }
  assert(state.trafficHistory.count == 121)
  assert(state.trafficHistory.compactMap { $0 }.last?.received == 199)
  assert(state.current(now: now + 91) == nil)
  print("Fleet network history: bounded, fresh, gaps and interface changes PASS")
 }
}
