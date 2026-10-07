import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

test('área pública não apresenta perfis de demonstração como dados reais', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1, name: 'Sua melhor vaga na indústria começa aqui.' })).toBeVisible();
  await expect(page.getByText('Marcos Silva', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Ana Martins', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Juliana Costa', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Rafael Souza', { exact: true })).toHaveCount(0);
});

test('recuperação de senha usa título coerente e mantém a tela de login acessível', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Entrar', exact: true }).first().evaluate((button) => (button as HTMLButtonElement).click());
  await expect(page.getByRole('heading', { name: 'Entrar como candidato' })).toBeVisible();
  await page.getByRole('button', { name: 'Alterar ou recuperar minha senha' }).click();
  await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
  await expect(page.getByLabel('E-mail')).toBeVisible();
});

test('confirmação e recuperação usam a URL canônica de produção', async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(resolve(here, '../../src/App.tsx'), 'utf8');
  expect(source).toContain("https://talentos-industrial.vercel.app");
  expect(source).toContain("authRedirectUrl('confirm')");
  expect(source).toContain("authRedirectUrl('recovery')");
  expect(source).not.toContain("resetPasswordForEmail(authEmail.trim(),{redirectTo:window.location.origin})");
});

test('preview não envia requisições ao Supabase de produção', async ({ page }) => {
  const productionRequests: string[] = [];
  await page.route('https://kvxqhvngkjxqlvlzcsef.supabase.co/**', async route => {
    productionRequests.push(new URL(route.request().url()).pathname);
    await route.abort();
  });

  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1, name: 'Sua melhor vaga na indústria começa aqui.' })).toBeVisible();
  await page.getByRole('button', { name: 'Entrar', exact: true }).first().click();
  await expect(page.getByRole('heading', { name: 'Entrar como candidato' })).toBeVisible();
  await page.waitForTimeout(300);
  expect(productionRequests).toEqual([]);
});
