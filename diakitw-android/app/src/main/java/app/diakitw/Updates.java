package app.diakitw;

import org.json.*;
import java.io.*;
import java.net.*;
import javax.net.ssl.HttpsURLConnection;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** Discovery only. Never downloads or installs an APK. */
public final class Updates {
 public static final String ENDPOINT="https://coinlogy.github.io/diakitw/updates/v1.json";
 static final Set<String> PLATFORMS=new HashSet<>(Arrays.asList("macos-arm64","macos-x86_64","windows-x64","linux-x64","android"));
 static int[] version(String s){if(s==null||!s.matches("(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})"))throw new IllegalArgumentException("version");String[] p=s.split("\\.");return new int[]{Integer.parseInt(p[0]),Integer.parseInt(p[1]),Integer.parseInt(p[2])};}
 static int compare(String a,String b){int[] x=version(a),y=version(b);for(int i=0;i<3;i++)if(x[i]!=y[i])return Integer.compare(x[i],y[i]);return 0;}
 static String text(JSONObject o,String k)throws JSONException{Object v=o.get(k);if(!(v instanceof String))throw new IllegalArgumentException(k);return (String)v;}
 static long integer(JSONObject o,String k,long max)throws JSONException{Object v=o.get(k);if(!(v instanceof Integer||v instanceof Long))throw new IllegalArgumentException(k);long n=((Number)v).longValue();if(n<1||n>max)throw new IllegalArgumentException(k);return n;}
 public static boolean validURL(String url,String v){version(v);String prefix="https://github.com/COINLOGY/diakitw/releases/download/v"+v+"/";if(url==null||!url.startsWith(prefix))return false;String file=url.substring(prefix.length());return file.matches("[A-Za-z0-9][A-Za-z0-9._-]{0,199}")&&!file.contains("..");}
 public static final class Release {public final String version,notes,url;public final int build;Release(String v,int b,String n,String u){version=v;build=b;notes=n;url=u;}}
 public static Release select(String body,String channel){try{
  if(body==null||body.getBytes(StandardCharsets.UTF_8).length>32768||!Arrays.asList("stable","preview").contains(channel))throw new IllegalArgumentException("manifest");
  JSONObject root=new JSONObject(body);if(integer(root,"schema",1)!=1)throw new IllegalArgumentException("schema");JSONArray releases=root.getJSONArray("releases");if(releases.length()>64)throw new IllegalArgumentException("releases");Release best=null;
  for(int i=0;i<releases.length();i++){JSONObject r=releases.getJSONObject(i);String v=text(r,"version"),c=text(r,"channel"),notes=text(r,"notes");version(v);int build=(int)integer(r,"build",2147483647L);if(!Arrays.asList("stable","preview").contains(c)||notes.length()>4096)throw new IllegalArgumentException("release");JSONObject assets=r.getJSONObject("assets");Iterator<String> keys=assets.keys();while(keys.hasNext()){String key=keys.next();if(!PLATFORMS.contains(key))throw new IllegalArgumentException("platform");JSONObject a=assets.getJSONObject(key);if(!validURL(text(a,"url"),v)||!text(a,"sha256").matches("[a-f0-9]{64}"))throw new IllegalArgumentException("asset");integer(a,"size",8589934592L);}
   if(!c.equals(channel)||!assets.has("android")||compare(v,"0.5.5")<=0||build<=55)continue;
   if(best==null||compare(v,best.version)>0)best=new Release(v,build,notes,text(assets.getJSONObject("android"),"url"));
  }return best;
 }catch(JSONException|NullPointerException e){throw new IllegalArgumentException("manifest",e);}}
 /** Main-thread policy; persisted timestamps are bounded on load. */
 public static final class Policy {
  public String channel;public long success,attempt,failure;public boolean active,busy;public int generation;long ready;
  public Policy(String c,long s,long a,long f,long now){channel="stable".equals(c)?"stable":"preview";success=bounded(s,now);attempt=bounded(a,now);failure=bounded(f,now);}
  static long bounded(long v,long now){return v>0&&v<=now?v:0;}
  public void start(long now){if(active)return;active=true;ready=now+3000;}
  public void stop(){active=false;busy=false;generation++;}
  public void channel(String c){if(!Arrays.asList("stable","preview").contains(c)||channel.equals(c))return;boolean was=active;stop();channel=c;success=0;if(was)start(System.currentTimeMillis());}
  public boolean begin(boolean manual,long now){if(!active||busy||(attempt>0&&now-attempt<60000)||(!manual&&(now<ready||(success>0&&now-success<86400000)||(failure>0&&now-failure<3600000))))return false;busy=true;attempt=now;return true;}
  public boolean complete(int token,boolean ok,long now){if(!active||generation!=token)return false;busy=false;if(ok){success=now;failure=0;}else failure=now;return true;}
 }
 public static final class Fetch {
  volatile boolean cancelled;volatile HttpsURLConnection connection;
  public void cancel(){cancelled=true;HttpsURLConnection c=connection;if(c!=null)c.disconnect();}
  public String run()throws IOException{
   if(cancelled)throw new IOException("cancelled");
   ScheduledExecutorService deadline=Executors.newSingleThreadScheduledExecutor(r->{Thread t=new Thread(r,"update-deadline");t.setDaemon(true);return t;});
   ScheduledFuture<?> timeout=deadline.schedule(this::cancel,10,TimeUnit.SECONDS);
   try{HttpsURLConnection c=(HttpsURLConnection)new URL(ENDPOINT).openConnection(Proxy.NO_PROXY);connection=c;if(cancelled)throw new IOException("cancelled");c.setInstanceFollowRedirects(false);c.setConnectTimeout(10000);c.setReadTimeout(10000);c.setUseCaches(false);c.setRequestProperty("Accept","application/json");c.setRequestProperty("Accept-Encoding","identity");c.setRequestProperty("Cookie","");
    if(c.getResponseCode()!=200||c.getContentLengthLong()>32768)throw new IOException("HTTP or size");
    try(InputStream input=c.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] buffer=new byte[2048];int n;while((n=input.read(buffer))!=-1){if(cancelled||out.size()+n>32768)throw new IOException("cancelled or size");out.write(buffer,0,n);}if(cancelled)throw new IOException("cancelled");return new String(out.toByteArray(),StandardCharsets.UTF_8);}
   }finally{timeout.cancel(false);deadline.shutdownNow();HttpsURLConnection c=connection;if(c!=null)c.disconnect();connection=null;}
  }
 }
}
