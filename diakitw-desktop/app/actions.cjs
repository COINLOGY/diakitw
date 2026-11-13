'use strict';
const {resolveTool}=require('./tools.cjs');const {mapURL}=require('./geo.cjs');
async function dispatch(command,{resolve=resolveTool,spawn=require('node:child_process').spawn,openExternal,geo}={}){
 if(!['terminal','tasks','map'].includes(command))return{ok:false,reason:'Команда запрещена'};
 try{
  if(command==='map'){const url=geo?.status==='current'?mapURL(geo):null;if(!url)return{ok:false,reason:'Нет актуального местоположения'};await openExternal(url);return{ok:true};}
  const spec=resolve(command);if(!spec)return{ok:false,reason:'Поддерживаемая системная программа не найдена'};
  return await new Promise(resolve=>{const child=spawn(spec.file,spec.args,{shell:false,detached:true,stdio:'ignore',windowsHide:false,cwd:require('node:os').homedir()});child.once('error',()=>resolve({ok:false,reason:'ОС не разрешила запуск программы'}));child.once('spawn',()=>{child.unref();resolve({ok:true});});});
 }catch{return{ok:false,reason:'Не удалось открыть системную программу'};}
}
module.exports={dispatch};
