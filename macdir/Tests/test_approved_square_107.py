"""Approved 1.0.7 Mac dashboard: CPU, RAM, SWAP, disk in one square row."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()
GAUGE = (ROOT / 'Sources/macdir/NeedleGauge.swift').read_text()


class ApprovedSquareLayout(unittest.TestCase):
    def test_disk_joins_three_resource_gauges_without_a_second_capacity_panel(self):
        resources = MAIN.split('private func compactResources(', 1)[1].split('private var compactNetwork:', 1)[0]
        positions = [resources.index(token) for token in ('title: "ПРОЦЕССОР"', 'title: "ПАМЯТЬ"', 'title: "SWAP"', 'diskGauge')]
        self.assertEqual(positions, sorted(positions))
        self.assertIn('count: 4', resources)
        self.assertEqual(resources.count('square: true'), 3)
        dashboard = MAIN.split('private func dashboard(viewport: CGSize)', 1)[1].split('final class AppDelegate:', 1)[0]
        self.assertNotIn('compactDisk', dashboard)
        self.assertNotIn('DiskCapacityOverview(', dashboard)
        disk = MAIN.split('private var diskGauge:', 1)[1].split('private func compactToolbar(', 1)[0]
        self.assertIn('square: true', disk)
        self.assertIn('.popover(isPresented: $model.showCapacity)', disk)

    def test_network_row_never_shorter_than_square_cards_at_wide_width(self):
        import re
        section = MAIN.split('private var networkInstruments:', 1)[1].split('private func receiveGauge', 1)[0]
        ratio = float(re.search(r'\.aspectRatio\(([0-9.]+), contentMode: \.fit\)', section).group(1))
        for width in (1060, 1440, 2532):
            self.assertLessEqual((width - 24) / 4, width / ratio, f'network cards overflow row at {width}')

    def test_square_gauge_has_tight_gauge_and_label_stack(self):
        self.assertIn('var square = false', GAUGE)
        self.assertIn('VStack(spacing: 0)', GAUGE)
        self.assertIn('.aspectRatio(1, contentMode: .fit)', GAUGE)


if __name__ == '__main__':
    unittest.main()
