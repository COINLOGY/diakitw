from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'diakitw-android/app/src/main/java/app/diakitw/MainActivity.java').read_text()
PROBE = (ROOT / 'diakitw-android/app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()

class MapVisibility104(unittest.TestCase):
    def test_embedded_map_follows_compact_resources_in_initial_viewport(self):
        dashboard = SRC.split('LinearLayout dashboard=column();', 1)[1].split('metricViewport.addView(dashboard)', 1)[0]
        self.assertLess(dashboard.index('dashboard.addView(metrics)'), dashboard.index('dashboard.addView(geo,gp)'))
        self.assertIn('if(!landscape)gauge.setVisibility(GONE)', SRC)
        self.assertIn('dp(landscape?140:220)', SRC)

    def test_country_and_map_precede_redundant_ip_summary(self):
        self.assertGreater(SRC.index('geo.addView(summary', SRC.index('LinearLayout geo=column()')), SRC.index('geo.addView(persistentMap', SRC.index('LinearLayout geo=column()')))
        self.assertIn('(compact||!landscape)&&getResources().getConfiguration().fontScale<=1.5f', SRC)

    def test_native_probe_asserts_actual_visible_map_not_only_parent(self):
        self.assertIn('getGlobalVisibleRect', PROBE)
        self.assertIn('Map hidden below initial viewport', PROBE)

if __name__ == '__main__':
    unittest.main()
