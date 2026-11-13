"""Entry wiring only; native EntryProbe verifies rendered click and freshness."""
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class IpEntry(unittest.TestCase):
 def test_explicit_entry_and_independent_status(self):
  s=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  summary=s.split('void updateSummary(){')[1].split('static String flag')[0]
  self.assertIn('"IP / карта · "',summary)
  self.assertIn('summary.setContentDescription("IP / карта")',summary)
  self.assertIn('summary.setOnClickListener(v->openIpDetails())',s)
  self.assertIn('String ipStatusLabel(){return ipBadge.equals("Снимок")?"Обновлено":ipBadge;}',s)
  self.assertIn('state.setText(ipStatusLabel()',s)
  self.assertIn('ipBadge="Снимок";',s)
  self.assertEqual(s.count('!ipBadge.equals("Снимок")'),4)
  self.assertIn('state.setTextColor(ipBadge.equals("Снимок")?GREEN:MUTED)',s)
if __name__=='__main__': unittest.main()
