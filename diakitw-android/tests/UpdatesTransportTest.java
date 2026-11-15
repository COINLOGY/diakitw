package app.diakitw;
import javax.net.ssl.*;import java.net.*;import java.io.*;import java.security.cert.Certificate;import java.util.concurrent.CountDownLatch;
public final class UpdatesTransportTest {
 static String mode="ok";static int checks;static Fake last;static Updates.Download download;static int reads;static void ok(boolean b){checks++;if(!b)throw new AssertionError("transport "+checks);}
 static final class Fake extends HttpsURLConnection {
  final CountDownLatch closed=new CountDownLatch(1);Fake(URL u){super(u);}
  public void disconnect(){closed.countDown();}public boolean usingProxy(){return false;}public void connect(){}public String getCipherSuite(){return "fixture";}public Certificate[] getLocalCertificates(){return null;}public Certificate[] getServerCertificates(){return null;}
  public int getResponseCode(){if(mode.equals("apk-race"))throw new AssertionError("cancelled connection used");ok(!getInstanceFollowRedirects());ok(!getUseCaches());ok(getConnectTimeout()==10000&&getReadTimeout()==10000);ok("".equals(getRequestProperty("Cookie")));return mode.equals("redirect")||mode.equals("apk-redirect")?302:200;}
  public String getHeaderField(String name){return mode.equals("apk-redirect")?"https://evil.example/apk":null;}
  public long getContentLengthLong(){return mode.equals("declared-large")?32769:mode.startsWith("apk")?3:-1;}
  public InputStream getInputStream(){if(mode.equals("apk-stream-cancel"))return new InputStream(){final byte[] bytes="apk".getBytes();int pos;public int read()throws IOException{if(pos>=bytes.length)return -1;if(pos==1)download.cancel();reads++;return bytes[pos++];}public int read(byte[] b)throws IOException{int n=read();if(n<0)return -1;b[0]=(byte)n;return 1;}};if(mode.equals("timeout")||mode.equals("cancel"))return new InputStream(){public int read()throws IOException{try{closed.await();}catch(InterruptedException e){throw new IOException(e);}throw new IOException("disconnected");}};return new ByteArrayInputStream(mode.startsWith("apk")?"apk".getBytes():mode.equals("large")?new byte[32769]:"{\"schema\":1,\"releases\":[]}".getBytes());}
 }
 public static void main(String[]args)throws Exception{
  URL.setURLStreamHandlerFactory(protocol->protocol.equals("https")?new URLStreamHandler(){protected URLConnection openConnection(URL u){ok(u.toString().equals(Updates.ENDPOINT)||u.toString().equals("https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/app.apk"));if(mode.equals("apk-race"))download.cancel();return last=new Fake(u);}protected URLConnection openConnection(URL u,Proxy p){return openConnection(u);}}:null);
  ok(new Updates.Fetch().run().contains("schema"));
  for(String value:new String[]{"redirect","declared-large","large"}){mode=value;try{new Updates.Fetch().run();throw new AssertionError(value);}catch(IOException expected){checks++;}}
  mode="cancel";Updates.Fetch f=new Updates.Fetch();Thread t=new Thread(()->{try{Thread.sleep(100);f.cancel();}catch(InterruptedException e){throw new RuntimeException(e);}});t.start();try{f.run();throw new AssertionError("cancel");}catch(IOException expected){checks++;}t.join();
  mode="timeout";long begin=System.nanoTime();try{new Updates.Fetch().run();throw new AssertionError("timeout");}catch(IOException expected){ok((System.nanoTime()-begin)/1000000>=9900);}
  Updates.Release offer=new Updates.Release("1.0.2",102,"","https://github.com/COINLOGY/diakitw/releases/download/v1.0.2/app.apk",3,"dd37c2d7274f7ea982cb83390c36918fee9ce8889073c44b68cdc00bdb8c3e04");
  File file=File.createTempFile("diakitw-apk-test",".apk");try{
   mode="apk";new Updates.Download().run(offer,file);ok(file.length()==3);
   mode="apk-race";download=new Updates.Download();try{download.run(offer,file);throw new AssertionError("assignment race accepted");}catch(IOException expected){ok(last.closed.getCount()==0);ok(!file.exists());}
   mode="apk-stream-cancel";reads=0;download=new Updates.Download();try{download.run(offer,file);throw new AssertionError("stream cancellation ignored");}catch(IOException expected){ok(reads==2);ok(!file.exists());}
   mode="apk-redirect";try{new Updates.Download().run(offer,file);throw new AssertionError("untrusted redirect accepted");}catch(IOException expected){ok(!file.exists());}
  }finally{file.delete();}
  System.out.println("UpdatesTransportTest PASS "+checks+" assertions; fixed URL, size, redirect, cancel, 10s deadline; no network");
 }
}
