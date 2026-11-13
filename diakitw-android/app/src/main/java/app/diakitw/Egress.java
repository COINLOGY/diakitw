package app.diakitw;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.*;
/** Bounded single-use proxy lookup; legacy provider only on failure. No address persistence. */
final class Egress {
 static final String ENDPOINT="https://aia.emcx.pro/diakitw-api/geo";
 static final String FALLBACK="https://ipwho.is/?fields=success,ip,country_code,city,connection.isp,connection.asn,latitude,longitude";
 static final AtomicBoolean BUSY=new AtomicBoolean();
 static final class RateLimited extends IOException {RateLimited(){super("quota");}}
 interface Factory {HttpURLConnection open()throws IOException;}
 final Factory factory,fallback; final boolean proxy; final AtomicBoolean used=new AtomicBoolean();
 volatile boolean cancelled; volatile HttpURLConnection connection;volatile Thread thread;
 Egress(){this(()->(HttpURLConnection)new URL(ENDPOINT).openConnection(),()->(HttpURLConnection)new URL(FALLBACK).openConnection());}
 Egress(Factory factory){this.factory=factory;this.fallback=null;this.proxy=false;}
 Egress(Factory factory,Factory fallback){this.factory=factory;this.fallback=fallback;this.proxy=true;}
 static final class Result {
  final String ip,country,city,isp,asn,source,region,timezone;final double latitude,longitude;
  Result(String ip,String country){this(ip,country,"","","");}
  Result(String ip,String country,String city,String isp,String asn){this(ip,country,city,isp,asn,Double.NaN,Double.NaN);}
  Result(String ip,String country,String city,String isp,String asn,double latitude,double longitude){this(ip,country,city,isp,asn,latitude,longitude,"IPwho.is","","");}
  Result(String ip,String country,String city,String isp,String asn,double latitude,double longitude,String source,String region,String timezone){this.ip=ip;this.country=country;this.city=city;this.isp=isp;this.asn=asn;this.latitude=latitude;this.longitude=longitude;this.source=source;this.region=region;this.timezone=timezone;}
  boolean hasPoint(){return !city.isEmpty()&&Double.isFinite(latitude)&&Double.isFinite(longitude)&&Math.abs(latitude)<=90&&Math.abs(longitude)<=180;}
 }
 static String optionalText(JSONObject o,String key){
  Object value=o==null?null:o.opt(key);if(!(value instanceof String))return "";
  String text=((String)value).trim();if(text.length()>120||text.equalsIgnoreCase("null")||text.equalsIgnoreCase("none")||text.equalsIgnoreCase("unknown"))return "";
  for(int i=0;i<text.length();i++)if(Character.isISOControl(text.charAt(i))||Character.getType(text.charAt(i))==Character.FORMAT)return "";
  return text;
 }
 static Result parse(String body)throws IOException {
  try{
   JSONTokener tokener=new JSONTokener(body);Object obj=tokener.nextValue();if(!(obj instanceof JSONObject)||tokener.nextClean()!=0)throw new IOException("schema");
   JSONObject o=(JSONObject)obj;if(!Boolean.TRUE.equals(o.get("success"))||!(o.get("ip") instanceof String)||!(o.get("country_code") instanceof String))throw new IOException("schema");
   String ip=o.getString("ip"),country=o.getString("country_code");
   if(ip.length()>45||ip.isEmpty()||!ip.matches("[0-9A-Fa-f:.]+"))throw new IOException("ip");
   if(ip.contains(":")){if(!ip.matches(".*:.*:.*"))throw new IOException("ip");InetAddress.getByName(ip);} // Literal-only; never hostname DNS.
   else {String[] parts=ip.split("\\.",-1);if(parts.length!=4)throw new IOException("ip");for(String s:parts)if(!s.matches("0|[1-9][0-9]{0,2}")||Integer.parseInt(s)>255)throw new IOException("ip");}
   if(!Arrays.asList(Locale.getISOCountries()).contains(country))throw new IOException("country");
   JSONObject connection=o.optJSONObject("connection");Object rawAsn=connection==null?null:connection.opt("asn");String asn="";
   if(rawAsn instanceof Integer||rawAsn instanceof Long){long n=((Number)rawAsn).longValue();if(n>0&&n<=4294967295L)asn="AS"+n;}
   Object lat=o.opt("latitude"),lon=o.opt("longitude");double latitude=Double.NaN,longitude=Double.NaN;
   if(lat instanceof Number&&lon instanceof Number){double a=((Number)lat).doubleValue(),b=((Number)lon).doubleValue();if(Double.isFinite(a)&&Double.isFinite(b)&&Math.abs(a)<=90&&Math.abs(b)<=180){latitude=a;longitude=b;}}
   return new Result(ip,country,optionalText(o,"city"),optionalText(connection,"isp"),asn,latitude,longitude);
  }catch(JSONException|IllegalArgumentException e){throw new IOException("schema");}
 }
 static String strictText(JSONObject o,String key)throws IOException {
  Object value=o.opt(key);if(value==null||value==JSONObject.NULL)return "";
  if(!(value instanceof String))throw new IOException("schema");String s=(String)value;
  if(s.length()>256)throw new IOException("schema");
  for(int i=0;i<s.length();i++)if(Character.isISOControl(s.charAt(i))||Character.getType(s.charAt(i))==Character.FORMAT)throw new IOException("schema");
  return s;
 }
 static double coordinate(JSONObject o,String key,double bound)throws IOException {
  Object v=o.opt(key);if(v==null||v==JSONObject.NULL)return Double.NaN;
  if(!(v instanceof Number))throw new IOException("coordinate");double d=((Number)v).doubleValue();
  if(!Double.isFinite(d)||Math.abs(d)>bound)throw new IOException("coordinate");return d;
 }
 static Result parseProxy(String body)throws IOException {
  try {
   if(body.length()>4096)throw new IOException("size");
   JSONTokener t=new JSONTokener(body);Object obj=t.nextValue();if(!(obj instanceof JSONObject)||t.nextClean()!=0)throw new IOException("schema");JSONObject o=(JSONObject)obj;
   String code=strictText(o,"code");if(!code.isEmpty()&&!Arrays.asList(Locale.getISOCountries()).contains(code))throw new IOException("country");
   // Use the same literal-IP validator, without inventing a country for output.
   JSONObject identity=new JSONObject();identity.put("success",true).put("ip",o.get("ip")).put("country_code",code.isEmpty()?"US":code);Result base=parse(identity.toString());
   String city=strictText(o,"city"),region=strictText(o,"region"),timezone=strictText(o,"timezone");strictText(o,"country");
   double lat=coordinate(o,"lat",90),lon=coordinate(o,"lon",180);if(!Double.isFinite(lat)||!Double.isFinite(lon)){lat=Double.NaN;lon=Double.NaN;}
   String asn="",isp="";Object raw=o.opt("asn");
   if(raw!=null&&raw!=JSONObject.NULL){if(!(raw instanceof JSONObject))throw new IOException("asn");JSONObject a=(JSONObject)raw;isp=strictText(a,"name");Object id=a.opt("id");
    if(id!=null&&id!=JSONObject.NULL){if(!(id instanceof Integer||id instanceof Long)||((Number)id).longValue()<0||((Number)id).longValue()>4294967295L)throw new IOException("asn");asn="AS"+((Number)id).longValue();}
    Object h=a.opt("hosting");if(h!=null&&h!=JSONObject.NULL&&!(h instanceof Boolean))throw new IOException("asn");
   }
   return new Result(base.ip,code,city,isp,asn,lat,lon,"2ip через EMCx",region,timezone);
  }catch(JSONException|IllegalArgumentException e){throw new IOException("schema");}
 }
 void cancel(){cancelled=true;Thread t=thread;if(t!=null)t.interrupt();HttpURLConnection c=connection;if(c!=null){Thread closer=new Thread(c::disconnect,"ip-disconnect");closer.setDaemon(true);closer.start();}}
 void check()throws IOException{if(cancelled||Thread.currentThread().isInterrupted())throw new InterruptedIOException();}
 Result run()throws IOException{
  if(!used.compareAndSet(false,true)||!BUSY.compareAndSet(false,true))throw new IOException("busy");
  thread=Thread.currentThread();ScheduledExecutorService timer=Executors.newSingleThreadScheduledExecutor();timer.schedule(this::cancel,10,TimeUnit.SECONDS);
  try{
   try{return request(factory,proxy);}catch(IOException failure){check();if(fallback==null)throw failure;return request(fallback,false);}
  }finally{HttpURLConnection c=connection;connection=null;if(c!=null)c.disconnect();timer.shutdownNow();thread=null;Thread.interrupted();BUSY.set(false);}
 }
 Result request(Factory factory,boolean primary)throws IOException {
  try{
   check();HttpURLConnection c=factory.open();connection=c;check();if(!"https".equals(c.getURL().getProtocol()))throw new IOException("TLS required");c.setRequestMethod("GET");c.setRequestProperty("Cookie","");c.setConnectTimeout(4000);c.setReadTimeout(4000);c.setInstanceFollowRedirects(false);c.setUseCaches(false);c.setRequestProperty("Accept","application/json");c.setRequestProperty("Accept-Encoding","identity");c.setRequestProperty("Cache-Control","no-store");c.setRequestProperty("Connection","close");c.setRequestProperty("User-Agent","diakitw/0.5.2");
   int status=c.getResponseCode();if(status==429)throw new RateLimited();if(status!=200)throw new IOException("http");check();String type=c.getContentType();if(type==null||!type.toLowerCase(Locale.US).startsWith("application/json"))throw new IOException("type");if(c.getContentLengthLong()>4096)throw new IOException("size");
   ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] b=new byte[512];try(InputStream in=c.getInputStream()){int n;while((n=in.read(b,0,Math.min(b.length,4097-out.size())))!=-1){check();out.write(b,0,n);if(out.size()>4096)throw new IOException("size");}}
   check();String body=new String(out.toByteArray(),StandardCharsets.UTF_8);return primary?parseProxy(body):parse(body);
  }finally{HttpURLConnection c=connection;connection=null;if(c!=null)c.disconnect();}
 }
}
