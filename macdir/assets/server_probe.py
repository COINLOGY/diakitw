"""Read-only Linux resource probe, executed over SSH stdin; installs nothing."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def cpu_percent(before, after):
    if before is None or after is None or len(before)<8 or len(after)<8:
        return None
    delta=[b-a for a,b in zip(before[:8],after[:8])]
    total=sum(delta)
    if total<=0 or any(v<0 for v in delta):
        return None
    return 100.0*(total-delta[3]-delta[4])/total


def network_rates(before, after, elapsed):
    rows=[]
    for name,values in sorted(after.items()):
        rates=[]
        for i,value in enumerate(values):
            old=before.get(name)
            rates.append((value-old[i])/elapsed if old and value>=old[i] and elapsed>0 else None)
        rows.append(dict(name=name,rx_bytes_per_second=rates[0],tx_bytes_per_second=rates[1]))
    return rows


def read_cpu():
    try:
        first=Path('/proc/stat').read_text().splitlines()[0].split()
        return [int(v) for v in first[1:]] if first[0]=='cpu' else None
    except (OSError,ValueError,IndexError):
        return None


def read_network():
    try:
        out={}
        for line in Path('/proc/net/dev').read_text().splitlines()[2:]:
            name,values=line.split(':',1);parts=values.split()
            out[name.strip()]=(int(parts[0]),int(parts[8]))
        return out
    except (OSError,ValueError,IndexError):
        return {}


def memory_fields(text):
    out={}
    for line in text.splitlines():
        name,_,value=line.partition(':')
        if name not in ('MemTotal','MemAvailable','SwapTotal','SwapFree'):
            continue
        try:
            fields=value.split()
            if fields[1]!='kB':continue
            number=int(fields[0])*1024
            if number>=0:out[name]=number
        except (ValueError,IndexError):pass
    return {key:out.get(source) for key,source in [('memory_total','MemTotal'),('memory_available','MemAvailable'),('swap_total','SwapTotal'),('swap_free','SwapFree')]}


def service_state(command):
    try:
        value=subprocess.run(command,capture_output=True,text=True,timeout=2).stdout.strip()
        return value if value in ('active','inactive','failed','activating','deactivating','running','exited','restarting','paused','dead','created') else 'unknown'
    except (OSError,subprocess.TimeoutExpired):return 'unknown'


def sample(role):
    first_cpu,first_net=read_cpu(),read_network();started=time.monotonic()
    time.sleep(1)
    second_cpu,second_net=read_cpu(),read_network();elapsed=time.monotonic()-started
    result=dict(schema=1,sampled_at=time.time(),cpu_percent=cpu_percent(first_cpu,second_cpu),network=network_rates(first_net,second_net,elapsed))
    try:result.update(memory_fields(Path('/proc/meminfo').read_text()))
    except OSError:result.update(memory_fields(''))
    try:
        disk=os.statvfs('/')
        result.update(disk_total=disk.f_blocks*disk.f_frsize,disk_free=disk.f_bfree*disk.f_frsize)
    except OSError:result.update(disk_total=None,disk_free=None)
    try:result['uptime_seconds']=float(Path('/proc/uptime').read_text().split()[0])
    except (OSError,ValueError,IndexError):result['uptime_seconds']=None
    units=['vpn-bot','coinlogy-admin','coinlogy-monitor'] if role=='bot' else ['docker']
    result['services']=[dict(name=name,state=service_state(['systemctl','is-active',name+'.service'])) for name in units]
    if role=='agent':
        result['services'].append(dict(name='emcx-hermes',state=service_state(['docker','inspect','--format','{{.State.Status}}','emcx-hermes'])))
    return result


def specs():
    count=os.cpu_count()
    result=dict(schema=1,sampled_at=time.time(),cpu_count=count if type(count) is int and count>0 else None)
    try:result['memory_total']=memory_fields(Path('/proc/meminfo').read_text())['memory_total']
    except OSError:result['memory_total']=None
    try:
        disk=os.statvfs('/')
        result['disk_total']=disk.f_blocks*disk.f_frsize
    except OSError:result['disk_total']=None
    return result


if __name__=='__main__':
    if len(sys.argv) not in (2,3) or sys.argv[1] not in ('bot','agent') or (len(sys.argv)==3 and sys.argv[2]!='specs'):
        raise SystemExit('Expected role bot or agent and optional specs')
    print(json.dumps(specs() if len(sys.argv)==3 else sample(sys.argv[1]),allow_nan=False))
