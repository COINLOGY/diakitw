const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');

test('country flag uses the validated egress country code only for current geodata',()=>{
 const context=vm.createContext({});
 vm.runInContext(fs.readFileSync('app/flag.js','utf8'),context);
 const flag=context.countryFlag;
 assert.equal(flag({status:'current',code:'US',country:'United States'}),'🇺🇸');
 assert.equal(flag({status:'current',code:'DE',country:'Germany'}),'🇩🇪');
 for(const state of [{status:'stale',code:'US',country:'United States'},{status:'failed',code:'US',country:'United States'},{status:'current',country:'United States'},{status:'current',code:'US'},{status:'current',code:'us',country:'United States'},{status:'current',code:'ZZ',country:'Unknown'}])assert.equal(flag(state),'');
});

test('flag is adjacent to egress country and renderer hides it when unavailable',()=>{
 const html=fs.readFileSync('app/index.html','utf8');
 const renderer=fs.readFileSync('app/renderer.js','utf8');
 assert.match(html, /id="egress-country">Н\/Д<\/strong>\s*<span id="egress-flag" aria-hidden="true" hidden><\/span>/);
 assert.match(html, /<script src="flag\.js"><\/script><script src="renderer\.js"><\/script>/);
 assert.match(renderer, /countryFlag\(s\)/);
 assert.match(renderer, /\$\('egress-flag'\)\.hidden=!flag/);
 assert.match(html, /Флаг страны показывается только для актуального кода страны/);
 assert.match(html, /Отдельного согласия на автоматический запрос в desktop сейчас нет/);
 assert.doesNotMatch(fs.readFileSync('app/flag.js','utf8'), /https?:\/\/|fetch\(|XMLHttpRequest/);
});
