function gauge(canvas,p,battery,rate){
 const [c,w,h,font=12]=context(canvas);c.font=font+'px sans-serif';
 const labels=rate?['0',String(rate.max/2),String(rate.max)]:['0%','50%','100%'];
 const gutter=Math.max(...labels.map(t=>c.measureText(t)?.width||t.length*font*.6))/2+8;
 // Approved v2 SVG uses radius 114; reserve the entire rotating straight tail below the pivot.
 const r=Math.min(w/2-gutter,h-2*font-24,(h-font-16)/(1+Math.hypot(21,4)/114)),x=w/2,y=r+font+12;
 const known=valid(p)&&p<=100;canvas.dataset.needle=String(known);canvas.dataset.unit=rate?.unit||'%';if(r<=20)return;
 const bands=!known?[[0,100,'neutral']]:rate?[[0,100,rate.color]]:[[0,20,band(10,battery)],[20,80,'blue'],[80,100,band(90,battery)]];
 c.globalAlpha=known?.85:.24;c.lineWidth=9;
 for(const [start,end,color] of bands){c.beginPath();c.arc(x,y,r,Math.PI+start/100*Math.PI,Math.PI+end/100*Math.PI);c.strokeStyle=colors[color];c.stroke();}c.globalAlpha=1;
 c.fillStyle='#bdc9d2';c.textAlign='center';
 for(let i=0;i<=4;i++){const a=Math.PI+i/4*Math.PI;c.beginPath();c.moveTo(x+Math.cos(a)*(r-9),y+Math.sin(a)*(r-9));c.lineTo(x+Math.cos(a)*(r-16),y+Math.sin(a)*(r-16));c.lineWidth=1;c.strokeStyle='#8194a3';c.stroke();if(i%2===0)c.fillText(labels[i/2],x+Math.cos(a)*r,i===2?font+4:y+font+8);}
 if(known){const a=p/100*Math.PI,s=r/114;c.beginPath();for(const [i,[u,v]] of [[-99,0],[0,-8],[21,-4],[21,4],[0,8]].entries()){const px=x+(u*Math.cos(a)-v*Math.sin(a))*s,py=y+(u*Math.sin(a)+v*Math.cos(a))*s;if(i===0)c.moveTo(px,py);else c.lineTo(px,py);}c.closePath();c.fillStyle=colors[rate?.color||band(p,battery)];c.fill();c.beginPath();c.arc(x,y,4,0,2*Math.PI);c.fillStyle='#f0f4f8';c.fill();}
}
// End of released 0.5.2 gauge; test-only fixture, never shipped.
function updateCard() {}
