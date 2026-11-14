"""Offline auth checks. No network, user config or actual Keychain access.
Usage: python3 Tests/run_server_auth_checks.py /absolute/owned/scratch
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
scratch = Path(sys.argv[1]).resolve(strict=True)
subprocess.run(['swift', 'build', '--jobs', '2', '--build-system', 'native', '--product', 'ServerChecks'], cwd=project, check=True)
binpath = Path(subprocess.check_output(['swift', 'build', '--jobs', '2', '--build-system', 'native', '--show-bin-path'], cwd=project, text=True).strip())
objects = sorted((binpath / 'MacdirCore.build').glob('*.o'))
assert objects
with tempfile.TemporaryDirectory(prefix='ssh-auth-checks-', dir=scratch) as tmp:
    root = Path(tmp)
    for script in ['ssh_fake.sh', 'ssh_fake_askpass.sh']:
        shutil.copyfile(project / 'Tests/fixtures' / script, root / script)
        (root / script).chmod(0o700)
    for name in ['server_auth_checks', 'server_password_checks', 'server_edit_checks', 'server_process_checks']:
        binary = root / name
        subprocess.run(['swiftc', '-j', '2', '-I', str(binpath / 'Modules'), str(project / 'Tests' / (name + '.swift')), *map(str, objects), '-o', str(binary)], check=True)
        subprocess.run([str(binary), str(root)], check=True, timeout=15)
    helper = root / 'ServerAskpass'
    subprocess.run(['swiftc', '-j', '2', '-I', str(binpath / 'Modules'), str(project / 'Sources/ServerAskpass/main.swift'), *map(str, objects), '-o', str(helper)], check=True)
    result = subprocess.run([str(helper), "user@example.invalid's password: "], capture_output=True, timeout=3)
    assert result.returncode == 1 and not result.stdout and not result.stderr, 'helper refuses non-SSH parent silently before Keychain'
    print('PASS real helper rejects non-SSH parent without output/Keychain access')
subprocess.run([sys.executable, str(project / 'Tests/server_auth_ui_test.py')], check=True)
print('Offline server auth checks passed')
