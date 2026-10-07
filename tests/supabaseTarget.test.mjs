import assert from 'node:assert/strict';
import test from 'node:test';
import { resolveSupabaseClientTarget } from '../src/lib/supabaseTarget.ts';

const productionUrl = 'https://kvxqhvngkjxqlvlzcsef.supabase.co';
const base = {
  isProductionBuild: true,
  productionUrl,
  productionPublishableKey: 'public-production-test-key',
};

test('production build retains the existing production backend', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    deploymentEnvironment: 'production',
    hostname: 'talentos-industrial-random.vercel.app',
  });
  assert.deepEqual(result, { url: productionUrl, key: base.productionPublishableKey });
});

test('preview with no staging backend cannot reach production', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    deploymentEnvironment: 'preview',
    hostname: 'talentos-industrial-feature.vercel.app',
  });
  assert.deepEqual(result, { url: undefined, key: undefined });
});

test('preview rejects accidentally copied production URL and key', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    deploymentEnvironment: 'preview',
    configuredUrl: productionUrl + '/',
    configuredKey: base.productionPublishableKey,
  });
  assert.deepEqual(result, { url: undefined, key: undefined });
});

test('preview accepts an explicitly configured independent backend', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    deploymentEnvironment: 'preview',
    configuredUrl: 'https://staging-project.supabase.co/',
    configuredKey: 'staging-public-key',
  });
  assert.deepEqual(result, { url: 'https://staging-project.supabase.co', key: 'staging-public-key' });
});

test('missing deployment metadata permits only known canonical production host', () => {
  assert.deepEqual(
    resolveSupabaseClientTarget({ ...base, hostname: 'talentos-industrial.vercel.app' }),
    { url: productionUrl, key: base.productionPublishableKey },
  );
  assert.deepEqual(
    resolveSupabaseClientTarget({ ...base, hostname: 'talentos-industrial-preview-xyz.vercel.app', configuredUrl: productionUrl, configuredKey: 'accidentally-shared-key' }),
    { url: undefined, key: undefined },
  );
});

test('local development can explicitly use a chosen backend', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    isProductionBuild: false,
    deploymentEnvironment: 'development',
    configuredUrl: 'http://127.0.0.1:54321',
    configuredKey: 'local-public-key',
  });
  assert.deepEqual(result, { url: 'http://127.0.0.1:54321', key: 'local-public-key' });
});

test('invalid URL fails closed', () => {
  const result = resolveSupabaseClientTarget({
    ...base,
    deploymentEnvironment: 'preview',
    configuredUrl: 'not-a-url',
    configuredKey: 'invalid',
  });
  assert.deepEqual(result, { url: undefined, key: undefined });
});
