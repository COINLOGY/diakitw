package app.diakitw;
import javax.net.ssl.*;import java.net.*;import java.io.*;import java.security.cert.Certificate;import java.util.concurrent.CountDownLatch;
public final class UpdatesTransportTest {
 static String mode="ok";static int checks;static Fake last;static void ok(boolean b){checks++;if(!b)throw new AssertionError("transport "+checks);}
 static final class Fake extends HttpsURLConnection {
  final CountDownLatch closed=new CountDownLatch(1);Fake(URL u){super(u);}
  public void disconnect(){closed.countDown();}public boolean usingProxy(){return false;}public void connect(){}public String getCipherSuite(){return "fixture";}public Certificate[] getLocalCertificates(){return null;}public Certificate[] getServerCertificates(){return null;}
  public int getResponseCode(){ok(!getInstanceFollowRedirects());ok(!getUseCaches());ok(getConnectTimeout()==10000&&getReadTimeout()==10000);ok("".equals(getRequestProperty("Cookie")));return mode.equals("redirect")?302:200;}
  public long getContentLengthLong(){return mode.equals("declared-large")?32769:-1;}
  public InputStream getInputStream(){if(mode.equals("timeout")||mode.equals("cancel"))return new InputStream(){public int read()throws IOException{try{closed.await();}catch(InterruptedException e){throw new IOException(e);}throw new IOException("disconnected");}};return new ByteArrayInputStream(mode.equals("large")?new byte[32769]:"{\"schema\":1,\"releases\":[]}".getBytes());}
 }
 public static void main(String[]args)throws Exception{
  URL.setURLStreamHandlerFactory(protocol->protocol.equals("https")?new URLStreamHandler(){protected URLConnection openConnection(URL u){ok(u.toString().equals(Updates.ENDPOINT));return last=new Fake(u);}protected URLConnection openConnection(URL u,Proxy p){return openConnection(u);}}:null);
  ok(new Updates.Fetch().run().contains("schema"));
  for(String value:new String[]{"redirect","declared-large","large"}){mode=value;try{new Updates.Fetch().run();throw new AssertionError(value);}catch(IOException expected){checks++;}}
  mode="cancel";Updates.Fetch f=new Updates.Fetch();Thread t=new Thread(()->{try{Thread.sleep(100);f.cancel();}catch(InterruptedException e){throw new RuntimeException(e);}});t.start();try{f.run();throw new AssertionError("cancel");}catch(IOException expected){checks++;}t.join();
  mode="timeout";long begin=System.nanoTime();try{new Updates.Fetch().run();throw new AssertionError("timeout");}catch(IOException expected){ok((System.nanoTime()-begin)/1000000>=9900);}
  System.out.println("UpdatesTransportTest PASS "+checks+" assertions; fixed URL, size, redirect, cancel, 10s deadline; no network");
 }
}
