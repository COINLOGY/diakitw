package app.diakitw;
import android.view.*;
import android.view.accessibility.AccessibilityNodeInfo;
import android.graphics.Rect;
/** Offline fixture, test APK only. */
final class EntryProbe {
 static void singleFlag(CharSequence displayed,String label,String flag,LayoutProbe p){
  String text=displayed.toString();
  p.check(label.startsWith(flag+" "),"Country flag must precede its name");
  p.check(text.contains(label),"Country name/flag absent: "+text);
  p.check(text.indexOf(flag)==text.lastIndexOf(flag),"Duplicate country flags: "+text);
 }
 static void run(LayoutProbe p,MainActivity a)throws Exception {
  p.ui(()->{a.autoIp.pause();a.main.removeCallbacks(a.ipTick);a.unwatchNetwork();a.stopIp();});Thread.sleep(300);
  p.ui(()->{
   p.check(a.summary.getText().toString().startsWith("IP / карта · "),"Visible entry label missing");
   p.check(a.summary.getText().toString().contentEquals(a.summary.getContentDescription()),"Accessible entry omits visible IP/country");
   View root=a.findViewById(android.R.id.content);int[] xy=new int[2];root.getLocationOnScreen(xy);p.inspect(root,new Rect(xy[0],xy[1],xy[0]+root.getWidth(),xy[1]+root.getHeight()),true);Rect visible=new Rect();p.check(a.persistentMap.getGlobalVisibleRect(visible)&&visible.height()>=a.persistentMap.getHeight()*.75,"Entry map hidden");
  });p.screenshot("048-main-offline");
  p.ui(()->a.summary.requestRectangleOnScreen(new Rect(0,0,a.summary.getWidth(),a.summary.getHeight()),true));p.waitForIdleSync();
  final int[] visibility=new int[3];p.ui(()->{Rect box=new Rect();visibility[0]=a.summary.getGlobalVisibleRect(box)?1:0;visibility[1]=box.height();visibility[2]=a.summary.getHeight();});
  AccessibilityNodeInfo root=p.getUiAutomation().getRootInActiveWindow();boolean clicked=false;int entryMask=0;
  for(AccessibilityNodeInfo n:root.findAccessibilityNodeInfosByText("IP / карта")){
   entryMask|=1;boolean named=n.getContentDescription()!=null&&n.getContentDescription().toString().startsWith("IP / карта");
   if(named)entryMask|=2;if(n.isVisibleToUser())entryMask|=4;if(n.isClickable())entryMask|=8;
   if(named&&n.isVisibleToUser()&&n.isClickable()){entryMask|=16;clicked|=n.performAction(AccessibilityNodeInfo.ACTION_CLICK);}
  }
  p.check(clicked,"Accessible click failed entryMask="+entryMask+" shown="+visibility[0]+" visible="+visibility[1]+" total="+visibility[2]);Thread.sleep(400);p.waitForIdleSync();
  p.ui(()->{p.check(a.ipDialog!=null&&a.ipDialog.isShowing(),"Entry did not open IP directly");p.check(a.testDialog==null,"Entry opened speed help instead");p.check(a.ipCards.size()==1,"Missing IP map card");p.check(!a.ipCards.get(0).copy.isEnabled(),"Unknown IP copy enabled");});
  MapProbe.ready(p,a.ipCards.get(0).map);p.screenshot("048-ip-offline");
  p.ui(()->p.button(a.ipDialog.getWindow().getDecorView(),"Развернуть карту").performClick());Thread.sleep(300);MapProbe.ready(p,a.expandedMap);p.screenshot("048-map-offline");
  p.ui(()->{
   a.ipSnapshot=new Egress.Result("192.0.2.1","FI");a.ipTime="01:02:03";a.ipBadge="Снимок";a.renderIp();
   p.check(a.ipCards.get(0).copy.isEnabled(),"Known IP copy disabled");a.ipCards.get(0).copy.performClick();android.content.ClipboardManager clipboard=(android.content.ClipboardManager)a.getSystemService(android.content.Context.CLIPBOARD_SERVICE);p.check("192.0.2.1".contentEquals(clipboard.getPrimaryClip().getItemAt(0).getText()),"Clipboard readback");
   p.check(a.summary.getText().toString().startsWith("IP / карта · Обновлено"),"Success label");
   String country=a.countryLabel(),flag=MainActivity.flag("FI");
   singleFlag(a.summary.getText(),country,flag,p);
   singleFlag(a.summary.getContentDescription(),country,flag,p);
   singleFlag(a.ipCards.get(0).location.getText(),country,flag,p);
   singleFlag(a.expandedMapCaption.getText(),country,flag,p);
   singleFlag(a.ipDetails(),country,flag,p);
   p.check(a.ipCards.get(0).state.getText().toString().startsWith("Обновлено"),"Detail success label");
   p.check(!a.expandedMap.stale&&!a.ipCards.get(0).map.stale&&!a.mapPrecision().contains("старый"),"Fresh snapshot shown stale");
   for(String state:new String[]{"Устарел","Ошибка","Проверка…","Лимит"}){a.ipBadge=state;a.renderIp();p.check(a.expandedMap.stale&&a.ipCards.get(0).map.stale&&a.mapPrecision().contains("старый"),"Stale state lost: "+state);p.check(a.ipTime.equals("01:02:03"),"Timestamp changed");p.check(a.summary.getText().toString().startsWith("IP / карта · "+state),"Entry lost during status change");}
   a.mapDialog.dismiss();a.ipDialog.dismiss();a.ipBadge="Снимок";a.renderIp();
  });Thread.sleep(300);p.screenshot("048-main-success-fixture");
  p.ui(()->a.openTest());Thread.sleep(300);p.ui(()->p.speedScroll(a.testDialog.getWindow().getDecorView()));p.screenshot("048-speed-idle");
  p.ui(()->{p.check(a.test==null&&!SpeedTest.BUSY.get(),"Unexpected speed workload");a.finish();});
  p.report.append("PASS exact visible/accessibility IP / карта; accessibility click directly to IP, map expand; fresh/error/stale/checking/quota state fixtures; main + speed no-scroll; no external lookup repeated.\n");
 }
}
