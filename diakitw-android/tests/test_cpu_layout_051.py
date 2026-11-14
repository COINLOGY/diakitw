"""Source wiring only; complements Core math and Android rendering tests."""
import pathlib, unittest
R=pathlib.Path(__file__).resolve().parents[1]
class CpuLayout(unittest.TestCase):
 def test_app_cpu_sampler_and_four_cards(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['new Metric("CPU APP")','new Metric[]{cpu,ram,disk,battery}','Process.getElapsedCpuTime()','Core.cpu(','cpu.update(s.cpu','previousCpu=-1','Только diakitw','countryLabel()','summary.setTextSize(18)']:
   self.assertIn(token,s)
  self.assertNotIn('SWAP, CPU процесса и UID-трафик убраны',s)
 def test_version(self):
  gradle=(R/'app/build.gradle').read_text()
  self.assertIn("versionName '0.5.5a'",gradle)
  self.assertRegex(gradle,r'\bversionCode\s+55\b')
