"""Fail closed on user-home build paths in distributable Mach-O copies."""
from pathlib import Path
import sys
app=Path(sys.argv[1])
for name in ['macdir','DiagnosticWorker','ServerAskpass']:
 data=(app/'Contents/MacOS'/name).read_bytes()
 assert b'/Users/' not in data, f'{name}: user-home path leaked'
 assert b'/home/' not in data, f'{name}: Linux build-home path leaked'
print('PASS privacy: three release executables have no user-home paths')
