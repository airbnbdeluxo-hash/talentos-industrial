import { expect, test } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

test('link de recuperação expirado oferece recuperação, sem reenviar cadastro', async ({ page }) => {
  await page.goto('/?auth=recovery#error_code=otp_expired&error=access_denied');
  await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Enviar link de recuperação' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Reenviar confirmação', exact: true })).toHaveCount(0);
  await expect(page).toHaveURL(/\?auth=recovery$/);
});

test('link de confirmação expirado oferece reenvio de confirmação', async ({ page }) => {
  await page.goto('/?auth=confirm#error_code=otp_expired&error=access_denied');
  await expect(page.getByRole('heading', { name: 'Confirmar meu e-mail' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Reenviar confirmação', exact: true })).toBeVisible();
  await expect(page).toHaveURL(/\?auth=confirm$/);
});

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

test('confirmação e recuperação usam somente o domínio oficial aprovado', async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(resolve(here, '../../src/App.tsx'), 'utf8');
  const guard = readFileSync(resolve(here, '../../src/lib/authRedirect.ts'), 'utf8');
  expect(source).toContain("authRedirectUrl('confirm')");
  expect(source).toContain("authRedirectUrl('recovery')");
  expect(source).toContain("authRedirectUrl as buildAuthRedirectUrl");
  expect(source).toContain("buildAuthRedirectUrl(intent,String(import.meta.env.VITE_PUBLIC_APP_URL??''))");
  expect(guard).toContain("TALENTOS_AUTH_ORIGIN = 'https://talentos-industrial.vercel.app'");
  expect(guard).toContain("parsed.origin === TALENTOS_AUTH_ORIGIN");
  expect(source).not.toContain("window.location.origin");
  expect(source).not.toContain("resetPasswordForEmail(authEmail.trim(),{redirectTo:window.location.origin})");
});

test('convites administrativos usam inviteUserByEmail e não aceitam fallback de link', async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(resolve(here, '../../supabase/functions/company-team/index.ts'), 'utf8');
  expect(source).toContain('admin.auth.admin.inviteUserByEmail');
  expect(source).not.toContain('admin.auth.admin.createUser');
  expect(source).not.toContain("delivery: 'link'");
  expect(source).toContain('admin.auth.admin.deleteUser(createdUser.id)');
  expect(source).toContain('O Supabase não confirmou o envio do e-mail de convite.');
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

test('conta existente pode continuar cadastro empresarial sem nova confirmação', async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(resolve(here, '../../src/App.tsx'), 'utf8');
  expect(source).toContain("existingCandidateStartingCompany");
  expect(source).toContain("requested_account_type:'empresa'");
  expect(source).toContain('Este e-mail já está cadastrado no TalentOS.');
  expect(source).toContain('Não enviaremos outro e-mail de confirmação.');
});

test('recuperação expirada mantém acesso e layout em 360px no preview configurado', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 780 });
  await page.goto('/?auth=recovery#error_code=otp_expired&error=access_denied');
  await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Enviar link de recuperação' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Reenviar confirmação', exact: true })).toHaveCount(0);
  const width = await page.evaluate(() => ({scroll:document.documentElement.scrollWidth,viewport:document.documentElement.clientWidth}));
  expect(width.scroll).toBeLessThanOrEqual(width.viewport + 1);
});

test('retorno de recuperação inválido não deixa tokens sintéticos no endereço', async ({ page }) => {
  await page.goto('/?auth=recovery&code=fake-code&token_hash=fake-hash#error=access_denied&error_code=otp_expired&access_token=fake-access&refresh_token=fake-refresh');
  await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Enviar link de recuperação' })).toBeVisible();
  await expect(page).toHaveURL(/\/\?auth=recovery$/);
  expect(page.url()).not.toMatch(/fake-|token|code|error/);
});

test('janela de login mantém foco de teclado e devolve foco ao fechar com Escape', async ({ page }) => {
  await page.goto('/');
  const trigger = page.getByRole('button', { name: 'Entrar', exact: true }).first();
  await trigger.focus();
  await trigger.click();
  const dialog = page.getByRole('dialog', { name: /Entrar como candidato/i });
  await expect(dialog).toBeVisible();
  await expect(dialog.locator('input').first()).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(trigger).toBeFocused();
});

test('Minha carreira permanece uma aba válida para restaurar a sessão do candidato', async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(resolve(here, '../../src/App.tsx'), 'utf8');
  expect(source).toContain("nextRole==='candidato'?['dashboard','jobs','passport','applications','skills','settings']");
});

test('login e recuperação não têm violações graves de contraste e acessibilidade', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Entrar', exact: true }).first().click();
  await expect(page.getByRole('heading', { name: 'Entrar como candidato' })).toBeVisible();
  for (const step of ['login','recovery']) {
    if (step === 'recovery') {
      await page.getByRole('button', { name: 'Alterar ou recuperar minha senha' }).click();
      await expect(page.getByRole('heading', { name: 'Recuperar acesso' })).toBeVisible();
    }
    const report = await new AxeBuilder({ page }).include('.auth-modal').analyze();
    const serious = report.violations.filter(v => v.impact === 'critical' || v.impact === 'serious')
      .map(v => ({ id:v.id, targets:v.nodes.flatMap(n => n.target).slice(0,8) }));
    expect(serious, step + ': ' + JSON.stringify(serious)).toEqual([]);
  }
});
