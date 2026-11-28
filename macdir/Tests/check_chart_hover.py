#!/usr/bin/env python3
"""Гейт: подсказка под курсором на всех графиках.

Нужны обе части: отслеживание курсора и отрисовка «время + значение».
Если оставить только отслеживание, пользователь не увидит цифру; если только
отрисовку — она никогда не включится.
"""
import pathlib

p = pathlib.Path(__file__).resolve().parent.parent
hover = (p / 'Sources/macdir/ChartHover.swift').read_text()
servers = (p / 'Sources/macdir/ServerPanel.swift').read_text()
mac = (p / 'Sources/macdir/TrafficChart.swift').read_text()

# --- общий механизм ---
assert 'func chartTimeLabel(_ epoch: Double) -> String' in hover, 'время замера в подсказке обязательно'
assert 'static let formatter: DateFormatter' in hover, 'форматтер должен быть один на приложение'
assert 'value.dateFormat = "HH:mm:ss"' in hover
assert 'func chartRateText(' in hover
assert 'func drawChartCursor(' in hover
assert 'func drawChartDot(' in hover
assert 'func drawChartTip(' in hover
assert 'context.resolve(Text(line)' in hover
assert 'measure(in: CGSize(width: 260, height: 40))' in hover, 'карточка должна знать свой размер'
assert 'min(max(2, originX), max(2, size.width - width - 2))' in hover, 'подсказка не должна вылезать за край'
assert 'NSTrackingArea(' in hover and '.mouseMoved' in hover
assert 'override func hitTest(_ point: NSPoint) -> NSView? { nil }' in hover, 'клик по графику должен проходить к карточке'
assert 'override func mouseExited' in hover
assert 'func chartHoverTracking(' in hover

# --- панель «Серверы»: CPU и сеть, в том числе в компактных карточках парка ---
assert servers.count('@State private var hoverX: CGFloat?') == 2, 'нужны оба графика серверов'
assert servers.count('.chartHoverTracking($hoverX)') == 2
assert servers.count('chartTimeLabel(nearest.sampledAt)') == 2, 'время замера на обоих графиках'
assert '"CPU " + MetricPresentation.percent(nearest.percent)' in servers
assert 'chartRateText(nearest.received) + " ↓' in servers, 'единица перед стрелкой, как в остальном интерфейсе'
assert servers.count('drawChartDot(') >= 3, 'точка на приёме и на отдаче'
assert 'let measured = readings.compactMap { $0 }.filter { $0.percent != nil }' in servers
assert 'let measured = readings.compactMap { $0 }.filter { $0.hasMeasurement }' in servers

# --- панель «Этот Mac»: сетевой график ---
assert mac.count('.chartHoverTracking($hoverX)') == 1
assert 'chartTimeLabel(nearest.time)' in mac
assert 'chartRateText(nearest.received) + " ↓' in mac
assert 'drawChartDot(context, x: x, y: baseline' in mac

print('Подсказка под курсором: время и значение на графиках обеих панелей проверены')
