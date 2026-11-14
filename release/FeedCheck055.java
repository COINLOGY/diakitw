package app.diakitw;
import java.nio.file.*;
public class FeedCheck055 {
 public static void main(String[] args) throws Exception {
  String text=Files.readString(Path.of("release/fixtures/v1-0.5.5.json"));
  Updates.Release r=Updates.select(text,"stable");
  if(args[0].equals("old")) {
   if(r==null||!r.version.equals("0.5.5")||r.build!=55||!r.notes.contains("uninstall")||!r.notes.contains("данные")) throw new AssertionError("old offer and migration notes");
  } else if(r!=null) throw new AssertionError("current/newer no offer");
  if(Updates.select(text,"preview")!=null)throw new AssertionError("stable only");
  System.out.println("PASS Android exact final five-platform feed: "+args[0]+"; channel and migration notes");
 }
}
