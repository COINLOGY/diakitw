"""Server-list layout contract; native geometry is checked on macOS CI."""
from pathlib import Path
import unittest
root = Path(__file__).resolve().parents[1]
view = (root / 'Sources/macdir/ServerPanel.swift').read_text()
core = (root / 'Sources/MacdirCore/ServerTelemetry.swift').read_text()
row = view.split('private struct ServerFleetRow:', 1)[1].split('private struct ServerAddSheet:', 1)[0]

class FleetCompactLayout(unittest.TestCase):
    def test_four_square_mini_gauges_fill_row_before_network(self):
        self.assertIn('GeometryReader { geometry in', row)
        self.assertIn('let side = min(', row)
        self.assertIn('.frame(width: side, height: side)', row)
        self.assertIn('NeedleGauge(fraction: fraction)', row)
        for label in ('CPU', 'RAM', 'SWAP', 'Диск /'):
            self.assertIn(f'fleetGauge("{label}"', row)
        self.assertIn('ServerNetworkActivity(', row)
        self.assertIn('.frame(maxWidth: .infinity)', row)

    def test_chart_uses_real_bounded_traffic_samples_and_hides_stale(self):
        self.assertIn('trafficHistory', core)
        self.assertIn('Array(trafficHistory.suffix(60))', core)
        self.assertIn('trafficHistory.append(nil)', core)
        self.assertIn('$0?.hasMeasurement == true', row)
        self.assertIn('point.follows(previous)', row)
        self.assertIn('sample.sampledAt', core)
        self.assertIn('state.current(now: now)', row)
        self.assertIn('Нет свежих данных сети', row)
        self.assertIn('Canvas {', row)
        self.assertIn('context.fill(Path(ellipseIn:', row)

    def test_native_geometry_checks_both_server_rows(self):
        renderer = (root / 'Tests/render_layout.swift').read_text()
        instrument = (root / 'Tests/check_layout.py').read_text()
        self.assertIn('for server in servers.configs {', renderer)
        self.assertIn('fleet-" + config.id + "-', instrument)

if __name__ == '__main__':
    unittest.main()
