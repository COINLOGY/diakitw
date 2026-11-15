"""Country labels share one flag and preserve the updater identity."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
ACTIVITY=(ROOT/"app/src/main/java/app/diakitw/MainActivity.java").read_text()

class CountryFlag057(unittest.TestCase):
 def test_all_ip_country_surfaces_share_one_flagged_label(self):
  label=ACTIVITY.split("String countryLabel(){",1)[1].split("\n",1)[0]
  self.assertEqual(label.count("flag(ipSnapshot.country)"),1)
  self.assertIn("countryLabel()",ACTIVITY.split("void updateSummary(){",1)[1].split("String ipStatusLabel()",1)[0])
  self.assertIn("countryLabel()",ACTIVITY.split("String ipDetails(){",1)[1].split("void renderIp()",1)[0])
  self.assertIn("countryLabel()",ACTIVITY.split("String expandedPrecision(){",1)[1].split("void openMap()",1)[0])
  self.assertIn("location.setText(countryLabel())",ACTIVITY)
  self.assertEqual(ACTIVITY.count("flag(ipSnapshot.country)"),1)
 def test_summary_accessibility_reads_the_same_flagged_country_as_visible_text(self):
  summary=ACTIVITY.split("void updateSummary(){",1)[1].split("String ipStatusLabel()",1)[0]
  self.assertIn("summary.setContentDescription(visible)",summary)
 def test_native_fixture_checks_each_rendered_country_once(self):
  probe=(ROOT/"app/src/androidTest/java/app/diakitw/EntryProbe.java").read_text()
  for surface in ("a.summary.getText()", "a.summary.getContentDescription()", "a.ipCards.get(0).location.getText()", "a.expandedMapCaption.getText()", "a.ipDetails()"):
   self.assertIn("singleFlag("+surface,probe)
 def test_updater_matches_installed_057_build(self):
  gradle=(ROOT/"app/build.gradle").read_text()
  updates=(ROOT/"app/src/main/java/app/diakitw/Updates.java").read_text()
  self.assertIn("versionCode 102; versionName '1.0.2'",gradle)
  self.assertIn('compare(v,installedVersion)<=0||build<=installedBuild',updates)

if __name__=="__main__": unittest.main()
