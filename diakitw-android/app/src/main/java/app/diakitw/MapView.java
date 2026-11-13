package app.diakitw;

import android.content.Context;
import android.graphics.*;
import android.os.*;
import android.view.View;
import org.json.*;
import java.io.*;
import java.lang.ref.WeakReference;
import java.util.*;
import java.util.concurrent.*;

/** Offline Natural Earth geometry. No network, GPS, tile cache or fabricated centers. */
final class MapView extends View {
 static final int SEA=0xff11242f,LAND=0xff2b4149,BORDER=0xff58717b,HIGHLIGHT=0xff28637a;
 static final ExecutorService LOADER=new ThreadPoolExecutor(0,1,5,TimeUnit.SECONDS,new LinkedBlockingQueue<>(),r->{Thread t=new Thread(r,"map-assets");t.setDaemon(true);return t;});
 static volatile List<Country> cached;
 static final class Country {final String iso;final float[][] rings;Country(String iso,float[][] rings){this.iso=iso;this.rings=rings;}}
 static synchronized List<Country> load(Context app)throws IOException,JSONException {
  if(cached!=null)return cached;
  ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[4096];
  try(InputStream in=app.getAssets().open("world-110m.json")){int n;while((n=in.read(buffer))!=-1){out.write(buffer,0,n);if(out.size()>512000)throw new IOException("map size");}}
  JSONArray root=new JSONArray(out.toString("UTF-8"));List<Country> data=new ArrayList<>();
  for(int i=0;i<root.length();i++){JSONArray entry=root.getJSONArray(i),rings=entry.getJSONArray(1);float[][] points=new float[rings.length()][];for(int j=0;j<points.length;j++){JSONArray ring=rings.getJSONArray(j);points[j]=new float[ring.length()];for(int k=0;k<points[j].length;k++)points[j][k]=(float)ring.getDouble(k);}data.add(new Country(entry.getString(0),points));}
  cached=Collections.unmodifiableList(data);return cached;
 }
 final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);final List<Path> paths=new ArrayList<>();final List<Boolean> selected=new ArrayList<>();
 final boolean expanded;List<Country> data;Egress.Result snapshot;boolean stale,failed;float scale,left,top,pinX,pinY;double west=-180,east=180,south=-90,north=90;int geometryBuilds;
 MapView(Context context,boolean expanded){super(context);this.expanded=expanded;setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);setContentDescription("Карта мира · загрузка локальных границ");
  Context app=context.getApplicationContext();WeakReference<MapView> weak=new WeakReference<>(this);Handler main=new Handler(Looper.getMainLooper());
  LOADER.execute(()->{List<Country> loaded=null;try{loaded=load(app);}catch(IOException|JSONException ignored){}final List<Country> result=loaded;main.post(()->{MapView v=weak.get();if(v==null)return;v.data=result;v.failed=result==null;v.rebuild();v.invalidate();});});
 }
 void update(Egress.Result result,boolean old){if(snapshot==result&&stale==old)return;snapshot=result;stale=old;rebuild();invalidate();}
 boolean hasPin(){return snapshot!=null&&snapshot.hasPoint();}
 boolean hasCountry(){if(data==null||snapshot==null)return false;for(Country c:data)if(c.iso.equals(snapshot.country))return true;return false;}
 float density(){return getResources().getDisplayMetrics().density;}
 float x(double lon){return left+(float)(lon-west)*scale;}
 float y(double lat){return top+(float)(north-lat)*scale;}
 @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){rebuild();}
 void rebuild(){
  paths.clear();selected.clear();if(getWidth()==0||getHeight()==0||data==null)return;geometryBuilds++;
  west=-180;east=180;south=-90;north=90;
  if(expanded&&hasPin()){west=Math.max(-180,Math.min(120,snapshot.longitude-30));east=west+60;south=Math.max(-90,Math.min(50,snapshot.latitude-20));north=south+40;}
  else if(expanded&&hasCountry()){
   double w=180,e=-180,s=90,n=-90;for(Country c:data)if(c.iso.equals(snapshot.country))for(float[] ring:c.rings)for(int i=0;i<ring.length;i+=2){w=Math.min(w,ring[i]);e=Math.max(e,ring[i]);s=Math.min(s,ring[i+1]);n=Math.max(n,ring[i+1]);}
   double padX=Math.max(4,(e-w)*.15),padY=Math.max(4,(n-s)*.15);west=Math.max(-180,w-padX);east=Math.min(180,e+padX);south=Math.max(-90,s-padY);north=Math.min(90,n+padY);
  }
  float padding=8*density();scale=(float)Math.min((getWidth()-2*padding)/(east-west),(getHeight()-2*padding)/(north-south));left=(getWidth()-(float)(east-west)*scale)/2;top=(getHeight()-(float)(north-south)*scale)/2;
  for(Country country:data){Path p=new Path();p.setFillType(Path.FillType.EVEN_ODD);for(float[] ring:country.rings){if(ring.length<6)continue;p.moveTo(x(ring[0]),y(ring[1]));for(int i=2;i<ring.length;i+=2)p.lineTo(x(ring[i]),y(ring[i+1]));p.close();}paths.add(p);selected.add(snapshot!=null&&country.iso.equals(snapshot.country));}
  pinX=hasPin()?x(snapshot.longitude):Float.NaN;pinY=hasPin()?y(snapshot.latitude):Float.NaN;
  setContentDescription((stale?"Устаревший снимок. ":"")+(hasPin()?"Приблизительная точка по IP, не GPS. "+snapshot.city:hasCountry()?"Выделена страна "+snapshot.country+", без точки местоположения":"Карта мира, местоположение не определено")+". Natural Earth, обобщённые границы.");
 }
 @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);canvas.drawColor(SEA);paint.setStyle(Paint.Style.FILL);
  if(data==null){paint.setColor(MainActivity.MUTED);paint.setTextSize(14*getResources().getDisplayMetrics().scaledDensity);canvas.drawText(failed?"Карта недоступна":"Загрузка карты…",12*density(),getHeight()/2f,paint);return;}
  for(int i=0;i<paths.size();i++){paint.setStyle(Paint.Style.FILL);paint.setColor(selected.get(i)?HIGHLIGHT:LAND);canvas.drawPath(paths.get(i),paint);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth((selected.get(i)?1.1f:.5f)*density());paint.setColor(selected.get(i)?MainActivity.BLUE:BORDER);canvas.drawPath(paths.get(i),paint);}
  if(hasPin()){paint.setStyle(Paint.Style.FILL);paint.setColor(stale?MainActivity.MUTED:MainActivity.GREEN);canvas.drawCircle(pinX,pinY,5*density(),paint);paint.setStyle(Paint.Style.STROKE);paint.setColor(SEA);paint.setStrokeWidth(2*density());canvas.drawCircle(pinX,pinY,6*density(),paint);}
 }
}
