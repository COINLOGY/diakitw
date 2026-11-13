package app.diakitw;
import java.lang.reflect.*;
final class ProxyProbe {
 static void run()throws Exception {
  Method p;
  try {p=Egress.class.getDeclaredMethod("parseProxy",String.class);}catch(NoSuchMethodException e){throw new AssertionError("Missing proxy parser");}
  Egress.Result r=(Egress.Result)p.invoke(null,"{\"ip\":\"203.0.113.2\",\"code\":\"FI\",\"city\":\"Helsinki\",\"lat\":60.17,\"lon\":24.94,\"asn\":{\"id\":64496,\"name\":\"Example\",\"hosting\":false}}");
  if(!r.country.equals("FI")||!r.city.equals("Helsinki")||!r.asn.equals("AS64496")||!r.hasPoint())throw new AssertionError("Rich proxy lost");
  r=(Egress.Result)p.invoke(null,"{\"ip\":\"2001:db8::1\",\"code\":null,\"city\":null,\"lat\":null,\"lon\":null,\"asn\":null}");
  if(!r.country.isEmpty()||r.hasPoint()||!Double.isNaN(r.latitude))throw new AssertionError("Null geo invented");
  for(String fields:new String[]{"\"ip\":\"hostname\"","\"ip\":\"fe80::1%en0\"","\"ip\":\"203.0.113.2\",\"code\":\"ZZ\"","\"ip\":\"203.0.113.2\",\"lat\":true,\"lon\":1","\"ip\":\"203.0.113.2\",\"lat\":91,\"lon\":1","\"ip\":\"203.0.113.2\",\"city\":\"Bad\\nCity\"","\"ip\":\"203.0.113.2\",\"asn\":{\"id\":1.2}"}){
   boolean bad=false;try{p.invoke(null,"{"+fields+"}");}catch(InvocationTargetException e){bad=true;}if(!bad)throw new AssertionError("Invalid proxy accepted");
  }
  transport();
 }
 static void transport()throws Exception {
  Constructor<Egress> c;try{c=Egress.class.getDeclaredConstructor(Egress.Factory.class,Egress.Factory.class);}catch(NoSuchMethodException e){throw new AssertionError("Missing primary/fallback injection");}
  String good="{\"ip\":\"203.0.113.2\",\"code\":\"FI\"}";
  for(int mode=0;mode<5;mode++){
   final int[] calls={0};IpProbe.Fake primary=new IpProbe.Fake(good),fallback=new IpProbe.Fake("{\"success\":true,\"ip\":\"198.51.100.1\",\"country_code\":\"US\"}");
   if(mode==1)primary.status=503;if(mode==2)primary.body="{}".getBytes();if(mode==3)primary.status=302;
   Egress run=c.newInstance((Egress.Factory)()->primary,(Egress.Factory)()->{calls[0]++;return fallback;});if(mode==4)run.cancel();
   if(mode==4){try{run.run();throw new AssertionError("Cancelled returned");}catch(java.io.IOException expected){}if(calls[0]!=0)throw new AssertionError("Cancel retried");continue;}
   Egress.Result r=run.run();if(calls[0]!=(mode==0?0:1))throw new AssertionError("Fallback call count");
   if(!r.ip.equals(mode==0?"203.0.113.2":"198.51.100.1")||!r.country.equals(mode==0?"FI":"US"))throw new AssertionError("Mixed snapshot");
   if(primary.getInstanceFollowRedirects()||primary.getUseCaches()||!"".equals(primary.getRequestProperty("Cookie")))throw new AssertionError("Transport policy");
  }
 }
}
