const test=require('node:test'),assert=require('node:assert/strict');
const tools=()=>require('../app/tools.cjs');
test('launcher only dispatches command enums, fixed argv, shell false and safe main-owned map',async()=>{
 const {dispatch}=require('../app/actions.cjs');const {EventEmitter}=require('node:events');const calls=[];
 const options={resolve:command=>tools().resolveTool(command,{platform:'linux',exists:()=>true}),spawn:(file,args,opts)=>{calls.push({file,args,opts});const p=new EventEmitter();p.unref=()=>{};queueMicrotask(()=>p.emit('spawn'));return p;},openExternal:async url=>calls.push(url),geo:{status:'current',ip:'1.2.3.4',country:'Germany',city:'Berlin',latitude:52,longitude:13}};
 assert.equal((await dispatch('terminal',options)).ok,true);assert.equal(calls[0].opts.shell,false);assert.deepEqual(calls[0].args,[]);
 for(const bad of ['rm -rf /','https://evil.test',{},null,['terminal']])assert.equal((await dispatch(bad,options)).ok,false);
 assert.equal(calls.length,1);assert.equal((await dispatch('map',options)).ok,true);assert.equal(new URL(calls[1]).hostname,'www.openstreetmap.org');
 assert.equal((await dispatch('map',{...options,geo:{...options.geo,status:'stale'}})).ok,false);
 assert.equal((await dispatch('tasks',{...options,resolve:()=>null})).ok,false);
 assert.equal((await dispatch('tasks',{...options,spawn:()=>{throw Error('private path')}})).ok,false);
});
test('fixed Windows system commands and Linux desktop allowlist; no user command or PATH lookup',()=>{
 const {resolveTool}=tools(),exists=()=>true;
 assert.deepEqual(resolveTool('terminal',{platform:'win32',systemRoot:'C:\\Windows',exists}),{file:'C:\\Windows\\System32\\cmd.exe',args:['/D']});
 assert.deepEqual(resolveTool('tasks',{platform:'win32',systemRoot:'D:\\Windows',exists}),{file:'D:\\Windows\\System32\\Taskmgr.exe',args:[]});
 for(const name of ['gnome-terminal','konsole','xfce4-terminal','xterm'])assert.equal(resolveTool('terminal',{platform:'linux',exists:p=>p==='/usr/bin/'+name}).file,'/usr/bin/'+name);
 for(const name of ['gnome-system-monitor','plasma-systemmonitor','ksysguard','xfce4-taskmanager','mate-system-monitor'])assert.equal(resolveTool('tasks',{platform:'linux',exists:p=>p==='/usr/bin/'+name}).file,'/usr/bin/'+name);
 for(const command of ['exec','terminal;whoami',{},null,'map'])assert.equal(resolveTool(command,{platform:'linux',exists}),null);
 assert.equal(resolveTool('terminal',{platform:'win32',systemRoot:'C:\\Users\\bad',exists}),null);
 assert.equal(resolveTool('tasks',{platform:'linux',exists:()=>false}),null);
 assert.equal(resolveTool('tasks',{platform:'darwin',exists}),null);
});
