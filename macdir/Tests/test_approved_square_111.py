"""Approved Mac dashboard: CPU, RAM, SWAP, disk in one uniform compact row.

Обновлено по просьбе владельца (27.11.2026): карточки больше не квадратные —
квадрат при четырёх в ряд давал ~340 px и прятал обзор диска под сгибом.
Теперь у карточек ресурсов и у сети одна и та же компактная высота, содержимое
прижато к верху без пустоты между прибором и подписью.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()
GAUGE = (ROOT / 'Sources/macdir/NeedleGauge.swift').read_text()

ROW_HEIGHT = '158'


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

    def test_resource_row_has_fixed_compact_height(self):
        resources = MAIN.split('private func compactResources(', 1)[1].split('private var compactNetwork:', 1)[0]
        self.assertIn('.frame(height: ' + ROW_HEIGHT + ')', resources)

    def test_network_row_matches_resource_height(self):
        section = MAIN.split('private var networkInstruments:', 1)[1].split('private func receiveGauge', 1)[0]
        # Никакого aspectRatio: высота ряда задана явно и совпадает с карточками.
        self.assertIsNone(re.search(r'\.aspectRatio\([0-9.]+, contentMode: \.fit\)', section))
        # График и общий HStack несут фиксированную высоту ряда.
        self.assertEqual(section.count('.frame(height: ' + ROW_HEIGHT + ')'), 2)

    def test_square_gauge_fills_the_given_frame(self):
        self.assertIn('var square = false', GAUGE)
        self.assertIn('VStack(spacing: 0)', GAUGE)
        # Квадрат по aspectRatio убран: карточка заполняет выданную высоту.
        self.assertNotIn('.aspectRatio(1, contentMode: .fit)', GAUGE)
        # Без GeometryReader внутри карточки: он схлопывается до 10×10.
        square = GAUGE.split('if square {', 1)[1].split('} else {\n    HStack(spacing: 4)', 1)[0]
        self.assertNotIn('GeometryReader', square)
        self.assertIn('dial.frame(maxWidth: 220).frame(height: 88)', square)
        self.assertIn('.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)', square)


if __name__ == '__main__':
    unittest.main()
