import pathlib, unittest, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Wiring(unittest.TestCase):
 def test_native_lifecycle_and_scope(self):
  s=(ROOT/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for text in ['onPause()', 'removeCallbacks', 'shutdownNow()', 'getMemoryInfo', 'getAvailableBytes', 'getTotalBytes', 'setOnApplyWindowInsetsListener','stopTest()', 'Тест интернета']: self.assertIn(text,s)
 def test_compact_dashboard(self):
  s=(ROOT/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  self.assertNotIn('TrafficStats',s)
  self.assertNotIn('new History()',s)
  self.assertIn('Обзор',s)
  self.assertIn('new Metric[]{cpu,ram,disk,battery}',s)
 def test_speed_security(self):
  s=(ROOT/'app/src/main/java/app/diakitw/SpeedTest.java').read_text()
  for t in ['https://speed.cloudflare.com','setInstanceFollowRedirects(false)','setUseCaches(false)','setFixedLengthStreamingMode','System.nanoTime()','BUSY.compareAndSet']:self.assertIn(t,s)
 def test_only_internet_no_services(self):
  root=ET.parse(ROOT/'app/src/main/AndroidManifest.xml').getroot()
  self.assertEqual(['android.permission.INTERNET','android.permission.ACCESS_NETWORK_STATE'],[p.get('{http://schemas.android.com/apk/res/android}name') for p in root.findall('uses-permission')])
  self.assertEqual([],root.findall('.//service'))
if __name__=='__main__': unittest.main()
