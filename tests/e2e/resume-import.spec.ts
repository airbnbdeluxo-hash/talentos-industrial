import { expect, test, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';

const fixtures = JSON.parse(readFileSync(new URL('../fixtures/resume-files.json', import.meta.url), 'utf8'));
const storageKey = 'talentos-industrial-db-v5';

async function openImport(page: Page) {
  await page.addInitScript(key => localStorage.setItem(key, JSON.stringify({candidates:[]})), storageKey);
  await page.goto('/?e2eRole=candidato');
  await page.getByRole('button', {name:'Meu currículo', exact:true}).click();
  await page.getByRole('button', {name:'Preencher meu currículo', exact:true}).click();
  await page.getByRole('button', {name:'Enviar meu currículo'}).click();
}

for (const extension of ['pdf', 'docx']) {
  test(`currículo ${extension} real é lido, editável e não salvo sem confirmação`, async ({page}) => {
    await openImport(page);
    await page.locator('.candidate-onboarding input[type=file]').setInputFiles({
      name:`curriculo.${extension}`,
      mimeType:extension==='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      buffer:Buffer.from(fixtures[extension], 'base64'),
    });
    await expect(page.getByRole('heading', {name:'Revise o que encontramos'})).toBeVisible();
    await expect(page.getByLabel('Nome', {exact:true})).toHaveValue('Maria da Silva');
    await page.getByLabel('Nome', {exact:true}).fill('Maria da Silva Revisada');
    await expect(page.getByLabel('Nome', {exact:true})).toHaveValue('Maria da Silva Revisada');
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)!).candidates, storageKey)).toEqual([]);
    await page.getByRole('button', {name:'Sair do preenchimento do currículo'}).click();
    await expect(page.getByRole('dialog', {name:'Preencher meu currículo'})).toHaveCount(0);
    expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)!).candidates, storageKey)).toEqual([]);
  });
}

test('sair durante a leitura impede resultado tardio e persistência', async ({page}) => {
  await page.addInitScript(() => {
    const original = File.prototype.arrayBuffer;
    File.prototype.arrayBuffer = async function() {
      if (this.name === 'leitura-lenta.docx') {
        await new Promise<void>(resolve => { (window as any).releaseResumeRead = resolve; });
      }
      return original.call(this);
    };
  });
  await openImport(page);
  await page.locator('.candidate-onboarding input[type=file]').setInputFiles({
    name:'leitura-lenta.docx',
    mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    buffer:Buffer.from(fixtures.docx, 'base64'),
  });
  await page.waitForFunction(() => typeof (window as any).releaseResumeRead === 'function');
  await page.getByRole('button', {name:'Sair do preenchimento do currículo'}).click();
  await page.evaluate(() => (window as any).releaseResumeRead());
  await expect(page.getByRole('dialog', {name:'Preencher meu currículo'})).toHaveCount(0);
  await expect(page.getByRole('heading', {name:'Revise o que encontramos'})).toHaveCount(0);
  expect(await page.evaluate(key => JSON.parse(localStorage.getItem(key)!).candidates, storageKey)).toEqual([]);
  await page.getByRole('button', {name:'Preencher meu currículo', exact:true}).click();
  await expect(page.getByRole('heading', {name:'Como você quer preencher seu perfil?'})).toBeVisible();
});
