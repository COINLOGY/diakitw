#!/usr/bin/env python3
"""Print only allowlisted failure metadata; never echo an Android probe report."""
from pathlib import Path
import re
import sys

try:
    report = Path(sys.argv[1]).read_text(errors='replace')[:65536]
except (OSError, IndexError):
    report = ''
classes = ('AssertionError', 'NullPointerException', 'IllegalStateException',
           'SecurityException', 'RuntimeException', 'IOException')
match = re.search(r'\bFAIL\s+([A-Za-z0-9.$]+)', report)
name = match.group(1).split('.')[-1] if match else ''
reason = ('java.lang.' + name) if name in classes and match and match.group(1).startswith('java.lang.') else 'reason unavailable'
frame = re.search(r'\bapp\.diakitw\.[A-Za-z0-9.$]+\(([A-Za-z0-9_]+\.java):([0-9]{1,5})\)', report)
location = f' at {frame.group(1)}:{frame.group(2)}' if frame else ''
bounds = re.search(r'Map hidden below initial viewport visible=([0-9]{1,6}) total=([0-9]{1,6})', report)
map_visibility = f'; map visible={bounds.group(1)}/{bounds.group(2)}' if bounds else ''
# Only fixed assertion messages from the checked-in offline probe can leave CI.
# Never print an arbitrary exception message: it may contain an external IP.
known = {
    'Visible entry label missing': 'entry-label',
    'Accessible entry omits visible IP/country': 'entry-accessibility',
    'Accessible click failed': 'entry-click',
    'Entry did not open IP directly': 'entry-dialog',
    'Entry opened speed help instead': 'wrong-dialog',
    'Missing IP map card': 'map-card',
    'Unknown IP copy enabled': 'copy-gate',
    'Country flag must precede its name': 'flag-order',
    'Known IP copy disabled': 'copy-known',
    'Fresh snapshot shown stale': 'fresh-stale',
}
code = next((label for message, label in known.items() if message in report), 'not-allowlisted')
print(f'FAIL native entry probe; {reason}{location}{map_visibility}; code={code}; raw report withheld')
