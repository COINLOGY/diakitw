"""Wiring + bounded execution of an explicitly supplied test bundle, never GUI."""
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SelfCheck(unittest.TestCase):
    def test_dispatch_precedes_all_live_paths(self):
        code = (ROOT / 'Sources/macdir/main.swift').read_text()
        self.assertIn('if CommandLine.arguments.contains("--self-check") {', code)
        self.assertLess(code.index('if CommandLine.arguments.contains("--self-check") {'),
                        code.index('CommandLine.arguments.contains("--server-snapshot")'))
        self.assertIn('exit(runOfflineSelfCheck())', code)

    def test_bounded_offline_bundle_execution(self):
        if len(sys.argv) < 2 or not sys.argv[1].endswith('.app'):
            self.skipTest('pass a dedicated fixture .app for runtime checks')
        self.test_dispatch_precedes_all_live_paths()  # never launch an old GUI binary
        exe = Path(sys.argv[1]) / 'Contents/MacOS/macdir'
        result = subprocess.run([str(exe), '--self-check'], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('SELF-CHECK PASS', result.stdout)
        self.assertIn('offline fixtures', result.stdout)
        result = subprocess.run([str(exe), '--self-check', '--snapshot'], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 64)

if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]])
