"""Exercise actual Monitor logic with host-only UIKit/transport substitutes.
Only the UIKit import is removed in a scratch copy. No production source rewriting.
This is not evidence of iOS compilation, UIKit API availability or device behavior.
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='diakitw-monitor-', dir=os.environ['TMPDIR']) as temp:
    temp = Path(temp)
    source = (root / 'Sources/Monitor.swift').read_text()
    assert source.count('import UIKit\n') == 1
    monitor = temp / 'Monitor.swift'
    monitor.write_text(source.replace('import UIKit\n', ''))
    binary = temp / 'monitor-tests'
    subprocess.run(['swiftc', '-j', '2', '-swift-version', '5', str(monitor),
                    str(root / 'Sources/NetworkPolicy.swift'),
                    str(root / 'Tests/MonitorLifecycleHost.swift'), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=10)
