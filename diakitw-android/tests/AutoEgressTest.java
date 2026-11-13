package app.diakitw;
public final class AutoEgressTest {
 static void check(boolean b){if(!b)throw new AssertionError();}
 public static void main(String[] args){
  AutoEgress a=new AutoEgress();a.resume(0);check(a.begin(1499,false)==-1);long t=a.begin(1500,false);check(t>=0);check(a.begin(1501,false)==-1);check(a.complete(t));
  check(a.begin(61499,false)==-1);long fallback=a.begin(61500,false);check(fallback>=0);check(!a.complete(t));check(a.running);check(a.complete(fallback));
  a.changed(62000);a.changed(62500);check(a.begin(71499,false)==-1);long vpn=a.begin(71500,false);check(vpn>=0);
  a.changed(72000);check(!a.complete(vpn));check(a.begin(81500,true)==-1);long next=a.begin(81500,false);check(next>=0);
  a.pause();check(!a.complete(next));check(a.begin(999999,false)==-1);a.resume(1000000);long resumed=a.begin(1001500,false);check(resumed>=0);a.pause();a.resume(1002000);check(a.begin(1003500,false)==-1);check(!a.complete(resumed));check(a.begin(1011500,false)>=0);
  AutoEgress limited=new AutoEgress();limited.resume(0);
  try{AutoEgress.class.getDeclaredMethod("blockUntil",long.class).invoke(limited,86400000L);}catch(ReflectiveOperationException e){throw new AssertionError("Missing quota backoff");}
  limited.changed(100);limited.pause();limited.resume(200);check(limited.begin(86399999L,false)==-1);check(limited.begin(86400000L,false)>=0);
  System.out.println("PASS quota backoff survives resume and route changes");
  System.out.println("PASS auto initial, debounce/cooldown, fake VPN changes, fallback, busy/no overlap, pause cancellation generations");
 }
}
