"""Read every archived byte; no extraction or target execution."""
import pathlib, hashlib, json, tarfile, zipfile
root=pathlib.Path(__file__).resolve().parents[1]
def sha(stream):
 h=hashlib.sha256()
 for block in iter(lambda:stream.read(1048576),b''): h.update(block)
 return h.hexdigest()
def filehash(p):
 with p.open('rb') as f:return sha(f)
checks=[]
for a in json.loads((root/'dist/release-manifest-0.5.5.json').read_text())['artifacts']:
 p=root/'dist'/a['file']; assert filehash(p)==a['sha256']
 folder=root/'bundles-v055a'/('diakitw-'+a['platform']+'-x64')
 expected={str(x.relative_to(folder)):x for x in folder.rglob('*') if x.is_file()}
 seen=set()
 if p.suffix=='.zip':
  with zipfile.ZipFile(p) as z:
   assert z.testzip() is None
   for info in z.infolist():
    rel=str(pathlib.PurePosixPath(info.filename).relative_to(p.stem));assert rel in expected and rel not in seen
    with z.open(info) as f:assert sha(f)==filehash(expected[rel]),rel
    seen.add(rel)
 else:
  with tarfile.open(p,'r:gz') as t:
   for m in t:
    assert not m.issym() and not m.islnk() and not m.mode&0o6000
    assert m.uid==0 and m.gid==0 and m.uname=='' and m.gname=='', 'No build-host ownership metadata'
    assert '..' not in pathlib.PurePosixPath(m.name).parts and not m.name.startswith('/')
    if not m.isfile():assert m.isdir();continue
    rel=str(pathlib.PurePosixPath(m.name).relative_to(p.name[:-7]));assert rel in expected and rel not in seen
    with t.extractfile(m) as f:assert sha(f)==filehash(expected[rel]),rel
    assert m.mode&0o777==expected[rel].stat().st_mode&0o777
    seen.add(rel)
 assert seen==set(expected)
 checks.append({'archive':str(p),'sha256':a['sha256'],'every_file_matches_bundle':True,'files':len(seen)})
expected={line.split()[1].lstrip('*'):line.split()[0] for line in (root/'evidence/SHASUMS256-upstream.txt').read_text().splitlines() if len(line.split())==2}
cached=[]
for p in (root/'.electron-cache').rglob('electron-v45.2.3-*.zip'):
 assert filehash(p)==expected[p.name];cached.append(p.name)
assert {'electron-v45.2.3-win32-x64.zip','electron-v45.2.3-linux-x64.zip'}<=set(cached)
report={'artifacts':checks,'old_release_hashes':'checked separately on delivery host','cached_upstream_verified':cached,'target_runtime_tested':False}
(root/'evidence/v055a/archive-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
