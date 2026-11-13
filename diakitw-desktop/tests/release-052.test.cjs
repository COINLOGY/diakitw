const test=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs');
test('release metadata and user privacy help name the proxy, fallback, cache and shared quotas',()=>{
 const html=fs.readFileSync('app/index.html','utf8');for(const text of ['2ip','EMCx','aia.emcx.pro/diakitw-api/geo','GPS','1 час','300','9000','общ','ipify'])a.ok(html.includes(text),text);
 a.ok(!html.includes('GeoJS'));
 for(const file of ['package.json','app/package.json','package-lock.json'])a.equal(JSON.parse(fs.readFileSync(file)).version,'0.5.2');a.equal(JSON.parse(fs.readFileSync('package-lock.json')).packages[''].version,'0.5.2');a.ok(html.includes('diakitw 0.5.2'));
});
