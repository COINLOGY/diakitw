package app.diakitw;
import org.json.*;import java.io.*;
public final class UpdatesTest {
 static int checks;static void ok(boolean b){checks++;if(!b)throw new AssertionError("check "+checks);}static void bad(String s)throws Exception{try{Updates.select(s,"preview");throw new AssertionError("accepted invalid feed");}catch(IllegalArgumentException expected){checks++;}}
 static String feed(String version,int build,String channel)throws Exception{return new JSONObject().put("schema",1).put("releases",new JSONArray().put(new JSONObject().put("version",version).put("build",build).put("channel",channel).put("notes","<b>plain text</b>").put("assets",new JSONObject().put("android",new JSONObject().put("url","https://github.com/COINLOGY/diakitw/releases/download/v"+version+"/app.apk").put("size",100).put("sha256","a".repeat(64)))))).toString();}
 public static void main(String[]args)throws Exception{
  String s=feed("0.5.10",60,"preview");ok(Updates.select(s,"preview").version.equals("0.5.10"));ok(Updates.select(s,"stable")==null);ok(Updates.select(feed("0.5.3",60,"preview"),"preview")==null);ok(Updates.select(feed("0.5.4",60,"preview"),"preview")==null);ok(Updates.select(feed("0.6.0",54,"preview"),"preview")==null);
  ok(Updates.select(feed("0.5.5",55,"preview"),"preview")==null);ok(Updates.select(feed("0.5.5",56,"preview"),"preview")==null);ok(Updates.select(feed("0.5.6",55,"preview"),"preview")==null);ok(Updates.select(feed("0.5.6",56,"preview"),"preview")!=null);
  for(String v:new String[]{"01.5.6","0.5.6-beta","0.5","-1.5.6","0.5.1000000"})bad(feed(v,60,"preview"));
  for(String change:new String[]{s.replace("github.com","evil.com"),s.replace("app.apk","../app.apk"),s.replace("app.apk","app.apk?x=1"),s.replace("app.apk","%61.apk"),s.replace("\"size\":100","\"size\":0"),s.replace("\"build\":60","\"build\":true"),s.replace("\"schema\":1","\"schema\":2"),s.replace("\"size\":100","\"size\":8589934593"),s.replace("a".repeat(64),"A".repeat(64)),s.replace("plain text","x".repeat(4097))," ".repeat(32769)})bad(change);
  Updates.Policy p=new Updates.Policy("preview",0,0,0,1000000);ok(!p.begin(false,1000000));p.start(1000000);ok(!p.begin(false,1002999));ok(p.begin(false,1003000));ok(!p.begin(true,1003001));int token=p.generation;p.stop();ok(!p.complete(token,true,1003002));p.start(1003003);ok(!p.begin(true,1003004));ok(p.begin(true,1063000));ok(p.complete(p.generation,false,1063001));ok(!p.begin(false,1123001));ok(p.begin(true,1123001));ok(p.complete(p.generation,true,1123002));ok(!p.begin(false,1123002+86400000-1));ok(p.begin(false,1123002+86400000));p.complete(p.generation,true,1123002+86400000);p.stop();p.channel("stable");ok(!p.active);ok(p.success==0);ok(!p.begin(true,999999999));
  Updates.Fetch cancelled=new Updates.Fetch();cancelled.cancel();try{cancelled.run();throw new AssertionError("cancel ignored");}catch(IOException expected){checks++;}
  System.out.println("UpdatesTest PASS "+checks+" assertions; offline parser, policy, cancellation");
 }
}
