import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

async function expectNoBlockingA11yViolations(page: Page) {
  const result = await new AxeBuilder({ page })
    .disableRules(['color-contrast'])
    .analyze();

  const blocking = result.violations
    .filter(v => v.impact === 'critical' || v.impact === 'serious')
    .map(v => ({
      id: v.id,
      impact: v.impact,
      help: v.help,
      targets: v.nodes.flatMap(n => n.target).slice(0, 8),
    }));

  expect(blocking, JSON.stringify(blocking, null, 2)).toEqual([]);
}

test.describe('TalentOS accessibility quality gate', () => {
  test('atalho de teclado permite pular a navegação lateral', async ({ page }) => {
    await page.goto('/');
    await page.keyboard.press('Tab');

    const skip = page.getByRole('link', { name: 'Ir para o conteúdo principal' });
    await expect(skip).toBeFocused();
    await expect(skip).toBeVisible();

    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#conteudo-principal$/);
  });

  test('currículo do candidato não possui violações sérias de acessibilidade', async ({ page }) => {
    await page.goto('/?e2eRole=candidato');
    await page.getByRole('button', { name: 'Meu currículo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Meu currículo' })).toBeVisible();
    await expectNoBlockingA11yViolations(page);
  });

  test('início e processo seletivo da empresa passam na auditoria', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible();
    await expectNoBlockingA11yViolations(page);

    await page.getByRole('button', { name: 'Processo seletivo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Processo seletivo' })).toBeVisible();
    await expectNoBlockingA11yViolations(page);
  });

  test('vagas públicas passam na auditoria', async ({ page }) => {
    await page.goto('/vagas');
    await expect(page.getByRole('heading', { level: 1, name: 'Oportunidades industriais' })).toBeVisible();
    await expectNoBlockingA11yViolations(page);
  });
});
