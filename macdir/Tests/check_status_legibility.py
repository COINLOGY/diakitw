"""Menu typography contract; AppKit render fixture verifies actual metrics."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
helper = root / 'Sources/macdir/StatusTypography.swift'
source = helper.read_text() if helper.exists() else (root / 'Sources/macdir/ResourceHUD.swift').read_text()
sizes = [float(x) for x in re.findall(r'monospaced(?:Digit)?SystemFont\(ofSize: ([\d.]+)', source)]
assert any(13 <= size <= 14 for size in sizes), f'numeric menu font must be 13–14pt, got {sizes}'
print('PASS: larger fixed menu numeric typography contract')
