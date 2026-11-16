 'use strict';
function diagnose(snapshot){
 if(!snapshot)return 'Диагностика ожидает первого локального замера.';
 const notes=[];const percent=p=>p&&Number.isFinite(p.used)&&Number.isFinite(p.total)&&p.total>0?Math.round(100*p.used/p.total):null;
 if(Number.isFinite(snapshot.cpu)&&snapshot.cpu>=85)notes.push('CPU: '+Math.round(snapshot.cpu)+'%');
 for(const [name,key] of [['RAM','ram'],['SWAP','swap'],['Диск','disk']]){const n=percent(snapshot[key]);if(n!==null&&n>=85)notes.push(name+': '+n+'%');}
 const battery=snapshot.battery?.percent;if(Number.isFinite(battery)&&battery<=20)notes.push('Батарея: '+Math.round(battery)+'%');
 if(!Array.isArray(snapshot.interfaces)||snapshot.interfaces.length===0)notes.push('Сетевые интерфейсы не обнаружены');
 return notes.length?'Локальные показатели требуют внимания — '+notes.join('; ')+'. Это не диагноз оборудования.':'Локальные показатели ниже порогов CPU/RAM/SWAP/диска 85% и батареи 20%. Это не проверка здоровья оборудования.';
}
module.exports={diagnose};
