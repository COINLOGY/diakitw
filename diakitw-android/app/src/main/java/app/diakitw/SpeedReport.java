package app.diakitw;
import org.json.*;
import java.util.*;
/** One bounded last-run report; never telemetry invented from absent samples. */
final class SpeedReport {
 static double average(List<Double> samples){if(samples.isEmpty())return Double.NaN;double sum=0;for(double x:samples){if(!Double.isFinite(x)||x<0)return Double.NaN;sum+=x;}return sum/samples.size();}
 static double jitter(List<Double> samples){if(samples.size()<2||!Double.isFinite(average(samples)))return Double.NaN;double sum=0;for(int i=1;i<samples.size();i++)sum+=Math.abs(samples.get(i)-samples.get(i-1));return sum/(samples.size()-1);}
 static Object known(double n){return Double.isFinite(n)&&n>=0?n:JSONObject.NULL;}
 static String number(double n){return Double.isFinite(n)&&n>=0?String.format(Locale.US,"%.1f",n):"Н/Д";}
 static String latency(SpeedTest.Result r){return "HTTP RTT (не ICMP) · "+number(average(r.samplesMs))+" мс · "+r.samplesMs.size()+"/3 пробы\nHTTP jitter · "+number(jitter(r.samplesMs))+" мс";}
 static String text(SpeedTest.Result r){return "diakitw 0.5.5a · "+r.status+"\n↓ "+number(r.down)+"   ↑ "+number(r.up)+" Мбит/с\n"+latency(r)+"\nПробы HTTP, мс: "+(r.samplesMs.isEmpty()?"Н/Д":r.samplesMs.toString())+"\nПрочитано: "+r.downBytes+" байт\nПередано в сокет: "+r.upBytes+" байт (не подтверждение доставки)\nВремя: "+(r.startedAtEpochMs==0?"Н/Д":r.elapsedMs)+" мс\nЛимиты: ↓ "+r.downloadBudget+" / ↑ "+r.uploadBudget+" байт, "+r.deadlineMs+" мс; HTTP/TLS сверх бюджета.\nCloudflare · speed.cloudflare.com\nHTTP RTT включает соединение, TLS и ответ сервера; jitter = среднее |разность соседних успешных проб|. Потери пакетов не измеряются. Н/Д — неизвестно; неполный тест не подтверждает скорость линии.";}
 static String json(SpeedTest.Result r){try{
  JSONArray samples=new JSONArray();for(double n:r.samplesMs)samples.put(known(n));
  JSONObject latency=new JSONObject().put("protocol","HTTP, not ICMP").put("unit","ms").put("samplesMs",samples).put("sampleCount",samples.length()).put("requestedSamples",3).put("averageMs",known(average(r.samplesMs))).put("jitterMs",known(jitter(r.samplesMs))).put("jitterMethod","mean absolute successive difference of successful HTTP samples");
  return new JSONObject().put("schema",1).put("appVersion","0.5.5a").put("build",55).put("state",r.state).put("status",r.status).put("endpoint","https://speed.cloudflare.com").put("startedAtEpochMs",r.startedAtEpochMs==0?JSONObject.NULL:r.startedAtEpochMs).put("elapsedMs",r.startedAtEpochMs==0?JSONObject.NULL:r.elapsedMs).put("httpLatency",latency).put("packetLossPercent",JSONObject.NULL).put("downloadMbps",known(r.down)).put("uploadMbps",known(r.up)).put("downloadBytesRead",r.downBytes).put("uploadBytesWrittenToSocket",r.upBytes).put("downloadBudgetBytes",r.downloadBudget).put("uploadBudgetBytes",r.uploadBudget).put("deadlineMs",r.deadlineMs).put("overheadIncludedInBudget",false).toString(2);
 }catch(JSONException e){throw new IllegalStateException("Report serialization failed",e);}}
}
