package app.diakitw;
import org.json.*;import java.io.*;
public final class UpdatesTest {
 static int checks;static void ok(boolean b){checks++;if(!b)throw new AssertionError("check "+checks);}static void bad(String s)throws Exception{try{select(s,"preview");throw new AssertionError("accepted invalid feed");}catch(IllegalArgumentException expected){checks++;}}
 static Updates.Release select(String body,String channel){return Updates.select(body,channel,"1.0.1",101);}
 static String feed(String version,int build,String channel)throws Exception{return new JSONObject().put("schema",1).put("releases",new JSONArray().put(new JSONObject().put("version",version).put("build",build).put("channel",channel).put("notes","<b>plain text</b>").put("assets",new JSONObject().put("android",new JSONObject().put("url","https://github.com/COINLOGY/diakitw/releases/download/v"+version+"/app.apk").put("size",100).put("sha256","a".repeat(64)))))).toString();}
 public static void main(String[]args)throws Exception{
  String s=feed("1.0.2",102,"preview");ok(select(s,"preview").version.equals("1.0.2"));ok(select(s,"stable")==null);ok(select(feed("0.5.3",60,"preview"),"preview")==null);ok(select(feed("0.5.4",60,"preview"),"preview")==null);ok(select(feed("0.6.0",54,"preview"),"preview")==null);
  // Replaying an installed release must not re-offer itself, but a newer one must appear.
  ok(Updates.select(s,"preview","1.0.2",102)==null);
  ok(Updates.select(feed("1.0.3",103,"preview"),"preview","1.0.2",102)!=null);
  ok(Updates.select(feed("1.0.3",102,"preview"),"preview","1.0.2",102)==null);
  ok(select(s,"preview").size==100);ok(select(s,"preview").sha256.equals("a".repeat(64)));
  try{Updates.verify(new ByteArrayInputStream("apk".getBytes()),3,"a".repeat(64),new ByteArrayOutputStream());throw new AssertionError("digest accepted");}catch(IOException expected){checks++;}
  ByteArrayOutputStream verified=new ByteArrayOutputStream();ok(Updates.verify(new ByteArrayInputStream("apk".getBytes()),3,"dd37c2d7274f7ea982cb83390c36918fee9ce8889073c44b68cdc00bdb8c3e04",verified)==3);ok(verified.toString().equals("apk"));
  for(int[] boundary:new int[][]{{30,36,0},{31,28,0},{31,29,1},{33,29,0},{33,30,1},{34,30,0},{34,31,1},{35,32,0},{35,33,1},{36,33,0},{36,34,1},{37,34,0},{37,35,1},{38,36,0}})ok(Updates.mayRequestNoUserAction(boundary[0],boundary[1])==(boundary[2]==1));
  for(int length:new int[]{2,4})try{Updates.verify(new ByteArrayInputStream("apk".getBytes()),length,"dd37c2d7274f7ea982cb83390c36918fee9ce8889073c44b68cdc00bdb8c3e04",new ByteArrayOutputStream());throw new AssertionError("size accepted");}catch(IOException expected){checks++;}
  ok(select(feed("0.5.5",55,"preview"),"preview")==null);ok(select(feed("0.5.5",56,"preview"),"preview")==null);ok(select(feed("0.5.6",55,"preview"),"preview")==null);ok(select(feed("0.5.6",56,"preview"),"preview")==null);ok(select(feed("0.5.7",57,"preview"),"preview")==null);ok(select(feed("0.5.7",58,"preview"),"preview")==null);ok(select(feed("0.5.8",57,"preview"),"preview")==null);ok(select(feed("1.0.2",102,"preview"),"preview")!=null);ok(select(feed("1.0.2",102,"stable"),"stable")!=null);ok(select(feed("1.0.2",102,"stable"),"preview")==null);
  for(String v:new String[]{"01.5.6","0.5.6-beta","0.5","-1.5.6","0.5.1000000"})bad(feed(v,60,"preview"));
  for(String change:new String[]{s.replace("github.com","evil.com"),s.replace("app.apk","../app.apk"),s.replace("app.apk","app.apk?x=1"),s.replace("app.apk","%61.apk"),s.replace("\"size\":100","\"size\":0"),s.replace("\"build\":102","\"build\":true"),s.replace("\"schema\":1","\"schema\":2"),s.replace("\"size\":100","\"size\":8589934593"),s.replace("a".repeat(64),"A".repeat(64)),s.replace("plain text","x".repeat(4097))," ".repeat(32769)})bad(change);
  Updates.Policy p=new Updates.Policy("preview",0,0,0,1000000);ok(!p.begin(false,1000000));p.start(1000000);ok(!p.begin(false,1002999));ok(p.begin(false,1003000));ok(!p.begin(true,1003001));int token=p.generation;p.stop();ok(!p.complete(token,true,1003002));p.start(1003003);ok(!p.begin(true,1003004));ok(p.begin(true,1063000));ok(p.complete(p.generation,false,1063001));ok(!p.begin(false,1123001));ok(p.begin(true,1123001));ok(p.complete(p.generation,true,1123002));ok(!p.begin(false,1123002+86400000-1));ok(p.begin(false,1123002+86400000));p.complete(p.generation,true,1123002+86400000);p.stop();p.start(1123002+86400000L+1);ok(!p.begin(false,1123002+86400000L+2999));p.stop();p.channel("stable");ok(!p.active);ok(p.success==0);ok(!p.begin(true,999999999));
  Updates.Policy restart=new Updates.Policy("preview",0,0,0,1000000);restart.start(1000000);ok(!restart.begin(false,1002999));ok(restart.begin(false,1003000));ok(restart.complete(restart.generation,true,1003001));restart.stop();restart.start(1004000);ok(!restart.begin(false,1007000));ok(restart.begin(true,1064000));ok(restart.complete(restart.generation,false,1064001));restart.stop();Updates.Policy persisted=new Updates.Policy(restart.channel,restart.success,restart.attempt,restart.failure,1065000);persisted.start(1065000);ok(persisted.begin(false,1068000));ok(!persisted.begin(true,1124000));
  // A fresh process must bypass persisted gates exactly once; resuming this process cannot.
  Updates.Policy fresh=new Updates.Policy("preview",2000000,2000000,0,2001000);
  fresh.start(2001000);ok(!fresh.begin(false,2003999));ok(fresh.begin(false,2004000));
  ok(fresh.complete(fresh.generation,true,2004001));fresh.stop();fresh.start(2005000);
  ok(!fresh.begin(false,2008000));
  Updates.Policy secondProcess=new Updates.Policy(fresh.channel,fresh.success,fresh.attempt,fresh.failure,2006000);
  secondProcess.start(2006000);ok(secondProcess.begin(false,2009000));
  ok(!secondProcess.begin(false,2009001));
  // A throttled manual tap must not hide a valid download offer.
  ok(!secondProcess.begin(true,2009002));
  Updates.Policy recreated=new Updates.Policy(secondProcess.channel,secondProcess.success,secondProcess.attempt,secondProcess.failure,2009100,false);recreated.start(2009100);ok(!recreated.begin(false,2012100));
  Updates.Fetch cancelled=new Updates.Fetch();cancelled.cancel();try{cancelled.run();throw new AssertionError("cancel ignored");}catch(IOException expected){checks++;}
  System.out.println("UpdatesTest PASS "+checks+" assertions; offline parser, policy, cancellation");
 }
}
