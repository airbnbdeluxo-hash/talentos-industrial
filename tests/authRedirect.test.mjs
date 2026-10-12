import test from 'node:test';
import assert from 'node:assert/strict';
import { TALENTOS_AUTH_ORIGIN, resolveAuthReturnOrigin, authRedirectUrl } from '../src/lib/authRedirect.ts';

test('confirmation and recovery always use the approved production domain', () => {
  assert.equal(authRedirectUrl('confirm'), TALENTOS_AUTH_ORIGIN + '/?auth=confirm');
  assert.equal(authRedirectUrl('recovery'), TALENTOS_AUTH_ORIGIN + '/?auth=recovery');
  assert.equal(authRedirectUrl('recovery', TALENTOS_AUTH_ORIGIN + '/'), TALENTOS_AUTH_ORIGIN + '/?auth=recovery');
});

test('rejects typo domains, phishing lookalikes, HTTP URLs, localhost and arbitrary preview origins', () => {
  for (const unsafe of [
    'http://talentos-industrial.vercel.app',
    'https://talentos-industrial.vercel.app.evil.example',
    'https://evil.example/talentos-industrial.vercel.app',
    'https://talentos-industrial-git-feature.vercel.app',
    'http://localhost:5173',
    'javascript:alert(1)',
    'not a URL',
  ]) {
    assert.equal(resolveAuthReturnOrigin(unsafe), TALENTOS_AUTH_ORIGIN, unsafe);
    assert.equal(authRedirectUrl('confirm', unsafe), TALENTOS_AUTH_ORIGIN + '/?auth=confirm', unsafe);
  }
});

test('does not accept credentials, extra redirect paths or injected URL parameters', () => {
  for (const unsafe of [
    'https://attacker@talentos-industrial.vercel.app',
    'https://talentos-industrial.vercel.app/reset',
    'https://talentos-industrial.vercel.app/?next=https://evil.example',
    'https://talentos-industrial.vercel.app/#access_token=fake',
    'https://talentos-industrial.vercel.app:4443',
  ]) {
    assert.equal(resolveAuthReturnOrigin(unsafe), TALENTOS_AUTH_ORIGIN, unsafe);
  }
});

test('ignores absent or malformed optional environment configuration', () => {
  assert.equal(resolveAuthReturnOrigin(null), TALENTOS_AUTH_ORIGIN);
  assert.equal(resolveAuthReturnOrigin(''), TALENTOS_AUTH_ORIGIN);
  assert.equal(resolveAuthReturnOrigin('  https://talentos-industrial.vercel.app/  '), TALENTOS_AUTH_ORIGIN);
});
