package app.diakitw;
final class SpeedScale {
 static double maximum(double n){
  if(!Double.isFinite(n)||n<0)return Double.NaN;
  if(n<=10)return 10;
  double base=Math.pow(10,Math.floor(Math.log10(n)));
  for(double step:new double[]{1,2,5,10}){double v=base*step;if(Double.isFinite(v)&&v>=n)return v;}
  return Double.MAX_VALUE;
 }
 static String label(double n){return n<10000?String.format(java.util.Locale.US,n%1==0?"%.0f":"%.1f",n):String.format(java.util.Locale.US,"%.1e",n);}
}
