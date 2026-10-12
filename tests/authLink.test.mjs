import test from 'node:test';
import assert from 'node:assert/strict';
import {readAuthLinkProblem,authLinkRepair} from '../src/lib/authLink.ts';

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
test('expired recovery requests another recovery link instead of signup confirmation',()=>{
 const repair=authLinkRepair('https://talentos-industrial.vercel.app/?auth=recovery#error_code=otp_expired&error=access_denied');
 assert.equal(repair.mode,'recovery');
 assert.match(repair.message,/redefinir sua senha/);
 assert.equal(repair.cleanPath,'/?auth=recovery');
});
test('confirmation repair removes errors and preserves unrelated query parameters',()=>{
 const repair=authLinkRepair('https://talentos-industrial.vercel.app/?auth=confirm&campaign=industrial&error=access_denied&error_code=otp_expired');
 assert.equal(repair.mode,'resend');
 assert.equal(repair.cleanPath,'/?auth=confirm&campaign=industrial');
});
test('successful recovery tokens are never rewritten by the repair flow',()=>{
 assert.equal(authLinkRepair('https://talentos-industrial.vercel.app/?auth=recovery#access_token=synthetic&type=recovery'),null);
});

test('expired link drops all fragment credentials and known sensitive query values',()=>{
 const repair=authLinkRepair('https://talentos-industrial.vercel.app/?auth=recovery&campaign=industrial&code=fake-code&token_hash=fake-hash&error_code=otp_expired#access_token=fake-access&refresh_token=fake-refresh&provider_token=fake-provider&error=access_denied');
 assert.equal(repair?.mode,'recovery');
 assert.equal(repair?.cleanPath,'/?auth=recovery&campaign=industrial');
 assert.doesNotMatch(repair?.cleanPath ?? '', /fake-|token|code/);
});

test('invalid confirmation error also discards all fragments, preserving ordinary query context',()=>{
 const repair=authLinkRepair('https://talentos-industrial.vercel.app/?auth=confirm&campaign=industrial#error=access_denied&state=fake-state&tracking=safe');
 assert.equal(repair?.mode,'resend');
 assert.equal(repair?.cleanPath,'/?auth=confirm&campaign=industrial');
});

test('successful recovery or signup callbacks are never cleaned or modified',()=>{
 assert.equal(authLinkRepair('https://talentos-industrial.vercel.app/?auth=recovery#access_token=fake-access&refresh_token=fake-refresh&type=recovery'),null);
 assert.equal(authLinkRepair('https://talentos-industrial.vercel.app/?auth=confirm&code=fake-valid-code'),null);
});
