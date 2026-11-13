"""Static allocation boundary gates; not a frame-time benchmark."""
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class DrawCache(unittest.TestCase):
 def test_draw_does_not_recompute_scale_or_allocate_geometry(self):
  source=(R/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for part in source.split('@Override protected void onDraw(Canvas c)')[1:]:
   body=part.split('\n  }',1)[0]
   for token in ['new RectF','new Gauge.Geometry','Typeface.create','getFontMetrics()','SpeedScale.maximum','SpeedScale.label']:
    self.assertNotIn(token,body)
if __name__=='__main__':unittest.main()
