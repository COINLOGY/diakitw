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
s=s.replace('networkNumbers.fixedSize()', 'networkNumbers.fixedSize().layoutProbe("numbers")')
s=s.replace('     networkNumbers\n', '     networkNumbers.layoutProbe("numbers")\n')
s=s.replace('TrafficChart(history: model.trafficHistory, range: $model.trafficRange)', 'TrafficChart(history: model.trafficHistory, range: $model.trafficRange).layoutProbe("chart")')
s=s.replace('.pickerStyle(.segmented)\n', '.pickerStyle(.segmented).layoutProbe("viewPicker")\n')
s=s.replace('}.frame(minWidth: 450)', '}.frame(minWidth: 450).layoutProbe("table")')
s=s.replace('}.padding(.leading, 12).frame(minWidth: 290)', '}.padding(.leading, 12).frame(minWidth: 290).layoutProbe("map")')
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
subprocess.run(['swiftc','-swift-version','5','-o',str(out/'render-layout')]+files,check=True,cwd=p)
r=subprocess.run([str(out/'render-layout'),str(out)],cwd=p,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
(out/'results.txt').write_text(r.stdout); print(r.stdout)
sys.exit(r.returncode)
