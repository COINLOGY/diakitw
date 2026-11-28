"""Linux source-contract gate; native SwiftUI rendering is a separate macOS gate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'Sources/macdir'
MAIN = (ROOT / 'main.swift').read_text()
PANEL = (ROOT / 'ServerPanel.swift').read_text()

class NextMacFleetUI(unittest.TestCase):
    def test_compact_dashboard_has_no_battery_tile(self):
        dashboard = MAIN.split('private func compactResources(', 1)[1].split('private var compactNetwork:', 1)[0]
        self.assertNotIn('battery', dashboard.lower())
        self.assertNotIn('БАТАРЕЯ', dashboard)
        self.assertEqual(dashboard.count('GaugeTile('), 3)
        self.assertIn('ПРОЦЕССОР', dashboard)
        self.assertIn('SWAP', dashboard)

    def test_root_tree_and_fleet_rows_have_real_fresh_metrics(self):
        self.assertIn('selectedServerID', PANEL)
        self.assertIn('Все серверы', PANEL)
        self.assertIn('DisclosureGroup', PANEL)
        self.assertIn('ServerFleetRow(', PANEL)
        self.assertIn('ServerHostPanel(config: config', PANEL)
        self.assertIn('state.current(now: now)', PANEL)
        self.assertIn('measuredPercent(sample?.memoryUsed, sample?.memoryTotal)', PANEL)
        self.assertIn('measuredPercent(sample?.swapUsed, sample?.swapTotal)', PANEL)
        self.assertIn('measuredPercent(sample?.diskUsed, sample?.diskTotal)', PANEL)
        self.assertIn('Нет свежих данных', PANEL)
        self.assertNotIn('plot()', PANEL)

    def test_editor_separates_endpoint_and_preserves_ssh_safety(self):
        self.assertIn('IP-адрес или домен SSH', PANEL)
        self.assertIn('SSH-порт (1–65535)', PANEL)
        self.assertIn('Логин SSH', PANEL)
        self.assertIn('draftUser', PANEL)
        self.assertIn('draftHost', PANEL)
        self.assertIn('SecureField(', PANEL)
        self.assertIn('ServerPasswordStore.save', PANEL)
        self.assertIn('known_hosts', PANEL)
        self.assertIn('автоматически не принимаются', PANEL)

if __name__ == '__main__': unittest.main()
