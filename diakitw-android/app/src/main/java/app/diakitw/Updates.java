package app.diakitw;

import org.json.*;
import java.io.*;
import java.net.*;
import javax.net.ssl.HttpsURLConnection;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.concurrent.*;

/** v2 discovery and bounded, authenticated APK transfer. Installation is delegated to Android. */
public final class Updates {
 public static final String ENDPOINT="https://coinlogy.github.io/diakitw/updates/v2.json";
 public static final String SIGNER_SHA256="d9298271dcb4e32856abdc2111b35ae43b7770b1c9fbfefa66100e899a58abc8";
 public static final long MAX_APK=536870912L;
 /** Android SessionParams thresholds; future platform releases fail closed. */
 public static boolean mayRequestNoUserAction(int sdk,int target){
  if(sdk<31||sdk>37)return false;
  int minimum=sdk>=37?35:sdk>=36?34:sdk>=35?33:sdk>=34?31:sdk>=33?30:29;
  return target>=minimum;
 }
 static final Set<String> PLATFORMS=new HashSet<>(Arrays.asList("macos-arm64","macos-x86_64","windows-x64","linux-x64","android"));
 static int[] version(String s){if(s==null||!s.matches("(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})"))throw new IllegalArgumentException("version");String[] p=s.split("\\.");return new int[]{Integer.parseInt(p[0]),Integer.parseInt(p[1]),Integer.parseInt(p[2])};}
 static int compare(String a,String b){int[] x=version(a),y=version(b);for(int i=0;i<3;i++)if(x[i]!=y[i])return Integer.compare(x[i],y[i]);return 0;}
 static String text(JSONObject o,String k)throws JSONException{Object v=o.get(k);if(!(v instanceof String))throw new IllegalArgumentException(k);return (String)v;}
 static long integer(JSONObject o,String k,long max)throws JSONException{Object v=o.get(k);if(!(v instanceof Integer||v instanceof Long))throw new IllegalArgumentException(k);long n=((Number)v).longValue();if(n<1||n>max)throw new IllegalArgumentException(k);return n;}
 public static boolean validURL(String url,String v){version(v);String prefix="https://github.com/COINLOGY/diakitw/releases/download/v"+v+"/";if(url==null||!url.startsWith(prefix))return false;String file=url.substring(prefix.length());return file.matches("[A-Za-z0-9][A-Za-z0-9._-]{0,199}")&&!file.contains("..");}
 public static final class Release {public final String version,notes,url,sha256;public final int build;public final long size;Release(String v,int b,String n,String u,long s,String hash){version=v;build=b;notes=n;url=u;size=s;sha256=hash;}}
 public static Release select(String body,String channel){try{
  if(body==null||body.getBytes(StandardCharsets.UTF_8).length>32768||!Arrays.asList("stable","preview").contains(channel))throw new IllegalArgumentException("manifest");
  JSONObject root=new JSONObject(body);if(integer(root,"schema",1)!=1)throw new IllegalArgumentException("schema");JSONArray releases=root.getJSONArray("releases");if(releases.length()>64)throw new IllegalArgumentException("releases");Release best=null;
  for(int i=0;i<releases.length();i++){JSONObject r=releases.getJSONObject(i);String v=text(r,"version"),c=text(r,"channel"),notes=text(r,"notes");version(v);int build=(int)integer(r,"build",2147483647L);if(!Arrays.asList("stable","preview").contains(c)||notes.length()>4096)throw new IllegalArgumentException("release");JSONObject assets=r.getJSONObject("assets");Iterator<String> keys=assets.keys();while(keys.hasNext()){String key=keys.next();if(!PLATFORMS.contains(key))throw new IllegalArgumentException("platform");JSONObject a=assets.getJSONObject(key);if(!validURL(text(a,"url"),v)||!text(a,"sha256").matches("[a-f0-9]{64}"))throw new IllegalArgumentException("asset");integer(a,"size",8589934592L);}
   if(!c.equals(channel)||!assets.has("android")||compare(v,"1.0.1")<=0||build<=101)continue;
   if(best==null||compare(v,best.version)>0){JSONObject apk=assets.getJSONObject("android");long size=integer(apk,"size",8589934592L);if(size>MAX_APK)continue;best=new Release(v,build,notes,text(apk,"url"),size,text(apk,"sha256"));}
  }return best;
 }catch(JSONException|NullPointerException e){throw new IllegalArgumentException("manifest",e);}}
 /** Reject truncation, overflow and digest mismatch; caller deletes temporary output on failure. */
 public static long verify(InputStream in,long size,String sha256,OutputStream out)throws IOException{
  if(size<1||size>MAX_APK||sha256==null||!sha256.matches("[a-f0-9]{64}"))throw new IOException("invalid APK metadata");
  MessageDigest digest;try{digest=MessageDigest.getInstance("SHA-256");}catch(NoSuchAlgorithmException e){throw new IOException(e);}
  byte[] buf=new byte[16384];long count=0;int n;
  while((n=in.read(buf))!=-1){if(Thread.currentThread().isInterrupted()||n>size-count)throw new IOException("APK too large or interrupted");digest.update(buf,0,n);out.write(buf,0,n);count+=n;}
  StringBuilder hex=new StringBuilder(64);for(byte b:digest.digest())hex.append(String.format(Locale.US,"%02x",b&255));
  if(count!=size||!sha256.equals(hex.toString()))throw new IOException("APK size or SHA-256 mismatch");return count;
 }
 public static final class Download {
  volatile boolean cancelled;volatile HttpsURLConnection connection;
  public void cancel(){cancelled=true;HttpsURLConnection c=connection;if(c!=null)c.disconnect();}
  public void run(Release offer,File target)throws IOException{
   if(offer==null||!validURL(offer.url,offer.version)||offer.size>MAX_APK||cancelled)throw new IOException("invalid offer");
   URL url=new URL(offer.url);boolean complete=false;
   try{
    for(int hop=0;hop<=5;hop++){
     if(cancelled||!trusted(url))throw new IOException("untrusted APK URL");
     HttpsURLConnection c=(HttpsURLConnection)url.openConnection(Proxy.NO_PROXY);connection=c;c.setInstanceFollowRedirects(false);c.setConnectTimeout(10000);c.setReadTimeout(10000);c.setUseCaches(false);c.setRequestProperty("Accept-Encoding","identity");c.setRequestProperty("Cookie","");
     int code=c.getResponseCode();if(code==302||code==303||code==307||code==308){String location=c.getHeaderField("Location");if(location==null)throw new IOException("missing redirect");URL next=new URL(url,location);c.disconnect();connection=null;url=next;continue;}
     if(code!=200||c.getContentLengthLong()>offer.size)throw new IOException("APK HTTP or size");
     try(InputStream in=c.getInputStream();OutputStream out=new FileOutputStream(target)){verify(in,offer.size,offer.sha256,out);}
     if(cancelled)throw new IOException("cancelled");complete=true;return;
    }throw new IOException("too many redirects");
   }finally{HttpsURLConnection c=connection;if(c!=null)c.disconnect();connection=null;if(!complete)target.delete();}
  }
  static boolean trusted(URL url){if(!"https".equals(url.getProtocol())||url.getUserInfo()!=null||url.getPort()!=-1||url.getRef()!=null)return false;String h=url.getHost();return "github.com".equals(h)||"release-assets.githubusercontent.com".equals(h)||"objects.githubusercontent.com".equals(h);}
 }
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
