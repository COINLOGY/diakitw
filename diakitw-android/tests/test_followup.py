"""Source wiring gates only, not Android rendered/tap acceptance."""
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class Followup(unittest.TestCase):
 def test_report_preserves_real_http_samples(self):
  s=(R/'app/src/main/java/app/diakitw/SpeedTest.java').read_text()
  self.assertIn('r.samplesMs.add(',s)
  self.assertIn('r.state="completed"',s)
  self.assertTrue((R/'app/src/main/java/app/diakitw/SpeedReport.java').exists())
 def test_single_start_and_saved_export(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  surface=s.split('void openTest(){')[1].split('void speedHelp()')[0]
  self.assertIn('button("Старт",null)',surface)
  self.assertIn('start.setOnClickListener(begin)',surface)
  self.assertNotIn('setPositiveButton("Запустить"',surface)
  self.assertIn('Нажимая «Старт»',surface)
  self.assertIn('нагрев',surface)
  self.assertIn('start.setEnabled(false);stop.setEnabled(true)',surface)
  self.assertIn('if(test!=null||SpeedTest.BUSY.get())',surface)
  self.assertIn('SpeedReport.json(r)',s)
  self.assertIn('putString("speedReportJson",json)',s)
  self.assertIn('Intent.ACTION_SEND',s)
  self.assertIn('Intent.EXTRA_TEXT,json',s)
  self.assertIn('speedResults.post(',surface)
  stop=surface.split('stop.setOnClickListener')[1].split('View.OnClickListener begin')[0]
  self.assertNotIn('start.setEnabled(true)',stop)
  self.assertEqual(surface.count('thread.start()'),1)
  self.assertEqual(surface.count('new SpeedTest()'),1)
  before_begin=surface.split('View.OnClickListener begin')[0]
  self.assertNotIn('thread.start()',before_begin)
  self.assertLess(surface.index('test=run;start.setEnabled(false)'),surface.index('thread.start()'))
  callback=surface.split('speedResults.post(')[1]
  self.assertIn('if(test==run)test=null',callback)
  self.assertIn('if(token!=testGeneration||testDialog!=dialog)return',callback)
  self.assertIn('dialog.setOnDismissListener(d->{stopTest();testGeneration++',surface)
  self.assertLess(surface.index('shell.addView(warning)'),surface.index('shell.addView(actions)'))
if __name__=='__main__':unittest.main()
