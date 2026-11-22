const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const html=fs.readFileSync('app/index.html','utf8'),js=fs.readFileSync('app/renderer.js','utf8'),preload=fs.readFileSync('app/preload.cjs','utf8'),main=fs.readFileSync('app/main.cjs','utf8'),css=fs.readFileSync('app/style.css','utf8');
test('desktop presents overview and server tree with all-list and selected detail, never sample values',()=>{
 for(const id of ['nav-overview','nav-servers','overview-view','servers-view','server-tree','server-content','server-add','server-refresh','server-editor'])assert.ok(html.includes(`id="${id}"`),id);
 for(const key of ['CPU','RAM','SWAP','Диск'])assert.match(js,new RegExp(key));
 assert.match(js,/textContent/);assert.doesNotMatch(html,/192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|28%|38%/);
 assert.match(css,/\.server-grid/);
});
test('SSH editor supports host, port, login, key/password, independent fingerprint and profile selection',()=>{
 for(const id of ['server-name','server-host','server-port','server-user','server-auth','server-key','server-password','server-fingerprint','server-save','server-cancel'])assert.ok(html.includes(`id="${id}"`),id);
 assert.match(preload,/serverCommand/);assert.match(main,/validSender\(event,win\.webContents\)/);assert.match(main,/server-command/);
 assert.match(js,/serverCommand\('save'/);assert.match(js,/serverCommand\('sample'/);
 assert.doesNotMatch(html,/value="secret"|value="root"/);
});
