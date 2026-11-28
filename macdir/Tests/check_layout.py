"""Rendered first-page regression. Test-only copy disables Model startup completely.
No app launch, scan, sampler, cache audit, SSH or external-address request.
AppKit hosting is used because ImageRenderer cannot render native Table/Picker.
"""
from pathlib import Path
import subprocess, sys, os
p = Path(__file__).resolve().parents[1]
out = p / 'evidence' / ('layout-' + (sys.argv[1] if len(sys.argv)>1 else 'after'))
out.mkdir(parents=True, exist_ok=True)
scratch = Path(os.environ['TMPDIR']) / ('macdir-layout-' + out.name)
scratch.mkdir(parents=True, exist_ok=True)
s = (p/'Sources/macdir/main.swift').read_text()
a=s.index(' init() {'); b=s.index('\n deinit',a)
s=s[:a]+' init() {}\n'+s[b:]
a=s.index(' func identityChanged() {'); b=s.index(' @Published var result:', a)
s=s[:a]+' func identityChanged() {}\n'+s[b:]
s=s[:s.index('if CommandLine.arguments.contains("--self-check")')]
# Tag the seven real action buttons on a test-only SwiftUI source copy.
for index, (old, new) in enumerate([
 ('Button("Тест интернета") { InternetTestWindow.shared.show() }', 'Button("Тест интернета") { InternetTestWindow.shared.show() }.layoutProbe("toolbar-0")'),
 ('Button("Диагностика") { DiagnosticsWindow.shared.show() }', 'Button("Диагностика") { DiagnosticsWindow.shared.show() }.layoutProbe("toolbar-1")'),
 ('Button("Терминал") { DesktopActions.shared.terminal() }', 'Button("Терминал") { DesktopActions.shared.terminal() }.layoutProbe("toolbar-2")'),
 ('Button("Мониторинг системы") { DesktopActions.shared.processes() }', 'Button("Мониторинг системы") { DesktopActions.shared.processes() }.layoutProbe("toolbar-3")'),
 ('Button("Проверить кэши") { model.showCaches = true; model.caches.audit() }', 'Button("Проверить кэши") { model.showCaches = true; model.caches.audit() }.layoutProbe("toolbar-4")'),
 ('Button("Корень /") { model.scan(URL(fileURLWithPath: "/")) }', 'Button("Корень /") { model.scan(URL(fileURLWithPath: "/")) }.layoutProbe("toolbar-5")'),
 ('.keyboardShortcut("o")', '.keyboardShortcut("o").layoutProbe("toolbar-6")'),
]):
    assert s.count(old) >= 1, f'missing action probe {index}'
    s=s.replace(old, new, 1)
s=s.replace('networkSelector; networkInstruments', 'networkSelector.layoutProbe("network-selector"); networkInstruments')
s=s.replace('receiveGauge(scale: scale, labels: labels)', 'receiveGauge(scale: scale, labels: labels).layoutProbe("network-rx")')
s=s.replace('sendGauge(scale: scale, labels: labels)', 'sendGauge(scale: scale, labels: labels).layoutProbe("network-tx")')
s=s.replace('TrafficChart(history: model.trafficHistory, range: $model.trafficRange, expanded: true)', 'TrafficChart(history: model.trafficHistory, range: $model.trafficRange, expanded: true).layoutProbe("chart")')
assert s.count('     diskGauge\n') == 1
s=s.replace('     diskGauge\n', '     diskGauge.layoutProbe("disk-gauge")\n', 1)
for title, label in [('ПРОЦЕССОР', 'resource-cpu'), ('ПАМЯТЬ', 'resource-memory'), ('SWAP', 'resource-swap')]:
    lines=s.splitlines(keepends=True)
    matches=[i for i, line in enumerate(lines) if 'GaugeTile(' in line and 'title: "'+title+'"' in line]
    assert len(matches)==1, (title, matches)
    i=matches[0]; lines[i]=lines[i].rstrip('\n')+'.layoutProbe("'+label+'")\n'
    s=''.join(lines)
s=s.replace('.pickerStyle(.segmented)\n', '.pickerStyle(.segmented).layoutProbe("viewPicker")\n')
s=s.replace('}.frame(minWidth: 450)', '}.frame(minWidth: 450).layoutProbe("table")')
s=s.replace('}.padding(.leading, 12).frame(minWidth: 290)', '}.padding(.leading, 12).frame(minWidth: 290).layoutProbe("map")')
# Probe only the unshipped copy; preserve production padding and proposals.
for old, new in [
    ('    .frame(height: 158)\n   }\n  }\n private var compactNetwork:', '    .frame(height: 158).layoutProbe("gaugeRow")\n   }\n  }\n private var compactNetwork:'),
    ('  }.padding(14).frame(maxWidth: .infinity)', '  }.layoutProbe("dashboardContent").padding(14).frame(maxWidth: .infinity).layoutProbe("dashboardDocument")'),
]:
    assert s.count(old) == 1, 'layout probe anchor changed: ' + old
    s = s.replace(old, new)
s += (p/'Tests/render_layout.swift').read_text()
files=[]
for f in list((p/'Sources/MacdirCore').glob('*.swift'))+list((p/'Sources/macdir').glob('*.swift')):
    text=s if f.name=='main.swift' else f.read_text()
    if f.name=='ServerPanel.swift':
        text=text.replace('if servers.section == 0 { ContentView(model: model) }',
                          'if servers.section == 0 { ContentView(model: model).layoutProbe("zoom-dashboard") }')
        zoom_anchor = '    }\n    .frame(width: geometry.size.width / CGFloat(zoom), height: geometry.size.height / CGFloat(zoom), alignment: .top)'
        assert text.count(zoom_anchor) == 1, 'zoom probe anchor changed: ' + zoom_anchor
        text=text.replace(zoom_anchor,
                          '     Color.clear.frame(width: 100, height: 1).layoutProbe("zoom-marker")\n' + zoom_anchor)
        text=text.replace('.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 12).padding(.vertical, 5)',
                          '.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 12).padding(.vertical, 5).layoutProbe("zoom-toolbar")')
        text=text.replace('private struct ServerHostPanel:', 'struct ServerHostPanel:').replace('private func measuredPercent(', 'func measuredPercent(').replace('private func measuredPair(', 'func measuredPair(')
        text=text.replace('private struct ServerFleetRow:', 'struct ServerFleetRow:')
        lines=text.splitlines(keepends=True)
        for label, token in [('cpu','fleetGauge("CPU"'),('ram','fleetGauge("RAM"'),('swap','fleetGauge("SWAP"'),('disk','fleetGauge("Диск /"')]:
            matches=[i for i,line in enumerate(lines) if token in line]
            assert len(matches)==1,(label,matches)
            i=matches[0];lines[i]=lines[i].rstrip('\n')+'.layoutProbe("fleet-" + config.id + "-'+label+'")\n'
        text=''.join(lines)
        for chart in ['load', 'network']:
            if chart == 'load':
                token = 'ServerLoadActivity(state: state, sample: sample, now: now, range: range, compact: true)\n'
                expected = 1
            else:
                token = 'ServerNetworkActivity(state: state, sample: sample, now: now, range: range, compact: true)\n'
                expected = 1
            assert text.count(token) == expected, token
            text=text.replace(token, token.rstrip('\n')+'.layoutProbe("fleet-" + config.id + "-'+chart+'")\n', 1)
        text=text.replace('}.frame(height: 111)\n', '}.frame(height: 111).layoutProbe("fleet-" + config.id + "-row")\n', 1)
    if f.name=='NeedleGauge.swift':
        text=text.replace('.help(explanation ?? detail)', '.help(explanation ?? detail).layoutProbe("gauge-" + title)')
    text=text.replace('import MacdirCore\n','').replace('MacdirCore.Scanner','Scanner')
    dest=scratch/f.name; dest.write_text(text); files.append(str(dest))
subprocess.run(['swiftc', '-j', '2','-swift-version','5','-o',str(out/'render-layout')]+files,check=True,cwd=p)
# Launch arguments populate the volatile NSArgumentDomain; no persistent/global
# defaults writes. A fresh process establishes each style before the first proposal.
results = []
failed = False
for style, preference in [('system', None), ('overlay', 'WhenScrolling'), ('legacy', 'Always')]:
    command = [str(out/'render-layout'), str(out), style]
    if preference is not None:
        command += ['-AppleShowScrollBars', preference]
    r = subprocess.run(command, cwd=p, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    results.append(r.stdout)
    (out/'results.txt').write_text(''.join(results))
    print(r.stdout)
    failed |= r.returncode != 0
sys.exit(1 if failed else 0)
