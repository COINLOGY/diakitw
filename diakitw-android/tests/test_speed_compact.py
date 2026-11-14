"""Focused source wiring, not a substitute for native bounds."""
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class CompactSpeed(unittest.TestCase):
 def test_details_not_repeated_on_speed_surface(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  surface=s.split('void openTest(){')[1].split('void stopIp()')[0]
  self.assertNotIn('addIpPanel(content)',surface)
  self.assertIn('speedHelp()',surface)
  self.assertIn('boolean stackSpeeds=!landscape',surface)
  self.assertIn('8 MiB ↓ + 2 MiB ↑',surface)
  self.assertIn('Нажимая «Старт»',surface)
  self.assertIn('start.setOnClickListener(begin)',surface)
  self.assertIn('status.setText(r.status)',surface)
if __name__=='__main__':unittest.main()
