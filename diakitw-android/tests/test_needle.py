"""Source wiring only; numeric sweep is exercised by GaugeTest."""
import unittest
from pathlib import Path
class NeedleWiring(unittest.TestCase):
    def test_shared_filled_polygon(self):
        source=(Path(__file__).parents[1]/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
        self.assertIn('Gauge.needle(fraction,r)',source)
        self.assertIn('c.drawPath(needlePath,paint)',source)
        self.assertIn('g.tailClearance',source)
        self.assertIn('ticks(c);if(known)needle(c,value/max,tint)',source)
        self.assertIn('needle(c,fraction,color)',source)
