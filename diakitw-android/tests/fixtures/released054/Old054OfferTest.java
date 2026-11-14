package app.diakitw;
import org.json.*;import java.nio.file.*;
public final class Old054OfferTest {
 static String feed(String v,int b)throws Exception{return new JSONObject().put("schema",1).put("releases",new JSONArray().put(new JSONObject().put("version",v).put("build",b).put("channel","preview").put("notes","Android 0.5.5a · build 55; буквенная версия в APK").put("assets",new JSONObject().put("android",new JSONObject().put("url","https://github.com/COINLOGY/diakitw/releases/download/v"+v+"/diakitw-android-0.5.5a-candidate.apk").put("sha256","a".repeat(64)).put("size",100))))).toString();}
 public static void main(String[]args)throws Exception{
  if(Updates.select(feed("0.5.4",55),"preview")!=null)throw new AssertionError("same numeric version should NOT offer");
  try{Updates.select(feed("0.5.4a",55),"preview");throw new AssertionError("letter admitted");}catch(IllegalArgumentException expected){}
  String input=args.length==0?feed("0.5.5",55):Files.readString(Path.of(args[0]));Updates.Release r=Updates.select(input,"preview");
  if(r==null||!r.version.equals("0.5.5")||r.build!=55||!r.notes.contains("0.5.5a")||!r.url.endsWith("diakitw-android-0.5.5a-candidate.apk"))throw new AssertionError("old-to-new offer");
  if(Updates.select(input,"stable")!=null)throw new AssertionError("wrong channel");
  System.out.println("EXACT released 054 parser PASS: numeric 0.5.5/build55 -> offer; displayed title 0.5.5, notes 0.5.5a, letter APK basename accepted; 0.5.4/build55 no offer; 0.5.4a rejected; preview only. No old binary modification.");
 }
}
