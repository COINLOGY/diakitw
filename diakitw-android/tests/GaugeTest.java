package app.diakitw;
public class GaugeTest {
 static int checks;
 static void near(double expected,double actual){checks++;if(Double.isNaN(expected)?!Double.isNaN(actual):!Double.isFinite(actual)||Math.abs(expected-actual)>0.00001)throw new AssertionError(expected+" != "+actual);}
 public static void main(String[] args){
  // Approved v2 polygon, not the forked tail. Reflective lookup keeps RED a behavioral assertion.
  try {
   java.lang.reflect.Method method=Gauge.class.getMethod("needle",double.class,double.class);
   double[][] reference={{-99,0},{0,-8},{21,-4},{21,4},{0,8}};
   for(double f:new double[]{0,.125,.25,.5,.75,.875,1}){
    double[][] points=(double[][])method.invoke(null,f,114.0);
    near(5,points.length);double a=Math.PI*f;
    for(int i=0;i<5;i++){near(reference[i][0]*Math.cos(a)-reference[i][1]*Math.sin(a),points[i][0]);near(reference[i][0]*Math.sin(a)+reference[i][1]*Math.cos(a),points[i][1]);}
   }
   for(double f:new double[]{Double.NaN,-1,1.1,Double.POSITIVE_INFINITY})near(0,((double[][])method.invoke(null,f,114.0)).length);
  }catch(ReflectiveOperationException e){throw new AssertionError("Approved polygon geometry missing",e);}
  Gauge.Geometry labeled=new Gauge.Geometry(112,100,18);
  if(labeled.cy-labeled.radius<22)throw new AssertionError("Midpoint needs its own band ABOVE arc/needle");
  near(0,Gauge.fraction(0));near(.2,Gauge.fraction(20));near(.8,Gauge.fraction(80));near(1,Gauge.fraction(100));
  for(double n:new double[]{-1,101,Double.NaN,Double.POSITIVE_INFINITY,Double.NEGATIVE_INFINITY})near(Double.NaN,Gauge.fraction(n));
  near(180,Gauge.angle(0));near(270,Gauge.angle(.5));near(360,Gauge.angle(1));near(Double.NaN,Gauge.angle(Double.NaN));
  for(double w:new double[]{84,96,104,120})for(double h:new double[]{64,72,90}){
   Gauge.Geometry g=new Gauge.Geometry(w,h,12);
   for(int n=0;n<=100;n++)for(double[] p:Gauge.needle(n/100.0,g.radius)){
    checks++;if(g.cy+p[1]+4+12>h)throw new AssertionError("Tail invades bottom label band");
   }
   for(int i=0;i<=100;i++){double a=Math.toRadians(Gauge.angle(i/100.0));double x=g.cx+Math.cos(a)*g.radius,y=g.cy+Math.sin(a)*g.radius;checks++;if(x<3-1e-6||x>w-3+1e-6||y<3-1e-6||y>h-16+1e-6)throw new AssertionError("Arc out of bounds");}
   near(w/2,g.cx);
  }
  for(double n:new double[]{0,20,20.0001,80,80.0001,100}){int b=n<=20?0:n<=80?1:2;near(b,Core.band(n,false));near(2-b,Core.band(n,true));}
  near(Double.NaN,Gauge.angle(-.1));near(Double.NaN,Gauge.angle(1.1));
  System.out.println("PASS "+checks+" gauge normalization/angle assertions");
 }
}
