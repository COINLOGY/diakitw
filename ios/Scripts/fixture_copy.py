"""Build-only test copy. Never modifies or ships production fixture hooks."""
from pathlib import Path
import shutil,sys
src=Path(__file__).resolve().parents[1]; dst=Path(sys.argv[1])
assert not dst.exists()
for name in ['Sources','Assets.xcassets','diakitw.xcodeproj','Tests']:
    shutil.copytree(src/name,dst/name)
for name in ['Info.plist','PrivacyInfo.xcprivacy']:
    shutil.copy2(src/name,dst/name)
p=dst/'Sources/BoundedTransfer.swift'
p.write_text('''import Foundation
enum BoundedTransfer {
    static func fetch(_ request: URLRequest, cap: Int) async throws -> Data {
        try Task.checkCancellation()
        if ProcessInfo.processInfo.environment["DIAKITW_FIXTURE"] == "unknown" { throw URLError(.notConnectedToInternet) }
        guard request.url == NetworkPolicy.egressURL else { throw URLError(.unsupportedURL) }
        return Data(#"{"ip":"203.0.113.53","code":"DE","city":"TEST FIXTURE"}"#.utf8)
    }
}
''')
p=dst/'Sources/Monitor.swift'; text=p.read_text()
a=text.index('        var info = mach_task_basic_info()'); b=text.index('    private func refreshIP',a)
text=text[:a]+'''        if ProcessInfo.processInfo.environment["DIAKITW_FIXTURE"] == "unknown" {
            appRAM = nil; diskUsed = nil; diskTotal = nil; charge = nil
            power = "TEST FIXTURE · unknown"
        } else {
            appRAM = physicalRAM * 0.12; diskUsed = 64 * 1_073_741_824; diskTotal = 128 * 1_073_741_824
            charge = 0.95; power = "TEST FIXTURE"
            download = 42; upload = 18
        }
        speedStatus = "TEST FIXTURE · no live speed test"
    }
'''+text[b:]
p.write_text(text)
p=dst/'Sources/DiakitwApp.swift'; p.write_text(p.read_text().replace('Text("diakitw")','Text("diakitw · TEST")'))
# Replace only the fixture checker construction; never contact the update feed during smoke.
p=dst/'Sources/DiakitwApp.swift'
p.write_text(p.read_text().replace('updates = UpdateChecker()', 'updates = UpdateChecker(load: { Data(#"{\"schema\":1,\"releases\":[]}"#.utf8) })'))
print('Created unshipped fixture copy; all production transport disabled')
