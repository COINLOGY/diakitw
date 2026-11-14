"""Offline provenance check against the previously fetched official Electron SHASUMS."""
import pathlib,hashlib,json,zipfile,struct
root=pathlib.Path(__file__).resolve().parents[1]
def digest(b):return hashlib.sha256(b).hexdigest()
checksums=root/'evidence/SHASUMS256-upstream.txt'
expected={line.split()[1].lstrip('*'):line.split()[0] for line in checksums.read_text().splitlines() if len(line.split())==2}
def text_section(b):
 pe=struct.unpack_from('<I',b,60)[0];count=struct.unpack_from('<H',b,pe+6)[0];optional=struct.unpack_from('<H',b,pe+20)[0];start=pe+24+optional
 for i in range(count):
  section=start+i*40
  if b[section:section+8].rstrip(b'\0')==b'.text':
   size,offset=struct.unpack_from('<II',b,section+16);return b[offset:offset+size]
 raise AssertionError('No executable text section')
report=[]
for platform in ['win32','linux']:
 name=f'electron-v45.2.3-{platform}-x64.zip';candidates=list((root/'.electron-cache').rglob(name));assert len(candidates)==1
 p=candidates[0];sha=digest(p.read_bytes());assert sha==expected[name]
 bundle=root/f'bundles-v055a/diakitw-{platform}-x64';checked=[]
 with zipfile.ZipFile(p) as z:
  assert z.testzip() is None
  for info in z.infolist():
   if info.is_dir() or info.filename in ['resources/default_app.asar','version']:continue
   rel=info.filename;target='diakitw.exe' if rel=='electron.exe' else 'diakitw' if rel=='electron' else rel
   f=bundle/target;assert f.is_file(),rel
   upstream=z.read(info);local=f.read_bytes()
   if rel=='electron.exe':assert text_section(local)==text_section(upstream);kind='PE .text byte parity (resources changed by Packager)'
   else:assert local==upstream,rel;kind='exact byte parity'
   checked.append({'file':target,'verification':kind,'sha256':digest(local)})
 report.append({'platform':platform,'officialRuntimeZip':name,'sha256':sha,'matchesOfficialSHASUMS':True,'bundleRuntime':checked})
result={'source':'https://github.com/electron/electron/releases/download/v45.2.3/SHASUMS256.txt','sourceMode':'Previously fetched official checksum file, rechecked offline; no geolocation network request','checksumsFileSHA256':digest(checksums.read_bytes()),'artifacts':report}
(root/'evidence/v055a/upstream-verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({r['platform']:{'sha256':r['sha256'],'runtimeFilesVerified':len(r['bundleRuntime'])} for r in report},indent=2))
