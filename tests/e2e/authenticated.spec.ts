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

  test('candidato altera privacidade e continua navegando sem reabrir a decisão', async ({ page }) => {
    await page.goto('/?e2eRole=candidato');

    await page.getByRole('button', { name: 'Configurações', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Configurações da conta' })).toBeVisible();

    await page.getByRole('button', { name: 'Gerenciar visibilidade', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Você decide quem encontra seu perfil' })).toBeVisible();

    await page.getByRole('button', { name: 'Manter privado', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Vagas' })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);

    await page.getByRole('button', { name: 'Meu currículo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Meu currículo' })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);

    await page.getByRole('button', { name: 'Configurações', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Configurações da conta' })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expectPlainLanguage(page);
  });

  test('candidato libera perfil, envia candidatura e informa disponibilidade', async ({ page }) => {
    await page.goto('/?e2eRole=candidato');

    await page.getByRole('button', { name: 'Configurações', exact: true }).click();
    await page.getByRole('button', { name: 'Gerenciar visibilidade', exact: true }).click();
    await page.getByRole('button', { name: 'Permitir que empresas encontrem meu perfil', exact: true }).click();

    await expect(page.getByRole('heading', { level: 1, name: 'Vagas' })).toBeVisible();
    const targetJob = page.locator('.jobrow').filter({ hasText: 'Técnico de Manutenção' });
    await expect(targetJob).toBeVisible();
    await targetJob.getByRole('button', { name: 'Candidatar-me', exact: true }).click();

    await expect(page.getByRole('heading', { level: 1, name: 'Minhas candidaturas' })).toBeVisible();
    const application = page.locator('.application-card').filter({ hasText: 'Técnico de Manutenção' });
    await expect(application).toBeVisible();
    await expect(application.getByText('Nova', { exact: true })).toBeVisible();

    await page.getByRole('button', { name: 'Definir horário', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Definir horário semanal' })).toBeVisible();
    await page.getByLabel('Dia').selectOption('1');
    await page.getByLabel('Início').fill('09:00');
    await page.getByLabel('Fim').fill('12:00');
    await page.getByRole('button', { name: 'Adicionar horário', exact: true }).click();
    await page.getByRole('button', { name: 'Fechar' }).click();

    await expect(page.getByText('Segunda · 09:00–12:00', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Remover', exact: true }).click();
    await expect(page.getByText('Nenhum horário padrão informado.', { exact: true })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expectPlainLanguage(page);
  });


  test('empresa avança candidato e abre agendamento de entrevista', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');

    await page.getByRole('button', { name: 'Processo seletivo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Processo seletivo' })).toBeVisible();

    const jobSelect = page.locator('.pipeline-job-picker select');
    await jobSelect.selectOption({ label: 'Técnico de Manutenção' });

    const candidate = page.locator('article.pipeline-card').filter({ hasText: 'Juliana Costa' });
    await expect(candidate).toBeVisible();
    await expect(candidate.getByRole('button', { name: 'Iniciar triagem', exact: true })).toBeVisible();

    await candidate.getByRole('button', { name: 'Iniciar triagem', exact: true }).click();
    await expect(candidate.getByRole('button', { name: 'Agendar entrevista', exact: true })).toBeVisible();

    await candidate.getByRole('button', { name: 'Agendar entrevista', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Agendar entrevista' })).toBeVisible();
    await expect(page.getByLabel('Data e hora')).toBeVisible();
    await expect(page.getByLabel('Duração (minutos)')).toBeVisible();
    await page.getByRole('button', { name: 'Fechar' }).click();

    await expect(page.locator('.overlay')).toHaveCount(0);
    await expect(candidate.getByRole('button', { name: 'Agendar entrevista', exact: true })).toBeVisible();
    await expectPlainLanguage(page);
  });

  test('empresa encontra a gestão da equipe e os papéis de acesso', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await page.getByRole('button', { name: 'Equipe', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Equipe da empresa' })).toBeVisible();
    await expect(page.getByRole('heading', { level: 2, name: 'Equipe da empresa' })).toBeVisible();
    await expect(page.getByText('Convide recrutadores, limite acessos e transfira a propriedade.', { exact: false })).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
  });

  test('empresa conduz candidato até proposta e candidato aceita contratação', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await page.getByRole('button', { name: 'Processo seletivo', exact: true }).click();

    const candidate = page.locator('article.pipeline-card').filter({ hasText: 'Marcos Silva' });
    await expect(candidate).toBeVisible();
    await expect(candidate.getByRole('button', { name: 'Agendar entrevista', exact: true })).toBeVisible();

    await candidate.getByRole('button', { name: 'Agendar entrevista', exact: true }).click();
    await page.getByLabel('Data e hora').fill('2026-10-05T10:00');
    await page.getByLabel('Duração (minutos)').fill('45');
    await page.getByRole('button', { name: 'Agendar', exact: true }).click();

    await expect(page.locator('.overlay')).toHaveCount(0);
    await expect(candidate.getByRole('button', { name: 'Registrar avaliação', exact: true })).toBeVisible();
    await expect(candidate.getByText('Próxima entrevista')).toBeVisible();

    await candidate.getByRole('button', { name: 'Registrar avaliação', exact: true }).click();
    const ratings = page.locator('.scorecard-row select');
    const ratingCount = await ratings.count();
    expect(ratingCount).toBeGreaterThan(0);
    for (let i = 0; i < ratingCount; i++) await ratings.nth(i).selectOption('4');
    await page.getByRole('button', { name: 'Salvar avaliação', exact: true }).click();
    await expect(page.locator('.overlay')).toHaveCount(0);

    await candidate.locator('summary').click();
    await candidate.locator('.pipeline-status-control select').selectOption('aprovado');
    await expect(candidate.getByRole('button', { name: 'Enviar proposta', exact: true })).toBeVisible();

    await candidate.getByRole('button', { name: 'Enviar proposta', exact: true }).click();
    await page.getByLabel('Salário').fill('4300');
    await page.getByLabel('Data de início').fill('2026-10-15');
    await page.getByLabel('Mensagem').fill('Proposta de demonstração para validação do fluxo.');
    await page.locator('.overlay').getByRole('button', { name: 'Enviar proposta', exact: true }).click();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expect(candidate.getByText(/Proposta enviada/i)).toBeVisible();

    await page.goto('/?e2eRole=candidato');
    await page.getByRole('button', { name: 'Minhas candidaturas', exact: true }).click();
    await expect(page.getByText('Operador CNC', { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Aceitar proposta', exact: true })).toBeVisible();

    await page.getByRole('button', { name: 'Aceitar proposta', exact: true }).click();
    await expect(page.getByText('Contratado', { exact: true })).toBeVisible();
    await expect(page.locator('.toast').getByText(/Proposta aceita/i)).toBeVisible();
    await expect(page.locator('.overlay')).toHaveCount(0);
    await expectPlainLanguage(page);
  });

  test('empresa edita e duplica uma vaga sem perder o processo', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await page.getByRole('button', { name: 'Vagas', exact: true }).click();

    let job = page.locator('article.company-managed-job').filter({ hasText: 'Operador CNC' }).first();
    await expect(job).toBeVisible();
    await expect(job.getByText('2', { exact: true }).first()).toBeVisible();

    await job.getByRole('button', { name: 'Editar vaga', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Editar vaga' })).toBeVisible();
    await page.getByLabel('Cargo').fill('Operador CNC Sênior');
    await page.getByRole('button', { name: 'Salvar alterações', exact: true }).click();

    job = page.locator('article.company-managed-job').filter({ hasText: 'Operador CNC Sênior' }).first();
    await expect(job).toBeVisible();
    await expect(job.getByText('2', { exact: true }).first()).toBeVisible();

    await job.getByRole('button', { name: 'Duplicar vaga', exact: true }).click();
    await expect(page.getByRole('heading', { level: 2, name: 'Estruturar nova vaga' })).toBeVisible();
    await expect(page.getByLabel('Cargo')).toHaveValue('Operador CNC Sênior (cópia)');
    await page.locator('.modal').getByRole('button', { name: 'Criar vaga', exact: true }).click();

    await expect(page.locator('article.company-managed-job').filter({ hasText: 'Operador CNC Sênior (cópia)' })).toBeVisible();
    await expect(page.locator('article.company-managed-job')).toHaveCount(4);
  });

  test('empresa registra motivo estruturado ao rejeitar candidato', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await page.getByRole('button', { name: 'Processo seletivo', exact: true }).click();

    const jobSelect = page.locator('.pipeline-job-picker select');
    await jobSelect.selectOption({ label: 'Técnico de Manutenção' });

    let candidate = page.locator('article.pipeline-card').filter({ hasText: 'Juliana Costa' });
    await expect(candidate).toBeVisible();
    await candidate.locator('summary').click();
    await candidate.locator('.pipeline-status-control select').selectOption('rejeitado');

    await expect(page.getByRole('heading', { level: 2, name: 'Por que este candidato não avançará?' })).toBeVisible();
    await page.getByLabel('Motivo').selectOption('disponibilidade');
    await page.getByLabel(/Observação interna/).fill('Disponibilidade atual incompatível com o turno desta vaga.');
    await page.getByRole('button', { name: 'Registrar rejeição', exact: true }).click();

    await expect(page.locator('.overlay')).toHaveCount(0);
    candidate = page.locator('article.pipeline-card').filter({ hasText: 'Juliana Costa' });
    await expect(candidate.getByText('Disponibilidade incompatível', { exact: true })).toBeVisible();
    await expect(candidate.getByText('Disponibilidade atual incompatível com o turno desta vaga.', { exact: true })).toBeVisible();

    await candidate.locator('summary').click();
    await expect(candidate.getByText(/Motivo da rejeição: Disponibilidade incompatível/)).toBeVisible();
    await expect(candidate.getByRole('button', { name: 'Reabrir processo', exact: true })).toBeVisible();
  });

  test('empresa pausa, reabre e encerra uma vaga mantendo o histórico', async ({ page }) => {
    await page.goto('/?e2eRole=empresa');
    await page.getByRole('button', { name: 'Vagas', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Minhas vagas' })).toBeVisible();

    const job = page.locator('article.company-managed-job').filter({ hasText: 'Operador CNC' });
    await expect(job).toBeVisible();
    await expect(job.getByText('Aberta', { exact: true })).toBeVisible();

    await job.getByRole('button', { name: 'Pausar vaga', exact: true }).click();
    await expect(job.getByText('Pausada', { exact: true })).toBeVisible();
    await expect(job.getByRole('button', { name: 'Reabrir vaga', exact: true })).toBeVisible();

    await job.getByRole('button', { name: 'Reabrir vaga', exact: true }).click();
    await expect(job.getByText('Aberta', { exact: true })).toBeVisible();

    page.once('dialog', dialog => dialog.accept());
    await job.getByRole('button', { name: 'Encerrar vaga', exact: true }).click();
    await expect(job.getByText('Encerrada', { exact: true })).toBeVisible();
    await expect(job.getByRole('button', { name: 'Reabrir vaga', exact: true })).toBeVisible();
    await expect(job.getByRole('button', { name: 'Processo seletivo', exact: true })).toBeVisible();
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


  test('páginas do candidato compartilham o mesmo eixo central', async ({ page }) => {
    await page.goto('/?e2eRole=candidato');

    const main = page.locator('#conteudo-principal');
    const header = main.locator(':scope > header');

    const expectAligned = async (content: ReturnType<typeof page.locator>) => {
      const [mainBox, headerBox, contentBox] = await Promise.all([
        main.boundingBox(),
        header.boundingBox(),
        content.boundingBox(),
      ]);
      expect(mainBox).not.toBeNull();
      expect(headerBox).not.toBeNull();
      expect(contentBox).not.toBeNull();
      if (!mainBox || !headerBox || !contentBox) return;

      const mainCenter = mainBox.x + mainBox.width / 2;
      const headerCenter = headerBox.x + headerBox.width / 2;
      const contentCenter = contentBox.x + contentBox.width / 2;

      expect(Math.abs(headerCenter - mainCenter)).toBeLessThanOrEqual(2);
      expect(Math.abs(contentCenter - mainCenter)).toBeLessThanOrEqual(2);
      expect(Math.abs(contentBox.x - headerBox.x)).toBeLessThanOrEqual(2);
      expect(Math.abs(contentBox.width - headerBox.width)).toBeLessThanOrEqual(2);
    };

    await expect(page.getByRole('heading', { level: 1, name: 'Vagas' })).toBeVisible();
    await expectAligned(main.locator(':scope > section.card').first());

    await page.getByRole('button', { name: 'Meu currículo', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Meu currículo' })).toBeVisible();
    await expectAligned(main.locator(':scope > .candidate-resume-page'));

    await page.getByRole('button', { name: 'Minhas candidaturas', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Minhas candidaturas' })).toBeVisible();
    await expectAligned(main.locator(':scope > section.card').first());

    await page.getByRole('button', { name: 'Competências e desenvolvimento', exact: true }).click();
    await expect(page.getByRole('heading', { level: 1, name: 'Competências e desenvolvimento' })).toBeVisible();
    await expectAligned(main.locator(':scope > section.card').first());
  });
});
