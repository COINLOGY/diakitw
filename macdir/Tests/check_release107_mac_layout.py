"""Source-level contract for the Mac dashboard; run on Linux without AppKit."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()


class DashboardLayoutTests(unittest.TestCase):
    def test_four_square_resources_long_network_and_folder_order(self):
        dashboard = MAIN.split('private func dashboard(viewport: CGSize)', 1)[1].split('\nfinal class AppDelegate:', 1)[0]
        resources = MAIN.split('private func compactResources(', 1)[1].split('private var compactNetwork:', 1)[0]
        for first, second in zip(('ПРОЦЕССОР', 'ПАМЯТЬ', 'SWAP'), ('ПАМЯТЬ', 'SWAP', 'diskGauge')):
            a = 'title: "' + first + '"' if first != 'diskGauge' else first
            b = 'title: "' + second + '"' if second != 'diskGauge' else second
            self.assertLess(resources.index(a), resources.index(b))
        self.assertNotIn('title: "БАТАРЕЯ', resources)
        self.assertIn('count: 4', resources)
        self.assertIn('square: true', resources)
        self.assertLess(dashboard.index('compactResources(viewportWidth:'), dashboard.index('compactNetwork'))
        self.assertLess(dashboard.index('compactNetwork'), dashboard.index('if let current = model.current'))
        self.assertNotIn('compactDisk', dashboard)
        self.assertNotIn('DiskCapacityOverview(', dashboard)
        instruments = MAIN.split('private var networkInstruments:', 1)[1].split('private var diskGauge:', 1)[0]
        self.assertLess(instruments.index('receiveGauge(scale:'), instruments.index('sendGauge(scale:'))
        self.assertLess(instruments.index('sendGauge(scale:'), instruments.index('TrafficChart(history:'))
        # Компактный ряд: график занимает всю оставшуюся ширину, высота фиксирована.
        self.assertIn('.frame(maxWidth: .infinity).frame(height: 158)', instruments)
        self.assertIn('expanded: true', instruments)
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

    def test_diagnostics_fixture_is_written_in_the_107_evidence_directory(self):
        harness = (ROOT / 'Tests/render_diagnostics.swift').read_text()
        self.assertIn(r'evidence/diakitw-1.0.7/\(suffix)', harness)
        self.assertNotIn('evidence/diakitw-1.0.6/', harness)

    def test_geo_transport_fixture_links_in_the_107_evidence_directory(self):
        script = (ROOT / 'Tests/check_geo_transport.py').read_text()
        self.assertIn("evidence/diakitw-1.0.7/transport-checks", script)
        self.assertNotIn("evidence/diakitw-1.0.6/transport-checks", script)

    def test_active_gauge_guard_tracks_compact_107_without_a_battery_tile(self):
        guard = (ROOT / 'Tests/check_gauges.py').read_text()
        self.assertIn("main.count('GaugeTile(') == 6", guard)
        self.assertNotIn("model.snapshot.batteryPercent' in main", guard)
        self.assertIn("four resource including disk and two network gauges", guard)

    def test_native_probe_covers_order_and_multiple_widths(self):
        harness = (ROOT / 'Tests/render_layout.swift').read_text()
        for name in ('resource-cpu', 'resource-memory', 'resource-swap', 'disk-gauge',
                     'network-rx', 'network-tx', 'chart', 'table', 'map'):
            self.assertIn('layoutFrames["' + name + '"]', harness)
        self.assertIn('for (width, height) in [(1440, 1200)', harness)
        self.assertIn('(2532, 1200)', harness)
        self.assertIn('(800, 540)', harness)
        self.assertTrue('resource/network/folder order or lower panels overlap' in harness, 'native order assertion missing')
        probe = (ROOT / 'Tests/check_layout.py').read_text()
        self.assertIn('layoutProbe("network-rx")', probe)
        self.assertIn('layoutProbe("network-tx")', probe)
        self.assertIn('layoutProbe("disk-gauge")', probe)


if __name__ == '__main__':
    unittest.main()
