import { expect, test } from '@playwright/test';

test.describe('TalentOS smoke', () => {
  test.beforeEach(async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push('pageerror: ' + error.message));
    page.on('console', message => {
      if (message.type() === 'error') errors.push('console.error: ' + message.text());
    });
    (page as any).__talentosErrors = errors;
  });

  test.afterEach(async ({ page }) => {
    const errors = ((page as any).__talentosErrors ?? []) as string[];
    expect(errors, errors.join('\n')).toEqual([]);
  });

  test('navegação principal troca de área sem abrir modal inesperado', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { level: 1, name: 'Visão geral' })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);

    const routes = [
      ['Vagas', 'Vagas'],
      ['Profissionais', 'Profissionais'],
      ['Mapa de competências', 'Mapa de competências'],
      ['Inteligência', 'Análises'],
      ['Processo seletivo', 'Processo seletivo'],
      ['Validar competências', 'Validar competências'],
      ['Configurações', 'Configurações'],
    ] as const;

    for (const [menu, heading] of routes) {
      await page.getByRole('button', { name: menu, exact: true }).click();
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
      await expect(page.locator('.overlay')).toHaveCount(0);
    }
  });

  test('lista pública de vagas abre sem autenticação', async ({ page }) => {
    await page.goto('/vagas');
    await expect(page.getByRole('heading', { level: 1, name: 'Oportunidades industriais' })).toBeVisible();
    await expect(page.getByText('TalentOS')).toBeVisible();
  });

  test('layout principal não cria rolagem horizontal em tela móvel', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');
    await expect(page.getByRole('heading', { level: 1, name: 'Visão geral' })).toBeVisible();

    const dimensions = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
    }));

    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth + 1);
  });


  test('entrada separa claramente candidato e empresa', async ({ page }) => {
    await page.goto('/?e2eAuthGate=1');

    await expect(page.getByRole('heading', { level: 2, name: 'Como você quer usar o TalentOS?' })).toBeVisible();
    await expect(page.getByRole('heading', { level: 3, name: 'Quero encontrar vagas' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Entrar como candidato', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Criar conta de candidato', exact: true })).toBeVisible();

    await expect(page.getByRole('heading', { level: 3, name: 'Sou empresa' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Entrar como empresa', exact: true })).toBeVisible();
    await expect(page.getByText('O acesso empresarial é liberado para empresas e recrutadores cadastrados no TalentOS.')).toBeVisible();
  });
});
