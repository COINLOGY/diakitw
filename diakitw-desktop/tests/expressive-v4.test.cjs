const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('app/renderer.js','utf8');
const released=fs.readFileSync('tests/fixtures/gauge-052.js','utf8');
const colors={green:'#a6e640',blue:'#4cbfff',red:'#ff737d',neutral:'#94a1ae'};
function draw(src,p,w,h,rate,battery=false){
 const strokes=[],fills=[],labels=[];let path=[];
 const ctx={font:'',beginPath(){path=[]},moveTo(...v){path.push(['move',...v])},lineTo(...v){path.push(['line',...v])},arc(...v){path.push(['arc',...v])},closePath(){},
  measureText(t){return {width:t.length*7}},
  stroke(){strokes.push({path:[...path],width:this.lineWidth,color:this.strokeStyle,alpha:this.globalAlpha})},
  fill(){fills.push({path:[...path],color:this.fillStyle})},
  fillText(t,x,y){labels.push({t,x,y,font:this.font,color:this.fillStyle})}};
 const sandbox={context:()=>[ctx,w,h,12],valid:n=>typeof n==='number'&&Number.isFinite(n)&&n>=0,band:require('../app/core.cjs').band,colors,Math};
 vm.createContext(sandbox);vm.runInContext(src.slice(src.indexOf('function gauge('),src.indexOf('function updateCard('))+';this.draw=gauge',sandbox);
 sandbox.draw({dataset:{}},p,battery,rate);return JSON.parse(JSON.stringify({strokes,fills,labels}));
}
const bands=d=>d.strokes.filter(s=>s.path[0]?.[0]==='arc'&&s.path[0][3]>5);
const ticks=d=>d.strokes.filter(s=>s.path[0]?.[0]==='move');
test('v4 thinner arcs, expressive ticks/labels and inset dark hub; fixed geometry',()=>{
 for(const [w,h] of [[150,91],[240,145],[500,303]])for(const p of [0,12.5,20,50,80,100])for(const battery of [false,true])for(const rate of [undefined,{max:8,unit:'MiB/s',color:'green'},{max:8,unit:'MiB/s',color:'blue'}]){
  const d=draw(source,p,w,h,rate,battery),old=draw(released,p,w,h,rate,battery);
  assert.deepEqual(bands(d).map(s=>s.path),bands(old).map(s=>s.path),'centres/radii/angles unchanged');
  assert.deepEqual(bands(d).map(s=>s.color),bands(old).map(s=>s.color),'semantic colors');
  for(const s of bands(d))assert.equal(s.width,7);
  assert.deepEqual(ticks(d).map(s=>s.path),ticks(old).map(s=>s.path),'tick locations unchanged');
  ticks(d).forEach((s,i)=>{assert.equal(s.width,i%2===0?1.5:1);assert.equal(s.color,i%2===0?'#d6e2ec':'#8194a3')});
  assert.deepEqual(d.labels.map(({t,x,y})=>({t,x,y})),old.labels.map(({t,x,y})=>({t,x,y})));
  for(const l of d.labels){assert.equal(l.font,'600 12px sans-serif');assert.equal(l.color,'#edf4fc')}
  const hubFill=d.fills.at(-1),hubStroke=d.strokes.at(-1),needle=d.fills[0];
  assert.equal(hubFill.color,'#141a21');assert.deepEqual(hubFill.path,old.fills.at(-1).path,'same outer hub bounds');
  assert.equal(hubStroke.color,needle.color);assert.equal(hubStroke.width,1.5);
  assert.equal(hubStroke.path[0][3]+hubStroke.width/2,4,'outline remains inside old radius');
 }
});
test('major marks/labels increase measured contrast without resizing text',()=>{
 const bg=fs.readFileSync('app/style.css','utf8').match(/--card:(#[0-9a-f]{6})/i)[1];
 function luminance(hex){return hex.slice(1).match(/../g).map(h=>parseInt(h,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0)}
 function contrast(a,b){const values=[luminance(a),luminance(b)].sort((x,y)=>x-y);return (values[1]+.05)/(values[0]+.05)}
 const current=draw(source,50,240,145),old=draw(released,50,240,145);
 for(let i=0;i<3;i++){
  assert.ok(contrast(current.labels[i].color,bg)>=4.5);
  assert.ok(contrast(current.labels[i].color,bg)>contrast(old.labels[i].color,bg));
  assert.equal(current.labels[i].font.match(/\d+px/)[0],old.labels[i].font.match(/\d+px/)[0]);
 }
 for(const i of [0,2,4]){
  assert.ok(contrast(ticks(current)[i].color,bg)>=3);
  assert.ok(contrast(ticks(current)[i].color,bg)>contrast(ticks(old)[i].color,bg));
 }
});
test('unknown: neutral arc, no needle/hub, labels preserved',()=>{
 for(const p of [null,undefined,NaN,Infinity,-1,101]){
  const d=draw(source,p,240,145);assert.equal(d.fills.length,0);assert.equal(d.strokes.length,6);
  assert.equal(bands(d)[0].color,colors.neutral);assert.equal(bands(d)[0].alpha,.24);
 }
});
