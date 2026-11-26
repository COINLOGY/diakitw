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
        self.assertIn('NeedleGauge(fraction: fraction, neutral: direction != nil, tickLabels: [],', row)
        self.assertIn('directionColor: direction ?? InstrumentTheme.lime, gutter: 8, needleBase: 8)', row)
        # Compact cards must shrink the label gutter, otherwise `height - 44`
        # collapses the radius and the needle is not drawn at all.
        face = (root / 'Sources/macdir/NeedleGauge.swift').read_text()
        self.assertIn('var gutter: Double = 44', face)
        self.assertIn('var needleBase: Double = 16', face)
        for label in ('CPU', 'RAM', 'SWAP', 'Диск /', 'Приём ↓', 'Отдача ↑'):
            self.assertIn(f'fleetGauge("{label}"', row)
        self.assertIn('shortRate(', row)
        self.assertIn('compact: true', row)
        self.assertIn('detail: coreCount(cores)', row)
        # Ядра и полные объёмы приходят суточным замером: строка списка обязана
        # брать их из кэша характеристик, иначе на приборах «ядер: Н/Д».
        self.assertIn('let hardware: ServerTelemetry?', row)
        self.assertIn('hardware: model.hardwareCache.snapshot(config)', view)
        self.assertIn('let cores = sample?.cpuCount ?? hardware?.cpuCount', row)
        self.assertIn('let memoryTotal = sample?.memoryTotal ?? hardware?.memoryTotal', row)
        self.assertIn('let diskTotal = sample?.diskTotal ?? hardware?.diskTotal', row)
        # Пик трафика печатается по своему направлению, а не общий.
        self.assertIn('shortRate(rxPeaks.max())', row)
        self.assertIn('shortRate(txPeaks.max())', row)
        self.assertIn('detail: gibPair(', row)
        self.assertIn('drawChartGrid(context, size: size)', view)
        # The two charts start after the six dials, shifted right by a spacer.
        self.assertIn('Spacer(minLength: 14)', row)
        self.assertLess(row.index('Отдача ↑'), row.index('Spacer(minLength: 14)'))
        self.assertLess(row.index('Spacer(minLength: 14)'), row.index('ServerLoadActivity('))
        # Trend lines are smoothed curves through the real samples, not a polyline.
        self.assertIn('func smoothPath', view)
        # Монотонная кубика без перехлёста: кривая не выходит за соседние точки.
        self.assertIn('path.addCurve(to: CGPoint(x: points[index + 1].x, y: clamp(points[index + 1].y)),', view)
        self.assertIn('tangent[index] = slope[index - 1] * slope[index] <= 0 ? 0', view)
        self.assertIn('dropToZero', view)
        # Сплошная линия от нуля: до первого замера и после последнего участок
        # идёт по базовой линии, пустых мест на графике нет.
        # Края держат крайние замеры: слева первое значение, справа последнее.
        self.assertIn('pts.insert(CGPoint(x: 0, y: firstSampleY), at: 0)', view)
        self.assertIn('pts.append(CGPoint(x: Double(size.width), y: lastSampleY))', view)
        # Пропуск заполняется половиной последнего максимума (среднее между
        # нулём и пиком), а не нулём и не разрывом.
        self.assertIn('(1 - (peak / 2) / 100)', view)
        self.assertIn('min(1, (seriesPeak / 2) / scale)', view)
        self.assertNotIn('path.addLine(to: position)', view)
        self.assertIn('ServerNetworkActivity(', row)
        self.assertIn('.frame(maxWidth: .infinity)', row)

    def test_chart_uses_real_bounded_traffic_samples_and_hides_stale(self):
        self.assertIn('trafficHistory', core)
        self.assertIn('Array(trafficHistory.suffix(121))', core)
        self.assertIn('trafficHistory.append(nil)', core)
        self.assertIn('$0?.hasMeasurement == true', row)
        self.assertIn('point.follows(previous)', row)
        self.assertIn('sample.sampledAt', core)
        self.assertIn('state.current(now: now)', row)
        self.assertIn('Нет свежих данных сети', row)
        self.assertIn('Canvas {', row)
        self.assertIn('context.fill(Path(ellipseIn:', row)

    def test_load_history_uses_timestamps_and_period_not_poll_indices(self):
        self.assertIn("public enum ServerHistoryRange:", core)
        self.assertIn("public struct ServerLoadPoint", core)
        self.assertIn("sampledAt: sampledAt, percent: sample.cpuPercent", core)
        self.assertIn("public func load(in range: ServerHistoryRange, now: Double)", core)
        self.assertIn("public func traffic(in range: ServerHistoryRange, now: Double)", core)

    def test_fleet_and_detail_show_load_before_network_with_visible_period(self):
        fleet = row.split("private struct ServerFleetRow:", 1)[-1].split("private struct ServerNetworkActivity:", 1)[0]
        self.assertIn("ServerLoadActivity(", fleet)
        self.assertLess(fleet.index("ServerLoadActivity("), fleet.index("ServerNetworkActivity("))
        self.assertIn("Период истории", view)
        self.assertIn("ForEach(ServerHistoryRange.allCases", view)
        detail = view.split("private struct ServerHostPanel:", 1)[1]
        self.assertLess(detail.index("ServerLoadActivity("), detail.index("ServerNetworkActivity("))
        self.assertIn("История нагрузки", view)

    def test_native_geometry_checks_both_server_rows(self):
        renderer = (root / 'Tests/render_layout.swift').read_text()
        instrument = (root / 'Tests/check_layout.py').read_text()
        self.assertIn('for server in servers.configs {', renderer)
        self.assertIn('fleet-" + config.id + "-', instrument)
        self.assertIn('prefix + "load"', renderer)
        self.assertIn("for chart in ['load', 'network']:", instrument)

if __name__ == '__main__':
    unittest.main()
