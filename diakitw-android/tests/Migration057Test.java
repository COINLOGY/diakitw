package app.diakitw;
import org.json.*;
public final class Migration057Test {
 static int checks;
 static void check(boolean value,String message){checks++;if(!value)throw new AssertionError(message);}
 static String feed(String channel)throws Exception {
  return new JSONObject().put("schema",1).put("releases",new JSONArray().put(new JSONObject()
   .put("version","0.5.7").put("build",57).put("channel",channel).put("notes","Android 0.5.7 · build 57")
   .put("assets",new JSONObject().put("android",new JSONObject().put("url","https://github.com/COINLOGY/diakitw/releases/download/v0.5.7/diakitw-android-0.5.7.apk")
    .put("size",1234).put("sha256","a".repeat(64)))))).toString();
 }
 public static void main(String[] args)throws Exception {
  boolean old=args.length==1&&args[0].equals("old");
  check((Updates.select(feed("preview"),"preview")!=null)==old,"preview offer mismatch");
  check((Updates.select(feed("stable"),"stable")!=null)==old,"stable offer mismatch");
  check(Updates.select(feed("preview"),"stable")==null,"cross-channel preview leak");
  check(Updates.select(feed("stable"),"preview")==null,"cross-channel stable leak");
  System.out.println("Migration057Test PASS "+checks+" assertions; "+(old?"released 055a->057 offer":"057->057 no offer")+" both channels");
 }
}
