#!/usr/bin/env python3
"""Offline naming and non-overwrite checks; no builds, mounts or credentials."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ArtifactChecks(unittest.TestCase):
    def test_packager_paths_and_preservation(self):
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        module = importlib.util.module_from_spec(spec)
        # Import must be inert: no subprocess, cwd/environment changes or packaging.
        import unittest.mock as mock
        cwd, env = os.getcwd(), dict(os.environ)
        with mock.patch('subprocess.run', side_effect=AssertionError('import ran subprocess')):
            spec.loader.exec_module(module)
        self.assertEqual(os.getcwd(), cwd)
        self.assertEqual(dict(os.environ), env)
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'], prefix='diakitw-artifacts-') as tmp:
            root = Path(tmp)
            old = root / 'dist/macdir-0.3.8-macos-arm64.dmg'
            old.parent.mkdir(); old.write_bytes(b'previous distribution sentinel')
            paths = [module.artifact_paths(root, arch) for arch in ('arm64', 'x86_64')]
            for arch, p in zip(('arm64', 'x86_64'), paths):
                self.assertEqual(p['app'], root / f'dist/diakitw-0.5.7-{arch}/diakitw.app')
                self.assertEqual(p['dmg'], root / f'dist/diakitw-0.5.7-macos-{arch}.dmg')
                module.require_absent(p['dmg'])
                p['dmg'].write_bytes(b'new distribution sentinel')
                with self.assertRaises(FileExistsError):
                    module.require_absent(p['dmg'])
                self.assertEqual(p['dmg'].read_bytes(), b'new distribution sentinel')
            self.assertNotEqual(paths[0]['app'], paths[1]['app'])
            self.assertEqual(old.read_bytes(), b'previous distribution sentinel')
            with self.assertRaises(ValueError): module.artifact_paths(root, 'universal')

    def test_build_refuses_existing_output_before_building(self):
        import subprocess
        with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR'], prefix='diakitw-preserve-') as tmp:
            output = Path(tmp) / 'previous-release'
            output.mkdir()
            sentinel = output / 'sentinel'
            sentinel.write_bytes(b'unchanged')
            env = dict(os.environ, MACDIR_OUTPUT=str(output))
            result = subprocess.run(['bash', str(ROOT / 'build.sh')], env=env,
                                    capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Refusing existing output', result.stderr)
            self.assertEqual(sentinel.read_bytes(), b'unchanged')
            self.assertEqual(list(output.iterdir()), [sentinel])

    def test_swiftpm_flags_preserve_argument_boundaries(self):
        import shlex
        build = (ROOT / 'build.sh').read_text()
        command = next(line for line in build.splitlines() if line.startswith('swift build '))
        tokens = shlex.split(command)
        forwarded = [tokens[i + 1] for i, token in enumerate(tokens) if token == '-Xswiftc']
        self.assertEqual(forwarded, ['-file-prefix-map', '$PWD=/diakitw-src',
                                     '-debug-prefix-map', '$PWD=/diakitw-src'])
        self.assertIn('--jobs 2', command)
        self.assertNotIn('-Xswiftc -j', command)

    def test_build_names_and_allowlist(self):
        build = (ROOT / 'build.sh').read_text()
        self.assertIn('dist/diakitw-0.5.7-arm64', build)
        self.assertIn('APP="$OUTPUT/diakitw.app"', build)
        self.assertIn('diakitw-0.5.7-macos-arm64.zip', build)
        self.assertIn('Refusing existing output', build)
        self.assertIn('check_rebrand.py', build)
        p = (ROOT / 'package-diagnostics-dmg.py').read_text()
        self.assertIn('Contents/MacOS/ServerAskpass', p)
        self.assertIn("'Contents/Resources/server_probe.py'", p)
        self.assertNotIn('copytree', p)
        self.assertNotIn('servers.json', p)
        self.assertIn('README-diakitw-0.5.7-RU.txt', p)

if __name__ == '__main__': unittest.main()
