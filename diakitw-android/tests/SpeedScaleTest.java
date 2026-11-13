package app.diakitw;
public final class SpeedScaleTest {
 public static void main(String[] args)throws Exception {
  Class<?> c=Class.forName("app.diakitw.SpeedScale");
  java.lang.reflect.Method scale=c.getDeclaredMethod("maximum",double.class);scale.setAccessible(true);
  for(double n:new double[]{0,1,10,10.1,100,1000,1e100,Double.MAX_VALUE}) {
   double m=(Double)scale.invoke(null,n);if(!Double.isFinite(m)||m<n||m<=0)throw new AssertionError("scale "+n);
  }
  for(double n:new double[]{-1,Double.NaN,Double.POSITIVE_INFINITY})if(!Double.isNaN((Double)scale.invoke(null,n)))throw new AssertionError("unknown");
  System.out.println("PASS speed scale zero, boundary, adaptive overflow, unknown");
 }
}
