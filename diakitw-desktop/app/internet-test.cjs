'use strict';
const https=require('node:https');
// Only a fixed endpoint, one bounded request, and never before native consent.
function probe(){return new Promise(resolve=>{const req=https.get('https://www.gstatic.com/generate_204',{timeout:5000,headers:{'Cache-Control':'no-cache'}},res=>{let bytes=0;res.on('data',chunk=>{bytes+=chunk.length;if(bytes>16384)req.destroy(new Error('response too large'));});res.on('end',()=>resolve({statusCode:res.statusCode,bytes}));});req.on('timeout',()=>req.destroy(new Error('timeout')));req.on('error',()=>resolve({statusCode:0,bytes:0}));});}
async function internetTest({consent,probe:request=probe}={}){
 if(typeof consent!=='function'||await consent()!==true)return{ok:false,reason:'Тест отменён; сетевой запрос не выполнялся'};
 const started=performance.now();try{const result=await request();if(result.statusCode!==204||!Number.isSafeInteger(result.bytes)||result.bytes<0||result.bytes>16384)return{ok:false,reason:'Сеть недоступна или ответ не прошёл проверку'};return{ok:true,reason:'Интернет доступен · отклик '+Math.round(performance.now()-started)+' мс (не тест скорости)'};}catch{return{ok:false,reason:'Сеть недоступна или истекло время ожидания'};}
}
module.exports={internetTest,probe};
