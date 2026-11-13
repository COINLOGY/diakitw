"""Run management fixtures without touching user config or contacting servers.
Usage: python3 Tests/run_server_management_checks.py /absolute/owned/scratch
"""
from pathlib import Path
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2 or not Path(sys.argv[1]).is_absolute():
    raise SystemExit('Supply an absolute owned scratch directory (no symlink ancestors).')
scratch = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='server-config-build-', dir=scratch) as directory:
    binary = Path(directory) / 'checks'
    sources = [project / 'Sources/MacdirCore' / name for name in ['MetricPresentation.swift', 'ServerSampler.swift', 'ServerTelemetry.swift', 'ServerConfigStore.swift', 'ServerPassword.swift', 'ServerSSHProcess.swift']]
    subprocess.run(['swiftc', *map(str, sources), str(project / 'Tests/server_config_store_checks.swift'), '-o', str(binary)], check=True)
    subprocess.run([str(binary), str(scratch)], check=True)
subprocess.run([sys.executable, str(project / 'Tests/test_server_management_model.py'), str(scratch)], check=True)
subprocess.run([sys.executable, str(project / 'Tests/test_server_management_wiring.py')], check=True)
