import XCTest
@testable import MacdirCore
final class CoreTests: XCTestCase {
 func testScannerTotalsAndSymlinkSafety() throws {
  let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"]!).appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  try Data(repeating: 42, count: 100).write(to: dir.appendingPathComponent("a"))
  try Data(repeating: 1, count: 50).write(to: dir.appendingPathComponent("sub/b"))
  try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("loop").path, withDestinationPath: dir.path)
  let result = Scanner.scan(dir)
  XCTAssertEqual(result.root.logical, 150)
  XCTAssertEqual(result.files, 2)
  XCTAssertEqual(result.symlinks, 1)
  XCTAssertEqual(result.errors, 0)
 }
}
