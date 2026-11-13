"""Isolated 2ip proxy. Upstream requires explicit activation; no secret logging."""

import ipaddress
import os
import stat
import re


def read_credential(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb') as stream:
            info = os.fstat(stream.fileno())
            if (not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600
                    or info.st_uid != os.getuid() or info.st_nlink != 1 or not 1 <= info.st_size <= 512):
                return False
            value = stream.read(513)
            return value.decode('ascii') if re.fullmatch(rb'[A-Za-z0-9._~-]{1,512}', value) else None
    except OSError:
        return False

def credential_present(path):
    return bool(read_credential(path))


class App:
    def __init__(self, token_path, enabled=False, engine=None, trusted_uid=None):
        self.token_path = token_path
        self.enabled, self.engine = enabled, engine
        self.trusted_uid = os.getuid() if trusted_uid is None else trusted_uid
        self.limiter = Limiter()

    def respond(self, method, path, headers, peer):
        if type(peer) is not int or peer != self.trusted_uid:
            return 403, {'error': 'untrusted_peer'}
        if method != 'GET':
            return 405, {'error': 'method_not_allowed'}
        if '?' in path or '#' in path:
            return 400, {'error': 'query_not_allowed'}
        if path not in ('/', '/health', '/geo'):
            return 404, {'error': 'not_found'}
        values = [v for k, v in headers if k.lower() == 'x-diakitw-client-ip']
        try:
            if len(values) != 1 or '%' in values[0]:
                raise ValueError()
            ip = ipaddress.ip_address(values[0])
            if not ip.is_global or ip.is_multicast or ip.is_reserved or getattr(ip, 'ipv4_mapped', None):
                raise ValueError()
        except (ValueError, TypeError):
            return 400, {'error': 'invalid_caller_ip'}
        configured = credential_present(self.token_path)
        if path == '/health':
            return 200, {'status': 'ready' if configured and self.enabled else 'blocked', 'configured': configured, 'provider_contract_verified': True, 'upstream_enabled': self.enabled}
        if not configured: return 503, {'error':'missing_key'}
        if not self.enabled: return 503, {'error':'upstream_disabled'}
        if not self.limiter.allow(str(ip),time.monotonic()): return 429, {'error':'rate_limited'}
        token = read_credential(self.token_path)
        if not token: return 503, {'error':'missing_key'}
        try:
            return 200, self.engine.lookup(str(ip),token)
        except SafeError as exc:
            return 503, {'error':str(exc)}
        except Exception:
            return 503, {'error':'service_unavailable'}


# Serial server: one active handler, bounded listen queue, two-second socket timeout.
# No network client/import exists: token entry cannot enable paid/API traffic.
import hashlib
import json
import time
from collections import OrderedDict
from http.server import HTTPServer, BaseHTTPRequestHandler


class Limiter:
    def __init__(self):
        self.clients = OrderedDict()
        self.window = 0
        self.count = 0
        self.salt = os.urandom(32)

    def allow(self, client, now):
        if now - self.window >= 60:
            self.window, self.count = now, 0
        if self.count >= 30:
            return False
        key = hashlib.sha256(self.salt + client.encode()).digest()
        last = self.clients.get(key)
        if last is not None and now - last < 10:
            return False
        self.count += 1
        self.clients[key] = now
        self.clients.move_to_end(key)
        while len(self.clients) > 256:
            self.clients.popitem(last=False)
        return True


import socket
import socketserver

class Server(socketserver.UnixStreamServer):
    request_queue_size = 8
    def get_request(self):
        sock, address = super().get_request()
        sock.settimeout(2)
        return sock, address
    def handle_error(self, request, client_address):
        pass  # Never emit IPs, headers, or exception bodies.


class Handler(BaseHTTPRequestHandler):
    server_version = 'diakitw'
    sys_version = ''

    def log_message(self, *args):
        pass

    def do_GET(self):
        if hasattr(socket, 'SO_PEERCRED'):
            import struct
            peer = struct.unpack('3i', self.connection.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))[1]
        else:
            import ctypes
            libc = ctypes.CDLL(None, use_errno=True)
            uid, gid = ctypes.c_uint(), ctypes.c_uint()
            if libc.getpeereid(self.connection.fileno(),ctypes.byref(uid),ctypes.byref(gid)) != 0: return
            peer = uid.value
        status, data = self.server.app.respond(self.command, self.path, self.headers.items(), peer)
        raw = json.dumps(data, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Connection', 'close')
        if status == 429:
            self.send_header('Retry-After', '60')
        if status == 405:
            self.send_header('Allow', 'GET')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(raw)
        self.close_connection = True

    do_POST = do_PUT = do_DELETE = do_PATCH = do_OPTIONS = do_HEAD = do_TRACE = do_GET


def make_server(path='/run/emcx-diakitw-api/api.sock', token_path='/opt/emcx-diakitw-api/credentials/token', trusted_uid=None, enabled=False):
    if os.path.exists(path):
        if not stat.S_ISSOCK(os.lstat(path).st_mode): raise ValueError('unsafe socket path')
        os.unlink(path)
    server = Server(path, Handler)
    os.chmod(path,0o660)
    server.app = App(token_path, enabled, Engine(Provider(),Quota('/opt/emcx-diakitw-api/state/quota.db')), trusted_uid)
    return server


class SafeError(Exception):
    pass


def public_ip(value):
    ip = ipaddress.ip_address(value)
    if '%' in value or not ip.is_global or ip.is_multicast or ip.is_reserved or getattr(ip, 'ipv4_mapped', None):
        raise ValueError()
    return str(ip)


def deadline_transport(call, seconds=6):
    # Production server is serial on the main thread: alarm includes DNS and TLS.
    import signal
    def expired(*args): raise TimeoutError()
    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, seconds)
    try:
        return call()
    finally:
        signal.setitimer(signal.ITIMER_REAL,0)
        signal.signal(signal.SIGALRM, previous)


def https_transport(ip, token):
    return deadline_transport(lambda: _https_transport(ip,token))


def _https_transport(ip, token):
    # Direct TLS, no environment proxy, no redirect handling, no request logs.
    import http.client
    import ssl
    from urllib.parse import quote
    connection = http.client.HTTPSConnection('api.2ip.io', 443, timeout=3, context=ssl.create_default_context())
    try:
        connection.request('GET', '/' + quote(public_ip(ip), safe=':') + '?token=' + quote(token, safe=''), headers={'Accept':'application/json', 'Accept-Encoding':'identity'})
        response = connection.getresponse()
        if response.status != 200:
            return response.status, b''
        if response.getheader('Content-Encoding', 'identity') != 'identity': raise ValueError()
        length = response.getheader('Content-Length')
        if length is not None and (not length.isdigit() or int(length) > 32768): raise ValueError()
        return response.status, response.read(32769)
    finally:
        connection.close()


class Provider:
    def __init__(self, transport=https_transport):
        self.transport = transport

    def lookup(self, ip, token):
        import math
        try:
            ip = public_ip(ip)
            status, raw = self.transport(ip, token)
            if status != 200 or len(raw) > 32768: raise ValueError()
            def unique(pairs):
                result = {}
                for k,v in pairs:
                    if k in result: raise ValueError()
                    result[k] = v
                return result
            data = json.loads(raw, object_pairs_hook=unique)
            required = {'ip','city','region','country','code','lat','lon','timezone','asn'}
            if not isinstance(data,dict) or not required <= data.keys() or public_ip(data['ip']) != ip: raise ValueError()
            result = {'ip':ip}
            for key in ('city','region','country','code','timezone'):
                value = data[key]
                if value is not None and (not isinstance(value,str) or len(value)>256 or any(ord(c)<32 for c in value)): raise ValueError()
                result[key] = value
            if result['code'] not in (None,'') and not re.fullmatch('[A-Z]{2}',result['code']): raise ValueError()
            for key, bound in [('lat',90),('lon',180)]:
                value = data[key]
                if value is not None and (type(value) not in (int,float) or not math.isfinite(value) or abs(value)>bound): raise ValueError()
                result[key] = value
            asn = data['asn']
            if asn is None:
                result['asn'] = None
            else:
                if not isinstance(asn,dict) or not {'id','name','hosting'} <= asn.keys(): raise ValueError()
                if asn['id'] is not None and (type(asn['id']) is not int or not 0<=asn['id']<=4294967295): raise ValueError()
                if asn['name'] is not None and (not isinstance(asn['name'],str) or len(asn['name'])>256 or any(ord(c)<32 for c in asn['name'])): raise ValueError()
                if asn['hosting'] is not None and type(asn['hosting']) is not bool: raise ValueError()
                result['asn'] = {k:asn[k] for k in ('id','name','hosting')}
            return result
        except Exception:
            raise SafeError('upstream_unavailable') from None



class Quota:
    """Local UTC calendar quota, committed before every attempt, never refunded."""
    def __init__(self, path): self.path = path

    @staticmethod
    def initialize(path):
        import sqlite3
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
        with sqlite3.connect(path) as db:
            db.execute('CREATE TABLE usage (period TEXT PRIMARY KEY, count INTEGER NOT NULL CHECK(count>=0))')
            db.execute('CREATE TABLE clock (id INTEGER PRIMARY KEY CHECK(id=1), last REAL NOT NULL)')
            db.execute('INSERT INTO clock VALUES (1,0)')

    def reserve(self, now):
        import sqlite3
        import datetime
        from pathlib import Path
        try:
            info = os.lstat(self.path)
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1: raise ValueError()
            date = datetime.datetime.fromtimestamp(now, datetime.timezone.utc)
            keys = [('m:'+date.strftime('%Y-%m'),9000),('d:'+date.strftime('%Y-%m-%d'),300)]
            db = sqlite3.connect(Path(self.path).resolve().as_uri()+'?mode=rw',uri=True,timeout=5)
            try:
                db.execute('PRAGMA synchronous=FULL')
                db.execute('BEGIN IMMEDIATE')
                last = db.execute('SELECT last FROM clock WHERE id=1').fetchone()
                if last is None or now < last[0]: raise ValueError()
                for key,limit in keys:
                    row = db.execute('SELECT count FROM usage WHERE period=?',(key,)).fetchone()
                    if row and (type(row[0]) is not int or row[0]<0 or row[0]>=limit): raise ValueError()
                    db.execute('INSERT INTO usage VALUES (?,1) ON CONFLICT(period) DO UPDATE SET count=count+1',(key,))
                db.execute('UPDATE clock SET last=? WHERE id=1',(now,))
                db.commit()
            finally:
                db.close()
        except Exception:
            raise SafeError('quota_unavailable_or_exhausted') from None


class Engine:
    # Global serialization is deliberately stronger than per-IP singleflight.
    # Bounded server concurrency, cache and failure TTL prevent stampedes.
    def __init__(self, provider, quota, ttl=3600, capacity=256):
        import threading
        self.provider, self.quota = provider, quota
        self.ttl, self.capacity = ttl, capacity
        self.cache = OrderedDict()
        self.lock = threading.Lock()

    def lookup(self, ip, token):
        import copy
        with self.lock:
            now = time.monotonic()
            cached = self.cache.get(ip)
            if cached and cached[0] > now:
                if isinstance(cached[1],str): raise SafeError(cached[1])
                return copy.deepcopy(cached[1])
            self.quota.reserve(time.time())
            try:
                result = self.provider.lookup(ip,token)
            except SafeError:
                self.cache[ip] = (time.monotonic()+10,'upstream_unavailable')
                while len(self.cache)>self.capacity: self.cache.popitem(last=False)
                raise
            self.cache[ip] = (time.monotonic()+self.ttl,result)
            self.cache.move_to_end(ip)
            while len(self.cache)>self.capacity: self.cache.popitem(last=False)
            return copy.deepcopy(result)


if __name__ == '__main__':
    import pwd
    make_server(trusted_uid=pwd.getpwnam('www-data').pw_uid, enabled=os.environ.get('DIAKITW_UPSTREAM_ENABLED')=='1').serve_forever()

