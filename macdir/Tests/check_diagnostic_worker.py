"""Only tiny low-resource smoke: 1s budget, 1% duty, 1 MiB. No max-load run."""
import json, os, subprocess, sys, time
from pathlib import Path
worker = Path(sys.argv[1] if len(sys.argv)>1 else '.build/release/DiagnosticWorker').resolve()
assert worker.is_file(), 'isolated DiagnosticWorker is missing'
invalid = subprocess.run([str(worker), 'cpu', '999', '100', '999', str(os.getpid())], capture_output=True, timeout=3)
assert invalid.returncode != 0, 'invalid limits must fail closed'
for mode in ('cpu', 'ram', 'gpu'):
    start = time.monotonic()
    p = subprocess.run([str(worker), mode, '1', '1', '1', str(os.getpid())], capture_output=True, text=True, timeout=3)
    elapsed = time.monotonic()-start
    print(mode, 'wall_seconds=', round(elapsed, 3), 'exit=', p.returncode, p.stdout.strip(), p.stderr.strip())
    assert elapsed < 2.5
    if mode=='gpu' and p.returncode == 69:
        print('GPU unavailable; NOT a pass')
        continue
    assert p.returncode == 0, (mode, p.stdout, p.stderr)
    r=json.loads(p.stdout)
    assert r['errors']==0 and r['verified']>0 and r['batches']>0
    assert r['status']=='completed'
print('Tiny worker smoke PASS (not full stress acceptance)')
