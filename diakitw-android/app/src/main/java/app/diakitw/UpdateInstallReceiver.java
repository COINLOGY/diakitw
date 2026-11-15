package app.diakitw;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.os.Build;
import android.util.Log;
import android.widget.Toast;

/** PackageInstaller owns the result; user action is never skipped or auto-approved. */
public final class UpdateInstallReceiver extends BroadcastReceiver {
 @Override public void onReceive(Context context,Intent result){
  if(!"app.diakitw.UPDATE_INSTALL".equals(result.getAction()))return;
  int status=result.getIntExtra(PackageInstaller.EXTRA_STATUS,PackageInstaller.STATUS_FAILURE);
  if(status==PackageInstaller.STATUS_PENDING_USER_ACTION){
   Intent confirmation;
   if(Build.VERSION.SDK_INT>=33)confirmation=result.getParcelableExtra(Intent.EXTRA_INTENT,Intent.class);
   else confirmation=result.getParcelableExtra(Intent.EXTRA_INTENT);
   if(confirmation==null){Log.e("diakitw","Installer omitted confirmation intent");return;}
   confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
   try{context.startActivity(confirmation);}catch(RuntimeException e){Log.e("diakitw","User must open Android installer manually",e);}
  }else if(status==PackageInstaller.STATUS_SUCCESS){
   Log.i("diakitw","Android reported update installation success");
  }else{
   Log.w("diakitw","Android installer status="+status+" message="+result.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE));
   Toast.makeText(context,"Установка отклонена Android или пользователем",Toast.LENGTH_LONG).show();
  }
 }
}
