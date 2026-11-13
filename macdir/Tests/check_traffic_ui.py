from pathlib import Path
p = Path(__file__).resolve().parents[1]
s = (p/'Sources/macdir/main.swift').read_text()
assert '@Published var trafficHistory = TrafficHistory()' in s
assert 'trafficHistory.select(selectedInterface)' in s
assert 'time: time, received: network?.received, sent: network?.sent' in s
assert 'sample.networkSampleTime' in s
assert 'ViewThatFits(in: .horizontal)' in s
assert 'TrafficChart(history: model.trafficHistory, range: $model.trafficRange)' in s
c = (p/'Sources/macdir/TrafficChart.swift').read_text()
assert 'Canvas' in c and 'Path' in c
assert 'trafficRange: TrafficRange = .minute' in s and 'TrafficRange.allCases' in c and 'range.tickLabels' in c
assert 'history.segments(in: range' in c and 'history.scale(in: range)' in c
assert '0.65, green: 0.90, blue: 0.25' in c and '0.30, green: 0.75, blue: 1.0' in c
assert 'opacity(0.18)' in c and 'opacity(0.12)' in c
assert 'Timer' not in c and 'ResourceSampler' not in c and 'TimelineView' not in c
print('Traffic UI source wiring passed (not a rendered UI test)')
