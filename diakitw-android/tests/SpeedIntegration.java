package app.diakitw;
import com.sun.net.httpserver.HttpServer;
import java.net.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
public class SpeedIntegration {
 public static void main(String[] args)throws Exception{
  HttpServer server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
  AtomicInteger mode=new AtomicInteger(); AtomicLong uploaded=new AtomicLong();
  server.createContext("/",x->{try{
   if(mode.get()==1){x.sendResponseHeaders(503,-1);return;}
   if(mode.get()==4){x.getResponseHeaders().add("Location","http://127.0.0.1:1/forbidden");x.sendResponseHeaders(302,-1);return;}
   if(mode.get()==5&&x.getRequestMethod().equals("POST")){x.sendResponseHeaders(500,-1);return;}
   if(mode.get()==2){Thread.sleep(3000);}
   if(x.getRequestMethod().equals("POST")){uploaded.addAndGet(x.getRequestBody().transferTo(java.io.OutputStream.nullOutputStream()));x.sendResponseHeaders(200,-1);}
   else {int n=Integer.parseInt(x.getRequestURI().getQuery().split("=")[1]);x.sendResponseHeaders(200,n);if(n>0)x.getResponseBody().write(new byte[mode.get()==3?n/2:n]);}
  }catch(Exception ignored){}finally{x.close();}});server.start();
  try{
   SpeedTest.Factory f=path->(HttpURLConnection)new URL("http://127.0.0.1:"+server.getAddress().getPort()+path).openConnection();
   AtomicInteger measured=new AtomicInteger();SpeedTest t=new SpeedTest(f,65536,32768,5000); SpeedTest.Result r=t.run(new SpeedTest.Progress(){public void update(String s){}public void measured(boolean upload,long bytes,long nanos){if(bytes<=0||bytes>(upload?32768:65536)||nanos<=0||!Double.isFinite(SpeedTest.mbps(bytes,nanos)))throw new AssertionError("invalid measured frame");measured.incrementAndGet();}});if(measured.get()<1)throw new AssertionError("no measured progress");
   if(!r.status.equals("Готово")||r.downBytes!=65536||r.upBytes!=32768||uploaded.get()!=32768||!Double.isFinite(r.down)||!Double.isFinite(r.up)||!Double.isFinite(r.latency))throw new AssertionError("success "+r.status);
   mode.set(1);r=new SpeedTest(f,10,10,5000).run(s->{});if(!r.status.startsWith("Ошибка"))throw new AssertionError("failure");
   for(int m:new int[]{3,4,5}){mode.set(m);r=new SpeedTest(f,10,10,5000).run(s->{});if(!r.status.startsWith("Ошибка")||Double.isFinite(r.up))throw new AssertionError("partial/redirect "+m);}
   SpeedTest cancelled=new SpeedTest(f,10,10,5000);cancelled.cancel();if(!cancelled.run(s->{}).status.equals("Отменено"))throw new AssertionError("pre-cancel");
   mode.set(2);SpeedTest slow=new SpeedTest(f,10,10,5000);AtomicReference<SpeedTest.Result> cancelledResult=new AtomicReference<>();Thread w=new Thread(()->cancelledResult.set(slow.run(s->{})));w.start();Thread.sleep(150);if(!new SpeedTest(f,10,10,5000).run(s->{}).status.equals("Другой тест ещё завершается"))throw new AssertionError("overlap");slow.cancel();w.join(1500);if(w.isAlive()||cancelledResult.get()==null||!cancelledResult.get().status.equals("Отменено"))throw new AssertionError("cancel worker/result");
   SpeedTest deadline=new SpeedTest(f,10,10,200);long start=System.nanoTime();r=deadline.run(s->{});if(!r.status.equals("Лимит времени")||(System.nanoTime()-start)>1500000000L)throw new AssertionError("deadline "+r.status);
   System.out.println("HTTP fixture PASS: exact bytes/success/503/pre-cancel/in-flight cancel/deadline");
  }finally{server.stop(0);}
 }
}
