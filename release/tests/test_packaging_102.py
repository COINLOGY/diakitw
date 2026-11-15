"""Versioned packaging must use 1.0.2, preserving Android signer."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[2]
class Packaging102(unittest.TestCase):
 def test_android_candidate_keeps_release_identity(self):
  s=(R/'diakitw-android/ci/build-signed-102.sh').read_text()
  self.assertIn('diakitw-android-1.0.2.apk',s)
  self.assertIn('diakitw-release-101',s)  # key continuity is mandatory
  self.assertIn('d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8',s)
 def test_desktop_portables_have_new_versioned_scripts(self):
  p=R/'diakitw-desktop/scripts'
  for f in ('build-v102.mjs','verify-bundles-v102.mjs','archive-v102.py','verify-archives-v102.py','verify-upstream-v102.py'):
   t=(p/f).read_text()
   self.assertIn('102',t,f)
  self.assertIn("buildVersion:'1.0.2.102'",(p/'build-v102.mjs').read_text())
 def test_macos_dmg_version_and_build(self):
  t=(R/'macdir/package-diagnostics-dmg.py').read_text()
  self.assertIn("VERSION = '1.0.2'",t)
  self.assertIn("BUILD = '102'",t)
  self.assertIn('README-diakitw-1.0.2-RU.txt',t)
 def test_candidate_ci_targets_102_branch(self):
  for f in ('android-release-102.yml','desktop-102-candidate.yml'):
   t=(R/'.github/workflows'/f).read_text()
   self.assertIn('feat/release-102',t)
   self.assertIn('1.0.2',t)
  mac=(R/'.github/workflows/macos-build.yml').read_text()
  self.assertIn('macOS 1.0.2 build-only',mac)
  self.assertIn('diakitw-1.0.2-macos-arm64.dmg',mac)
 def test_ios_compiles_only_without_upload(self):
  t=(R/'ios/Scripts/ci-build.sh').read_text()
  self.assertIn('diakitw-1.0.2-ios-',t)
  w=(R/'.github/workflows/ios-build.yml').read_text()
  self.assertNotIn('upload-artifact@',w)
if __name__=='__main__':unittest.main()
