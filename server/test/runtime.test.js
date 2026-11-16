import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Miniflare,convertV4MiniflareOptions} from 'miniflare';
import {readFileSync} from 'node:fs';
import {RESERVE_AI} from '../src/worker.js';

test('Worker runs in workerd with real D1 migrations while AI is disabled',async t=>{
 const mf=new Miniflare(convertV4MiniflareOptions({workers:[{name:"growza",modules:[{type:'ESModule',path:'src/index.js'},{type:'ESModule',path:'src/worker.js'},{type:'ESModule',path:'src/topic_chunks.js'}],compatibilityDate:'2026-11-15',
 d1Databases:{DB:'growza-runtime-test'},bindings:{IP_HASH_SECRET:'runtime-test-secret-not-production-12345',AI_ENABLED:'false'}}]}));
 t.after(()=>mf.dispose());
 const db=await mf.getD1Database('DB','growza');
 for(const name of ['0001_limits.sql','0002_installations.sql','0003_model_call_budget.sql']){
  const text=readFileSync(new URL('../migrations/'+name,import.meta.url),'utf8');
  for(const sql of text.replace(/--[^\n]*/g,'').split(';').map(x=>x.trim()).filter(Boolean))await db.prepare(sql).run();
 }
 const reserve=(id,calls)=>db.prepare(RESERVE_AI).bind(id,'ai:fixture','today','ip',calls,'ai:fixture','today',3,'today',calls,5,'today','ip',calls,10).all();
 assert.equal((await reserve('first',3)).results.length,1);
 assert.equal((await reserve('second',3)).results.length,0);
 assert.equal((await db.prepare("SELECT SUM(model_calls) n FROM quota_requests WHERE bucket LIKE 'ai:%'").first()).n,3);
 const health=await mf.dispatchFetch('https://growza.test/health');
 assert.equal(health.status,200);assert.deepEqual(await health.json(),{ok:true,ready:true,ai:false});
 const result=await mf.dispatchFetch('https://growza.test/installations',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
 assert.equal(result.status,503);assert.deepEqual(await result.json(),{code:'unavailable'});
 assert.equal((await db.prepare('SELECT COUNT(*) n FROM installations').first()).n,0);
 const denied=await mf.dispatchFetch('https://growza.test/health',{headers:{Origin:'https://unknown.test'}});
 assert.equal(denied.status,403);
});
