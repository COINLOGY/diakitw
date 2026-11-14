"""Final read-only bundle checks; never GUI, root scan, network or stress."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'evidence/diakitw-0.5.3'
spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
source = (ROOT / 'Sources/macdir/main.swift').read_text()
assert source.index('if CommandLine.arguments.contains("--self-check") {') < source.index('CommandLine.arguments.contains("--server-snapshot")')
assert 'exit(runOfflineSelfCheck())' in source
rosetta = subprocess.run(['arch', '-x86_64', '/usr/bin/true'], capture_output=True, timeout=10).returncode == 0
records = json.loads((EVIDENCE / 'distribution-manifest.json').read_text())
assert {r['arch'] for r in records} == {'arm64', 'x86_64'} and len(records) == 2
for rec in records:
    dmg = Path(rec['dmg'])
    assert p.sha(dmg) == rec['sha256']
    with p.read_only_mount(dmg) as mount:
        app = mount / 'diakitw.app'
        p.run('codesign', '--verify', '--deep', '--strict', app)
        p.run('python3', ROOT / 'Tests/check_binary_privacy.py', app)
        for name in ('macdir', 'DiagnosticWorker', 'ServerAskpass'):
            binary = app / 'Contents/MacOS' / name
            metadata = p.run('xcrun', 'vtool', '-show-build', binary).decode()
            assert 'minos 14.0' in metadata, metadata
        runtime = 'SKIPPED: Intel runtime requires existing Rosetta; no installation attempted'
        if rec['arch'] == 'arm64' or rosetta:
            result = subprocess.run([str(app / 'Contents/MacOS/macdir'), '--self-check'], capture_output=True, text=True, timeout=10, check=True)
            assert 'SELF-CHECK PASS: ' + rec['arch'] in result.stdout
            runtime = result.stdout.strip()
            mixed = subprocess.run([str(app / 'Contents/MacOS/macdir'), '--self-check', '--server-snapshot'], capture_output=True, timeout=10)
            assert mixed.returncode == 64 and b'use --self-check alone' in mixed.stdout
            rejection = subprocess.run([str(app / 'Contents/MacOS/ServerAskpass'), 'Password:'], capture_output=True, timeout=3)
            assert rejection.returncode != 0 and not rejection.stdout
        rec.update(dmg=dmg.name, self_check=runtime, minimum_macos='14.0', binary_privacy_verified=True)
        print(rec['arch'], runtime)
with zipfile.ZipFile(ROOT / 'dist/diakitw-0.5.3-arm64/diakitw-0.5.3-macos-arm64.zip') as z:
    assert z.testzip() is None
result = {
    'commit': os.environ['GITHUB_SHA'],
    'run_url': 'https://github.com/' + os.environ['GITHUB_REPOSITORY'] + '/actions/runs/' + os.environ['GITHUB_RUN_ID'],
    'version': '0.5.3', 'build': '53', 'compiler_jobs': 2,
    'rosetta_available': rosetta, 'artifacts': records,
    'not_run': ['hardware stress/GPU worker', 'live external network/SSH/Keychain', 'installed GUI', 'physical Intel / oldest macOS runtime', 'Developer ID / notarization / Gatekeeper acceptance'],
    'release_published': False,
}
with (EVIDENCE / 'ci-manifest.json').open('x') as f:
    json.dump(result, f, indent=2)
    f.write('\n')
print(json.dumps(result, indent=2))
