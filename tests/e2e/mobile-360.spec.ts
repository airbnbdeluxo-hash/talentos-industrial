import { expect, test, type Page } from '@playwright/test';

const mobile = { width: 360, height: 780 };

async function expectNoHorizontalOverflow(page: Page, context: string) {
  const dimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(dimensions.scrollWidth, `${context}: width ${JSON.stringify(dimensions)}`)
    .toBeLessThanOrEqual(dimensions.clientWidth + 1);
}

test('candidato mantém as áreas principais usáveis em 360px', async ({ page }) => {
  await page.setViewportSize(mobile);
  await page.goto('/?e2eRole=candidato');
  const menus = ['Minha carreira','Vagas','Meu currículo','Minhas candidaturas','Competências e desenvolvimento','Configurações'];
  for (const menu of menus) {
    await page.getByRole('button',{name:menu,exact:true}).click();
    await expectNoHorizontalOverflow(page, `candidato/${menu}`);
  }
});

test('empresa mantém as áreas principais usáveis em 360px', async ({ page }) => {
  await page.setViewportSize(mobile);
  await page.goto('/?e2eRole=empresa');
  const menus = ['Início','Vagas','Candidatos','Processo seletivo','Comprovações','Equipe','Configurações'];
  for (const menu of menus) {
    await page.getByRole('button',{name:menu,exact:true}).click();
    await expectNoHorizontalOverflow(page, `empresa/${menu}`);
  }
});
