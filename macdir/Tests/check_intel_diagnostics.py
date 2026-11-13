from pathlib import Path
import os, subprocess, tempfile, unittest
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'assets/Intel-Diagnostics.command'
class Diagnostics(unittest.TestCase):
    def test_missing_adjacent_bundle_fails_closed_from_other_cwd(self):
        self.assertTrue(SCRIPT.is_file(), 'diagnostic script missing')
        with tempfile.TemporaryDirectory(prefix='macdir diagnostic spaces ', dir=os.environ['TMPDIR']) as tmp:
            path = Path(tmp) / 'Intel-Diagnostics.command'
            path.write_bytes(SCRIPT.read_bytes()); path.chmod(0o755)
            p = subprocess.run([str(path), '--no-pause'], cwd='/', capture_output=True, text=True, timeout=15)
            self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
            self.assertIn('BUNDLE: MISSING', p.stdout)
            self.assertNotIn(str(Path.home()), p.stdout + p.stderr)
if __name__ == '__main__': unittest.main()
