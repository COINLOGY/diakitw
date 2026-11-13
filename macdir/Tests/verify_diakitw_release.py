"""Read-only final release verification. No GUI, network or stress workload."""
import hashlib, importlib.util, json, os, subprocess, zipfile
from pathlib import Path
r = Path(__file__).resolve().parents[1]
e = r/'evidence/diakitw-0.5.2'
os.environ['TMPDIR'] = str(Path.home()/'.cache/diakitw/scratch')
spec = importlib.util.spec_from_file_location('packager', r/'package-diagnostics-dmg.py')
p = importlib.util.module_from_spec(spec); spec.loader.exec_module(p)
sha = p.sha
before = json.loads((e/'previous-artifact-hashes.json').read_text())
assert all(sha(r/k) == v for k,v in before.items()), 'prior distribution changed'
print('Prior distributions unchanged:', len(before))
rosetta = subprocess.run(['arch','-x86_64','/usr/bin/true'], capture_output=True)
print('Rosetta probe:', rosetta.returncode, rosetta.stderr.decode().strip())
records = []
for rec in json.loads((e/'distribution-manifest.json').read_text()):
 assert sha(Path(rec['dmg'])) == rec['sha256']
 with p.read_only_mount(Path(rec['dmg'])) as mount:
  app = mount/'diakitw.app'
  p.run('codesign','--verify','--deep','--strict',app)
  p.run('codesign','-dv','--verbose=2',app)
  icon = app/'Contents/Resources/macdir.icns'
  assert sha(icon) == sha(r/'assets/macdir.icns')
  runtime = 'SKIPPED: Rosetta absent; no installation attempted'
  if rec['arch'] == 'arm64' or rosetta.returncode == 0:
   runtime = p.run(app/'Contents/MacOS/macdir','--self-check').decode().strip()
   assert 'SELF-CHECK PASS' in runtime
   mixed = subprocess.run([str(app/'Contents/MacOS/macdir'),'--self-check','--server-snapshot'],capture_output=True)
   assert mixed.returncode == 64 and b'use --self-check alone' in mixed.stdout
   print('Mixed-argument rejection PASS')
   rejection = subprocess.run([str(app/'Contents/MacOS/ServerAskpass'),'Password:'],capture_output=True)
   assert rejection.returncode != 0 and not rejection.stdout
   print('ASKPASS non-SSH-parent rejection PASS')
  records.append(dict(arch=rec['arch'],icon_sha256=sha(icon),self_check=runtime))
with zipfile.ZipFile(r/'dist/diakitw-0.5.2-arm64/diakitw-0.5.2-macos-arm64.zip') as z:
 assert z.testzip() is None
 print('arm64 supplemental ZIP CRC PASS')
result={'previous_files_unchanged':len(before),'selected_svg_sha256':sha(r.parent/'diakitw-brand/03-modular-w-icon.svg'),'icon_png_sha256':sha(r/'assets/diakitw-modular-w.iconset/icon_512x512@2x.png'),'rosetta_available':rosetta.returncode==0,'artifacts':records}
(e/'supplemental-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
