"""Rate-arrow source wiring; macOS CI also renders the dashboard fixture."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RateArrowOrder(unittest.TestCase):
    def test_main_and_server_rate_views_put_arrow_after_unit(self):
        view = (ROOT / "Sources/macdir/NetworkRateValue.swift").read_text()
        number = view.index("Text(formatted.displayNumber)")
        unit = view.index('Text(formatted.unit + "/с")')
        arrow = view.index("if !direction.isEmpty { Text(direction)")
        self.assertLess(number, unit)
        self.assertLess(unit, arrow)
        self.assertIn(".frame(width: size * 0.65)", view)
        for file in ("main.swift", "ServerPanel.swift"):
            self.assertIn('NetworkRateValue(value:', (ROOT / "Sources/macdir" / file).read_text())
    def test_network_gauge_and_menus_put_arrow_after_rate(self):
        main = (ROOT / "Sources/macdir/main.swift").read_text()
        tile = (ROOT / "Sources/macdir/NeedleGauge.swift").read_text()
        hud = (ROOT / "Sources/macdir/ResourceHUD.swift").read_text()
        self.assertIn('title: "СЕТЬ · " + selectedInterface', main)
        self.assertIn('NetworkRateValue(value: networkRate, direction: "↓", size: 16)', tile)
        self.assertIn('"RX · \\(interface): \\(rateDetail(n?.received)) ↓"', hud)
        self.assertIn('"TX · \\(interface): \\(rateDetail(n?.sent)) ↑"', hud)
        self.assertIn('Segment(text: rate(n?.received) + "↓"', (ROOT / "Sources/MacdirCore/StatusPresentation.swift").read_text())

    def test_diagnostic_summary_and_speed_test_put_arrow_after_unit(self):
        summary = (ROOT / "Sources/MacdirCore/Resources.swift").read_text()
        self.assertIn('B/s", $0) } ?? "Н/Д") ↓', summary)
        self.assertIn('B/s", $0) } ?? "Н/Д") ↑', summary)
        speed = (ROOT / "Sources/macdir/InternetTestWindow.swift").read_text()
        self.assertIn('Text(valid.map { String(format: "%.2f Mbps %@", $0, direction) } ?? "Н/Д " + direction)', speed)
        self.assertIn('InternetSpeedGauge(title: "Скачивание", direction: "↓"', speed)
        self.assertIn('InternetSpeedGauge(title: "Отдача", direction: "↑"', speed)


    def test_rendered_layout_fixture_uses_current_gauge_api(self):
        fixture = (ROOT / "Tests/render_layout.swift").read_text()
        self.assertIn('InternetSpeedGauge(title: "Fixture DL", direction: "↓", value:', fixture)
        self.assertIn('InternetSpeedGauge(title: "Fixture UL", direction: "↑", value:', fixture)

if __name__ == "__main__":
    unittest.main()
