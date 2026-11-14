const {app,BrowserWindow,ipcMain,protocol,session,net,Menu,shell}=require('electron');const path=require('node:path');const {pathToFileURL}=require('node:url');const {Collector}=require('./collector.cjs');const {Sampler,validSender,allowedRequest}=require('./lifecycle.cjs');
protocol.registerSchemesAsPrivileged([{scheme:'diakitw',privileges:{standard:true,secure:true,supportFetchAPI:true}}]);
const {Egress,lookupEgress}=require('./egress.cjs');const {mapURL}=require('./geo.cjs');const {resolveTool}=require('./tools.cjs');const {dispatch}=require('./actions.cjs');
function boot({collector=new Collector(),onWindow=()=>{},userData,lookup=lookupEgress}={}){
 if(userData)app.setPath('userData',userData);
 let win,sampler,egress,updates;app.whenReady().then(async()=>{
 // Native menus and visible overflow share the same fixed actions.
 const files=new Set(['index.html','style.css','renderer.js','logo.svg','icon.png']);
 protocol.handle('diakitw',request=>{const u=new URL(request.url);const name=u.pathname.slice(1);return u.hostname==='app'&&files.has(name)?net.fetch(pathToFileURL(path.join(__dirname,name)).href):new Response('',{status:403});});
 session.defaultSession.setPermissionRequestHandler((_wc,_p,callback)=>callback(false));session.defaultSession.setPermissionCheckHandler(()=>false);
 const assets=new Set([...files].flatMap(name=>['diakitw://app/'+name,pathToFileURL(path.join(__dirname,name)).href]));
 session.defaultSession.webRequest.onBeforeRequest((details,callback)=>callback({cancel:!allowedRequest(details.url,assets)}));
 win=new BrowserWindow({width:1100,height:760,minWidth:640,minHeight:600,title:'diakitw',backgroundColor:'#141a21',icon:path.join(__dirname,'icon.png'),webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,sandbox:true,nodeIntegration:false,webSecurity:true,webviewTag:false}});
 win.webContents.setWindowOpenHandler(()=>({action:'deny'}));win.webContents.on('will-navigate',e=>e.preventDefault());win.webContents.on('will-attach-webview',e=>e.preventDefault());
 let lastCommand=-Infinity;
 const invoke=async command=>{if(performance.now()-lastCommand<1000)return{ok:false,reason:'Подождите секунду'};lastCommand=performance.now();const result=await dispatch(command,{geo:egress?.state,openExternal:url=>shell.openExternal(url)});if(!result.ok&&!win.isDestroyed())win.webContents.send('action-result',result);return result;};
 const {Checker,asset}=require('./updates.cjs');const fs=require('node:fs');const stateFile=path.join(app.getPath('userData'),'update-state-v1.json');let saved={},offer=null;
 try{if(fs.statSync(stateFile).size<=2048)saved=JSON.parse(fs.readFileSync(stateFile,'utf8'));}catch(_){}
 const publishUpdate=data=>{if(!win.isDestroyed())win.webContents.send('updates',data);};
 updates=new Checker({platform:process.platform==='win32'?'windows-x64':'linux-x64',state:saved&&typeof saved==='object'?saved:{},save:state=>{try{fs.writeFileSync(stateFile,JSON.stringify(state),{mode:0o600});}catch(_){}},notify:data=>{offer=data.status==='available'?data.release:null;publishUpdate(data);}});
 ipcMain.handle('update-command',async(event,command)=>{if(!validSender(event,win.webContents)||!['check','download','later'].includes(command))return false;if(command==='check')return updates.check(true);if(command==='later'){offer=null;publishUpdate({status:'dismissed'});return true;}if(!offer)return false;try{asset(offer.asset,offer.version);await shell.openExternal(offer.asset.url);return true;}catch(_){publishUpdate({status:'download-error'});return false;}});
 const updateItems=()=>[{label:'Проверить обновления…',click:()=>updates.check(true)},{label:'Канал обновлений',submenu:[['stable','Стабильный'],['preview','Тестовый']].map(([value,label])=>({label,type:'radio',checked:updates.state.channel===value,click:()=>{offer=null;publishUpdate({status:'dismissed'});updates.channel(value);Menu.setApplicationMenu(Menu.buildFromTemplate([{label:'diakitw',submenu:menu()}]));}}))}];
 const toolItems=()=>['terminal','tasks'].map(command=>{const available=!!resolveTool(command);const label=command==='terminal'?'Терминал':'Диспетчер задач';return{id:command,label:label+(available?'':' — программа не найдена'),enabled:available,click:()=>invoke(command)};});
 const menu=()=>Menu.buildFromTemplate([...toolItems(),{type:'separator'},...updateItems(),{label:'В диспетчере: нажмите CPU для сортировки',enabled:false},{type:'separator'},{role:'quit',label:'Выход'}]);
 Menu.setApplicationMenu(Menu.buildFromTemplate([{label:'diakitw',submenu:menu()}]));
 ipcMain.handle('command',async(event,command)=>{if(!validSender(event,win.webContents)||!['terminal','tasks','map','menu'].includes(command))return{ok:false,reason:'Команда запрещена'};if(command==='menu'){menu().popup({window:win});return{ok:true};}return invoke(command);});
 egress=new Egress({lookup,publish:data=>{if(!win.isDestroyed())win.webContents.send('egress',{...data,mapAvailable:data.status==='current'&&!!mapURL(data)});}});
 sampler=new Sampler(signal=>collector.sample(signal),data=>{const {networkKey,...snapshot}=data;egress.observe(networkKey);if(!win.isDestroyed())win.webContents.send('snapshot',snapshot);});
 const stop=()=>{sampler.stop();collector.reset();egress.stop();updates.stop();};const start=()=>{if(win.isVisible()&&!win.isMinimized()&&win.isFocused()){sampler.start();egress.start();updates.start();}};
 win.on('blur',stop);win.on('hide',stop);win.on('minimize',stop);win.on('focus',start);win.on('restore',start);win.on('closed',stop);
 ipcMain.on('ready',event=>{if(validSender(event,win.webContents)){win.webContents.send('egress',{...egress.state,mapAvailable:egress.state.status==='current'&&!!mapURL(egress.state)});start();}});
 await win.loadURL('diakitw://app/index.html');start();onWindow(win,{sampler,collector,egress});
 });app.on('before-quit',()=>{sampler?.stop();egress?.stop();updates?.stop();});app.on('window-all-closed',()=>app.quit());
}
module.exports={boot};if(require.main===module)boot();
