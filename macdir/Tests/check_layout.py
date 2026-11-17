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
s=s.replace('TrafficChart(history: model.trafficHistory, range: $model.trafficRange)', 'TrafficChart(history: model.trafficHistory, range: $model.trafficRange).layoutProbe("chart")')
s=s.replace('diskGauge.frame(width: 240)', 'diskGauge.layoutProbe("disk-gauge").frame(width: 240)')
s=s.replace('VStack(spacing: 8) { diskGauge;', 'VStack(spacing: 8) { diskGauge.layoutProbe("disk-gauge");')
s=s.replace('DiskCapacityOverview(snapshot: model.snapshot, scan: model.result)', 'DiskCapacityOverview(snapshot: model.snapshot, scan: model.result).layoutProbe("disk-overview")')
for title, label in [('ПРОЦЕССОР', 'resource-cpu'), ('ПАМЯТЬ', 'resource-memory'), ('SWAP', 'resource-swap'), ('БАТАРЕЯ · ЗАРЯД', 'resource-battery')]:
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
    ('   }\n  }\n }\n private var compactNetwork:', '   }.layoutProbe("gaugeRow")\n  }\n }\n private var compactNetwork:'),
    ('  }.padding(14).frame(maxWidth: .infinity)', '  }.layoutProbe("dashboardContent").padding(14).frame(maxWidth: .infinity).layoutProbe("dashboardDocument")'),
]:
    assert s.count(old) == 1, 'layout probe anchor changed: ' + old
    s = s.replace(old, new)
s += (p/'Tests/render_layout.swift').read_text()
files=[]
for f in list((p/'Sources/MacdirCore').glob('*.swift'))+list((p/'Sources/macdir').glob('*.swift')):
    text=s if f.name=='main.swift' else f.read_text()
    if f.name=='ServerPanel.swift':
        text=text.replace('private struct ServerHostPanel:', 'struct ServerHostPanel:').replace('private func measuredPercent(', 'func measuredPercent(').replace('private func measuredPair(', 'func measuredPair(')
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
