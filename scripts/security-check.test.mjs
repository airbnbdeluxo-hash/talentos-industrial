import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const scanner = fileURLToPath(new URL('./security-check.mjs', import.meta.url));

function runFixture(filename, text) {
  const dir = mkdtempSync(join(tmpdir(), 'talentos-security-test-'));
  try {
    execFileSync('git', ['init', '-q'], { cwd: dir });
    writeFileSync(join(dir, filename), text);
    execFileSync('git', ['add', '-f', '--', filename], { cwd: dir });
    return spawnSync(process.execPath, [scanner], { cwd: dir, encoding: 'utf8' });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function fakeJwt(role) {
  return [
    Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url'),
    Buffer.from(JSON.stringify({ role, iss: 'supabase' })).toString('base64url'),
    'X'.repeat(43),
  ].join('.');
}

test('rejects legacy Supabase service_role JWT without printing the token', () => {
  const token = fakeJwt('service_role');
  const run = runFixture('fixture.ts', `const key = "${token}";`);
  assert.equal(run.status, 1);
  assert.match(run.stderr, /legacy service_role JWT/);
  assert.ok(!run.stderr.includes(token));
});

test('allows the public anon JWT role', () => {
  const run = runFixture('fixture.ts', `const key = "${fakeJwt('anon')}";`);
  assert.equal(run.status, 0, run.stderr);
});

test('blocks tracked environment files', () => {
  const run = runFixture('.env', 'APP_ENV=production');
  assert.equal(run.status, 1);
  assert.match(run.stderr, /Arquivos de ambiente rastreados/);
});

test('blocks modern Supabase secret API keys', () => {
  const key = 'sb' + '_secret_' + 'X'.repeat(32);
  const run = runFixture('fixture.ts', `const key = "${key}";`);
  assert.equal(run.status, 1);
  assert.match(run.stderr, /Supabase secret key/);
});
