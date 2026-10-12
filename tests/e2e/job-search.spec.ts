import {expect, test} from '@playwright/test';

test.beforeEach(async ({page}) => {
  // Only development E2E data. Never connects to the production Supabase database.
  await page.addInitScript(() => {
    localStorage.setItem('talentos-industrial-db-v5', JSON.stringify({
      jobs: [
        {id:'qa-open',title:'Operador CNC',companyId:'c1',city:'Caxias do Sul',min:3500,max:5000,skills:['CNC'],status:'aberta',shift:'2º turno',workModel:'Presencial',screeningQuestions:[],interviewQuestions:[]},
        {id:'qa-closed',title:'Operador CNC',companyId:'c1',city:'Caxias do Sul',min:3500,max:5000,skills:['CNC'],status:'fechada',shift:'2º turno',workModel:'Presencial',screeningQuestions:[],interviewQuestions:[]},
        {id:'qa-remote',title:'Soldador TIG',companyId:'c2',city:'Bento Gonçalves',min:5500,max:6500,skills:['TIG'],status:'aberta',shift:'1º turno',workModel:'Remota',screeningQuestions:[],interviewQuestions:[]},
      ],
    }));
  });
  await page.goto('/?e2eRole=candidato');
  await page.getByRole('button',{name:'Vagas',exact:true}).click();
});

test('candidato vê somente vagas abertas, nunca uma encerrada',async ({page}) => {
  await expect(page.locator('.jobrow')).toHaveCount(2);
  await expect(page.locator('.jobs-results')).toContainText('2 vaga(s) encontrada(s)');
  await expect(page.locator('.jobrow').filter({hasText:'fechada'})).toHaveCount(0);
});

test('filtros de salário, modalidade e cargo combinam e podem ser limpos',async ({page}) => {
  const salary=page.getByLabel('Salário mínimo (R$)');
  await salary.fill('5.000,00');
  await salary.blur();
  await expect(page.locator('.jobrow')).toHaveCount(1);
  await expect(page.locator('.jobrow')).toContainText('Soldador TIG');

  await page.getByLabel('Modalidade').selectOption('Presencial');
  await expect(page.locator('.jobrow')).toHaveCount(0);
  await expect(page.locator('.jobs-results')).toContainText('0 vaga(s) encontrada(s)');

  await page.getByRole('button',{name:'Limpar filtros'}).click();
  await expect(page.locator('.jobrow')).toHaveCount(2);

  const cargo=page.locator('fieldset.catalog-single').filter({has:page.locator('legend').getByText('Cargo',{exact:true})});
  await cargo.locator('summary').click();
  await cargo.locator('input[type=search]').fill('Soldador TIG');
  await cargo.getByRole('radio',{name:'Soldador TIG'}).check();
  await expect(page.locator('.jobrow')).toHaveCount(1);
  await expect(page.locator('.jobrow')).toContainText('Soldador TIG');
});
