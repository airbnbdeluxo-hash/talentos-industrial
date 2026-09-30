import { expect, test } from '@playwright/test';

test('área pública não apresenta perfis de demonstração como dados reais', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Acesso público', { exact: true })).toBeVisible();
  await expect(page.getByText('Marcos Silva', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Ana Martins', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Juliana Costa', { exact: true })).toHaveCount(0);
  await expect(page.getByText('Rafael Souza', { exact: true })).toHaveCount(0);
});

test('recuperação de senha usa título coerente e mantém a tela de login acessível', async ({ page }) => {
  await page.goto('/');
  const closeOverlay = page.locator('.overlay button.close').first();
  if (await closeOverlay.isVisible().catch(() => false)) await closeOverlay.click();
  await page.getByRole('button', { name: 'Entrar', exact: true }).first().click();
  await expect(page.getByRole('heading', { name: 'Entrar como candidato' })).toBeVisible();
  await page.getByRole('button', { name: 'Alterar ou recuperar minha senha' }).click();
  await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
  await expect(page.getByLabel('E-mail')).toBeVisible();
});
