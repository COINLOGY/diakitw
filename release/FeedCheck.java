package app.diakitw;
import java.nio.file.*;
public class FeedCheck {
 public static void main(String[] args) throws Exception {
  String text=Files.readString(Path.of(args[0]));
  Updates.Release r=Updates.select(text,"preview");
  if(args.length>1) {if(r==null||!r.version.equals("0.5.4"))throw new AssertionError("old fixture must offer");}
  else if(r!=null)throw new AssertionError("current must not offer");
  if(Updates.select(text,"stable")!=null)throw new AssertionError("no stable release");
  System.out.println("Android actual shared manifest PASS: "+(args.length>1?"0.5.3 fixture offers 0.5.4":"0.5.4 no offer"));
 }
}
