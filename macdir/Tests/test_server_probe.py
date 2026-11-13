import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('probe',Path(__file__).parents[1]/'assets/server_probe.py')
probe=importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
class ProbeTests(unittest.TestCase):
 def test_sample_logical_cpu_count(self):
  # Exercise the existing probe, never SSH or invoke service commands.
  with patch.object(probe.time, 'sleep'), patch.object(probe, 'service_state', return_value='unknown'):
   for count in (4, None, 0, -1, True, 1.5):
    with self.subTest(count=count), patch.object(probe.os, 'cpu_count', return_value=count):
     result=probe.specs()
     self.assertEqual(result['cpu_count'], count if type(count) is int and count>0 else None)
     self.assertEqual(result['schema'], 1)
 def test_live_does_not_read_cpu_count(self):
  with patch.object(probe.time, 'sleep'), patch.object(probe, 'service_state', return_value='unknown'), patch.object(probe.os, 'cpu_count', side_effect=AssertionError('daily only')):
   self.assertNotIn('cpu_count', probe.sample('bot'))
 def test_memory_totals_bytes(self):
  self.assertEqual(probe.memory_fields('MemTotal: 8388608 kB')['memory_total'], 8589934592)
  self.assertIsNone(probe.memory_fields('')['memory_total'])
 def test_cpu_delta_excludes_guest(self):
  self.assertEqual(probe.cpu_percent([100,0,50,850,0,0,0,0,80],[120,0,60,920,0,0,0,0,90]),30)
  self.assertIsNone(probe.cpu_percent([1]*8,[1]*8))
  self.assertIsNone(probe.cpu_percent([10]*8,[1]*8))
 def test_network_delta(self):
  self.assertEqual(probe.network_rates({'eth0':(100,50)},{'eth0':(300,150)},2),[{'name':'eth0','rx_bytes_per_second':100.0,'tx_bytes_per_second':50.0}])
  self.assertIsNone(probe.network_rates({'e':(100,50)},{'e':(1,100)},2)[0]['rx_bytes_per_second'])
if __name__=='__main__':unittest.main()
