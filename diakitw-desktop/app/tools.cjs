'use strict';
const fs=require('node:fs');
const linux={terminal:['gnome-terminal','konsole','xfce4-terminal','mate-terminal','lxterminal','xterm'],tasks:['gnome-system-monitor','plasma-systemmonitor','ksysguard','xfce4-taskmanager','mate-system-monitor','lxtask']};
function trustedExists(file){try{const s=fs.statSync(file);if(!s.isFile())return false;if(process.platform!=='win32'){const real=fs.realpathSync(file);if(!real.startsWith('/usr/')||s.uid!==0||(s.mode&0o022))return false;fs.accessSync(file,fs.constants.X_OK);}return true;}catch{return false;}}
function resolveTool(command,{platform=process.platform,systemRoot=process.env.SystemRoot,exists=trustedExists}={}){
 if(!['terminal','tasks'].includes(command))return null;
 if(platform==='win32'){
  if(typeof systemRoot!=='string'||! /^[A-Za-z]:\\Windows$/i.test(systemRoot))return null;
  const file=systemRoot+'\\System32\\'+(command==='terminal'?'cmd.exe':'Taskmgr.exe');return exists(file)?{file,args:command==='terminal'?['/D']:[]}:null;
 }
 if(platform==='linux'){for(const name of linux[command]){const file='/usr/bin/'+name;if(exists(file))return{file,args:[]};}}
 return null;
}
module.exports={resolveTool,trustedExists};
