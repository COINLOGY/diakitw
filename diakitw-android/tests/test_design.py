"""Design wiring gates; actual view bounds are tested on API30 separately."""
import pathlib, unittest, hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Design(unittest.TestCase):
 def test_brand_and_native_interaction_states(self):
  s=(ROOT/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  for token in ['0xff141a21','0xffa6e640','RippleDrawable','state_enabled','setMinimumHeight(dp(48))','class ResourceGauge','setFontFeatureSettings("tnum")']:
   self.assertIn(token,s)
 def test_speed_engine_budgets_preserved(self):
  s=(ROOT/'app/src/main/java/app/diakitw/SpeedTest.java').read_text()
  for token in ['DOWNLOAD=8*1024*1024, UPLOAD=2*1024*1024','DOWNLOAD,UPLOAD,30000','Synthetic zeros only','progress.measured']:
   self.assertIn(token,s)
 def test_large_font_speed_results_stack(self):
  s=(ROOT/'app/src/main/java/app/diakitw/MainActivity.java').read_text()
  self.assertIn('boolean stackSpeeds=',s)
  self.assertIn('speeds.setOrientation(stackSpeeds?LinearLayout.VERTICAL:LinearLayout.HORIZONTAL)',s)
 def test_contrast(self):
  def luminance(c):
   v=[int(c[i:i+2],16)/255 for i in (0,2,4)]
   v=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v]
   return sum(a*b for a,b in zip(v,[.2126,.7152,.0722]))
  for fg,bg in [('EDF4FC','1D2732'),('AFBECD','1D2732'),('4CBFFF','1D2732'),('A6E640','1D2732'),('141A21','4CBFFF')]:
   a,b=sorted([luminance(fg),luminance(bg)])
   self.assertGreaterEqual((b+.05)/(a+.05),4.5,(fg,bg))
if __name__=='__main__':unittest.main()
