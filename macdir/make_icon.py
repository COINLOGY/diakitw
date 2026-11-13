"""Generate only the approved Modular W logo; no previous-logo fallback."""
from pathlib import Path
import subprocess
r = Path(__file__).resolve().parent
source = r.parent / 'diakitw-brand/03-modular-w-icon.svg'
iconset = r / 'assets/diakitw-modular-w.iconset'
subprocess.run(['swift', str(r/'Tools/render_icon.swift'), str(source), str(iconset)], check=True)
subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(r/'assets/macdir.icns')], check=True)
print('Approved Modular W -> assets/macdir.icns (legacy resource name retained)')
