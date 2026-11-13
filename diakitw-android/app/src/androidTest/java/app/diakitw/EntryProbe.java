package app.diakitw;
import android.view.*;
import android.view.accessibility.AccessibilityNodeInfo;
import android.graphics.Rect;
/** Offline fixture, test APK only. */
final class EntryProbe {
 static void run(LayoutProbe p,MainActivity a)throws Exception {
  p.ui(()->{a.autoIp.pause();a.main.removeCallbacks(a.ipTick);a.unwatchNetwork();a.stopIp();});Thread.sleep(300);
  p.ui(()->{
   p.check(a.summary.getText().toString().startsWith("IP / карта · "),"Visible entry label missing");
   p.check("IP / карта".contentEquals(a.summary.getContentDescription()),"Exact accessible entry missing");
   View root=a.findViewById(android.R.id.content);int[] xy=new int[2];root.getLocationOnScreen(xy);p.inspect(root,new Rect(xy[0],xy[1],xy[0]+root.getWidth(),xy[1]+root.getHeight()));
  });p.screenshot("048-main-offline");
  AccessibilityNodeInfo root=p.getUiAutomation().getRootInActiveWindow();boolean clicked=false;
  for(AccessibilityNodeInfo n:root.findAccessibilityNodeInfosByText("IP / карта"))if("IP / карта".contentEquals(n.getContentDescription())&&n.isVisibleToUser()&&n.isClickable())clicked=n.performAction(AccessibilityNodeInfo.ACTION_CLICK);
  p.check(clicked,"Accessible click failed");Thread.sleep(400);p.waitForIdleSync();
  p.ui(()->{p.check(a.ipDialog!=null&&a.ipDialog.isShowing(),"Entry did not open IP directly");p.check(a.testDialog==null,"Entry opened speed help instead");p.check(a.ipCards.size()==1,"Missing IP map card");p.check(!a.ipCards.get(0).copy.isEnabled(),"Unknown IP copy enabled");});
  MapProbe.ready(p,a.ipCards.get(0).map);p.screenshot("048-ip-offline");
  p.ui(()->p.button(a.ipDialog.getWindow().getDecorView(),"Развернуть карту").performClick());Thread.sleep(300);MapProbe.ready(p,a.expandedMap);p.screenshot("048-map-offline");
  p.ui(()->{
   a.ipSnapshot=new Egress.Result("192.0.2.1","FI");a.ipTime="01:02:03";a.ipBadge="Снимок";a.renderIp();
   p.check(a.ipCards.get(0).copy.isEnabled(),"Known IP copy disabled");a.ipCards.get(0).copy.performClick();android.content.ClipboardManager clipboard=(android.content.ClipboardManager)a.getSystemService(android.content.Context.CLIPBOARD_SERVICE);p.check("192.0.2.1".contentEquals(clipboard.getPrimaryClip().getItemAt(0).getText()),"Clipboard readback");
   p.check(a.summary.getText().toString().startsWith("IP / карта · Обновлено"),"Success label");
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
