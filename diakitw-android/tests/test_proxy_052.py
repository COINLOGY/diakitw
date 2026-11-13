from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class ProxyContract(unittest.TestCase):
 def test_primary_fixed_proxy(self):
  s=(R/'app/src/main/java/app/diakitw/Egress.java').read_text()
  self.assertIn('ENDPOINT="https://aia.emcx.pro/diakitw-api/geo"',s)
