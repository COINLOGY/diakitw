"""Focused Linux-runnable tests for the explicitly unsigned CI route."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class RouteTests(unittest.TestCase):
    def test_packager_adhoc_never_notarizes_or_claims_developer_id(self):
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        pkg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pkg)
        with patch.object(pkg, 'run') as run, patch.object(pkg, 'verify_developer_id') as dev:
            pkg.preflight('adhoc')
            pkg.sign_target('adhoc', Path('/tmp/fixture.app'))
            pkg.finish_dmg('adhoc', Path('/tmp/fixture.dmg'))
            self.assertFalse(dev.called)
            commands = [' '.join(map(str, call.args)) for call in run.call_args_list]
            self.assertTrue(any('adhoc-preflight' in c for c in commands))
            self.assertTrue(any('adhoc-sign' in c for c in commands))
            self.assertFalse(any(' notarize ' in c or 'staple ' in c for c in commands))
            self.assertEqual(pkg.signature_evidence('adhoc'), {'signing': 'ad-hoc', 'developer_id_signature_verified': False, 'notarized_and_stapled': False, 'gatekeeper_accepted': False})

    def test_signed_path_keeps_existing_security_gates(self):
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        pkg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pkg)
        with patch.object(pkg, 'run') as run:
            pkg.preflight('signed')
            pkg.sign_target('signed', Path('/tmp/fixture.app'))
            pkg.finish_dmg('signed', Path('/tmp/fixture.dmg'))
            commands = [' '.join(map(str, call.args)) for call in run.call_args_list]
            self.assertTrue(any('preflight' in c for c in commands))
            self.assertTrue(any(' sign ' in c for c in commands))
            self.assertTrue(any('notarize' in c for c in commands))
            self.assertEqual(pkg.signature_evidence('signed')['notarized_and_stapled'], True)

    def test_workflow_is_build_only_and_secret_free_in_unsigned_branch(self):
        workflow = (ROOT.parent / '.github/workflows/macos-build-106.yml').read_text()
        self.assertIn('options: [full, unsigned, server-model, layout]', workflow)
        self.assertIn("if: inputs.scope == 'full'", workflow)
        self.assertIn("if: inputs.scope == 'full' || github.event_name == 'push' || inputs.scope == 'unsigned'", workflow)
        self.assertIn("(github.event_name == 'push' || inputs.scope == 'unsigned') && 'adhoc'", workflow)
        self.assertIn('diakitw-1.0.6-macos-unsigned-arm64', workflow)
        self.assertIn('diakitw-1.0.6-macos-unsigned-x86_64', workflow)
        self.assertNotIn('gh release', workflow)

    def test_unsigned_artifact_paths_are_separate_from_signed_outputs(self):
        spec = importlib.util.spec_from_file_location('packager', ROOT / 'package-diagnostics-dmg.py')
        pkg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pkg)
        for arch in ('arm64', 'x86_64'):
            unsigned = pkg.artifact_paths(ROOT, arch, 'adhoc')
            signed = pkg.artifact_paths(ROOT, arch, 'signed')
            self.assertNotEqual(unsigned['output'], signed['output'])
            self.assertNotEqual(unsigned['dmg'], signed['dmg'])
            self.assertEqual(unsigned['dmg'].name, f'diakitw-1.0.6-macos-unsigned-{arch}.dmg')
        with patch.dict(os.environ, {'MACDIR_SIGNING_MODE': 'adhoc', 'GITHUB_ACTIONS': ''}):
            with self.assertRaises(RuntimeError): pkg.signing_mode()

    def test_bundled_readme_discloses_unsigned_candidate(self):
        readme = (ROOT / 'assets/README-diakitw-1.0.6-RU.txt').read_text()
        self.assertIn('macos-unsigned-arm64.dmg', readme)
        self.assertIn('macos-unsigned-x86_64.dmg', readme)
        self.assertIn('Gatekeeper', readme)
        self.assertIn('не нотариализованы', readme)

    def test_build_and_verifier_support_explicit_mode(self):
        build = (ROOT / 'build.sh').read_text()
        ci = (ROOT / 'ci-build.sh').read_text()
        verify = (ROOT / 'Tests/verify_ci_artifacts.py').read_text()
        self.assertIn('adhoc-preflight', build)
        self.assertIn('adhoc-sign', build)
        self.assertIn('MACDIR_SIGNING_MODE', ci)
        self.assertIn("rec['notarized_and_stapled']", verify)
        self.assertIn('gatekeeper_accepted', verify)


if __name__ == '__main__':
    unittest.main()
