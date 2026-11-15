const {test}=require("node:test");
const a=require("node:assert/strict"),fs=require("node:fs"),vm=require("node:vm");
const src=fs.readFileSync("app/renderer.js","utf8");
function values(rx,tx){const e=new Map(),get=id=>{if(!e.has(id))e.set(id,{textContent:"",classList:{toggle(){}},dataset:{}});return e.get(id)};const s={$:get,latest:{time:1,interfaces:[{name:"eth0",rx,tx}]},selected:"eth0",history:[],valid:n=>typeof n==="number"&&Number.isFinite(n)&&n>=0,gauge(){},drawHistory(){},Math};vm.createContext(s);vm.runInContext(src.slice(src.indexOf("const speed="),src.indexOf("const cards="))+src.slice(src.indexOf("function network("),src.indexOf("function render("))+";this.network=network",s);s.network(false);return {rx:get("rx").textContent,tx:get("tx").textContent}}
test("arrows follow complete KiB/s and MiB/s readings",()=>{a.deepEqual(values(166400,19608),{rx:"162.5 KiB/s ↓",tx:"19.1 KiB/s ↑"});a.deepEqual(values(1048576,0),{rx:"1.0 MiB/s ↓",tx:"0.0 KiB/s ↑"})});
test("unavailable readings retain direction after placeholder",()=>a.deepEqual(values(null,null),{rx:"Н/Д ↓",tx:"Н/Д ↑"}));
test("headings do not duplicate arrows before values",()=>{const html=fs.readFileSync("app/index.html","utf8");a.match(html,/<span>Приём<\/span>/);a.match(html,/<span>Передача<\/span>/);a.ok(html.includes('<strong id="rx">Н/Д ↓</strong>'));a.ok(html.includes('<strong id="tx">Н/Д ↑</strong>'))});
