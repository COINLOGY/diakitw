package app.diakitw;
public class CoreTest {
 static int assertions;
 static void eq(double expected,double actual){assertions++; if(Double.isNaN(expected)?!Double.isNaN(actual):!Double.isFinite(actual)||Math.abs(expected-actual)>0.00001)throw new AssertionError(expected+" != "+actual);}
 public static void main(String[] args){
 eq(75,Core.percent(100,25)); eq(Double.NaN,Core.percent(0,0)); eq(Double.NaN,Core.percent(10,11)); eq(Double.NaN,Core.percent(-1,0));
 eq(Double.NaN,Core.rate(-1,10,1000)); eq(Double.NaN,Core.rate(20,10,1000)); eq(Double.NaN,Core.rate(1,2,0)); eq(Double.NaN,Core.rate(1,2,5001)); eq(1024,Core.rate(100,2148,2000));
 eq(0,Core.band(20,false)); eq(1,Core.band(20.01,false)); eq(1,Core.band(80,false)); eq(2,Core.band(80.01,false)); eq(0,Core.band(90,true)); eq(-1,Core.band(Double.NaN,false));
 eq(0,Core.percent(100,100));eq(100,Core.percent(100,0));eq(Double.NaN,Core.percent(100,-1));
 eq(0,Core.rate(42,42,1000));eq(Double.NaN,Core.rate(42,-1,1000));eq(Double.NaN,Core.rate(1,2,-1));eq(0.2,Core.rate(1,2,5000));
 eq(-1,Core.band(Double.POSITIVE_INFINITY,false));eq(-1,Core.band(-1,false));eq(-1,Core.band(101,false));eq(2,Core.band(0,true));eq(1,Core.band(80,true));
 assertions++; if(!"Н/Д".equals(Core.number(Double.NaN))||!"7.0".equals(Core.number(7)))throw new AssertionError("format");
 try {
 java.lang.reflect.Method cpu=Core.class.getMethod("cpu",long.class,long.class,long.class,int.class);
 eq(25,(double)cpu.invoke(null,100L,1100L,1000L,4));
 eq(0,(double)cpu.invoke(null,100L,100L,1000L,4));
 for(long[] x:new long[][]{{-1,100,1000,4},{100,99,1000,4},{0,100,0,4},{0,100,-1,4},{0,100,5001,4},{0,100,1000,0},{0,100,1000,-1},{0,5000,1000,4}})eq(Double.NaN,(double)cpu.invoke(null,x[0],x[1],x[2],(int)x[3]));
 eq(100,(double)cpu.invoke(null,0L,4000L,1000L,4));
 }catch(ReflectiveOperationException e){throw new AssertionError("Missing normalized process CPU contract",e);}
 System.out.println("PASS "+assertions+" assertions");
 }
}
