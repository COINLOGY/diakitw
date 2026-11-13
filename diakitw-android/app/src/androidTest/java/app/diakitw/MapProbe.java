package app.diakitw;
import android.app.AlertDialog;
import android.graphics.*;
import android.net.TrafficStats;
import android.view.View;

/** Only in test APK. Synthetic state fixtures are not provider results. */
final class MapProbe {
 static void ready(LayoutProbe p,MapView map)throws Exception {for(int i=0;i<50;i++){final boolean[] ok={false};p.ui(()->ok[0]=map.data!=null);if(ok[0])return;Thread.sleep(100);}throw new AssertionError("Local map did not load");}
 static void raster(LayoutProbe p,MapView map,boolean point,int color){
  p.check(map.data!=null&&map.data.size()==177,"Wrong bundled geography");p.check(map.paths.size()==177,"Missing real map paths");p.check(map.hasPin()==point,"Fabricated/absent pin");
  Bitmap b=Bitmap.createBitmap(map.getWidth(),map.getHeight(),Bitmap.Config.ARGB_8888);int builds=map.geometryBuilds;for(int i=0;i<20;i++)map.draw(new Canvas(b));p.check(map.geometryBuilds==builds,"Map geometry rebuilt on draw");
  int[] pixels=new int[b.getWidth()*b.getHeight()];b.getPixels(pixels,0,b.getWidth(),0,0,b.getWidth(),b.getHeight());int land=0,highlight=0,lime=0;for(int c:pixels){if(c==MapView.LAND)land++;if(c==MapView.HIGHLIGHT)highlight++;if(c==MainActivity.GREEN)lime++;}
  p.check(land>0||highlight>0,"Blank geographic raster");
  if(point){p.check(Float.isFinite(map.pinX)&&Float.isFinite(map.pinY)&&map.pinX>=0&&map.pinX<map.getWidth()&&map.pinY>=0&&map.pinY<map.getHeight(),"Pin outside viewport");p.check(b.getPixel(Math.round(map.pinX),Math.round(map.pinY))==color,"Pin color/projection mismatch");}
  else p.check(lime==0,"Unknown/country-only raster invented point");
  // In a world thumbnail the real city marker can cover a small country's entire fill.
  if(map.hasCountry()&&!point)p.check(highlight>0,"Country-only shape was not highlighted");b.recycle();
 }
 static void run(LayoutProbe p,MainActivity a)throws Exception {
  p.ui(()->{a.autoIp.pause();a.main.removeCallbacks(a.ipTick);a.stopIp();a.ipSnapshot=null;a.renderIp();a.openIpDetails();});p.waitForIdleSync();MapView mini=a.ipCards.get(0).map;ready(p,mini);Thread.sleep(150);p.waitForIdleSync();
  long rx=TrafficStats.getUidRxBytes(android.os.Process.myUid()),tx=TrafficStats.getUidTxBytes(android.os.Process.myUid());
  p.ui(()->{raster(p,mini,false,0);p.check(!a.ipCards.get(0).copy.isEnabled(),"Unknown copy enabled");});p.screenshot("046-map-fixture-unknown");
  p.ui(()->p.button(a.ipDialog.getWindow().getDecorView(),"Развернуть карту").performClick());p.waitForIdleSync();ready(p,a.expandedMap);Thread.sleep(150);p.ui(()->raster(p,a.expandedMap,false,0));p.screenshot("046-map-fixture-unknown-expanded");
  p.ui(()->{a.mapDialog.getButton(AlertDialog.BUTTON_POSITIVE).performClick();});p.waitForIdleSync();p.ui(()->{p.check(a.expandedMap==null&&a.mapDialog==null&&a.ipDialog.isShowing(),"Collapse did not restore card/release map");a.ipSnapshot=new Egress.Result("192.0.2.1","FI");a.ipBadge="Снимок";a.ipTime="fixture";a.renderIp();});p.waitForIdleSync();p.ui(()->raster(p,mini,false,0));p.screenshot("046-map-fixture-country-only");
  p.ui(()->{a.ipSnapshot=new Egress.Result("192.0.2.1","FI","Fixture city","Fixture ISP","",60,25);a.renderIp();a.openMap();});p.waitForIdleSync();ready(p,a.expandedMap);Thread.sleep(150);p.ui(()->{raster(p,mini,true,MainActivity.GREEN);raster(p,a.expandedMap,true,MainActivity.GREEN);p.check(a.expandedMap.east-a.expandedMap.west==60,"Expanded region not focused");p.check(a.expandedMapCaption.getText().toString().contains("Fixture city"),"Expanded map missing place label");});p.screenshot("046-map-fixture-point-expanded");
  p.ui(()->{a.ipBadge="Устарел";a.renderIp();raster(p,a.expandedMap,true,MainActivity.MUTED);p.check(a.expandedMapCaption.getText().toString().contains("старый снимок"),"Stale map missing notice");});p.screenshot("046-map-fixture-stale-expanded");
  p.ui(()->p.callActivityOnPause(a));p.waitForIdleSync();p.ui(()->{p.check(a.mapDialog==null&&a.expandedMap==null&&a.ipCards.isEmpty(),"Pause retained map windows");p.check(a.test==null&&!SpeedTest.BUSY.get(),"Map started speed test");});
  p.check(rx==TrafficStats.getUidRxBytes(android.os.Process.myUid())&&tx==TrafficStats.getUidTxBytes(android.os.Process.myUid()),"Map loaded network tiles");
  p.report.append("PASS local 177-feature map, unknown/country-only no pin, true coordinate fixture projection, expanded/collapse, stale muted pin, pause refs released, 20 draws cached; UID RX/TX delta0; synthetic fixtures explicitly labelled\n");
 }
}
