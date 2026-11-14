"""Offline exact released-054 and current parser fixtures; no installer build."""
from pathlib import Path
import subprocess, hashlib, json
s=Path('.ci-scratch');s.mkdir(exist_ok=True)
def run(*args):subprocess.run(args,check=True)
def old(path):return subprocess.check_output(['git','show','v0.5.4:'+path])
feed=Path('release/fixtures/v1-0.5.5.json').read_bytes()
print('FINAL_FEED_SHA256',hashlib.sha256(feed).hexdigest(),flush=True)
assert set(json.loads(feed)['releases'][0]['assets'])=={'windows-x64','linux-x64','android','macos-arm64','macos-x86_64'}
for label in ['old','current']:
 desktop='diakitw-desktop/app/updates.cjs'; swift='macdir/Sources/MacdirCore/UpdateChecker.swift'; android='diakitw-android/app/src/main/java/app/diakitw/Updates.java'
 d=s/label;d.mkdir(exist_ok=True)
 for path,name in [(desktop,'updates.cjs'),(swift,'UpdateChecker.swift'),(android,'Updates.java')]:
  data=old(path) if label=='old' else Path(path).read_bytes();(d/name).write_bytes(data)
  print(label,path,hashlib.sha256(data).hexdigest(),flush=True)
 run('node','release/check-feed-055.cjs',str(d/'updates.cjs'))
 run('swiftc',str(d/'UpdateChecker.swift'),'release/check-feed-055.swift','-o',str(d/'swift-feed'))
 run(str(d/'swift-feed'))
 run('javac','-encoding','UTF-8','-cp',str(s/'json.jar'),'-d',str(d),str(d/'Updates.java'),'release/FeedCheck055.java')
 run('java','-Dfile.encoding=UTF-8','-cp',str(s/'json.jar')+':'+str(d),'app.diakitw.FeedCheck055',label)
# Labelled future-version fixture, never a shipped source modification.
d=s/'newer-fixture';d.mkdir(exist_ok=True)
text=Path(android).read_text();needle='compare(v,"0.5.5")<=0||build<=55';assert text.count(needle)==1
(d/'Updates.java').write_text(text.replace(needle,'compare(v,"0.5.6")<=0||build<=56'))
run('javac','-encoding','UTF-8','-cp',str(s/'json.jar'),'-d',str(d),str(d/'Updates.java'),'release/FeedCheck055.java')
run('java','-Dfile.encoding=UTF-8','-cp',str(s/'json.jar')+':'+str(d),'app.diakitw.FeedCheck055','newer-fixture')
print('ALL EXACT FINAL MANIFEST PARSERS PASS',flush=True)
