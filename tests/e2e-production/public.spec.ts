import { expect, test } from '@playwright/test';

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

test('recuperação de senha sempre retorna para a produção do TalentOS', async ({ page }) => {
  let recoveryRequestUrl = '';
  await page.route('https://kvxqhvngkjxqlvlzcsef.supabase.co/auth/v1/recover**', async route => {
    recoveryRequestUrl = route.request().url();
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
  });

  await page.goto('/');
  await page.getByRole('button', { name: 'Entrar', exact: true }).first().evaluate((button) => (button as HTMLButtonElement).click());
  await page.getByRole('button', { name: 'Alterar ou recuperar minha senha' }).click();
  await page.getByLabel('E-mail').fill('teste-recuperacao@example.com');
  await page.getByRole('button', { name: 'Enviar link de recuperação' }).click();

  await expect.poll(() => recoveryRequestUrl).not.toBe('');
  expect(new URL(recoveryRequestUrl).searchParams.get('redirect_to')).toBe('https://talentos-industrial.vercel.app/?auth=recovery');
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
