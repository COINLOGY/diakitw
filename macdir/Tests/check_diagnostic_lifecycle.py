"""Owned, tiny CPU worker only. No GUI process or user app touched."""
import os, subprocess, sys, time
from pathlib import Path
worker=str(Path(sys.argv[1] if len(sys.argv)>1 else '.build/release/DiagnosticWorker').resolve())
# Test parent death independently of the parent's own cancellation path.
parent_code='''import subprocess,os,sys,time
p=subprocess.Popen([sys.argv[1],'cpu','1','1','1',str(os.getpid())],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
print(p.pid,flush=True)
time.sleep(2)
'''
p=subprocess.Popen([sys.executable,'-c',parent_code,worker],stdout=subprocess.PIPE,text=True)
child=int(p.stdout.readline())
time.sleep(0.15)
p.terminate(); p.wait(timeout=1)
t=time.monotonic()
def exists(pid):
    try: os.kill(pid,0); return True
    except ProcessLookupError: return False
while exists(child) and time.monotonic()-t<0.6: time.sleep(0.01)
assert not exists(child), 'orphan worker still alive'
print('Parent-death watchdog PASS; child absent after',round(time.monotonic()-t,3),'s')
# Signal cancellation of an owned worker; no long run is requested.
p=subprocess.Popen([worker,'ram','1','1','1',str(os.getpid())],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
time.sleep(0.1); p.terminate(); p.communicate(timeout=1)
assert p.returncode != 0
print('Worker cancellation PASS; exit=',p.returncode)
