package app.diakitw;
import android.app.Instrumentation;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.graphics.Rect;
import android.view.*;
import android.widget.*;
import android.text.Layout;

/** Test APK only: actual Android layout measurements, never shipped in main APK. */
public final class LayoutProbe extends Instrumentation {
 String requestedOrientation;StringBuilder report=new StringBuilder();boolean interactions,idleOnly; String mode;float expectedRadius=-1;
 @Override public void onCreate(Bundle args){super.onCreate(args);requestedOrientation=args.getString("orientation");mode=args.getString("mode");idleOnly="idle".equals(args.getString("mode"));interactions=idleOnly||"interactions".equals(args.getString("mode"));start();}
 Button button(View v,String label){if(v instanceof Button&&(((Button)v).getText().toString().equals(label)||label.equals(v.getContentDescription())))return (Button)v;if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++){Button b=button(g.getChildAt(i),label);if(b!=null)return b;}}return null;}
 void ui(Runnable action){final Throwable[] error={null};runOnMainSync(()->{try{action.run();}catch(Throwable t){error[0]=t;}});if(error[0]!=null)throw new AssertionError(error[0]);}
 void interactions(MainActivity a)throws Exception{
  int uid=android.os.Process.myUid();long rx=android.net.TrafficStats.getUidRxBytes(uid),tx=android.net.TrafficStats.getUidTxBytes(uid);
  ui(()->a.openTest());Thread.sleep(1500);check(a.test==null&&!SpeedTest.BUSY.get(),"Open starts test");
  check(rx==android.net.TrafficStats.getUidRxBytes(uid)&&tx==android.net.TrafficStats.getUidTxBytes(uid),"Traffic on open");
  if(idleOnly){ui(()->a.testDialog.dismiss());report.append("PASS online open/close: no worker, UID byte delta RX=0 TX=0\n");return;}
  for(String action:new String[]{"stop","close","pause"}){
   ui(()->{if(a.testDialog==null)a.openTest();View decor=a.testDialog.getWindow().getDecorView();Button start=button(decor,"Начать"),stop=button(decor,"Стоп");check(start!=null&&start.isEnabled()&&stop!=null&&!stop.isEnabled(),"Idle states");start.performClick();check(!start.isEnabled()&&stop.isEnabled(),"Running states");check(a.test!=null,"No worker");if(action.equals("stop")){stop.performClick();check(start.isEnabled()&&!stop.isEnabled(),"Cancelled states");}else if(action.equals("close"))a.testDialog.dismiss();else callActivityOnPause(a);});
   Thread.sleep(1800);check(a.test==null&&!SpeedTest.BUSY.get(),"Worker alive after "+action);report.append("PASS offline Start → "+action+"; worker stopped\n");
   if(action.equals("stop"))ui(()->a.testDialog.dismiss());
  }
  check(rx==android.net.TrafficStats.getUidRxBytes(uid)&&tx==android.net.TrafficStats.getUidTxBytes(uid),"Unexpected test traffic offline");report.append("UID byte delta: RX=0 TX=0; open has no worker; offline cancellation only\n");
 }
 void ipLife(MainActivity a)throws Exception {
  long rx=android.net.TrafficStats.getUidRxBytes(android.os.Process.myUid()),tx=android.net.TrafficStats.getUidTxBytes(android.os.Process.myUid());
  ui(a::openTest);Thread.sleep(800);check(a.ipRun==null&&!Egress.BUSY.get(),"IP starts on open");
  for(String action:new String[]{"cancel","close","pause"}){
   final int[] oldToken={0};ui(()->{if(a.testDialog==null)a.openTest();View decor=a.testDialog.getWindow().getDecorView();Button b=button(decor,"Определить IP");b.performClick();check(a.ipRun!=null&&!b.isEnabled(),"IP running state");Egress first=a.ipRun;b.performClick();check(a.ipRun==first,"IP overlap");oldToken[0]=a.ipGeneration;if(action.equals("cancel"))button(decor,"Отмена IP").performClick();else if(action.equals("close"))a.testDialog.dismiss();else callActivityOnPause(a);});Thread.sleep(1800);check(a.ipRun==null&&a.ipGeneration>oldToken[0],"IP stale callback generation");check(!Egress.BUSY.get(),"IP still running");if(action.equals("cancel"))ui(()->a.testDialog.dismiss());report.append("PASS IP "+action+"\n");
  }
  check(rx==android.net.TrafficStats.getUidRxBytes(android.os.Process.myUid())&&tx==android.net.TrafficStats.getUidTxBytes(android.os.Process.myUid()),"Offline fixture transferred");
 }
 void autoLifecycle(MainActivity a)throws Exception {
  Thread.sleep(1500);ui(()->{check(a.autoIp.lastStart>0,"No initial auto request");check(a.test==null&&!SpeedTest.BUSY.get(),"Speed auto-start");check(a.networkCallback!=null,"No network callback");check(a.ipRun==null&&!Egress.BUSY.get(),"Offline initial must finish");a.ipSnapshot=new Egress.Result("192.0.2.1","US");a.ipTime="01:02:03";a.renderIp();a.autoIp.due=0;a.startAutoIp();});
  Thread.sleep(2000);ui(()->{check(a.ipRun==null,"Error request not finished");check(a.ipDetails().contains("Ошибка")&&a.ipDetails().contains("01:02:03"),"Error replaced old timestamp");a.networkCallback.onCapabilitiesChanged(null,new android.net.NetworkCapabilities());});waitForIdleSync();
  ui(()->{check(a.ipState.contains("устарел"),"Fake VPN callback not handled");long before=a.autoIp.generation;a.networkCallback.onLost(null);a.networkCallback.onAvailable(null);check(a.ipRun==null,"Debounce absent");});waitForIdleSync();
  final Egress[] cancelled={null};ui(()->{a.autoIp.due=0;a.startAutoIp();cancelled[0]=a.ipRun;check(cancelled[0]!=null,"No forced request");a.startAutoIp();check(a.ipRun==cancelled[0],"Overlapping workers");callActivityOnPause(a);check(cancelled[0].cancelled&&!a.autoIp.foreground&&a.networkCallback==null,"Pause must cancel/unregister");});
  Thread.sleep(2000);ui(()->{check(!Egress.BUSY.get()&&a.ipRun==null&&!a.autoIp.running,"Pause worker not drained");check(a.ipTime.equals("01:02:03"),"Stale result published");long start=a.autoIp.lastStart;a.startAutoIp();check(a.autoIp.lastStart==start,"Hidden request");});
 }
 void check(boolean ok,String message){if(!ok)throw new AssertionError(message);}
 void inspect(View v,Rect area){
  if(v.getVisibility()!=View.VISIBLE)return;
  int[] p=new int[2];v.getLocationOnScreen(p);Rect bounds=new Rect(p[0],p[1],p[0]+v.getWidth(),p[1]+v.getHeight());
  check(area.contains(bounds),"Outside parent: "+v.getClass()+" "+bounds+" parent "+area);
  if(v instanceof ScrollView){android.content.res.Configuration cfg=v.getResources().getConfiguration();boolean typical=cfg.smallestScreenWidthDp>=360&&cfg.fontScale<=1.5f;if(typical)check(!v.canScrollVertically(1)&&!v.canScrollVertically(-1),"Typical main must not scroll: viewport="+v.getHeight()+" content="+((ScrollView)v).getChildAt(0).getHeight()+" config="+cfg.screenHeightDp);}
  if(v.isClickable()){float density=v.getResources().getDisplayMetrics().density;check(v.getWidth()>=48*density&&v.getHeight()>=48*density,"Touch target <48dp: "+v);}
  if(v instanceof TextView){TextView t=(TextView)v;Layout l=t.getLayout();if(l!=null&&t.getText().toString().equals("diakitw"))check(l.getLineCount()==1,"Brand must not wrap");if(l!=null){check(l.getHeight()<=t.getHeight()-t.getCompoundPaddingTop()-t.getCompoundPaddingBottom(),"Text clipped vertically: "+t.getText());for(int i=0;i<l.getLineCount();i++){check(l.getEllipsisCount(i)==0,"Ellipsis: "+t.getText());check(l.getLineWidth(i)<=l.getWidth()+1,"Text clipped horizontally: "+t.getText());}}report.append(t.getText()).append(" ").append(bounds).append('\n');}
  if(v instanceof MainActivity.ResourceGauge){
   MainActivity.ResourceGauge gauge=(MainActivity.ResourceGauge)v;dial(gauge,Double.isFinite(gauge.fraction));
  }
  if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++){View child=g.getChildAt(i);Rect childArea=bounds;if(v instanceof ScrollView){int[] loc=new int[2];child.getLocationOnScreen(loc);childArea=new Rect(loc[0],loc[1],loc[0]+child.getWidth(),loc[1]+child.getHeight());}inspect(child,childArea);}}
 }
 void secondary(View v){
  if(v.getVisibility()!=View.VISIBLE)return;
  if(v instanceof ViewGroup&&!(v instanceof ScrollView)){ViewGroup group=(ViewGroup)v;for(int i=0;i<group.getChildCount();i++){View child=group.getChildAt(i);if(child.getVisibility()==View.VISIBLE)check(child.getLeft()>=0&&child.getTop()>=0&&child.getRight()<=v.getWidth()&&child.getBottom()<=v.getHeight(),"Secondary child out of bounds: "+child);}}
  if(v instanceof TextView){TextView t=(TextView)v;Layout l=t.getLayout();if(l!=null){check(l.getHeight()<=t.getHeight()-t.getCompoundPaddingTop()-t.getCompoundPaddingBottom(),"Secondary text height "+t.getText());for(int i=0;i<l.getLineCount();i++)check(l.getLineMax(i)<=l.getWidth()+1,"Secondary text width "+t.getText());}}
  if(v instanceof Button){float d=v.getResources().getDisplayMetrics().density;check(v.getWidth()>=48*d&&v.getHeight()>=48*d,"Secondary touch size");}
  if(v instanceof MainActivity.SpeedDial){MainActivity.SpeedDial dial=(MainActivity.SpeedDial)v;check(dial.getOrientation()==LinearLayout.HORIZONTAL,"Speed gauge must be RIGHT, values LEFT");check(dial.face.getLeft()>=dial.getChildAt(0).getRight(),"Speed/text overlap");}
  if(v instanceof MainActivity.SpeedFace){MainActivity.SpeedFace face=(MainActivity.SpeedFace)v;dial(face,Double.isFinite(SpeedScale.maximum(face.value)));android.graphics.Bitmap b=android.graphics.Bitmap.createBitmap(v.getWidth(),v.getHeight(),android.graphics.Bitmap.Config.ARGB_8888);face.draw(new android.graphics.Canvas(b));for(int y=0;y<b.getHeight();y++)for(int x=0;x<b.getWidth();x++){int color=b.getPixel(x,y);check(color!=MainActivity.RED,"Speed red danger color");if(!Double.isFinite(face.value))check(color!=MainActivity.GREEN&&color!=MainActivity.BLUE,"Unknown speed needle");}b.recycle();}
  if(v instanceof ViewGroup){ViewGroup group=(ViewGroup)v;for(int i=0;i<group.getChildCount();i++)secondary(group.getChildAt(i));}
 }
 void dial(MainActivity.DialFace face,boolean known){
  float d=face.getResources().getDisplayMetrics().density;if(expectedRadius<0){expectedRadius=face.r;report.append("Radius px: ").append(expectedRadius).append("; stable geometry: 20 draws, zero rebuilds per dial\n");}check(Math.abs(expectedRadius-face.r)<.01,"Different apparent resource/network radii");android.graphics.Paint.FontMetrics fm=face.paint.getFontMetrics();
  String middle=face instanceof MainActivity.SpeedFace?((MainActivity.SpeedFace)face).middle:"50%",left=face instanceof MainActivity.SpeedFace?"0":"0%",right=face instanceof MainActivity.SpeedFace?((MainActivity.SpeedFace)face).end:"100%";check(face.paint.measureText(middle)<=face.getWidth()-2*d,"Midpoint label horizontal clipping");check(face.paint.measureText(left)+face.paint.measureText(right)<face.getWidth()-4*d,"Endpoint labels overlap");
  check(face.labelTop+fm.ascent>=0,"Top label clipped");check(face.labelBottom+fm.descent<=face.getHeight(),"Bottom label clipped");
  check(face.labelTop+fm.descent<=face.cy-face.r-3*d,"Midpoint overlaps arc");check(face.labelBottom+fm.ascent>=face.cy+3*d,"Endpoints overlap arc");
  check(Math.abs(face.arc.width()-face.arc.height())<.01,"Non circular arc");
  check(face.r>14*d,"Unusable radius");
  android.graphics.Bitmap b=android.graphics.Bitmap.createBitmap(face.getWidth(),face.getHeight(),android.graphics.Bitmap.Config.ARGB_8888);android.graphics.Canvas c=new android.graphics.Canvas(b);int builds=face.geometryBuilds;for(int i=0;i<20;i++)face.draw(c);check(face.geometryBuilds==builds,"Geometry rebuilt on draw");
  for(int y=0;y<b.getHeight();y++)for(int x=0;x<b.getWidth();x++){int color=b.getPixel(x,y);boolean tinted=color==MainActivity.GREEN||color==MainActivity.BLUE||color==MainActivity.RED;if(!known)check(!tinted,"Unknown colored needle");if(y>face.cy+4*d&&tinted){
   android.graphics.Path allowed=new android.graphics.Path(face.needlePath);
   android.graphics.Region region=new android.graphics.Region();region.setPath(allowed,new android.graphics.Region(0,0,b.getWidth(),b.getHeight()));
   check(known&&region.contains(x,y),"Lower arc pixel outside approved tail");
  }}
  // Needle interior contains no pixels at all when unknown (ticks stay outside).
  if(!known)for(int y=(int)(face.cy-4*d);y<face.cy;y++)for(int x=(int)(face.cx-4*d);x<face.cx+4*d;x++)check(b.getPixel(x,y)==0,"Unknown has a hub/needle");
  b.recycle();
 }
 void compactSpeed(MainActivity a)throws Exception {
  android.content.res.Configuration config=a.getResources().getConfiguration();check(config.orientation==("1".equals(requestedOrientation)?2:1),"Actual orientation mismatch: "+config);report.append(config).append("\n");
  ui(()->{a.autoIp.pause();a.main.removeCallbacks(a.ipTick);a.unwatchNetwork();a.openTest();});Thread.sleep(500);waitForIdleSync();
  View decor=a.testDialog.getWindow().getDecorView();
  ui(()->{expectedRadius=-1;secondary(decor);speedScroll(decor);check(a.test==null,"Open started speed worker");});
  screenshot("047-speed-idle");
  for(double n:new double[]{0,9999.9,Double.MAX_VALUE}){ui(()->setSpeed(decor,n));Thread.sleep(80);waitForIdleSync();ui(()->{expectedRadius=-1;secondary(decor);if(n!=Double.MAX_VALUE)speedScroll(decor);});}ui(()->setSpeed(decor,Double.NaN));
  ui(()->button(decor,"Начать").performClick());Thread.sleep(300);waitForIdleSync();
  check(a.test==null&&!SpeedTest.BUSY.get(),"Consent started traffic");screenshot("047-speed-consent");tapText("ОТМЕНА");Thread.sleep(300);check(a.test==null,"Cancel consent started traffic");
  ui(()->button(decor,"?").performClick());Thread.sleep(300);tapText("IP / КАРТА");Thread.sleep(400);check(a.ipDialog!=null&&a.ipDialog.isShowing(),"IP details not reachable");ui(()->{check(a.ipCards.size()==1,"Missing map card");a.ipDialog.dismiss();});Thread.sleep(200);
  ui(()->button(decor,"Начать").performClick());Thread.sleep(200);tapText("ЗАПУСТИТЬ");Thread.sleep(100);ui(()->{Button stop=button(decor,"Стоп");if(stop.isEnabled())stop.performClick();});Thread.sleep(1800);check(a.test==null&&!SpeedTest.BUSY.get(),"Offline worker did not drain");
  ui(()->{expectedRadius=-1;secondary(decor);speedScroll(decor);});screenshot("047-speed-offline-result");
  report.append("Offline run: cancellation or immediate network error, no throughput assertion.\n");
 }
 void tapText(String text)throws Exception {
  android.view.accessibility.AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();check(root!=null,"No active accessibility window");
  java.util.List<android.view.accessibility.AccessibilityNodeInfo> nodes=root.findAccessibilityNodeInfosByText(text);boolean clicked=false;
  for(android.view.accessibility.AccessibilityNodeInfo node:nodes)if(node.isClickable()&&node.getText()!=null&&node.getText().toString().equalsIgnoreCase(text)){clicked=node.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK);break;}
  check(clicked,"Button unavailable: "+text);waitForIdleSync();
 }
 void speedScroll(View v){
  if(v.getVisibility()!=View.VISIBLE)return;
  if(v instanceof ScrollView){ScrollView s=(ScrollView)v;boolean typical=v.getResources().getConfiguration().fontScale<=1.5f;report.append("Speed viewport ").append(s.getHeight()).append(" content ").append(s.getChildAt(0).getHeight()).append(" scroll ").append(s.canScrollVertically(1)).append('\n');if(typical)check(!s.canScrollVertically(1)&&!s.canScrollVertically(-1),"Speed page scrolls");}
  if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++)speedScroll(g.getChildAt(i));}
 }
 void setSpeed(View v,double n){if(v instanceof MainActivity.SpeedDial)((MainActivity.SpeedDial)v).update(n);if(v instanceof ViewGroup){ViewGroup g=(ViewGroup)v;for(int i=0;i<g.getChildCount();i++)setSpeed(g.getChildAt(i),n);}}
 void screenshot(String name)throws Exception{android.graphics.Bitmap bitmap=getUiAutomation().takeScreenshot();check(bitmap!=null,"Screenshot unavailable");try(java.io.FileOutputStream out=new java.io.FileOutputStream(new java.io.File(getTargetContext().getCacheDir(),name+".png"))){check(bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,out),"PNG failure");}bitmap.recycle();}
 void live(boolean replay)throws Exception {
  java.io.File record=new java.io.File(getTargetContext().getCacheDir(),"046-map-observed.json");Egress.Result actual;String measured;
  if(replay){java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();try(java.io.InputStream in=new java.io.FileInputStream(record)){byte[] bytes=new byte[512];int n;while((n=in.read(bytes))!=-1){out.write(bytes,0,n);check(out.size()<8192,"Captured model too large");}}String saved=out.toString("UTF-8");actual=Egress.parse(saved);measured=new org.json.JSONObject(saved).getString("capturedAt");}
  else {actual=new Egress().run();measured=new java.text.SimpleDateFormat("HH:mm:ss",java.util.Locale.US).format(new java.util.Date());org.json.JSONObject saved=new org.json.JSONObject();saved.put("success",true).put("ip",actual.ip).put("country_code",actual.country).put("city",actual.city).put("capturedAt",measured);org.json.JSONObject network=new org.json.JSONObject();network.put("isp",actual.isp);if(!actual.asn.isEmpty())network.put("asn",Long.parseLong(actual.asn.substring(2)));saved.put("connection",network);if(Double.isFinite(actual.latitude)&&Double.isFinite(actual.longitude))saved.put("latitude",actual.latitude).put("longitude",actual.longitude);try(java.io.FileOutputStream out=new java.io.FileOutputStream(record)){out.write(saved.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));}}
  Egress.BUSY.set(true);MainActivity a;
  try{a=(MainActivity)startActivitySync(new Intent(getTargetContext(),MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));ui(()->{a.autoIp.pause();a.main.removeCallbacks(a.ipTick);a.unwatchNetwork();a.ipSnapshot=actual;a.ipTime=measured;a.ipBadge="Снимок";a.ipState=replay?"Сохранённое реальное измерение · без нового запроса":"Выход сети на момент проверки";a.renderIp();});}finally{Egress.BUSY.set(false);}
  Thread.sleep(700);waitForIdleSync();screenshot("046-map-live-main");ui(a::openIpDetails);MapProbe.ready(this,a.ipCards.get(0).map);Thread.sleep(500);waitForIdleSync();screenshot("046-map-live-ip-details");ui(a::openMap);MapProbe.ready(this,a.expandedMap);Thread.sleep(400);waitForIdleSync();screenshot("046-map-live-expanded");ui(()->a.mapDialog.getButton(android.app.AlertDialog.BUTTON_POSITIVE).performClick());waitForIdleSync();screenshot("046-map-live-collapsed");ui(()->{check(a.test==null,"Speed auto-start");a.ipDialog.dismiss();a.openTest();});Thread.sleep(500);screenshot("046-map-live-internet");ui(a::finish);
  report.append(replay?"PASS replay of captured actual provider model, zero new lookups; ":"PASS exactly one bounded Egress.run HTTPS lookup with coordinates; ").append("actual data rendered, polling suppressed only in harness; city=").append(!actual.city.isEmpty()).append(" ISP=").append(!actual.isp.isEmpty()).append(" ASN=").append(!actual.asn.isEmpty()).append(" mapPoint=").append(actual.hasPoint()).append("; no speedtest\n");
 }
 @Override public void onStart(){Bundle out=new Bundle();try{
  if("live".equals(mode)||"live-replay".equals(mode)){live("live-replay".equals(mode));out.putString("stream",report.toString());finish(Activity.RESULT_OK,out);return;}
  if("proxy".equals(mode)){ProxyProbe.run();out.putString("stream","PASS proxy fixtures\n");finish(Activity.RESULT_OK,out);return;}
  if("ip".equals(mode)){IpProbe.run();out.putString("stream","PASS IP parsing IPv4/IPv6 and malformed schema\n");finish(Activity.RESULT_OK,out);return;}
  MainActivity a=(MainActivity)startActivitySync(new Intent(getTargetContext(),MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
  Thread.sleep(3500);waitForIdleSync();
  if("cpu".equals(mode)){
   ui(()->{a.autoIp.pause();a.stopIp();a.generation++;a.worker.shutdownNow();a.previousCpu=-1;a.previousWall=-1;check(Double.isNaN(a.sample().cpu),"First CPU must be unknown");a.cpu.update(Double.NaN,"Только diakitw");check(Double.isNaN(a.cpu.gauge.fraction),"Unknown CPU needle");check(a.cpu.information.contains("не всего телефона"),"CPU scope");});
   Thread.sleep(200);ui(()->{double cpu=a.sample().cpu;check(Double.isFinite(cpu)&&cpu>=0&&cpu<=100,"Process CPU sample");a.cpu.update(cpu,"Только diakitw");});Thread.sleep(300);waitForIdleSync();
   ui(()->{View root=a.findViewById(android.R.id.content);int[] p=new int[2];root.getLocationOnScreen(p);inspect(root,new Rect(p[0],p[1],p[0]+root.getWidth(),p[1]+root.getHeight()));int height=a.cpu.getHeight();for(MainActivity.Metric m:new MainActivity.Metric[]{a.cpu,a.ram,a.disk,a.battery})check(Math.abs(m.getHeight()-height)<=1,"Unequal resource cards");});screenshot("051-main");ui(a::finish);out.putString("stream","PASS CPU scope, first sample unknown, actual process sample, four equal cards and bounds\n"+report);finish(Activity.RESULT_OK,out);return;
  }
  if("entry".equals(mode)){EntryProbe.run(this,a);out.putString("stream",report.toString());finish(Activity.RESULT_OK,out);return;}
  if("compact".equals(mode)){compactSpeed(a);ui(a::finish);out.putString("stream","PASS compact speed native bounds, consent/cancel, details and offline Stop\n"+report);finish(Activity.RESULT_OK,out);return;}
  if("map".equals(mode)){MapProbe.run(this,a);ui(a::finish);out.putString("stream",report.toString());finish(Activity.RESULT_OK,out);return;}
  if("card".equals(mode)){
   ui(()->{a.autoIp.pause();a.stopIp();a.ipSnapshot=null;a.renderIp();a.openTest();});waitForIdleSync();
   ui(()->{Button copy=button(a.testDialog.getWindow().getDecorView(),"Копировать IP");check(copy!=null,"Missing native IP copy button");check(!copy.isEnabled(),"Unknown IP copy enabled");a.ipSnapshot=new Egress.Result("192.0.2.1","FI","Helsinki","Example ISP","AS64496");a.ipTime="01:02:03";a.renderIp();check(copy.isEnabled(),"Known copy disabled");copy.performClick();android.content.ClipboardManager clipboard=(android.content.ClipboardManager)a.getSystemService(android.content.Context.CLIPBOARD_SERVICE);check(clipboard.getPrimaryClip().getItemAt(0).getText().toString().equals("192.0.2.1"),"Native clipboard wrong");check(a.test==null,"Copy starts speed test");});
   ui(()->{MainActivity.IpCard card=a.ipCards.get(0);check(card.address.isTextSelectable(),"IP not selectable");check(card.city.getVisibility()==View.VISIBLE&&card.network.getVisibility()==View.VISIBLE,"Rich fields hidden");a.ipSnapshot=new Egress.Result("192.0.2.1","FI");a.renderIp();check(card.city.getVisibility()==View.GONE&&card.network.getVisibility()==View.GONE,"Missing fields shown");callActivityOnPause(a);check(a.ipBadge.equals("Устарел"),"Paused snapshot not marked stale");});waitForIdleSync();ui(()->check(a.ipCards.isEmpty(),"Detached IP cards retained"));
   ui(a::finish);out.putString("stream","PASS native IP card unknown/copy/clipboard, optional fields, pause stale/unsubscribe, no speed worker\n");finish(Activity.RESULT_OK,out);return;
  }
  if("perf".equals(mode)){ui(()->{a.generation++;a.worker.shutdownNow();a.ram.update(50,"0.7 / 1.4 GiB");});Thread.sleep(500);waitForIdleSync();ui(()->{check(!a.ram.gauge.isDirty(),"Initial frame not drawn");a.ram.update(50,"0.7 / 1.4 GiB");check(!a.ram.gauge.isDirty(),"Unchanged sample invalidates gauge");check(!a.ram.value.isLayoutRequested()&&!a.ram.detail.isLayoutRequested(),"Unchanged sample requests text layout");});ui(a::finish);out.putString("stream","PASS unchanged sample: no gauge invalidation or text layout request\n");finish(Activity.RESULT_OK,out);return;}
  if("auto".equals(mode)){autoLifecycle(a);ui(a::finish);out.putString("stream","PASS auto initial, fake route callback, dated error snapshot, pause cancellation, stale generations, no speed auto-start\n"+report);finish(Activity.RESULT_OK,out);return;}
  if("ip-life".equals(mode)){ipLife(a);ui(()->a.finish());out.putString("stream","PASS IP Start/Cancel/close/pause stale callbacks and no overlap\n"+report);finish(Activity.RESULT_OK,out);return;}
  if(interactions){interactions(a);ui(()->a.finish());out.putString("stream","PASS native button/lifecycle checks\n"+report);finish(Activity.RESULT_OK,out);return;}
  ui(()->{for(MainActivity.Metric m:new MainActivity.Metric[]{a.ram,a.disk,a.battery}){check(m.detail.getParent()!=null,"Resource details must remain visible");View gauge=m.getChildAt(m.getChildCount()-1);check(gauge.getLeft()>=m.getChildAt(0).getRight(),"Gauge must be RIGHT of text");}a.ram.update(Double.NaN,"Недоступно");check(a.ram.getVisibility()==View.VISIBLE&&a.ram.value.getText().toString().equals("Н/Д"),"Unknown must stay visible N/A");});
  ui(()->{a.ipSnapshot=new Egress.Result("2001:db8:abcd:1234:5678:90ab:cdef:1234","FI","Helsinki","Example ISP","AS64496");a.ipTime="23:59:59";a.renderIp();});
  for(String status:new String[]{null,"Готово\n↓ 9999.9   ↑ 9999.9 Мбит/с\nHTTP RTT 9999.9 мс","Ошибка сети / HTTP · результат неполный\n↓ Н/Д   ↑ Н/Д Мбит/с\nHTTP RTT Н/Д мс"}){
   runOnMainSync(()->{if(status!=null){a.last=status;a.updateSummary();}});Thread.sleep(300);waitForIdleSync();
   final Throwable[] failure={null};runOnMainSync(()->{try{View root=a.findViewById(android.R.id.content);int[] pos=new int[2];root.getLocationOnScreen(pos);inspect(root,new Rect(pos[0],pos[1],pos[0]+root.getWidth(),pos[1]+root.getHeight()));}catch(Throwable t){failure[0]=t;}});if(failure[0]!=null)throw new AssertionError(failure[0]);
  }
  ui(()->{a.generation++;a.worker.shutdownNow();});
  for(double reading:new double[]{0,20,20.0001,80,80.0001,100,Double.NaN,-1,101,Double.POSITIVE_INFINITY}){
   ui(()->{for(MainActivity.Metric m:new MainActivity.Metric[]{a.ram,a.disk,a.battery}){m.update(reading,m==a.battery?"Питание подключено":"0.7 / 1.9 GiB");boolean known=Double.isFinite(Gauge.fraction(reading));check(known==Double.isFinite(m.gauge.fraction),"Needle availability");check(m.value.getCurrentTextColor()==MainActivity.resourceColor(reading,m==a.battery),"Number color");check(known||m.value.getText().toString().equals("Н/Д"),"Unknown number");}});
   Thread.sleep(80);waitForIdleSync();ui(()->{View root=a.findViewById(android.R.id.content);int[] pos=new int[2];root.getLocationOnScreen(pos);inspect(root,new Rect(pos[0],pos[1],pos[0]+root.getWidth(),pos[1]+root.getHeight()));});
  }
  ui(a::openTest);Thread.sleep(300);waitForIdleSync();
  for(double n:new double[]{Double.NaN,0,35,9999.9,Double.MAX_VALUE}){ui(()->setSpeed(a.testDialog.getWindow().getDecorView(),n));Thread.sleep(100);waitForIdleSync();ui(()->secondary(a.testDialog.getWindow().getDecorView()));}
  ui(()->a.testDialog.dismiss());waitForIdleSync();ui(a::openIpDetails);Thread.sleep(300);waitForIdleSync();ui(()->secondary(a.ipDialog.getWindow().getDecorView()));
  ui(a::openMap);Thread.sleep(300);waitForIdleSync();ui(()->secondary(a.mapDialog.getWindow().getDecorView()));
  report.append("PASS secondary native text/touch bounds and speed unknown/zero/overflow rasters; rich IPv6 card, mini-map and expanded map dialog\n");
  runOnMainSync(()->a.finish());out.putString("stream","PASS actual Android view/text/touch and gauge label bounds, right alignment, unknown raster and threshold fixtures; real metrics + explicit test-only result fixtures\n"+report);finish(Activity.RESULT_OK,out);
 }catch(Throwable t){out.putString("stream","FAIL "+t+"\n"+report);finish(Activity.RESULT_CANCELED,out);}}
}
