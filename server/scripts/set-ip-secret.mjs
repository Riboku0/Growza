// Run once after the Worker exists. The generated value never enters logs or files.
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const cli=fileURLToPath(new URL('../node_modules/wrangler/bin/wrangler.js',import.meta.url));
const result=spawnSync(process.execPath,[cli,'secret','put','IP_HASH_SECRET'],{
 cwd:fileURLToPath(new URL('..',import.meta.url)),
 env:{...process.env,WRANGLER_SEND_METRICS:'false'},
 input:randomBytes(32).toString('base64url')+'\n',encoding:'utf8',
});
if(result.stdout)process.stdout.write(result.stdout);
if(result.stderr)process.stderr.write(result.stderr);
if(result.error){console.error('Could not start Wrangler.');process.exitCode=1;}
else process.exitCode=result.status??1;
