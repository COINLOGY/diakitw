package app.diakitw;
import java.nio.file.*;
public class FeedCheck {
 public static void main(String[] args) throws Exception {
  String text=Files.readString(Path.of(args[0]));
  if(args.length>1 && args[1].equals("current-feed")){
   Updates.Release offer=Updates.select(text,"preview","1.0.1",101);
   if(offer==null||!offer.version.equals("1.0.2")||offer.build!=102)throw new AssertionError("1.0.1 must offer 1.0.2");
   if(Updates.select(text,"preview","1.0.2",102)!=null)throw new AssertionError("1.0.2 must be current");
   if(Updates.select(text,"stable","1.0.1",101)!=null)throw new AssertionError("no stable v2 release");
   System.out.println("Android production parser 1.0.1 -> 1.0.2; current -> none PASS");return;
  }
  String installedVersion=args.length>1?"0.5.3":"1.0.1";int installedBuild=args.length>1?53:101;
  Updates.Release r=Updates.select(text,"preview",installedVersion,installedBuild);
  if(args.length>1) {if(r==null||!r.version.equals("0.5.4"))throw new AssertionError("old fixture must offer");}
  else if(r!=null)throw new AssertionError("current must not offer");
  if(Updates.select(text,"stable",installedVersion,installedBuild)!=null)throw new AssertionError("no stable release");
  System.out.println("Android actual shared manifest PASS: "+(args.length>1?"0.5.3 fixture offers 0.5.4":"0.5.4 no offer"));
 }
}
