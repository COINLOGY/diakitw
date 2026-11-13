import unittest
import os
import importlib.util

class HealthTests(unittest.TestCase):
    def test_missing_key_fail_closed(self):
        self.assertIsNotNone(importlib.util.find_spec('service'), 'service not implemented')
        import service
        app = service.App('/nonexistent-diakitw-token')
        self.assertEqual(app.respond('GET', '/', [('X-Diakitw-Client-IP', '8.8.8.8')], os.getuid()), (503, {'error': 'missing_key'}))

class IngressTests(unittest.TestCase):
    def test_ingress_policy(self):
        import service
        app = service.App('/nonexistent-diakitw-token')
        good = [('X-Diakitw-Client-IP', '8.8.8.8')]
        cases = [
            ('POST', '/', good, os.getuid(), 405),
            ('GET', '/?ip=1.1.1.1', good, os.getuid(), 400),
            ('GET', '/other', good, os.getuid(), 404),
            ('GET', '/', good, '192.168.1.2', 403),
            ('GET', '/', [], os.getuid(), 400),
            ('GET', '/', good + good, os.getuid(), 400),
        ]
        for method, path, headers, peer, status in cases:
            with self.subTest(method=method, path=path, peer=peer, headers=headers):
                self.assertEqual(app.respond(method, path, headers, peer)[0], status)
        for ip in ['127.0.0.1', '10.0.0.1', '169.254.1.1', '192.0.2.1', '100.64.0.1', '224.0.0.1', '::1', 'fc00::1', 'fe80::1', '2001:db8::1', '::ffff:8.8.8.8', '8.8.8.8,1.1.1.1', '8.8.8.8%eth0']:
            with self.subTest(ip=ip):
                self.assertEqual(app.respond('GET', '/', [('X-Diakitw-Client-IP', ip)], os.getuid())[0], 400)
        spoof = [('X-Forwarded-For', os.getuid()), ('Forwarded', 'for=1.1.1.1'), ('X-Real-IP', '192.168.1.1')]
        self.assertEqual(app.respond('GET', '/', good + spoof, os.getuid())[0], 503)
        self.assertEqual(app.respond('GET', '/', [('X-Diakitw-Client-IP', '2606:4700:4700::1111')], os.getuid())[0], 503)

class CredentialTests(unittest.TestCase):
    def test_health_and_credential_gate(self):
        import service, tempfile, pathlib, os
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'token'
            app = service.App(str(path))
            good = [('X-Diakitw-Client-IP', '8.8.8.8')]
            self.assertEqual(app.respond('GET', '/health', good, os.getuid()), (200, {'status': 'blocked', 'configured': False, 'provider_contract_verified': True, 'upstream_enabled': False}))
            path.write_text('fixture-token-not-real')
            path.chmod(0o600)
            self.assertEqual(app.respond('GET', '/health', good, os.getuid())[1]['configured'], True)
            self.assertEqual(app.respond('GET', '/geo', good, os.getuid()), (503, {'error': 'upstream_disabled'}))
            path.chmod(0o644)
            self.assertFalse(app.respond('GET', '/health', good, os.getuid())[1]['configured'])
            path.chmod(0o600)
            link = pathlib.Path(directory) / 'link'
            link.symlink_to(path)
            self.assertFalse(service.App(str(link)).respond('GET', '/health', good, os.getuid())[1]['configured'])
            path.write_text('invalid\\nvalue')
            self.assertFalse(app.respond('GET', '/health', good, os.getuid())[1]['configured'])
            path.unlink()
            os.mkfifo(path, 0o600)
            self.assertFalse(app.respond('GET', '/health', good, os.getuid())[1]['configured'])

class HTTPTests(unittest.TestCase):
    def test_http_boundary(self):
        import service, threading, http.client, socket, tempfile
        self.assertTrue(hasattr(service, 'make_server'), 'HTTP server not implemented')
        directory = tempfile.TemporaryDirectory()
        server = service.make_server(directory.name+'/api.sock', '/nonexistent-diakitw-token', trusted_uid=os.getuid())
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            connection = http.client.HTTPConnection('localhost', timeout=3)
            connection.sock = socket.socket(socket.AF_UNIX)
            connection.sock.connect(directory.name+'/api.sock')
            connection.request('GET', '/health', headers={'X-Diakitw-Client-IP': '8.8.8.8'})
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(response.getheader('Cache-Control'), 'no-store')
            self.assertIsNone(response.getheader('Access-Control-Allow-Origin'))
            self.assertNotIn(b'8.8.8.8', response.read())
            connection.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
            directory.cleanup()

    def test_rate_limits(self):
        import service
        self.assertTrue(hasattr(service, 'Limiter'), 'limiter not implemented')
        limiter = service.Limiter()
        self.assertTrue(limiter.allow('8.8.8.8', 100))
        self.assertFalse(limiter.allow('8.8.8.8', 100))
        self.assertTrue(limiter.allow('8.8.8.8', 111))
        for n in range(100):
            limiter.allow(str(n), 112)
        self.assertFalse(limiter.allow('other', 112))
        self.assertTrue(limiter.allow('other', 172))
        self.assertLessEqual(len(limiter.clients), 256)

if __name__ == '__main__':
    unittest.main()
