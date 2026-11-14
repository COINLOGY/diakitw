package app.diakitw;

import android.app.*;
import android.content.*;
import android.content.res.Configuration;
import android.content.res.ColorStateList;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.*;
import android.net.*;
import android.util.Log;
import android.view.*;
import android.widget.*;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import java.util.Locale;
import java.util.concurrent.*;

public final class MainActivity extends Activity {
 static final int BG=0xff141a21,CARD=0xff1d2732,TEXT=0xffedf4fc,MUTED=0xffafbecd,BLUE=0xff4cbfff,GREEN=0xffa6e640,RED=0xffff747e,LINE=0xff354452;
 Updates.Policy updates;Updates.Fetch updateFetch;Thread updateThread;Updates.Release updateOffer;TextView updateNotice;AlertDialog updateDialog;
 final Handler updateResults=new Handler(Looper.getMainLooper());
 final Runnable updateTick=new Runnable(){public void run(){if(updates==null||!updates.active)return;checkUpdates(false);main.postDelayed(this,3000);}};
 void saveUpdates(){getPreferences(MODE_PRIVATE).edit().putString("updateChannel",updates.channel).putLong("updateSuccess",updates.success).putLong("updateAttempt",updates.attempt).putLong("updateFailure",updates.failure).apply();}
 void stopUpdates(){if(updates!=null)updates.stop();if(updateFetch!=null)updateFetch.cancel();main.removeCallbacks(updateTick);if(updateDialog!=null){updateDialog.dismiss();updateDialog=null;}}
 void checkUpdates(boolean manual){
  if(updateThread!=null&&updateThread.isAlive()){if(manual)Toast.makeText(this,"Проверка уже выполняется",Toast.LENGTH_SHORT).show();return;}
  if(!updates.begin(manual,System.currentTimeMillis())){if(manual)Toast.makeText(this,"Повторная проверка — не чаще раза в минуту",Toast.LENGTH_LONG).show();return;}
  saveUpdates();final int token=updates.generation;final String channel=updates.channel;final Updates.Fetch run=new Updates.Fetch();updateFetch=run;
  if(manual)Toast.makeText(this,"Проверка обновлений…",Toast.LENGTH_SHORT).show();
  updateThread=new Thread(()->{Updates.Release result=null;boolean success=false;try{result=Updates.select(run.run(),channel);success=true;}catch(java.io.IOException|RuntimeException ignored){}final Updates.Release offer=result;final boolean ok=success;
   updateResults.post(()->{if(updateFetch==run)updateFetch=null;if(!updates.complete(token,ok,System.currentTimeMillis()))return;saveUpdates();if(ok){updateOffer=offer;updateNotice.setVisibility(offer==null?View.GONE:View.VISIBLE);if(offer!=null)updateNotice.setText("Доступна diakitw "+offer.version+" · Подробнее");}if(manual){if(offer!=null)showUpdateOffer();else showText("Обновления",ok?"Новых версий для выбранного канала нет.":"Не удалось проверить обновления. Проверьте сеть и повторите позже.");}});
  },"update-check");updateThread.setDaemon(true);updateThread.start();
 }
 void updatesMenu(){
  if(updateDialog!=null)updateDialog.dismiss();
  updateDialog=new AlertDialog.Builder(this).setTitle("Обновления · 0.5.5a (55)").setSingleChoiceItems(new String[]{"Стабильный","Тестовый"},updates.channel.equals("stable")?0:1,(d,which)->{if(updateFetch!=null)updateFetch.cancel();updates.channel(which==0?"stable":"preview");updateOffer=null;updateNotice.setVisibility(View.GONE);saveUpdates();})
   .setPositiveButton("Проверить обновления",(d,w)->checkUpdates(true)).setNegativeButton("Позже",null).show();updateDialog.getWindow().setBackgroundDrawable(panel());
 }
 void showUpdateOffer(){
  final Updates.Release offer=updateOffer;if(offer==null)return;if(updateDialog!=null)updateDialog.dismiss();
  updateDialog=new AlertDialog.Builder(this).setTitle("Доступна diakitw "+offer.version).setMessage(offer.notes+"\n\nУстановка вручную. Скачать — открыть GitHub в браузере. Автоустановки нет. SHA256 в feed не является независимой подписью.")
   .setPositiveButton("Скачать",(d,w)->{if(!Updates.validURL(offer.url,offer.version))return;try{Intent browser=new Intent(Intent.ACTION_VIEW,Uri.parse(offer.url));browser.addCategory(Intent.CATEGORY_BROWSABLE);startActivity(browser);}catch(RuntimeException e){showText("Обновления","Не удалось открыть браузер");}})
   .setNegativeButton("Позже",(d,w)->{updateOffer=null;updateNotice.setVisibility(View.GONE);}).show();updateDialog.getWindow().setBackgroundDrawable(panel());
 }
 final Handler main=new Handler(Looper.getMainLooper());
 final Handler speedResults=new Handler(Looper.getMainLooper());
 ScheduledExecutorService worker; int generation,testGeneration; SpeedTest test; AlertDialog testDialog;
 Metric cpu,ram,disk,battery; long previousCpu=-1,previousWall=-1; TextView summary; String last="Ещё не измерено";
 boolean compact,landscape; Egress ipRun; int ipGeneration;
 final AutoEgress autoIp=new AutoEgress();final Handler ipResults=new Handler(Looper.getMainLooper());
 ConnectivityManager connectivity;ConnectivityManager.NetworkCallback networkCallback;
 final java.util.ArrayList<IpCard> ipCards=new java.util.ArrayList<>();AlertDialog ipDialog,mapDialog;MapView expandedMap;TextView expandedMapCaption;
 Egress.Result ipSnapshot;String ipTime="",ipState="Ожидание автоматической проверки",ipBadge="Ожидание";
 static final String IP_NOTICE="2ip через EMCx · приблизительная геолокация публичного IP, не GPS телефона. При VPN это выход сети, не доказательство работы VPN. Город и сеть показаны только при наличии данных провайдера; иногда доступна только страна.\n\nHTTPS автоматически при входе, событиях сети и примерно каждые 60 с, только пока приложение видно. Смена VPN без события ОС обнаруживается не сразу. До 4 KiB, тайм-аут 10 с. Основной GET: aia.emcx.pro/diakitw-api/geo, без параметров и токена в приложении. EMCx и 2ip получают IP выхода; серверный кеш 1 ч, общая квота 300/день и 9000/месяц. Только при ошибке — прежний IPwho.is. Нет GPS, файлов и ID устройства. Карта встроенная: Natural Earth, public domain, масштаб 1:110m; обобщённые границы де-факто, малые территории могут отсутствовать. Нет тайлов и сетевых запросов карты. Точка только при наличии города и допустимых координат IPwho.is, приблизительная, не GPS. Иначе выделяется страна без точки. Провайдер видит публичный IP и может хранить журналы согласно ipwhois.io/privacy. Бесплатный endpoint: 1000 запросов/день на общий внешний IP, без гарантии доступности. При HTTP 429 — пауза 24 ч, включая перезапуск. Документация: ipwhois.io/documentation.";
 final Runnable ipTick=new Runnable(){public void run(){if(!autoIp.foreground)return;startAutoIp();main.postDelayed(this,1000);}};
 @Override public void onCreate(Bundle state){
  super.onCreate(state);if(state!=null)last=state.getString("summary",last);
  SharedPreferences prefs=getPreferences(MODE_PRIVATE);updates=new Updates.Policy(prefs.getString("updateChannel","preview"),prefs.getLong("updateSuccess",0),prefs.getLong("updateAttempt",0),prefs.getLong("updateFailure",0),System.currentTimeMillis());
  getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);
  Configuration config=getResources().getConfiguration();
  landscape=config.orientation==Configuration.ORIENTATION_LANDSCAPE&&config.fontScale<=1.5f;compact=landscape||config.fontScale>1.3f;
  LinearLayout root=column();if(landscape)root.setOrientation(LinearLayout.HORIZONTAL);root.setBackgroundColor(BG);root.setPadding(dp(16),dp(6),dp(16),dp(10));
  root.setOnApplyWindowInsetsListener((v,i)->{v.setPadding(dp(16)+i.getSystemWindowInsetLeft(),dp(6)+i.getSystemWindowInsetTop(),dp(16)+i.getSystemWindowInsetRight(),dp(10)+i.getSystemWindowInsetBottom());return i;});
  LinearLayout header=new LinearLayout(this);header.setGravity(Gravity.CENTER_VERTICAL);
  ImageView logo=new ImageView(this);logo.setImageResource(R.drawable.ic_diakitw);logo.setContentDescription("diakitw — Modular W");header.addView(logo,new LinearLayout.LayoutParams(dp(36),dp(36)));
  TextView title=text("diakitw",24,TEXT);title.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));title.setPadding(dp(8),0,0,0);header.addView(title,new LinearLayout.LayoutParams(0,-2,1));
  Button help=button("?",v->help());help.setContentDescription("Обзор — справка");if(!landscape)header.addView(help,new LinearLayout.LayoutParams(dp(48),dp(48)));LinearLayout rail=column();if(landscape){rail.addView(header);LinearLayout.LayoutParams hp=new LinearLayout.LayoutParams(dp(48),dp(48));hp.gravity=Gravity.END;rail.addView(help,hp);LinearLayout.LayoutParams rp=new LinearLayout.LayoutParams(dp(184),-1);rp.setMargins(0,0,dp(10),0);ScrollView railViewport=new ScrollView(this);railViewport.setFillViewport(true);railViewport.addView(rail);root.addView(railViewport,rp);}else root.addView(header);
  LinearLayout metrics=new LinearLayout(this){@Override protected void onMeasure(int w,int h){int equal=0;for(int i=0;i<getChildCount();i++){View child=getChildAt(i);child.getLayoutParams().height=-2;}super.onMeasure(w,View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));for(int i=0;i<getChildCount();i++)equal=Math.max(equal,getChildAt(i).getMeasuredHeight());for(int i=0;i<getChildCount();i++)getChildAt(i).getLayoutParams().height=equal;super.onMeasure(w,h);}};metrics.setOrientation(LinearLayout.VERTICAL);metrics.setPadding(0,dp(2),0,dp(2));
  cpu=new Metric("CPU APP");ram=new Metric("RAM");disk=new Metric("Хранилище");battery=new Metric("Батарея");
  for(Metric m:new Metric[]{cpu,ram,disk,battery}){LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,dp(dialHeight()+8),1);p.setMargins(dp(3),dp(1),dp(3),dp(1));metrics.addView(m,p);}
  ScrollView metricViewport=new ScrollView(this);metricViewport.setFillViewport(true);metricViewport.addView(metrics);root.addView(metricViewport,landscape?new LinearLayout.LayoutParams(0,-1,1):new LinearLayout.LayoutParams(-1,0,1));
  LinearLayout footer=new LinearLayout(this);footer.setOrientation(LinearLayout.VERTICAL);footer.setGravity(Gravity.CENTER_VERTICAL);
  updateNotice=text("",14,BLUE);updateNotice.setVisibility(View.GONE);updateNotice.setMinHeight(dp(48));updateNotice.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);updateNotice.setOnClickListener(v->showUpdateOffer());footer.addView(updateNotice,new LinearLayout.LayoutParams(-1,-2));
  summary=text(last,14,TEXT);summary.setPadding(dp(12),dp(6),dp(12),dp(6));summary.setBackground(shape(CARD,LINE,14));summary.setMinHeight(dp(48));summary.setGravity(Gravity.CENTER_VERTICAL);summary.setOnClickListener(v->openIpDetails());updateSummary();
  summary.setIncludeFontPadding(false);summary.setTextSize(18);footer.addView(summary,new LinearLayout.LayoutParams(-1,-2));
  Button internet=button("Тест интернета",v->openTest());styleButton(internet,true);internet.setMinHeight(dp(56));footer.addView(internet,new LinearLayout.LayoutParams(-1,-2));if(landscape){Space spacer=new Space(this);rail.addView(spacer,new LinearLayout.LayoutParams(-1,0,1));rail.addView(footer);}else root.addView(footer);setContentView(root);
 }
 LinearLayout column(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.VERTICAL);return l;}
 Button button(String s,View.OnClickListener action){Button b=new Button(this);b.setText(s);b.setTextSize(16);b.setIncludeFontPadding(false);b.setAllCaps(false);b.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));b.setOnClickListener(action);styleButton(b,false);return b;}
 void styleButton(Button b,boolean primary){
  b.setMinimumHeight(dp(48));b.setMinHeight(dp(48));b.setPadding(dp(12),dp(4),dp(12),dp(4));b.setStateListAnimator(null);
  b.setTextColor(new ColorStateList(new int[][]{new int[]{-android.R.attr.state_enabled},new int[]{}},new int[]{MUTED,primary?BG:TEXT}));
  StateListDrawable states=new StateListDrawable();states.addState(new int[]{-android.R.attr.state_enabled},shape(CARD,LINE,14));states.addState(new int[]{},shape(primary?BLUE:CARD,primary?BLUE:LINE,14));
  b.setBackground(new RippleDrawable(ColorStateList.valueOf(primary?0x33000000:0x444cbfff),states,shape(0xffffffff,0xffffffff,14)));
 }
 TextView text(String s,int size,int color){TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(color);t.setFontFeatureSettings("tnum");return t;}
 int dp(float n){return Math.round(n*getResources().getDisplayMetrics().density);}
 GradientDrawable shape(int color,int stroke,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));d.setStroke(dp(1),stroke);return d;}
 GradientDrawable panel(){return shape(CARD,LINE,20);}
 void showText(String title,String message){AlertDialog d=new AlertDialog.Builder(this).setTitle(title).setMessage(message).setPositiveButton("Понятно",null).show();d.getWindow().setBackgroundDrawable(panel());d.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(BLUE);}
 void showHelp(String title,String message){AlertDialog d=new AlertDialog.Builder(this).setTitle(title).setMessage(message+"\n\nОбновления: HTTPS GitHub Pages, до 32 KiB, 10 с. Автоматически раз в 24 ч при активном приложении, без автоустановки. GitHub видит IP. Канал по умолчанию: тестовый.").setNeutralButton("Обновления",(x,w)->updatesMenu()).setPositiveButton("Понятно",null).show();d.getWindow().setBackgroundDrawable(panel());}
 void help(){showHelp("Обзор · diakitw 0.5.5a","RAM: (totalMem − availMem) / totalMem. Хранилище: StatFs total − available, том данных приложения; не здоровье накопителя. Батарея: системный заряд. Нажмите карточку для подробностей. Недоступные показания: Н/Д, без стрелки. Шкалы 0–100%: до 20% зелёный, до 80% синий, выше красный; для заряда батареи цвета обращены. RAM и хранилище: занято / всего GiB.\n\nCPU APP: только процесс diakitw, не нагрузка всего телефона. Разность CPU-времени / монотонное время / число доступных логических CPU. Первый, сброшенный и задержанный более 5 с интервал — Н/Д. SWAP и UID-трафик не показываются.\n\nТест интернета запускается только вручную, отдельно от мониторинга. HTTP RTT — не ICMP ping; включает установление соединения, TLS и обработку сервера. Потери пакетов не измеряются. HTTP jitter — среднее абсолютных разностей соседних успешных проб, только при 2–3 пробах. Скорости одного короткого потока включают накладные задержки и не являются максимумом линии.\n\nСбор и тест останавливаются при уходе из приложения, повороте или закрытии теста. Последний отчёт сохраняется локально и доступен через «Последний отчёт / JSON». Payload-файлы не создаются.");}
 void updateSummary(){
  String label="IP / карта · "+ipStatusLabel();
  String visible=label+"\n"+(ipSnapshot==null?"Н/Д\nСтрана: Н/Д":ipSnapshot.ip+"\n"+countryLabel()+(ipSnapshot.city.isEmpty()?"":" · ≈ "+ipSnapshot.city));
  SpannableString styled=new SpannableString(visible);styled.setSpan(new ForegroundColorSpan(BLUE),0,label.length(),Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
  styled.setSpan(new android.text.style.RelativeSizeSpan(12f/18f),0,label.length(),Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);summary.setText(styled);summary.setContentDescription("IP / карта");
 }
 String ipStatusLabel(){return ipBadge.equals("Снимок")?"Обновлено":ipBadge;}
 static String flag(String country){return new String(Character.toChars(0x1f1e6+country.charAt(0)-'A'))+new String(Character.toChars(0x1f1e6+country.charAt(1)-'A'));}
 String countryLabel(){return ipSnapshot==null||ipSnapshot.country.isEmpty()?"Страна не определена":flag(ipSnapshot.country)+" "+new Locale("",ipSnapshot.country).getDisplayCountry(new Locale("ru"));}
 @Override protected void onResume(){super.onResume();updates.start(System.currentTimeMillis());main.post(updateTick);long remaining=Math.max(0,Math.min(86400000L,getPreferences(MODE_PRIVATE).getLong("ipQuotaUntil",0)-System.currentTimeMillis()));autoIp.blockUntil(SystemClock.elapsedRealtime()+remaining);if(remaining>0){ipBadge="Лимит";ipState="Лимит IPwho.is · проверка отложена до 24 ч";renderIp();}autoIp.resume(SystemClock.elapsedRealtime());watchNetwork();main.post(ipTick);synchronized(this){previousCpu=-1;previousWall=-1;}cpu.update(Double.NaN,"Только diakitw");int token=++generation;worker=Executors.newSingleThreadScheduledExecutor();worker.scheduleWithFixedDelay(()->{Sample s;synchronized(this){if(token!=generation)return;s=sample();}main.post(()->{if(token==generation){cpu.update(s.cpu,"Только diakitw");ram.update(s.ram,s.ramDetail);disk.update(s.disk,s.diskDetail);battery.update(s.battery,s.power);Log.d("diakitw","sample published");}});},0,3,TimeUnit.SECONDS);}
 @Override protected void onPause(){stopUpdates();generation++;autoIp.pause();if(ipSnapshot!=null){ipBadge="Устарел";ipState="Приложение было скрыто · снимок не текущий";renderIp();}unwatchNetwork();stopIp();stopTest();if(mapDialog!=null){mapDialog.dismiss();mapDialog=null;expandedMap=null;expandedMapCaption=null;}if(ipDialog!=null){ipDialog.dismiss();ipDialog=null;}if(testDialog!=null){testDialog.dismiss();testDialog=null;}if(worker!=null){worker.shutdownNow();worker=null;}main.removeCallbacksAndMessages(null);Log.i("diakitw","sampler paused; callbacks cancelled");super.onPause();}
 @Override public void onSaveInstanceState(Bundle out){out.putString("summary",test!=null?"Отменено при смене экрана":last);super.onSaveInstanceState(out);}
 void stopTest(){if(test!=null){test.cancel();Log.i("diakitw","speed cancellation requested");}}
 boolean saveSpeedReport(SpeedTest.Result r){String json=SpeedReport.json(r);return getPreferences(MODE_PRIVATE).edit().putString("speedReportJson",json).putString("speedReportText",SpeedReport.text(r)).commit();}
 void showSpeedReport(){
  SharedPreferences p=getPreferences(MODE_PRIVATE);String json=p.getString("speedReportJson","");String report=p.getString("speedReportText","Сохранённого результата пока нет. После завершения, ошибки или отмены здесь будет последний отчёт.");
  AlertDialog.Builder b=new AlertDialog.Builder(this).setTitle("Последний отчёт").setMessage(report).setNegativeButton("Закрыть",null);
  if(!json.isEmpty())b.setPositiveButton("Поделиться JSON",(d,w)->{Intent send=new Intent(Intent.ACTION_SEND);send.setType("text/plain");send.putExtra(Intent.EXTRA_SUBJECT,"diakitw · отчёт интернета");send.putExtra(Intent.EXTRA_TEXT,json);try{startActivity(Intent.createChooser(send,"Экспорт отчёта JSON"));}catch(RuntimeException e){showText("Отчёт","Не удалось открыть экспорт");}});
  AlertDialog d=b.show();d.getWindow().setBackgroundDrawable(panel());
 }
 void openTest(){
  if(testDialog!=null&&testDialog.isShowing())return;
  if(test!=null){showText("Тест интернета","Предыдущий тест завершается. Дождитесь остановки соединения.");return;}
  LinearLayout shell=column();shell.setPadding(dp(12),dp(4),dp(12),dp(4));
  LinearLayout heading=new LinearLayout(this);heading.setGravity(Gravity.CENTER_VERTICAL);
  TextView title=text("Тест интернета",20,TEXT);title.setTypeface(Typeface.DEFAULT,Typeface.BOLD);heading.addView(title,new LinearLayout.LayoutParams(0,-2,1));
  Button close=button("×",v->{if(testDialog!=null)testDialog.dismiss();});close.setContentDescription("Закрыть тест");heading.addView(close,new LinearLayout.LayoutParams(dp(48),dp(48)));shell.addView(heading);
  LinearLayout content=column();content.setPadding(0,dp(4),0,dp(4));

  LinearLayout speeds=new LinearLayout(this);boolean stackSpeeds=!landscape;speeds.setOrientation(stackSpeeds?LinearLayout.VERTICAL:LinearLayout.HORIZONTAL);
  SpeedDial down=new SpeedDial("↓ Загрузка",GREEN),up=new SpeedDial("↑ Отправка",BLUE);
  LinearLayout.LayoutParams half=stackSpeeds?new LinearLayout.LayoutParams(-1,-2):new LinearLayout.LayoutParams(0,-2,1);half.setMargins(0,0,stackSpeeds?0:dp(6),stackSpeeds?dp(6):0);speeds.addView(down,half);speeds.addView(up,stackSpeeds?new LinearLayout.LayoutParams(-1,-2):new LinearLayout.LayoutParams(0,-2,1));content.addView(speeds);
  LinearLayout readings=column();readings.setBaselineAligned(false);if(landscape)readings.setOrientation(LinearLayout.HORIZONTAL);content.addView(readings);
  TextView latency=text("HTTP RTT · — мс",16,MUTED);latency.setPadding(0,dp(2),dp(8),0);readings.addView(latency,landscape?new LinearLayout.LayoutParams(0,-2,1):new LinearLayout.LayoutParams(-1,-2));
  TextView status=text("Готов к запуску",16,TEXT);status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);readings.addView(status,landscape?new LinearLayout.LayoutParams(0,-2,1):new LinearLayout.LayoutParams(-1,-2));
  Button report=button("Последний отчёт / JSON",v->showSpeedReport());content.addView(report);
  ProgressBar progress=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);progress.setIndeterminateTintList(ColorStateList.valueOf(BLUE));progress.setIndeterminate(false);progress.setMax(100);progress.setVisibility(View.GONE);content.addView(progress);
  ScrollView scroll=new ScrollView(this);scroll.setFillViewport(false);scroll.addView(content);shell.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
  TextView warning=text("До 8 MiB ↓ + 2 MiB ↑ + HTTP/TLS; до 30 с. Платный трафик, нагрев и расход батареи; VPN влияет. Нажимая «Старт», вы соглашаетесь на тест синтетических данных.",14,MUTED);shell.addView(warning);
  LinearLayout actions=new LinearLayout(this);actions.setBaselineAligned(false);actions.setPadding(0,dp(4),0,0);
  Button start=button("Старт",null),stop=button("Стоп",null);styleButton(start,true);stop.setEnabled(false);
  LinearLayout.LayoutParams startParams=new LinearLayout.LayoutParams(0,-2,1);startParams.setMargins(0,0,dp(10),0);actions.addView(start,startParams);actions.addView(stop,new LinearLayout.LayoutParams(0,-2,1));Button details=button("?",v->speedHelp());details.setContentDescription("Справка о тесте, IP и карта");LinearLayout.LayoutParams detailsParams=new LinearLayout.LayoutParams(dp(48),dp(48));detailsParams.setMargins(dp(6),0,0,0);actions.addView(details,detailsParams);shell.addView(actions);
  AlertDialog dialog=new AlertDialog.Builder(this).setView(shell).create();testDialog=dialog;
  dialog.setOnDismissListener(d->{stopTest();testGeneration++;testDialog=null;});dialog.show();dialog.getWindow().setBackgroundDrawable(panel());
  android.util.DisplayMetrics dm=getResources().getDisplayMetrics();dialog.getWindow().setLayout(Math.min(dm.widthPixels-dp(24),dp(840)),Math.min(dm.heightPixels-dp(24),dp(580)));
  stop.setOnClickListener(v->{stopTest();status.setText("Отмена · ожидание завершения соединения");stop.setEnabled(false);});
  View.OnClickListener begin=v->{if(testDialog==null||!testDialog.isShowing())return;if(test!=null||SpeedTest.BUSY.get()){status.setText("Предыдущий тест ещё завершается");return;}stopIp();int token=++testGeneration;SpeedTest run=new SpeedTest();test=run;start.setEnabled(false);stop.setEnabled(true);report.setEnabled(false);progress.setVisibility(View.VISIBLE);status.setText("Подключение…");status.setOnClickListener(null);progress.setProgress(0);down.update(Double.NaN);up.update(Double.NaN);latency.setText("HTTP RTT · — мс");
   Thread thread=new Thread(()->{SpeedTest.Result r=run.run(new SpeedTest.Progress(){public void update(String phase){main.post(()->{if(token==testGeneration&&test==run&&!run.cancelled)status.setText(phase);});}public void measured(boolean upload,long bytes,long nanos){main.post(()->{if(token!=testGeneration||test!=run||run.cancelled)return;(upload?up:down).update(SpeedTest.mbps(bytes,nanos));progress.setProgress((int)(100*bytes/(upload?SpeedTest.UPLOAD:SpeedTest.DOWNLOAD)));});}});boolean saved=saveSpeedReport(r);Log.i("diakitw","speed worker finished: "+r.status);speedResults.post(()->{if(test==run)test=null;if(token!=testGeneration||testDialog!=dialog)return;last=format(r);updateSummary();down.update(r.down);up.update(r.up);latency.setText(SpeedReport.latency(r));status.setText(r.status);if(!saved)status.append(" · отчёт не сохранён");status.setOnClickListener(detailsView->showSpeedReport());status.setMinHeight(dp(48));progress.setVisibility(View.GONE);start.setEnabled(true);stop.setEnabled(false);report.setEnabled(true);});},"speed-test");thread.setDaemon(true);thread.start();
  };
  start.setOnClickListener(begin);
 }
 void speedHelp(){
  AlertDialog details=new AlertDialog.Builder(this).setTitle("О тесте").setMessage("Cloudflare · speed.cloudflare.com\n\nКороткий однопоточный тест, не максимум линии. Мбит/с — мегабиты в секунду; MiB — мебибайты трафика. Шкала адаптивная, не ёмкость линии.\n\nHTTP RTT — не ICMP ping: включает DNS, TCP/TLS и ответ сервера. HTTP jitter — среднее |разность соседних успешных проб| при 2–3 пробах. Потери не измеряются. Отправка в сокет не равна подтверждённому результату HTTP.\n\nСервер видит IP. Payload до 10 MiB, служебный трафик сверх бюджета. При закрытии, повороте или уходе из приложения тест отменяется. Payload-файлы не создаются; последний отчёт сохраняется локально.\n\nНажмите завершённый статус для деталей результата.").setNeutralButton("IP / карта",(d,w)->openIpDetails()).setPositiveButton("Понятно",null).show();details.getWindow().setBackgroundDrawable(panel());
 }
 void stopIp(){ipGeneration++;if(ipRun!=null)ipRun.cancel();}
 void routeChanged(){if(!autoIp.foreground)return;autoIp.changed(SystemClock.elapsedRealtime());stopIp();ipBadge="Устарел";ipState="Сеть изменилась · предыдущий снимок устарел";renderIp();}
 void watchNetwork(){
  connectivity=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);
  networkCallback=new ConnectivityManager.NetworkCallback(){
   void changed(){main.post(()->{if(networkCallback==this)routeChanged();});}
   @Override public void onAvailable(Network n){changed();}
   @Override public void onLost(Network n){changed();}
   @Override public void onCapabilitiesChanged(Network n,NetworkCapabilities c){changed();}
   @Override public void onLinkPropertiesChanged(Network n,LinkProperties p){changed();}
  };
  try{connectivity.registerDefaultNetworkCallback(networkCallback);}catch(RuntimeException e){networkCallback=null;ipState="События сети недоступны · проверка каждые 60 с";}
 }
 void unwatchNetwork(){if(networkCallback!=null){try{connectivity.unregisterNetworkCallback(networkCallback);}catch(RuntimeException ignored){}networkCallback=null;}}
 void startAutoIp(){
  long token=autoIp.begin(SystemClock.elapsedRealtime(),ipRun!=null||Egress.BUSY.get()||test!=null||SpeedTest.BUSY.get());if(token<0)return;
  int publication=++ipGeneration;Egress run=new Egress();ipRun=run;ipBadge="Проверка…";ipState="Ожидание HTTPS · прошлый снимок не текущий";renderIp();Log.i("diakitw","auto IP started");
  Thread t=new Thread(()->{Egress.Result r=null;boolean quota=false;try{r=run.run();}catch(Egress.RateLimited e){quota=true;}catch(java.io.IOException|RuntimeException ignored){}final Egress.Result received=r;final boolean limited=quota;
   ipResults.post(()->{boolean publish=autoIp.complete(token);if(ipRun==run)ipRun=null;Log.i("diakitw","auto IP finished");if(limited){autoIp.blockUntil(SystemClock.elapsedRealtime()+86400000L);getPreferences(MODE_PRIVATE).edit().putLong("ipQuotaUntil",System.currentTimeMillis()+86400000L).apply();}if(!publish||publication!=ipGeneration)return;
    if(received!=null){ipSnapshot=received;ipTime=new java.text.SimpleDateFormat("HH:mm:ss",Locale.US).format(new java.util.Date());ipBadge="Снимок";ipState="Выход сети на момент проверки";}else {ipBadge="Ошибка";ipState="Ошибка / тайм-аут · текущий IP неизвестен; старый снимок не обновлён";}if(limited){ipBadge="Лимит";ipState="Лимит IPwho.is · проверка отложена на 24 ч";}renderIp();
   });},"ip-lookup");t.setDaemon(true);t.start();
 }
 String ipDetails(){return (ipSnapshot==null?"IP / страна: Н/Д":ipSnapshot.ip+"\n"+countryLabel()+" ("+ipSnapshot.country+")"+(ipSnapshot.city.isEmpty()?"":"\n≈ "+ipSnapshot.city)+(ipSnapshot.isp.isEmpty()?"":"\nISP · "+ipSnapshot.isp)+(ipSnapshot.asn.isEmpty()?"":"\n"+ipSnapshot.asn)+"\n"+ipSnapshot.source+" · обновлено "+ipTime)+"\n"+ipState;}
 void renderIp(){updateSummary();for(IpCard card:ipCards)card.refresh();if(expandedMap!=null){expandedMap.update(ipSnapshot,!ipBadge.equals("Снимок"));expandedMapCaption.setText(expandedPrecision());}}
 String mapPrecision(){return (ipSnapshot==null?"Карта мира · локация неизвестна":(ipSnapshot.hasPoint()?"≈ Точка по IP, не GPS":"Страна по IP · без точки")+(!ipBadge.equals("Снимок")?" · старый снимок":""))+"\nNatural Earth · обобщённые границы";}
 String expandedPrecision(){return countryLabel()+(ipSnapshot!=null&&!ipSnapshot.city.isEmpty()?" · ≈ "+ipSnapshot.city:"")+"\n"+mapPrecision();}
 void openMap(){
  if(mapDialog!=null&&mapDialog.isShowing())return;
  LinearLayout content=column();content.setPadding(dp(16),dp(8),dp(16),dp(8));
  expandedMapCaption=text(expandedPrecision(),14,MUTED);content.addView(expandedMapCaption);
  expandedMap=new MapView(this,true);expandedMap.update(ipSnapshot,!ipBadge.equals("Снимок"));content.addView(expandedMap,new LinearLayout.LayoutParams(-1,dp(260)));
  TextView info=text("Оценка по IP, не положение телефона. Без координат карта выделяет страну, а не её центр. Малые территории могут отсутствовать на масштабе 1:110m. Приблизительные границы не предназначены для навигации. Карта встроенная, без сетевых тайлов.",14,MUTED);content.addView(info);
  ScrollView scroll=new ScrollView(this);scroll.addView(content);AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Карта выхода сети").setView(scroll).setPositiveButton("Свернуть карту",null).create();mapDialog=dialog;
  dialog.setOnDismissListener(d->{if(mapDialog==dialog){mapDialog=null;expandedMap=null;expandedMapCaption=null;}});dialog.show();dialog.getWindow().setBackgroundDrawable(panel());dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(BLUE);
  android.util.DisplayMetrics dm=getResources().getDisplayMetrics();dialog.getWindow().setLayout(Math.min(dm.widthPixels-dp(24),dp(620)),Math.min(dm.heightPixels-dp(72),dp(580)));
 }
 void openIpDetails(){
  if(ipDialog!=null&&ipDialog.isShowing())return;
  LinearLayout content=column();content.setPadding(dp(16),dp(8),dp(16),dp(8));IpCard card=addIpPanel(content);
  TextView result=text("Последний тест\n"+last,14,MUTED);result.setPadding(0,dp(12),0,dp(12));content.addView(result);
  ScrollView scroll=new ScrollView(this);scroll.addView(content);
  AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Выход в интернет").setView(scroll).setPositiveButton("Готово",null).create();ipDialog=dialog;
  dialog.setOnDismissListener(d->{ipCards.remove(card);if(ipDialog==dialog)ipDialog=null;});dialog.show();dialog.getWindow().setBackgroundDrawable(panel());dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(BLUE);
  android.util.DisplayMetrics dm=getResources().getDisplayMetrics();dialog.getWindow().setLayout(Math.min(dm.widthPixels-dp(24),dp(560)),Math.min(dm.heightPixels-dp(72),dp(580)));
 }
 IpCard addIpPanel(LinearLayout content){IpCard card=new IpCard();ipCards.add(card);LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,-2);p.setMargins(0,dp(12),0,0);content.addView(card,p);return card;}
 final class IpCard extends LinearLayout {
  final TextView address,location,city,network,state,mapCaption;final Button copy;final MapView map;
  IpCard(){super(MainActivity.this);setOrientation(VERTICAL);setPadding(dp(12),dp(12),dp(12),dp(12));setBackground(shape(BG,LINE,16));
   TextView eyebrow=text("ВНЕШНИЙ IP",12,BLUE);eyebrow.setLetterSpacing(.1f);addView(eyebrow);
   address=text("Н/Д",20,TEXT);address.setTypeface(Typeface.MONOSPACE);address.setTextIsSelectable(true);address.setMinHeight(dp(48));address.setGravity(Gravity.CENTER_VERTICAL);LinearLayout ipRow=new LinearLayout(MainActivity.this);ipRow.setGravity(Gravity.CENTER_VERTICAL);ipRow.addView(address,new LinearLayout.LayoutParams(0,-2,1));
   copy=button("⧉",v->{Egress.Result value=ipSnapshot;if(value==null)return;ClipboardManager clipboard=(ClipboardManager)getSystemService(CLIPBOARD_SERVICE);clipboard.setPrimaryClip(ClipData.newPlainText("Внешний IP · снимок "+ipTime,value.ip));Toast.makeText(MainActivity.this,"IP скопирован",Toast.LENGTH_SHORT).show();});copy.setContentDescription("Копировать IP");copy.setPadding(0,0,0,0);LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(dp(48),dp(48));cp.setMargins(dp(8),0,0,0);ipRow.addView(copy,cp);addView(ipRow);
   location=text("",18,TEXT);location.setTypeface(Typeface.DEFAULT,Typeface.BOLD);addView(location);
   city=text("",14,MUTED);addView(city);
   map=new MapView(MainActivity.this,false);LinearLayout.LayoutParams mp=new LinearLayout.LayoutParams(-1,dp(140));mp.setMargins(0,dp(10),0,0);addView(map,mp);
   mapCaption=text("",13,MUTED);addView(mapCaption);addView(button("Развернуть карту",v->openMap()),new LinearLayout.LayoutParams(-1,-2));
   state=text("",14,MUTED);state.setPadding(0,dp(8),0,dp(8));addView(state);
   network=text("",14,TEXT);network.setPadding(0,0,0,dp(8));addView(network);
   TextView precision=text("Приблизительный выход сети / VPN\n2ip через EMCx / резерв IPwho.is · не GPS",13,MUTED);precision.setPadding(0,dp(8),0,0);addView(precision);
   Button about=button("Источник и точность",v->showText("IP · источник и точность",IP_NOTICE));addView(about,new LinearLayout.LayoutParams(-1,-2));refresh();
  }
  void refresh(){map.update(ipSnapshot,!ipBadge.equals("Снимок"));mapCaption.setText(mapPrecision());boolean known=ipSnapshot!=null;address.setText(known?ipSnapshot.ip:"Н/Д");copy.setEnabled(known);location.setText(countryLabel());city.setVisibility(known&&!ipSnapshot.city.isEmpty()?VISIBLE:GONE);city.setText(known?"≈ "+ipSnapshot.city:"");
   String detail=known?((ipSnapshot.isp.isEmpty()?"":"ISP · "+ipSnapshot.isp)+(ipSnapshot.asn.isEmpty()?"":"\n"+ipSnapshot.asn)).trim():"";network.setText(detail);network.setVisibility(detail.isEmpty()?GONE:VISIBLE);
   state.setText(ipStatusLabel()+(known?" · обновлено "+ipTime:"")+"\n"+ipState);state.setTextColor(ipBadge.equals("Снимок")?GREEN:MUTED);
  }
 }
 final class SpeedDial extends LinearLayout {
  final TextView value;final SpeedFace face;final String name;final int tint;
  SpeedDial(String name,int tint){super(MainActivity.this);this.name=name;this.tint=tint;setOrientation(HORIZONTAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(8),dp(8),dp(8),dp(8));setBackground(panel());LinearLayout copy=column();copy.addView(text(name,16,tint));value=text("Н/Д",24,tint);value.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));copy.addView(value);copy.addView(text("Мбит/с",14,MUTED));addView(copy,new LinearLayout.LayoutParams(0,-2,1));face=new SpeedFace(tint);LinearLayout.LayoutParams fp=new LinearLayout.LayoutParams(dp(dialWidth()),dp(dialHeight()));fp.setMargins(dp(8),0,0,0);addView(face,fp);update(Double.NaN);}
  void update(double n){boolean known=Double.isFinite(n)&&n>=0;setTextIfChanged(value,known?SpeedScale.label(n):"Н/Д");value.setTextColor(known?tint:MUTED);face.setValue(known?n:Double.NaN);setContentDescription(name+" "+value.getText()+" Мбит/с. Адаптивная шкала, не ёмкость линии.");}
 }
 final class SpeedFace extends DialFace {
  final int tint;double value=Double.NaN,max=10;boolean known;String middle="5",end="10";
  SpeedFace(int tint){super();this.tint=tint;}
  void setValue(double next){if(Double.compare(next,value)==0)return;value=next;double scale=SpeedScale.maximum(value);known=Double.isFinite(scale);if(!known)scale=10;if(scale!=max){max=scale;middle=SpeedScale.label(max/2);end=SpeedScale.label(max);}invalidate();}
  @Override protected void onDraw(Canvas c){super.onDraw(c);
   paint.setStyle(Paint.Style.STROKE);paint.setStrokeCap(Paint.Cap.BUTT);paint.setStrokeWidth(dp(3)*7f/9f);paint.setColor(known?tint:LINE);c.drawArc(arc,180,180,false,paint);
   ticks(c);if(known)needle(c,value/max,tint);labels(c,middle,"0",end);
  }
 }
 static String number(double n){return Double.isFinite(n)?String.format(Locale.US,"%.1f",n):"Н/Д";}
 static String format(SpeedTest.Result r){return SpeedReport.text(r);}
 synchronized Sample sample(){Sample s=new Sample();
  long wall=SystemClock.elapsedRealtime(),process=android.os.Process.getElapsedCpuTime();
  s.cpu=Core.cpu(previousCpu,process,previousWall<0?0:wall-previousWall,Runtime.getRuntime().availableProcessors());previousCpu=process;previousWall=wall;
  try{ActivityManager am=(ActivityManager)getSystemService(ACTIVITY_SERVICE);ActivityManager.MemoryInfo m=new ActivityManager.MemoryInfo();if(am!=null){am.getMemoryInfo(m);s.ram=Core.percent(m.totalMem,m.availMem);s.ramDetail=pair(m.totalMem,m.availMem);}}catch(RuntimeException ignored){}
  try{StatFs f=new StatFs(getFilesDir().getAbsolutePath());s.disk=Core.percent(f.getTotalBytes(),f.getAvailableBytes());s.diskDetail=pair(f.getTotalBytes(),f.getAvailableBytes());}catch(RuntimeException ignored){}
  try{Intent i=registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));if(i!=null&&i.getBooleanExtra(BatteryManager.EXTRA_PRESENT,false)){int level=i.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=i.getIntExtra(BatteryManager.EXTRA_SCALE,-1);if(level>=0&&scale>0&&level<=scale)s.battery=Math.round(100.0*level/scale);s.power=i.getIntExtra(BatteryManager.EXTRA_PLUGGED,0)==0?"От батареи":"Питание подключено";}}catch(RuntimeException ignored){}return s;
 }
 static String pair(long total,long available){return number((total-available)/1073741824.0)+" / "+number(total/1073741824.0)+" GiB";}
 final class Metric extends LinearLayout {
  final TextView value,detail;final String name;final ResourceGauge gauge;String information="",previousDetail;double previous=Double.NaN;
  Metric(String name){
   super(MainActivity.this);this.name=name;setOrientation(HORIZONTAL);setGravity(Gravity.CENTER_VERTICAL);setPadding(dp(12),dp(3),dp(12),dp(3));setBackground(new RippleDrawable(ColorStateList.valueOf(0x224cbfff),panel(),null));setElevation(dp(2));
   LinearLayout copy=column();copy.setGravity(Gravity.CENTER_VERTICAL);TextView label=text(name,12,TEXT);label.setPadding(0,0,dp(6),0);
   value=text("Н/Д",22,MUTED);value.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));
   if(compact&&getResources().getConfiguration().fontScale<=1.5f){LinearLayout line=new LinearLayout(MainActivity.this);line.setGravity(Gravity.CENTER_VERTICAL);line.addView(label,new LinearLayout.LayoutParams(0,-2,1));line.addView(value);copy.addView(line);}else{copy.addView(label);copy.addView(value);}
   detail=text("Н/Д",12,MUTED);label.setIncludeFontPadding(false);value.setIncludeFontPadding(false);detail.setIncludeFontPadding(false);copy.addView(detail);addView(copy,new LinearLayout.LayoutParams(0,-2,1));
   gauge=new ResourceGauge(name.equals("Батарея"));LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(dp(dialWidth()),dp(dialHeight()));p.setMargins(dp(8),0,0,0);addView(gauge,p);
   if(getResources().getConfiguration().fontScale>1.5f){setOrientation(VERTICAL);copy.setLayoutParams(new LinearLayout.LayoutParams(-1,-2));p.gravity=Gravity.RIGHT;}
   setOnClickListener(v->showText(name,information));setContentDescription(name);update(Double.NaN,"Н/Д");
  }
  void update(double n,String desc){
   if(Double.compare(n,previous)==0&&desc.equals(previousDetail))return;previous=n;previousDetail=desc;
   double fraction=Gauge.fraction(n);boolean known=Double.isFinite(fraction);setTextIfChanged(value,known?(name.equals("Батарея")?String.format(Locale.US,"%.0f",n):number(n))+"%":"Н/Д");
   int color=resourceColor(n,name.equals("Батарея"));if(value.getCurrentTextColor()!=color)value.setTextColor(color);if(Double.compare(gauge.fraction,fraction)!=0||gauge.color!=color){gauge.fraction=fraction;gauge.color=color;gauge.invalidate();}
   setTextIfChanged(detail,desc.replace("Питание подключено","Подключено"));information=value.getText()+"\n"+desc+(name.equals("CPU APP")?"\nТолько процесс diakitw; доля доступных логических CPU, не всего телефона.":name.equals("Батарея")?"":"\nЗанято / всего GiB");setContentDescription(name+" "+information);
  }
 }
 static int resourceColor(double percent,boolean battery){int band=Core.band(percent,battery);return band==0?GREEN:band==1?BLUE:band==2?RED:MUTED;}
 // Geometry, tick coordinates and font metrics change only with size/configuration.
 int dialWidth(){return Math.max(112,(int)Math.ceil(72*getResources().getConfiguration().fontScale));}
 int dialHeight(){float f=getResources().getConfiguration().fontScale;float labels=14*f;float radius=landscape?Math.max(18,Math.min(32,(getResources().getConfiguration().screenHeightDp-52)/4f-8-2*labels-10)):compact?18:32;return (int)Math.floor(radius+2*labels+10);}
 void setTextIfChanged(TextView view,String value){if(!view.getText().toString().equals(value))view.setText(value);}
 abstract class DialFace extends View {
  final android.graphics.Path needlePath=new android.graphics.Path();
  final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);final RectF arc=new RectF();final float[] tickLines=new float[84];
  float cx,cy,r,labelTop,labelBottom;int geometryBuilds;
  DialFace(){super(MainActivity.this);paint.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));paint.setTextSize(12*getResources().getDisplayMetrics().scaledDensity);setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);}
  @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){super.onSizeChanged(w,h,oldw,oldh);geometryBuilds++;float d=getResources().getDisplayMetrics().density;Paint.FontMetrics fm=paint.getFontMetrics();Gauge.Geometry g=new Gauge.Geometry(w/d,h/d,(fm.descent-fm.ascent)/d);cx=(float)g.cx*d;cy=(float)g.cy*d;r=(float)g.radius*d;arc.set(cx-r,cy-r,cx+r,cy+r);labelTop=cy-r-dp(4)-fm.descent;labelBottom=cy+(float)g.tailClearance*d+dp(4)-fm.ascent;
   for(int i=0;i<=20;i++){double a=Math.toRadians(Gauge.angle(i/20.0));float x=(float)Math.cos(a),y=(float)Math.sin(a);float inner=r*(i%5==0?103f:108f)/114f,outer=r*111f/114f;int j=i*4;tickLines[j]=cx+x*inner;tickLines[j+1]=cy+y*inner;tickLines[j+2]=cx+x*outer;tickLines[j+3]=cy+y*outer;}
  }
  void ticks(Canvas c){paint.setStyle(Paint.Style.STROKE);for(int i=0;i<=20;i++){paint.setStrokeWidth(dp(1)*(i%5==0?1.5f:1f));paint.setColor(i%5==0?TEXT:MUTED);c.drawLines(tickLines,i*4,4,paint);}}
  void needle(Canvas c,double fraction,int tint){
   double[][] points=Gauge.needle(fraction,r);if(points.length==0)return;
   needlePath.rewind();needlePath.moveTo(cx+(float)points[0][0],cy+(float)points[0][1]);
   for(int i=1;i<points.length;i++)needlePath.lineTo(cx+(float)points[i][0],cy+(float)points[i][1]);needlePath.close();
   paint.setColor(tint);paint.setStyle(Paint.Style.FILL);c.drawPath(needlePath,paint);paint.setColor(BG);c.drawCircle(cx,cy,dp(3),paint);
   float outline=dp(1)*1.5f;paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(outline);paint.setColor(tint);c.drawCircle(cx,cy,dp(3)-outline/2,paint);
  }
  void labels(Canvas c,String middle,String left,String right){paint.setStyle(Paint.Style.FILL);paint.setColor(TEXT);paint.setFakeBoldText(true);paint.setTextAlign(Paint.Align.CENTER);c.drawText(middle,cx,labelTop,paint);paint.setTextAlign(Paint.Align.LEFT);c.drawText(left,dp(1),labelBottom,paint);paint.setTextAlign(Paint.Align.RIGHT);c.drawText(right,getWidth()-dp(1),labelBottom,paint);paint.setFakeBoldText(false);}
 }
 final class ResourceGauge extends DialFace {
  final boolean battery;double fraction=Double.NaN;int color=MUTED;
  ResourceGauge(boolean battery){super();this.battery=battery;}
  @Override protected void onDraw(Canvas c){super.onDraw(c);paint.setStyle(Paint.Style.STROKE);paint.setStrokeCap(Paint.Cap.BUTT);paint.setStrokeWidth(dp(3)*7f/9f);boolean known=Double.isFinite(fraction);
   for(int i=0;i<40;i++){paint.setColor(known?resourceColor((i+.5)*2.5,battery):LINE);c.drawArc(arc,180+i*4.5f,3.6f,false,paint);}
   ticks(c);if(known)needle(c,fraction,color);labels(c,"50%","0%","100%");
  }
 }
 static final class Sample{double cpu=Double.NaN,ram=Double.NaN,disk=Double.NaN,battery=Double.NaN;String ramDetail="Н/Д",diskDetail="Н/Д",power="Н/Д";}
}
