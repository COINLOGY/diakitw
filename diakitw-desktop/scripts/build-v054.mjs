import {packager} from '@electron/packager';
import fs from 'node:fs';
const platform=process.argv[2];if(!['linux','win32'].includes(platform))throw Error('platform');
const out=process.argv[3]||'bundles-v054';if(!/^[a-z0-9-]+$/.test(out))throw Error('output');const dest=`${out}/diakitw-${platform}-x64`;if(fs.existsSync(dest))throw Error('Refusing overwrite '+dest);
if(JSON.parse(fs.readFileSync('app/package.json')).version!=='0.5.4')throw Error('version');
console.log(await packager({dir:'app',out,name:'diakitw',platform,arch:'x64',electronVersion:'45.2.3',appVersion:'0.5.4',buildVersion:'54',asar:true,overwrite:false,prune:false,windowsSign:undefined,download:{cacheRoot:process.cwd()+'/.electron-cache'},...(platform==='win32'?{icon:'app/icon.ico',win32metadata:{CompanyName:'EMCx',ProductName:'diakitw'}}:{})}));
