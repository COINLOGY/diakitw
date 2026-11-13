const {test}=require('node:test');const a=require('node:assert/strict');const {run}=require('../app/runner.cjs');
test('abort cancels an owned telemetry worker',async()=>{const c=new AbortController();const p=run(process.execPath,['-e','setInterval(()=>{},1000)'],{signal:c.signal});c.abort();await a.rejects(p);});
