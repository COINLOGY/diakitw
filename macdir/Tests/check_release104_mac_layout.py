"""Source-level contract for the Mac dashboard; run on Linux without AppKit."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()


class DashboardLayoutTests(unittest.TestCase):
    def test_resources_network_disk_folder_order_and_real_rates(self):
        dashboard = MAIN.split('private func dashboard(viewport: CGSize)', 1)[1].split('\nfinal class AppDelegate:', 1)[0]
        resources = dashboard.index('title: "ПРОЦЕССОР"')
        swap = dashboard.index('title: "SWAP"')
        battery = dashboard.index('title: "БАТАРЕЯ · ЗАРЯД"')
        network = dashboard.index('networkInstruments')
        disk = dashboard.index('diskGauge')
        overview = dashboard.index('DiskCapacityOverview(')
        folders = dashboard.index('if let current = model.current')
        self.assertLess(resources, swap)
        self.assertLess(swap, battery)
        self.assertLess(battery, network)
        self.assertLess(network, disk)
        self.assertLess(disk, overview)
        self.assertLess(overview, folders)
        instruments = MAIN.split('private var networkInstruments:', 1)[1].split('private var diskGauge:', 1)[0]
        self.assertLess(instruments.index('receiveGauge(scale:'), instruments.index('sendGauge(scale:'))
        self.assertLess(instruments.index('sendGauge(scale:'), instruments.index('TrafficChart(history:'))
        self.assertIn('selectedNetwork?.received', instruments)
        self.assertIn('selectedNetwork?.sent', instruments)
        self.assertIn('model.trafficHistory.scale(in: model.trafficRange)', instruments)

    def test_invalid_capacity_is_not_presented_as_negative_or_overfull(self):
        core = (ROOT / 'Sources/MacdirCore/Resources.swift').read_text()
        overview = (ROOT / 'Sources/macdir/DiskCapacityOverview.swift').read_text()
        self.assertIn('diskTotal > 0, diskFree >= 0, diskFree <= diskTotal', core)
        self.assertIn('fs.f_bfree', core, 'occupied capacity must use filesystem free, not user-available blocks')
        self.assertIn('fs.f_bavail', core, 'available-to-user blocks remain separate')
        self.assertIn('snapshot.validatedDiskFree', overview)
        self.assertNotIn('bytes(snapshot.diskFree)', overview)

    def test_native_probe_covers_order_and_multiple_widths(self):
        harness = (ROOT / 'Tests/render_layout.swift').read_text()
        for name in ('resource-cpu', 'resource-battery', 'network-rx', 'network-tx',
                     'chart', 'disk-gauge', 'disk-overview', 'table', 'map'):
            self.assertIn('layoutFrames["' + name + '"]', harness)
        self.assertIn('for (width, height) in [(1440, 1200)', harness)
        self.assertIn('(800, 540)', harness)
        self.assertIn('resources/network/disk/folder order', harness)
        probe = (ROOT / 'Tests/check_layout.py').read_text()
        self.assertIn('layoutProbe("network-rx")', probe)
        self.assertIn('layoutProbe("network-tx")', probe)
        self.assertIn('layoutProbe("disk-overview")', probe)


if __name__ == '__main__':
    unittest.main()
