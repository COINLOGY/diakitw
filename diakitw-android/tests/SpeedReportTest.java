package app.diakitw;
import org.json.*;import java.net.*;import java.io.*;import java.util.*;import java.util.concurrent.atomic.*;
public final class SpeedReportTest {
 static int checks;static void ok(boolean b){checks++;if(!b)throw new AssertionError("check "+checks);}
 static class Fake extends HttpURLConnection {
  final String path;final int failProbe;final AtomicInteger probes;final SpeedTest[] owner;final boolean cancelAfterFirst;
  Fake(String p,int fail,AtomicInteger count,SpeedTest[] run,boolean cancel)throws Exception{super(new URL("https://speed.cloudflare.com"+p));path=p;failProbe=fail;probes=count;owner=run;cancelAfterFirst=cancel;}
  public void connect(){}public boolean usingProxy(){return false;}public void disconnect(){if(cancelAfterFirst&&probes.get()==1)owner[0].cancel();}
  public int getResponseCode(){return path.endsWith("bytes=0")&&probes.incrementAndGet()==failProbe?503:200;}
  public InputStream getInputStream(){return new ByteArrayInputStream(new byte[path.endsWith("bytes=0")?0:32]);}
  public OutputStream getOutputStream(){return new ByteArrayOutputStream();}
 }
 static SpeedTest.Result run(int fail,boolean cancel){AtomicInteger probes=new AtomicInteger();SpeedTest[] holder=new SpeedTest[1];holder[0]=new SpeedTest(p->{try{return new Fake(p,fail,probes,holder,cancel);}catch(Exception e){throw new IOException(e);}},32,16,1000);return holder[0].run(s->{});}
 public static void main(String[]args)throws Exception{
  ok(Double.isNaN(SpeedReport.average(List.of())));ok(Double.isNaN(SpeedReport.jitter(List.of(10.0))));ok(SpeedReport.average(List.of(10.0,20.0,40.0))==70.0/3);ok(SpeedReport.jitter(List.of(10.0,20.0,40.0))==15.0);
  SpeedTest.Result none=new SpeedTest.Result();JSONObject n=new JSONObject(SpeedReport.json(none));JSONObject h=n.getJSONObject("httpLatency");ok(h.isNull("averageMs"));ok(h.isNull("jitterMs"));ok(h.getJSONArray("samplesMs").length()==0);ok(n.isNull("downloadMbps"));ok(n.isNull("elapsedMs"));ok(n.isNull("packetLossPercent"));
  for(int fail:new int[]{0,1,2,3}){SpeedTest.Result r=run(fail,false);JSONObject j=new JSONObject(SpeedReport.json(r));int count=fail==0?3:fail-1;ok(j.getJSONObject("httpLatency").getInt("sampleCount")==count);ok(j.getString("state").equals(fail==0?"completed":"error"));ok(j.getJSONObject("httpLatency").isNull("averageMs")== (count==0));ok(j.getJSONObject("httpLatency").isNull("jitterMs")== (count<2));ok(j.getString("endpoint").equals("https://speed.cloudflare.com"));ok(SpeedReport.text(r).contains("не ICMP"));}
  SpeedTest.Result c=run(0,true);JSONObject j=new JSONObject(SpeedReport.json(c));ok(c.state.equals("cancelled"));ok(c.samplesMs.size()==1);ok(Double.isFinite(c.latency));ok(j.isNull("downloadMbps"));ok(j.getJSONObject("httpLatency").isNull("jitterMs"));ok(j.getLong("downloadBytesRead")==0);ok(!SpeedTest.BUSY.get());
  SpeedTest once=new SpeedTest(p->{throw new IOException();},32,16,1000);once.run(s->{});ok(once.run(s->{}).state.equals("rejected"));
  for(double invalid:new double[]{Double.NaN,Double.POSITIVE_INFINITY,-1}){ok(Double.isNaN(SpeedReport.average(List.of(invalid))));ok(Double.isNaN(SpeedReport.jitter(List.of(1.0,invalid))));}
  if(args.length==1){java.nio.file.Path out=java.nio.file.Path.of(args[0]);java.nio.file.Files.createDirectories(out);for(String state:new String[]{"completed","error","cancelled"}){SpeedTest.Result sample=run(state.equals("error")?2:0,state.equals("cancelled"));String json=SpeedReport.json(sample);java.nio.file.Path p=out.resolve(state+".json");java.nio.file.Files.writeString(p,json);ok(java.nio.file.Files.readString(p).equals(json));}}
  System.out.println("SpeedReportTest PASS "+checks+" assertions: actual fake HTTP completed/error/partial/cancel results, JSON nulls and statistics");
 }
}
