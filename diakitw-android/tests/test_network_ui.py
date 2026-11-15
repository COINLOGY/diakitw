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
 def test_speed_dial_direction_follows_full_rate_and_unit(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  self.assertIn('new SpeedDial("Загрузка","↓",GREEN)',s)
  self.assertIn('new SpeedDial("Отправка","↑",BLUE)',s)
  self.assertIn('String reading=label+" Мбит/с "+direction',s)
  self.assertIn('value.setText(styled)',s)
  self.assertIn('value.setSingleLine(true)',s)
  self.assertIn('setAutoSizeTextTypeUniformWithConfiguration',s)
  self.assertNotIn('copy.addView(text("Мбит/с "+direction,14,MUTED))',s)
  probe=(R/'app/src/androidTest/java/app/diakitw/LayoutProbe.java').read_text()
  self.assertIn('dial.value.getLayout().getLineCount()==1',probe)
 def test_measured_progress(self):
  s=(R/'app/src/main/java/app/diakitw/SpeedTest.java').read_text()
  self.assertIn('default void measured(',s)
  self.assertIn('progress.measured(false,r.downBytes,System.nanoTime()-tick)',s)
  self.assertIn('progress.measured(true,r.upBytes,System.nanoTime()-tick)',s)
