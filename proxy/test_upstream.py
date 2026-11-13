import unittest
import json
import service

FIXTURE = dict(ip='8.8.8.8', city=None, region='', country='United States', code='US', lat=0, lon=0, timezone=None, asn=dict(id=15169, name='Google', hosting=True))

class ProviderTests(unittest.TestCase):
    def test_provider_contract(self):
        self.assertTrue(hasattr(service, 'Provider'), 'provider missing')
        calls = []
        def transport(ip, token):
            calls.append((ip, token))
            return 200, json.dumps(FIXTURE).encode()
        result = service.Provider(transport).lookup('8.8.8.8', 'offline-fixture')
        self.assertEqual(result, FIXTURE)
        self.assertEqual(calls, [('8.8.8.8', 'offline-fixture')])

class SafetyTests(unittest.TestCase):
    def test_reject_bad_upstream(self):
        self.assertTrue(hasattr(service, 'SafeError'), 'safe errors missing')
        cases = [(s, b'offline-secret') for s in [301,302,307,308,401,429,500]]
        cases += [(200, b'x'*32769), (200, b'bad json'), (200, b'{}')]
        for field, value in [('ip','1.1.1.1'), ('lat',float('nan')), ('lon',181), ('city',[]), ('asn',{}), ('lat',True)]:
            data = dict(FIXTURE, **{field:value})
            cases.append((200,json.dumps(data).encode()))
        for status, raw in cases:
            with self.subTest(status=status, size=len(raw)):
                with self.assertRaises(service.SafeError) as caught:
                    service.Provider(lambda i,t: (status,raw)).lookup('8.8.8.8','offline-secret')
                self.assertNotIn('offline-secret',str(caught.exception))
    def test_timeout_sanitized(self):
        self.assertTrue(hasattr(service, 'SafeError'), 'safe errors missing')
        def fail(i,t): raise TimeoutError('https://host/?token=offline-secret')
        with self.assertRaises(service.SafeError) as caught:
            service.Provider(fail).lookup('8.8.8.8','offline-secret')
        self.assertEqual(str(caught.exception),'upstream_unavailable')

class QuotaTests(unittest.TestCase):
    def test_persistent_atomic_limits_fail_closed(self):
        import tempfile, pathlib, concurrent.futures
        self.assertTrue(hasattr(service,'Quota'),'quota missing')
        with tempfile.TemporaryDirectory() as d:
            path = str(pathlib.Path(d)/'quota.db')
            service.Quota.initialize(path)
            def reserve(_):
                try: service.Quota(path).reserve(1798761600); return True
                except service.SafeError: return False
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                self.assertEqual(sum(pool.map(reserve,range(310))),300)
            self.assertFalse(reserve(0))
            for day in range(1,30):
                for _ in range(300): service.Quota(path).reserve(1798761600+day*86400)
            with self.assertRaises(service.SafeError): service.Quota(path).reserve(1798761600+29*86400)
            with self.assertRaises(service.SafeError): service.Quota(path+'missing').reserve(1798761600)
            pathlib.Path(path).write_bytes(b'corrupt')
            with self.assertRaises(service.SafeError): service.Quota(path).reserve(1798761600)

class EngineTests(unittest.TestCase):
    def test_cache_singleflight_ttl_bounded(self):
        import tempfile, pathlib, concurrent.futures, time
        self.assertTrue(hasattr(service,'Engine'),'engine missing')
        with tempfile.TemporaryDirectory() as d:
            q=str(pathlib.Path(d)/'q'); service.Quota.initialize(q)
            calls=[]
            def transport(ip,token):
                calls.append(ip); time.sleep(.02)
                return 200,json.dumps(dict(FIXTURE,ip=ip)).encode()
            engine=service.Engine(service.Provider(transport),service.Quota(q),ttl=.08,capacity=2)
            with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                results=list(pool.map(lambda _:engine.lookup('8.8.8.8','fixture'),range(8)))
            self.assertEqual(len(calls),1)
            self.assertEqual(results[0]['ip'],'8.8.8.8')
            time.sleep(.1); engine.lookup('8.8.8.8','fixture')
            self.assertEqual(len(calls),2)
            for ip in ['1.1.1.1','9.9.9.9']: engine.lookup(ip,'fixture')
            self.assertLessEqual(len(engine.cache),2)

class ActivationTests(unittest.TestCase):
    def test_enabled_app_end_to_end_and_spoof(self):
        import tempfile, pathlib, os
        with tempfile.TemporaryDirectory() as d:
            token=pathlib.Path(d)/'token'; token.write_text('offline-fixture'); token.chmod(0o600)
            q=str(pathlib.Path(d)/'q'); service.Quota.initialize(q)
            calls=[]
            def transport(ip,key):
                calls.append(ip); return 200,json.dumps(FIXTURE).encode()
            app=service.App(str(token),True,service.Engine(service.Provider(transport),service.Quota(q)),trusted_uid=42)
            headers=[('X-Diakitw-Client-IP','8.8.8.8'),('X-Forwarded-For','1.1.1.1')]
            self.assertEqual(app.respond('GET','/geo',headers,43)[0],403)
            self.assertEqual(calls,[])
            self.assertEqual(app.respond('GET','/geo',headers,42),(200,FIXTURE))
            self.assertEqual(app.respond('GET','/geo',headers,42)[0],429)
            self.assertEqual(calls,['8.8.8.8'])
            token.write_text('invalid key')
            self.assertEqual(app.respond('GET','/geo',headers,42)[0],503)
    def test_transport_fixed_host_limits_no_redirect(self):
        from unittest.mock import patch, MagicMock
        conn=MagicMock(); response=conn.getresponse.return_value
        response.status=302
        with patch('http.client.HTTPSConnection',return_value=conn) as constructor:
            self.assertEqual(service.https_transport('8.8.8.8','offline-fixture'),(302,b''))
        self.assertEqual(constructor.call_args.args,('api.2ip.io',443))
        self.assertEqual(constructor.call_args.kwargs['timeout'],3)
        self.assertEqual(conn.request.call_args.args[:2],('GET','/8.8.8.8?token=offline-fixture'))
        response.read.assert_not_called(); conn.close.assert_called_once()
    def test_transport_total_deadline(self):
        self.assertTrue(hasattr(service,'deadline_transport'),'total deadline missing')
        import time
        with self.assertRaises(TimeoutError):
            service.deadline_transport(lambda: time.sleep(.2),seconds=.02)

    def test_unknown_geodata(self):
        data=dict.fromkeys(FIXTURE); data['ip']='8.8.8.8'
        self.assertEqual(service.Provider(lambda i,t:(200,json.dumps(data).encode())).lookup('8.8.8.8','fixture'),data)

if __name__ == '__main__': unittest.main()
