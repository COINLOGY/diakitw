const {test}=require('node:test');const a=require('node:assert/strict');
test('Linux meminfo uses available RAM and actual swap',()=>{const c=require('../app/core.cjs');a.deepEqual(c.memory('MemTotal: 100 kB\nMemAvailable: 40 kB\nSwapTotal: 20 kB\nSwapFree: 5 kB'),{ram:{used:61440,total:102400},swap:{used:15360,total:20480}});a.equal(c.memory('').ram.total,null);});
