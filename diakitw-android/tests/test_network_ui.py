from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class NewUI(unittest.TestCase):
 def test_real_dials_and_midpoint(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['class SpeedDial','50%','100%','Страна:','new SpeedTest.Progress()']:
   self.assertIn(token,s)
  for token in ['"25%"','"75%"','"Определить IP"','"Отмена IP"','SpeedScale.label(max/4)','SpeedScale.label(max*.75)']:
   self.assertNotIn(token,s)
  self.assertIn('SpeedScale.label(max/2)',s)
 def test_measured_progress(self):
  s=(R/'app/src/main/java/app/diakitw/SpeedTest.java').read_text()
  self.assertIn('default void measured(',s)
  self.assertIn('progress.measured(false,r.downBytes,System.nanoTime()-tick)',s)
  self.assertIn('progress.measured(true,r.upBytes,System.nanoTime()-tick)',s)
