from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'diakitw-android/app/src/main/java/app/diakitw/MainActivity.java'
class Release103(unittest.TestCase):
 def test_three_metrics_and_persistent_map(self):
  s=SRC.read_text()
  self.assertIn('new Metric[]{cpu,ram,disk}',s)
  self.assertNotIn('ACTION_BATTERY_CHANGED',s)
  self.assertNotIn('battery.update(',s)
  self.assertIn('persistentMap=new MapView(this,true)',s)
  self.assertIn('persistentMap.update(ipSnapshot',s)
  self.assertIn('Тест интернета',s)
 def test_current_version_and_historical_candidate(self):
  self.assertIn("versionCode 106; versionName '1.0.6'",(ROOT/'diakitw-android/app/build.gradle').read_text())
  workflow=(ROOT/'.github/workflows/android-release-103.yml').read_text()
  self.assertIn('feat/release-103',workflow)
  self.assertIn('build-signed-103.sh',workflow)
  self.assertIn('run-android-103.sh',workflow)
  self.assertIn('d9298271', (ROOT/'diakitw-android/ci/build-signed-103.sh').read_text())
  self.assertNotIn('release: create',workflow)
  native=(ROOT/'diakitw-android/ci/run-android-103.sh').read_text()
  for configuration in ('portrait landscape large-font','Active default network: none','-e mode release103'):
   self.assertIn(configuration,native)
  activity=SRC.read_text()
  self.assertIn('static boolean startupCheckUsed',activity)
  self.assertIn('!startupCheckUsed',activity)
  self.assertIn('Скачать доступное',activity)
  self.assertNotIn('setNegativeButton("Позже",(d,w)->{updateOffer=null',activity)
