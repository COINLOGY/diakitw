package app.diakitw;
import java.io.*;
import java.net.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

final class SpeedTest {
 static final int DOWNLOAD=8*1024*1024, UPLOAD=2*1024*1024;
 interface Factory { HttpURLConnection open(String path)throws IOException; }
 interface Progress { void update(String phase); default void measured(boolean upload,long bytes,long nanos){} }
 static final AtomicBoolean BUSY=new AtomicBoolean();
 final Factory factory; final int download,upload,limitMs;
 volatile boolean cancelled,timedOut; volatile HttpURLConnection connection; volatile Thread thread;
 final AtomicBoolean used=new AtomicBoolean();
 SpeedTest(){this(path->{URL u=new URL("https://speed.cloudflare.com"+path);return (HttpURLConnection)u.openConnection(Proxy.NO_PROXY);},DOWNLOAD,UPLOAD,30000);}
 // Package-private transport injection: only local JVM tests, never user configuration.
 SpeedTest(Factory f,int down,int up,int ms){if(down<1||down>DOWNLOAD||up<1||up>UPLOAD||ms<1||ms>30000)throw new IllegalArgumentException();factory=f;download=down;upload=up;limitMs=ms;}
 static final class Result {
  String status="Не запущен"; double down=Double.NaN,up=Double.NaN,latency=Double.NaN; long downBytes,upBytes,elapsedMs;
 }
 void cancel(){cancelled=true;abort();}
 void abort(){Thread t=thread;if(t!=null)t.interrupt();HttpURLConnection c=connection;if(c!=null){Thread closer=new Thread(c::disconnect,"speed-disconnect");closer.setDaemon(true);closer.start();}}
 void check()throws IOException{if(cancelled||timedOut||Thread.currentThread().isInterrupted())throw new InterruptedIOException();}
 HttpURLConnection open(String path)throws IOException{
  check();HttpURLConnection c=factory.open(path);connection=c;
  c.setConnectTimeout(5000);c.setReadTimeout(5000);c.setInstanceFollowRedirects(false);c.setUseCaches(false);
  c.setRequestProperty("Accept-Encoding","identity");c.setRequestProperty("Cache-Control","no-store");c.setRequestProperty("Connection","close");c.setRequestProperty("User-Agent","diakitw/0.1.1");check();return c;
 }
 void ok(HttpURLConnection c)throws IOException{int status=c.getResponseCode();if(status!=200&&status!=204)throw new IOException("HTTP");check();}
 void close(){HttpURLConnection c=connection;connection=null;if(c!=null)c.disconnect();}
 Result run(Progress progress){
  Result r=new Result();if(!used.compareAndSet(false,true)){r.status="Ошибка: повторный запуск";return r;}
  if(!BUSY.compareAndSet(false,true)){r.status="Другой тест ещё завершается";return r;}
  long start=System.nanoTime();thread=Thread.currentThread();
  ScheduledExecutorService timer=Executors.newSingleThreadScheduledExecutor(task->{Thread t=new Thread(task,"speed-deadline");t.setDaemon(true);return t;});
  timer.schedule(()->{timedOut=true;abort();},limitMs,TimeUnit.MILLISECONDS);
  try{
   check();progress.update("HTTP RTT · 3 пробы");double sum=0;
   for(int i=0;i<3;i++){long tick=System.nanoTime();HttpURLConnection c=open("/__down?bytes=0");ok(c);try(InputStream in=c.getInputStream()){if(in.read()!=-1)throw new IOException("Unexpected probe payload");}sum+=(System.nanoTime()-tick)/1e6;close();}
   r.latency=sum/3;check();progress.update("Загрузка · до 8 MiB");
   long tick=System.nanoTime();HttpURLConnection c=open("/__down?bytes="+download);ok(c);
   byte[] buffer=new byte[16384];long last=0;
   try(InputStream in=c.getInputStream()){while(r.downBytes<download){check();int n=in.read(buffer,0,(int)Math.min(buffer.length,download-r.downBytes));if(n<0)throw new EOFException();r.downBytes+=n;if(System.nanoTime()-last>200000000){progress.update("Загрузка · "+r.downBytes+" / "+download+" байт");progress.measured(false,r.downBytes,System.nanoTime()-tick);last=System.nanoTime();}}}
   r.down=mbps(r.downBytes,System.nanoTime()-tick);close();check();progress.update("Отправка · до 2 MiB");
   tick=System.nanoTime();c=open("/__up");c.setRequestMethod("POST");c.setDoOutput(true);c.setFixedLengthStreamingMode(upload);c.setRequestProperty("Content-Type","application/octet-stream");
   // Synthetic zeros only. No files, credentials or application data.
   java.util.Arrays.fill(buffer,(byte)0);
   try(OutputStream out=c.getOutputStream()){while(r.upBytes<upload){check();int n=(int)Math.min(buffer.length,upload-r.upBytes);out.write(buffer,0,n);r.upBytes+=n;if(System.nanoTime()-last>200000000){progress.update("Отправка · "+r.upBytes+" / "+upload+" байт");progress.measured(true,r.upBytes,System.nanoTime()-tick);last=System.nanoTime();}}}
   ok(c);r.up=mbps(r.upBytes,System.nanoTime()-tick);check();r.status="Готово";
  }catch(IOException|RuntimeException e){r.status=cancelled?"Отменено":timedOut?"Лимит времени":"Ошибка сети / HTTP · результат неполный";
  }finally{close();timer.shutdownNow();thread=null;Thread.interrupted();r.elapsedMs=(System.nanoTime()-start)/1000000;BUSY.set(false);}
  return r;
 }
 static double mbps(long bytes,double nanos){if(bytes<0||!Double.isFinite(nanos)||nanos<=0)return Double.NaN;double value=bytes*8000.0/nanos;return Double.isFinite(value)?value:Double.NaN;}
}
