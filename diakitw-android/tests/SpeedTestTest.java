package app.diakitw;
public final class SpeedTestTest {
 static int assertions;
 static void check(boolean b){assertions++;if(!b)throw new AssertionError("check "+assertions);}
 public static void main(String[] args)throws Exception{
  Class<?> c=Class.forName("app.diakitw.SpeedTest");
  var rate=c.getDeclaredMethod("mbps",long.class,double.class);rate.setAccessible(true);
  check((double)rate.invoke(null,1000000L,1000000000.0)==8.0);
  for(double n:new double[]{0,-1,Double.NaN,Double.POSITIVE_INFINITY})check(Double.isNaN((double)rate.invoke(null,1L,n)));
  check(Double.isNaN((double)rate.invoke(null,-1L,1.0)));
  check(Double.isFinite((double)rate.invoke(null,Long.MAX_VALUE,1e9)));
  check(Double.isNaN((double)rate.invoke(null,Long.MAX_VALUE,Double.MIN_VALUE)));
  for(int[] budget:new int[][]{{0,1,1},{1,0,1},{Integer.MAX_VALUE,1,1},{1,Integer.MAX_VALUE,1},{1,1,Integer.MAX_VALUE}}){boolean rejected=false;try{new SpeedTest(path->{throw new AssertionError();},budget[0],budget[1],budget[2]);}catch(IllegalArgumentException e){rejected=true;}check(rejected);}
  System.out.println("Speed math: "+assertions+" assertions PASS");
 }
}
