from pathlib import Path
import unittest
root = Path(__file__).resolve().parents[1]
panel = (root/'Sources/macdir/ServerPanel.swift').read_text()
layout = (root/'Tests/render_layout.swift').read_text()

class NativeRevisionChecks(unittest.TestCase):
    def test_selected_interface_drives_network_chart(self):
        detail = panel.split('private struct ServerHostPanel:', 1)[1]
        chart = panel.split('private struct ServerNetworkActivity:', 1)[1].split('private struct ServerAddSheet:', 1)[0]
        self.assertIn('interface: selection', detail)
        self.assertIn('traffic(for: name, in: range, now: now)', chart)

    def test_both_charts_label_time_axis(self):
        load = panel.split('private struct ServerLoadActivity:', 1)[1].split('private struct ServerNetworkActivity:', 1)[0]
        network = panel.split('private struct ServerNetworkActivity:', 1)[1].split('private struct ServerAddSheet:', 1)[0]
        self.assertIn('ServerHistoryAxis(range: range, now: now)', load)
        self.assertIn('ServerHistoryAxis(range: range, now: now)', network)

    def test_native_probe_checks_scaled_dashboard_bounds(self):
        self.assertIn('layoutFrames["zoom-dashboard"]', layout)
        self.assertIn('zoom dashboard clipped', layout)
