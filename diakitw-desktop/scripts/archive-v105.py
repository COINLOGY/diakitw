import pathlib,tarfile,zipfile,hashlib,json,shutil,stat,struct
root=pathlib.Path(__file__).resolve().parents[1]
(root/'dist').mkdir(exist_ok=True)
(root/'evidence/v105').mkdir(parents=True,exist_ok=True)
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def portable_metadata(member):
 member.uid=member.gid=0
 member.uname=member.gname=''
 member.pax_headers={}
 return member
results=[]
for name in ['diakitw-1.0.5-windows-x64.zip','diakitw-1.0.5-linux-x64.tar.gz','release-manifest-1.0.5.json','SHA256SUMS-1.0.5.txt']:
 if (root/'dist'/name).exists():raise RuntimeError('Refusing overwrite '+name)
for platform,ext in [('win32','zip'),('linux','tar.gz')]:
 folder=root/'bundles-v105'/('diakitw-'+platform+'-x64')
 # Portable candidate: no previous-release documentation is copied.
 title='diakitw-1.0.5-'+('windows' if platform=='win32' else 'linux')+'-x64'
 dest=root/'dist'/(title+'.'+ext)
 if dest.exists():raise RuntimeError('Refusing overwrite '+str(dest))
 notice=folder/'README-CANDIDATE.txt'
 if notice.exists():raise RuntimeError('Refusing overwrite '+str(notice))
 if platform=='win32':
  notice.write_text('diakitw 1.0.5 · предварительная сборка Windows x64.\nEXE неподписан (нет доверенной Authenticode-подписи); SmartScreen может заблокировать запуск. Не считать стабильным выпуском и не распространять массово. Сверяйте SHA-256 архива с evidence этого запуска GitHub Actions.\n',encoding='utf-8')
 else:
  notice.write_text('diakitw 1.0.5 · предварительная переносимая сборка Linux x64.\nЭто не подписанный пакет и не автоустановщик. Сверяйте SHA-256 архива с evidence этого запуска GitHub Actions.\n',encoding='utf-8')
 files=sorted(p for p in folder.rglob('*') if p.is_file())
 assert not any(p.suffix=='.node' for p in files)
 if ext=='zip':
  with zipfile.ZipFile(dest,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for p in files:z.write(p,title+'/'+str(p.relative_to(folder)))
  with zipfile.ZipFile(dest) as z:
   assert z.testzip() is None
   names=z.namelist();assert title+'/diakitw.exe' in names
   assert z.read(title+'/diakitw.exe')[:2]==b'MZ'
 else:
  with tarfile.open(dest,'x:gz',compresslevel=6) as t:t.add(folder,arcname=title,filter=portable_metadata)
  with tarfile.open(dest,'r:gz') as t:
   members=t.getmembers();names=[m.name for m in members];binary=t.getmember(title+'/diakitw');assert binary.mode&0o111;assert t.extractfile(binary).read(4)==b'\x7fELF'
   assert not any(m.mode&0o6000 for m in members),'No setuid/setgid allowed'
 assert all(not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts for n in names)
 for n in ['resources/app.asar','LICENSE','LICENSES.chromium.html']:assert title+'/'+n in names
 (root/'evidence/v105'/(title+'-manifest.txt')).write_text('\n'.join(names)+'\n')
 results.append({'platform':platform,'arch':'x64','version':'1.0.5','file':dest.name,'bytes':dest.stat().st_size,'sha256':digest(dest),'archive_entries':len(names),'runtime_tested_on_target':False})
manifest={'product':'diakitw','version':'1.0.5','build':105,'displayVersion':'1.0.5','tag':'v1.0.5','electron':'45.2.3','artifacts':results,'verification':'candidate; target OS runtime pending'}
(root/'dist/release-manifest-1.0.5.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'dist/SHA256SUMS-1.0.5.txt').write_text(''.join(r['sha256']+'  '+pathlib.Path(r['file']).name+'\n' for r in results));print(json.dumps(manifest,indent=2))
