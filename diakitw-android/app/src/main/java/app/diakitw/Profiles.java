package app.diakitw;

import java.util.List;
import org.json.JSONObject;

final class Profiles {
 private Profiles() {}
 static boolean remove(List<JSONObject> profiles, String id) {
  if (id == null || id.isEmpty()) return false;
  for (int i = 0; i < profiles.size(); i++) {
   if (id.equals(profiles.get(i).optString("id"))) {
    profiles.remove(i);
    return true;
   }
  }
  return false;
 }
}
