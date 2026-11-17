from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / 'app/src/main/java/app/diakitw/MainActivity.java').read_text()
MODEL = ROOT / 'app/src/main/java/app/diakitw/TrafficRate.java'
PROBE = (ROOT / 'app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()

class Dashboard104(unittest.TestCase):
    def test_network_between_existing_resources_and_disk_analysis(self):
        block = SRC.split('LinearLayout dashboard=column();', 1)[1].split('LinearLayout page=column();', 1)[0]
        self.assertIn('dashboard.addView(metrics,landscape?', block)
        self.assertIn('dashboard.addView(geo,gp)', block)
        section = SRC.split('LinearLayout page=column();', 1)[1].split('metricViewport.addView(page)', 1)[0]
        self.assertLess(section.index('page.addView(dashboard)'), section.index('page.addView(networkSection)'))
        self.assertLess(section.index('page.addView(networkSection)'), section.index('page.addView(storageSection,sectionGap)'))
        self.assertIn('persistentMap.getGlobalVisibleRect', PROBE)
        self.assertIn('a.networkSection', PROBE)
        self.assertIn('TrafficRate.Rates observed', PROBE)
        self.assertIn('release104 font scale mismatch', PROBE)
        self.assertIn('PASS release104 offline resources, RX/TX, disk, map visible, folder grant gate', PROBE)

    def test_monitored_counters_are_device_wide_not_synthetic(self):
        self.assertIn('TrafficStats.getTotalRxBytes()', SRC)
        self.assertIn('TrafficStats.getTotalTxBytes()', SRC)
        self.assertIn('SystemClock.elapsedRealtimeNanos()', SRC)
        self.assertIn('new TrafficRate()', SRC)
        self.assertIn('traffic.reset()', SRC)
        self.assertIn('traffic.update(', SRC)
        self.assertTrue(MODEL.exists())

    def test_storage_is_app_data_and_folder_map_requires_user_grant(self):
        self.assertIn('new StatFs(getFilesDir().getAbsolutePath())', SRC)
        self.assertIn('ACTION_OPEN_DOCUMENT_TREE', SRC)
        self.assertIn('DocumentsContract', SRC)
        self.assertIn('ДИСК · данные приложения', SRC)
        self.assertNotIn('APFS', SRC)

if __name__ == '__main__':
    unittest.main()
