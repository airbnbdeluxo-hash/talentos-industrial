import { expect, test } from '@playwright/test';

async function expectPlainLanguage(page: import('@playwright/test').Page) {
  const text = await page.locator('body').innerText();
  expect(text).not.toMatch(/Skill Passport|Readiness|Adicionar evidência|Evidência desta habilidade|\bAnalytics\b|\bGaps?\b/i);
}

test.describe('TalentOS authenticated journeys', () => {
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

  test('candidato navega pelo currículo sem modal de privacidade reaparecer', async ({ page }) => {
    await page.goto('/?e2eRole=candidato');

    await expect(page.getByRole('heading', { level: 1, name: 'Vagas' })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);

    await page.getByRole('button', { name: 'Meu currículo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Meu currículo' })).toBeVisible();
    await expect(page.getByText('Marcos Silva', { exact: true })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expectPlainLanguage(page);

    await page.getByRole('button', { name: 'Editar currículo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Editar meu currículo' })).toBeVisible();
    await page.getByRole('button', { name: 'Fechar' }).click();
    await expect(page.locator('.overlay')).toHaveCount(0);

    await page.getByRole('button', { name: 'Comprovar uma habilidade', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Como você quer comprovar?' })).toBeVisible();
    await page.getByRole('button', { name: 'Fechar' }).click();
    await expect(page.locator('.overlay')).toHaveCount(0);

    const routes = [
      ['Minhas candidaturas', 'Minhas candidaturas'],
      ['Competências e desenvolvimento', 'Competências e desenvolvimento'],
      ['Configurações', 'Configurações da conta'],
      ['Vagas', 'Vagas'],
    ] as const;

    for (const [menu, heading] of routes) {
      await page.getByRole('button', { name: menu, exact: true }).click();
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
      await expect(page.locator('.overlay')).toHaveCount(0);
      await expectPlainLanguage(page);
    }
  });

  test('empresa percorre gestão de recrutamento e abre criação de vaga', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');

    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible();
    await expect(page.getByText('RECRUTAMENTO DA EMPRESA')).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expectPlainLanguage(page);

    await page.getByRole('button', { name: 'Criar vaga', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Estruturar nova vaga' })).toBeVisible();
    await page.getByRole('button', { name: 'Fechar' }).click();

    const routes = [
      ['Vagas', 'Minhas vagas'],
      ['Candidatos', 'Candidatos'],
      ['Processo seletivo', 'Processo seletivo'],
      ['Comprovações', 'Comprovações'],
      ['Competências', 'Competências'],
      ['Análises', 'Análises'],
      ['Configurações', 'Configurações'],
      ['Início', 'Início'],
    ] as const;

    for (const [menu, heading] of routes) {
      await page.getByRole('button', { name: menu, exact: true }).click();
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible();
      await expect(page.locator('.overlay')).toHaveCount(0);
      await expectPlainLanguage(page);
    }
  });
});
