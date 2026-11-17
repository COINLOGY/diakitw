package app.diakitw;

/** Device-wide cumulative OS counters; unsupported/reset baselines are unknown. */
final class TrafficRate {
 static final class Rates {final double rx,tx; Rates(double rx,double tx){this.rx=rx;this.tx=tx;}}
 private long rx=-1,tx=-1,nanos=-1;
 void reset(){rx=tx=nanos=-1;}
 Rates update(long nextRx,long nextTx,long now){
  double receive=rate(rx,nextRx,nanos,now),send=rate(tx,nextTx,nanos,now);
  rx=nextRx;tx=nextTx;nanos=now;
  return new Rates(receive,send);
 }
 static double rate(long before,long after,long start,long end){
  if(before<0||after<before||start<0||end<=start)return Double.NaN;
  double mbps=(after-before)*8.0/(end-start)*1000.0;
  return Double.isFinite(mbps)&&mbps>=0?mbps:Double.NaN;
 }
}
