const {execFile}=require('node:child_process');
function run(executable,args,{signal,timeout=3500,maxBuffer=262144}={}){return new Promise((resolve,reject)=>{execFile(executable,args,{signal,timeout,maxBuffer,windowsHide:true,shell:false,encoding:'utf8',killSignal:'SIGKILL'},(error,stdout)=>error?reject(new Error('Telemetry command unavailable')):resolve(stdout));});}
module.exports={run};
