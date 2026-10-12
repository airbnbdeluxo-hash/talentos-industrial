import test from 'node:test';
import assert from 'node:assert/strict';
import {readAuthLinkProblem} from '../src/lib/authLink.ts';

test('expired confirmation link is detected with query string',()=>{
 assert.equal(readAuthLinkProblem('https://talentos-industrial.vercel.app/?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid'), 'expired');
});
test('expired confirmation link in fragment is detected',()=>{
 assert.equal(readAuthLinkProblem('https://talentos-industrial.vercel.app/#error=access_denied&error_code=otp_expired'), 'expired');
});
test('unrelated email error is recoverable',()=>{
 assert.equal(readAuthLinkProblem('https://talentos-industrial.vercel.app/?error=access_denied'), 'invalid');
});
test('successful auth callback and recovery tokens are not disturbed',()=>{
 assert.equal(readAuthLinkProblem('https://talentos-industrial.vercel.app/?auth=confirm#access_token=not-a-real-token'),null);
 assert.equal(readAuthLinkProblem('https://talentos-industrial.vercel.app/?auth=recovery'),null);
});
