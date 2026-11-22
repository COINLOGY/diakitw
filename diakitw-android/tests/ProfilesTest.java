package app.diakitw;

import java.util.ArrayList;
import org.json.JSONObject;

public final class ProfilesTest {
 static void check(boolean yes,String message){if(!yes)throw new AssertionError(message);}
 static JSONObject profile(String id,String name)throws Exception{return new JSONObject().put("id",id).put("name",name);}
 public static void main(String[] args)throws Exception{
  ArrayList<JSONObject> profiles=new ArrayList<>();
  profiles.add(profile("one","First"));profiles.add(profile("two","Second"));profiles.add(profile("three","Third"));
  check(Profiles.remove(profiles,"two"),"existing ID deleted");
  check(profiles.size()==2,"only one record deleted");
  check("one".equals(profiles.get(0).getString("id"))&&"three".equals(profiles.get(1).getString("id")),"other records retained in order");
  check(!Profiles.remove(profiles,"missing"),"missing ID does not change list");
  check(!Profiles.remove(profiles,""),"empty ID cannot delete");
  check(profiles.size()==2,"unknown IDs retain all records");
  check(Profiles.remove(profiles,"one")&&Profiles.remove(profiles,"three")&&profiles.isEmpty(),"last profile can be removed");
  System.out.println("PASS ProfilesTest");
 }
}
