package app.diakitw;
import java.lang.reflect.*;
final class IpProbe {
 static void run()throws Exception{
  Class<?> c=Class.forName("app.diakitw.Egress");Method parse=c.getDeclaredMethod("parse",String.class);parse.setAccessible(true);
  for(String ip:new String[]{"8.8.8.8","2001:4860:4860::8888","::ffff:8.8.8.8"})parse.invoke(null,"{\"success\":true,\"ip\":\""+ip+"\",\"country_code\":\"US\"}");
  for(String s:new String[]{"{}","[]","null","not-json","{\"success\":false}","{\"success\":true,\"ip\":\"localhost\",\"country_code\":\"US\"}","{\"success\":true,\"ip\":\"999.1.1.1\",\"country_code\":\"US\"}","{\"success\":true,\"ip\":\"fe80::1%wlan0\",\"country_code\":\"US\"}","{\"success\":true,\"ip\":\"8.8.8.8\",\"country_code\":\"ZZ\"}","{\"success\":\"true\",\"ip\":\"8.8.8.8\",\"country_code\":\"US\"}","{\"success\":true,\"ip\":\"8.8.8.8\",\"country_code\":\"US\"}junk"}){
   boolean rejected=false;try{parse.invoke(null,s);}catch(InvocationTargetException e){rejected=true;}if(!rejected)throw new AssertionError("Invalid schema accepted");
  }
  Object rich=parse.invoke(null,"{\"success\":true,\"ip\":\"192.0.2.1\",\"country_code\":\"FI\",\"city\":\"Helsinki\",\"connection\":{\"isp\":\"Example ISP\",\"asn\":64496}}");
  for(String[] pair:new String[][]{{"city","Helsinki"},{"isp","Example ISP"},{"asn","AS64496"}}){Field field;try{field=rich.getClass().getDeclaredField(pair[0]);}catch(NoSuchFieldException e){throw new AssertionError("Missing optional provider field: "+pair[0]);}field.setAccessible(true);if(!pair[1].equals(field.get(rich)))throw new AssertionError("Optional data lost: "+pair[0]);}
  for(String body:new String[]{"{\"city\":null}","{\"city\":\"None\",\"connection\":{\"isp\":22,\"asn\":-1}}","{\"city\":\"Bad\\nCity\",\"connection\":{\"isp\":\"A\\u202eB\",\"asn\":4294967296}}"}){
   org.json.JSONObject fixture=new org.json.JSONObject(body);fixture.put("success",true).put("ip","192.0.2.1").put("country_code","FI");Egress.Result result=Egress.parse(fixture.toString());if(!result.city.isEmpty()||!result.isp.isEmpty()||!result.asn.isEmpty())throw new AssertionError("Unsafe optional fields visible");
  }
  if(!Egress.FALLBACK.contains("city,connection.isp,connection.asn"))throw new AssertionError("Optional fields not requested");
  Object positioned=parse.invoke(null,"{\"success\":true,\"ip\":\"192.0.2.1\",\"country_code\":\"FI\",\"city\":\"Helsinki\",\"latitude\":60.1699,\"longitude\":24.9384}");
  try{Field lat=positioned.getClass().getDeclaredField("latitude");lat.setAccessible(true);if(Math.abs(lat.getDouble(positioned)-60.1699)>.00001)throw new AssertionError("Coordinate lost");}catch(NoSuchFieldException e){throw new AssertionError("Missing real coordinate model");}
  for(String coords:new String[]{""," ,\"latitude\":1"," ,\"latitude\":91,\"longitude\":20"," ,\"latitude\":1,\"longitude\":181"," ,\"latitude\":\"60\",\"longitude\":24"," ,\"latitude\":null,\"longitude\":24"}){
   Egress.Result value=Egress.parse("{\"success\":true,\"ip\":\"192.0.2.1\",\"country_code\":\"FI\",\"city\":\"Helsinki\""+coords+"}");if(value.hasPoint())throw new AssertionError("Invalid/partial coordinates created pin");
  }
  if(Egress.parse("{\"success\":true,\"ip\":\"192.0.2.1\",\"country_code\":\"FI\",\"latitude\":60,\"longitude\":24}").hasPoint())throw new AssertionError("Country-only response invented city pin");
  transport();
 }
 static final class Fake extends java.net.HttpURLConnection {
  byte[] body;int status=200;String type="application/json";boolean slow,disconnected;
  Fake(String body)throws Exception{super(new java.net.URL("https://fixture.invalid"));this.body=body.getBytes(java.nio.charset.StandardCharsets.UTF_8);}
  public void connect(){} public boolean usingProxy(){return false;}public void disconnect(){disconnected=true;}
  public int getResponseCode(){return status;}public String getContentType(){return type;}
  public java.io.InputStream getInputStream(){if(!slow)return new java.io.ByteArrayInputStream(body);return new java.io.InputStream(){public int read()throws java.io.IOException{try{Thread.sleep(20000);}catch(InterruptedException e){throw new java.io.InterruptedIOException();}return -1;}};}
 }
 static void transport()throws Exception{
  String valid="{\"success\":true,\"ip\":\"8.8.8.8\",\"country_code\":\"US\"}";
  for(int mode=0;mode<5;mode++){
   Fake f=new Fake(mode==2?new String(new char[5000]).replace('\0','x'):valid);if(mode==1)f.status=429;if(mode==3)f.type="text/html";Egress e=new Egress(()->f);if(mode==4)e.cancel();boolean failed=false;try{e.run();}catch(java.io.IOException x){failed=true;if(mode==1&&!x.getClass().getSimpleName().equals("RateLimited"))throw new AssertionError("429 must defer requests");}if(failed!=(mode!=0))throw new AssertionError("transport "+mode);if(Egress.BUSY.get())throw new AssertionError("busy leaked");
  }
  Fake f=new Fake(valid);f.slow=true;Egress e=new Egress(()->f);java.util.concurrent.atomic.AtomicReference<Throwable> error=new java.util.concurrent.atomic.AtomicReference<>();Thread t=new Thread(()->{try{e.run();error.set(new AssertionError("cancel returned value"));}catch(java.io.IOException expected){}catch(Throwable x){error.set(x);}});t.start();Thread.sleep(100);e.cancel();t.join(2000);if(t.isAlive()||error.get()!=null||Egress.BUSY.get())throw new AssertionError("cancel fixture",error.get());
 }
}
