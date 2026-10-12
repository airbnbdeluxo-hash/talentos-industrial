# Critérios objetivos de conclusão — TalentOS Industrial

**Versão inicial:** 12/10/2026. **Escopo exclusivo:** `airbnbdeluxo-hash/talentos-industrial` · `https://talentos-industrial.vercel.app` · Supabase `kvxqhvngkjxqlvlzcsef`.
**Fonte de verdade:** requisitos aprovados em `docs/REQUIREMENTS_MATRIX.md`, roteiro `docs/AUTH_PRODUCTION_VALIDATION.md` e portões `docs/PR89_RELEASE_CHECKLIST.md`.

## Regra de decisão (sem interpretação subjetiva)

**Três marcos distintos e cronológicos:**
1. **AUTORIZADO A PUBLICAR (pré-deploy):** G01 e G02 aprovados, revisão humana do diff completo, plano de aplicação/reversão seguro documentado e responsáveis pela homologação real definidos. Esse marco **não** atesta a produção e não libera tráfego comercial antes do smoke pós-deploy.
2. **PRODUÇÃO HOMOLOGADA (liberação comercial):** **G01–G18 aprovados**, no SHA revisado e efetivamente publicado, com todos os ensaios pós-deploy executados. Critérios que só podem ser testados depois do deploy (G03, G04, G05 etc.) **não** são exigidos antes do deploy, mas são obrigatórios para declarar produção homologada. Se falharem, suspender a liberação e seguir o plano seguro de contenção, sem restaurar a RLS vulnerável.
3. **100% DO ESCOPO APROVADO:** além de G01–G18, **C01–C04 aprovados** e **cada requisito aprovado da matriz, incluindo P2**, implementado e homologado. Qualquer retirada de escopo exige decisão humana explícita registrada. Não atribuir "100%" com base em CI sintética, screenshots, deploy READY ou aprovação verbal genérica.

**Estado de cada caso:** `PENDENTE`, `EM TESTE`, `APROVADO`, `REPROVADO`, `BLOQUEADO` (dependência externa sem acesso), `DISPENSADO POR ESCOPO` (somente decisão humana explícita, com justificativa e link). `BLOQUEADO` **não** conta como `APROVADO`. Ausência de evidência = `PENDENTE`.

**Regra para evidência:** cada caso aprovado precisa registrar `data UTC/BRT | ambiente/domínio | SHA/deploy | identidade técnica não pessoal | ação exata | resultado esperado | resultado observado | link para CI ou relatório/log sem segredo | responsável pela validação`. Nunca guardar tokens, links de recuperação, senhas, currículos reais ou PII em relatórios. Para cada suíte, indicar **N de casos aprovados / N executados / N previstos**, não apenas "testes passaram".

## Portões quantitativos de aceite

| ID | Bloqueia homologação comercial? | Critério objetivo (100% dos cenários descritos) | Prova mínima |
|---|---|---|---|
| G01 | **SIM** | PR #89 recebeu **revisão humana favorável do diff completo** do HEAD exato; não há solicitação de mudanças pendente. Após qualquer novo commit, revalidar revisão e SHA. | Link para revisão GitHub e SHA aprovado. |
| G02 | **SIM** | CI **SUCCESS**, Security **SUCCESS** e Vercel Preview **READY** no **mesmo HEAD**; **0 testes falhando**; build bem-sucedido; **0 credenciais em arquivos versionados**. | IDs dos workflows, jobs e preview atrelados ao SHA. |
| G03 | **SIM** | O domínio público responde sem erro fatal; Vercel Production **READY** no SHA final aprovado; **0 divergências entre SHA publicado, release e diff revisado**. | URL oficial, deployment ID, SHA, teste HTTP/browser pós-publicação. |
| G04 | **SIM** | A migração RLS de `applications_insert` consta como aplicada no **Supabase correto**. Em `application_closed_job_rls.sql` pós-migração, **6/6 casos PASS**: vaga aberta/status `novo` aceita; vaga fechada, status `contratado`, status `triagem`, motivo de rejeição e nota de rejeição forjados recusados; **0 fixtures remanescentes** após rollback. | Migration history, política `WITH CHECK` real, teste SQL com rollback, auditoria de IDs. |
| G05 | **SIM** | A mesma regra passa **por HTTP** com conta candidata consentida: 1 criação legítima resulta `novo` e 5 criações proibidas não são persistidas (vaga fechada, `contratado`, `triagem`, código de rejeição, nota de rejeição). **0 bypasses**. | Requisições/respostas redigidas sem JWT ou PII e checagem de estado no banco. |
| G06 | **SIM** | Cadastro candidato e empresa com **duas contas técnicas distintas**: confirmação por e-mail real recebida, link válido abre domínio oficial e conta autentica. Reenvio, recuperação e senha alterada funcionam; **7/7 cenários** (candidato, empresa, conta existente, reenvio, recuperação válida, recuperação expirada e limpeza de link inválido) PASS. | Evidências de inbox sem endereços pessoais, callback sem tokens e resultado de login. |
| G07 | **SIM** | Política de senha é imposta **no servidor**: senha de **7 caracteres rejeitada** e senha de **8 caracteres** que atende a política declarada **aceita**; login, logout, sessão expirada e redefinição não permitem uso indevido de sessão antiga. **0 operações autorizadas após logout**. | Configuração verificada no painel autorizado + resultado real de Auth com contas técnicas. |
| G08 | **SIM** | Site URL/redirect allowlist apontam ao domínio oficial, **0 redirecionamentos para destino externo não autorizado**, SMTP real envia e-mails de confirmação/reenvio/recuperação a destinatário técnico, sem erros de callback. Não contam mensagens apenas "enviadas" no frontend. | Inspeção autorizada de Auth URLs/SMTP + e-mails efetivamente recebidos. |
| G09 | **SIM** | Isolamento de acesso por papéis: candidato não lista/edita outro candidato; empresa A não acessa/modifica empresa B; viewer não altera recursos; recruiter só faz ações autorizadas; anônimo não lê dados privados. **0 acessos cruzados indevidos** nos testes HTTP das operações relevantes. | Matriz de permissões por API com requisições e respostas sanitizadas; RLS de todas as tabelas relevantes. |
| G10 | **SIM** | Storage `candidate-resumes` e `skill-evidence` privados: dono obtém arquivo próprio; segundo candidato e anônimo **não** obtêm arquivo do dono; URL expirada não permite acesso; limite de upload de **10 MiB** aplicado; **0 vazamentos**. | Testes HTTP upload/download com arquivos fictícios e análise das políticas de Storage. |
| G11 | **SIM** | Candidato importa **1 PDF e 1 DOCX de teste**, vê campos e habilidades extraídos para revisão, edita e **só persiste após "Confirmar e salvar"**. Cancelamento antes da confirmação resulta em **0 registros/arquivos persistidos indevidamente**; após salvar, os dados corretos reaparecem em nova sessão. | Teste de navegador com backend autorizado + consulta remota, sem currículo real. |
| G12 | **SIM** | Candidatura legítima criada **uma única vez**; segunda tentativa e concorrência não geram duplicação (**1 registro final por candidato/vaga**). Empresa pode conduzir etapas autorizadas e candidato não pode forjar decisões; sem erros fatais no fluxo candidato → vaga → candidatura → seleção. | HTTP + consulta ao índice único, status transicionado e UI em contas de teste. |
| G13 | **SIM** | Menus e dados separados para candidato/empresa/admin; em **360, 390, 768 e 1440 px**, **0 rolagens horizontais indevidas**, **0 elementos críticos cortados** e tarefas centrais concluíveis; logo retorna ao início e mensagens de erro/sucesso identificáveis por texto além de cor. | Capturas e testes por largura/role, navegação real e registro de falhas. |
| G14 | **SIM** | Fluxos críticos (landing/login/cadastro/recuperação, currículo, busca de vagas, candidatura, empresa) sem violações **critical/serious** de axe, **inclusive regra de contraste**; navegação completa por teclado, foco visível e ordem de foco correta, leitura assistiva verificada ao menos no fluxo de login e formulário de candidatura. **0 bloqueios de teclado**. | Relatórios axe sem `disableRules(['color-contrast'])` + roteiro teclado/leitor de tela. |
| G15 | **SIM** | Regressão de **todos os casos P0/P1 afetados** executada após o último commit de código e, após a implantação, smoke de autenticação, vagas, candidatura e permissões **100% PASS**; **0 falhas críticas/altas abertas**. Histórico SQL aprovado preservado, sem repetir testes imutados sem motivo. | CI do SHA, relatório pós-publicação e lista explícita dos casos executados. |
| G16 | **SIM** | Segurança: **0 vulnerabilidades high/critical conhecidas sem tratamento** no código/dependências; **0 segredos expostos**, revisão de RLS/RPC/Storage e plano de rollback que **não restaure a política vulnerável**. Avisos moderados e proteção de senha vazada desabilitada só podem ser aceitos como risco residual mediante decisão humana específica e documentada; caso contrário, não declarar segurança integral. | Security workflow, advisories do Supabase, lista de exceções/responsável, ata de aceite quando aplicável. |
| G17 | **SIM** | Privacidade: consentimento explícito e configurável; exportação/solicitação de exclusão acessíveis somente ao titular ou administrador autorizado; **0 PII, JWT ou dados reais de CV em logs de evidências**; arquivos de teste e identidades técnicas descartados segundo plano. | Testes de perfil/permissão e auditoria de evidências sem dados pessoais. |
| G18 | **SIM** | Homologação final assinada pelo responsável humano: **G01–G17 = APROVADO**, nenhum `PENDENTE`, `BLOQUEADO`, `REPROVADO` ou `DISPENSADO` nos bloqueantes; checklist de produção e plano de reversão revisados. | Registro datado do aceite humano, evidências cruzadas com SHA. |

### Critérios adicionais para declarar **100% do escopo** (não dispensáveis por conveniência)

| ID | Critério mensurável | Evidência |
|---|---|---|
| C01 | **100% das linhas aprovadas** de `docs/REQUIREMENTS_MATRIX.md` possuem teste de aceite real, resultado `APROVADO`, versão/deploy e responsável; funcionalidades P2 ainda não implementadas continuam pendentes até entrega ou exclusão formal humana do escopo. | Matriz atualizada sem linhas sem comprovação. |
| C02 | Módulos avançados aprovados (por exemplo carreira, recomendações, simulação, inteligência e desenvolvimento) demonstrados em jornadas reais com **ao menos um cenário positivo, um de erro e um de acesso indevido por módulo**; heurística não é declarada IA generativa. | Roteiros, outputs e logs anonimizados por módulo. |
| C03 | Desempenho de páginas críticas no perfil mobile controlado: **Lighthouse Performance ≥ 80** e **Accessibility ≥ 90** em **3 execuções por página** (registrar os 3 valores), sem erro de console fatal; quando houver amostra suficiente de usuários, **p75 LCP ≤ 2,5 s, INP ≤ 200 ms e CLS ≤ 0,1**. Sem dados suficientes, registrar medição sintética e não inventar p75 real. | Relatórios com condições de rede, dispositivo, data e URL. |
| C04 | **0 defeitos P0/P1 abertos**, **0 testes de regressão falhando**, revisão de UX/CX concluída para candidato, empresa e administrador, manual de operação/homologação disponível e documentação reproduzível por outra pessoa. | Backlog e CI, relatório de UX, documentação e termo de aceite. |

### Critério de interrupção e reabertura
- Qualquer falha em G01–G18, divergência de SHA, acesso cruzado, exposição de dados, falha em e-mail real ou rollback que reabra RLS = **NÃO LIBERADO**, mesmo que o restante esteja verde.
- Correção posterior ao aceite obriga executar novamente os checks e os testes impactados no **novo SHA** e renovar a revisão humana quando o diff mudar.
- Um item classificado `BLOQUEADO` depende de evidência/ação externa e permanece não aprovado; não simular a configuração de SMTP, sessão ou Auth com dados fictícios.
- A decisão de reduzir o escopo requer registro humano explícito com requisito, motivo, risco e versão-alvo; **não** reclassificar P0 de segurança como opcional.

## Quadro de status inicial — evidência já existente, sem promover a PASS real

| Bloco | Estado em 12/10/2026 | Motivo |
|---|---|---|
| CI/Security do SHA anterior `9027acd` | **APROVADO somente para aquela revisão** | CI `38318565505` e Security `38318565624` SUCCESS; SHA muda ao editar documentação. |
| Revisão humana do PR #89 | **PENDENTE** | Zero revisões humanas registradas na consulta. |
| Migração de integridade e HTTP | **BLOQUEADO** | Correção SQL validada em transação com rollback, mas não aplicada. |
| Produção com SHA revisado | **BLOQUEADO** | Produção ainda `baa7cc4`. |
| Auth/SMTP/política servidor/e-mails reais | **BLOQUEADO** | Ausência de acesso confiável às configurações e de prova de entrega de e-mail. |
| Storage HTTP, currículo persistido e jornadas reais | **PENDENTE** | Suítes SQL e Playwright sintéticas não equivalem a homologação remota. |
| Acessibilidade integral/contraste e desempenho real | **PENDENTE** | Contraste foi desativado na auditoria automatizada prévia; faltam relatórios completos. |
| Funcionalidades P2 e aceite integral | **PENDENTE** | Matriz registra funcionalidades não implementadas/parciais. |

**Conclusão atual:** não liberado; não homologado 100%. Atualizar este quadro **somente após obter evidências**.
