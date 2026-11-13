#!/usr/bin/env python3
"""Offline source/metadata contract; does not open app or read user settings."""
import plistlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class RebrandChecks(unittest.TestCase):
    def test_display_identity_and_legacy_identity(self):
        p = plistlib.loads((ROOT / 'Info.plist').read_bytes())
        self.assertEqual(p['CFBundleName'], 'diakitw')
        self.assertEqual(p['CFBundleDisplayName'], 'diakitw')
        self.assertEqual(p['CFBundleShortVersionString'], '0.5.2')
        self.assertEqual(p['CFBundleVersion'], '52')
        self.assertEqual(p['CFBundleIdentifier'], 'local.emcx.macdir')
        self.assertEqual(p['CFBundleExecutable'], 'macdir')
        self.assertEqual(p['CFBundleIconFile'], 'macdir')

    def test_existing_storage_and_auth_contract(self):
        source = lambda p: (ROOT / p).read_text()
        self.assertIn('Library/Application Support/macdir/servers.json', source('Sources/MacdirCore/ServerSampler.swift'))
        password = source('Sources/MacdirCore/ServerPassword.swift')
        self.assertIn('"pro.emcx.macdir.ssh-password.v1"', password)
        self.assertIn('c.id + "|" + c.target + "|" + String(c.port) + "|" + ref', password)
        self.assertIn('"MACDIR_SSH_REF"', password)
        self.assertIn('StrictHostKeyChecking=yes', source('Sources/MacdirCore/ServerSampler.swift'))
        self.assertIn('"server.interface."', source('Sources/macdir/ServerPanel.swift'))
        self.assertIn('name: "macdir"', source('Package.swift'))

    def test_visible_names_outside_diagnostics(self):
        for file, text in [('main.swift', 'Text("diakitw")'),
                           ('main.swift', 'О diakitw'),
                           ('main.swift', 'window.title = "diakitw'),
                           ('ResourceHUD.swift', 'Открыть diakitw'),
                           ('ResourceHUD.swift', 'Завершить diakitw'),
                           ('InternetTestWindow.swift', 'w.title = "diakitw')]:
            self.assertIn(text, (ROOT / 'Sources/macdir' / file).read_text())

if __name__ == '__main__':
    unittest.main()
