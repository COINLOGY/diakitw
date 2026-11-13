package app.diakitw;
import java.util.Locale;
public final class Core {
 public static double percent(long total,long available){return total<=0||available<0||available>total?Double.NaN:100.0*(total-available)/total;}
 public static double rate(long previous,long current,long ms){return previous<0||current<previous||ms<=0||ms>5000?Double.NaN:(current-previous)*1000.0/ms;}
 /** Process CPU milliseconds / monotonic wall milliseconds / available logical processors.
  * Shares rate's <=5s freshness contract. Impossible/reset samples are unknown, not clamped. */
 public static double cpu(long previous,long current,long elapsedMs,int processors){double p=rate(previous,current,elapsedMs)/10.0/processors;return processors<=0||!Double.isFinite(p)||p<0||p>100?Double.NaN:p;}
 public static int band(double p,boolean battery){if(!Double.isFinite(p)||p<0||p>100)return -1; int b=p<=20?0:p<=80?1:2;return battery?2-b:b;}
 public static String number(double n){return Double.isFinite(n)&&n>=0?String.format(Locale.ROOT,"%.1f",n):"Н/Д";}
}
