"""Fault-injection proof: same actual SwiftUI raster test rejects 40/20 sweep.
Only a temporary source copy is changed; production source is never mutated.
"""
from pathlib import Path
import os, subprocess, tempfile
r = Path(__file__).resolve().parents[1]
e = r/'evidence/diakitw-0.5.4'
with tempfile.TemporaryDirectory(prefix='gauge-regression-', dir=os.environ['TMPDIR']) as tmp:
    tmp = Path(tmp)
    source = (r/'Sources/macdir/NeedleGauge.swift').read_text()
    assert 'let f = Double(i) / 40' in source
    fault = tmp/'NeedleGauge.swift'
    fault.write_text(source.replace('let f = Double(i) / 40', 'let f = Double(i) / 20').replace('import MacdirCore\n',''))
    copies = []
    for name in ['Sources/macdir/NetworkRateValue.swift', 'Tests/render_gauge_geometry.swift']:
        copy = tmp/Path(name).name
        copy.write_text((r/name).read_text().replace('import MacdirCore\n',''))
        copies.append(str(copy))
    binary = tmp/'fault-check'
    core = ['Sources/MacdirCore/' + n + '.swift' for n in ['GaugeScale','NetworkPresentation','MetricPresentation']]
    subprocess.run(['swiftc', '-j', '2','-parse-as-library',str(fault),*copies,*core,'-o',str(binary)],cwd=r,check=True,timeout=45)
    run = subprocess.run([str(binary),str(e/'gauge-fault-injected')],cwd=r,capture_output=True,text=True)
    (e/'gauge-fault-injected.log').write_text(run.stdout+run.stderr)
    assert run.returncode == 1 and 'FAIL lower semicircle' in run.stdout
    print('PASS: current raster assertions reject injected original full-circle defect')
