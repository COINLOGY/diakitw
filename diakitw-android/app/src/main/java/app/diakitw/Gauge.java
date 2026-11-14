package app.diakitw;
/** Pure display geometry: invalid measurements stay unknown, never a zero needle. */
public final class Gauge {
 private Gauge(){}
 public static final class Geometry {
  public final double cx,cy,radius,tailClearance;
  public Geometry(double width,double height,double labelHeight){
   // Dedicated top/midpoint and bottom/endpoint bands, outside the needle sweep.
   radius=Math.max(0,Math.min(width/2-5,(height-2*labelHeight-10)/(1+Math.hypot(21,4)/114)));cx=width/2;cy=labelHeight+5+radius;tailClearance=radius*Math.hypot(21,4)/114;
  }
 }
 // Exact approved SVG offsets relative to (150,146), scaled by arc radius 114.
 public static double[][] needle(double fraction,double radius){
  if(!Double.isFinite(angle(fraction))||!Double.isFinite(radius)||radius<=0)return new double[0][0];
  double[][] p={{-99,0},{0,-10},{21,-4},{21,4},{0,10}};
  double a=Math.PI*fraction,c=Math.cos(a),s=Math.sin(a),scale=radius/114;
  for(double[] v:p){double x=v[0],y=v[1];v[0]=(x*c-y*s)*scale;v[1]=(x*s+y*c)*scale;}
  return p;
 }
 public static double fraction(double percent){return Double.isFinite(percent)&&percent>=0&&percent<=100?percent/100:Double.NaN;}
 public static double angle(double fraction){return Double.isFinite(fraction)&&fraction>=0&&fraction<=1?180+180*fraction:Double.NaN;}
}
