# Matriz de requisitos — 12/10/2026

Base em produção: baa7cc4; correções propostas em PR #89: 39511e1 (autenticação) e c8f485b (currículo), seguidas de atualização documental. Esta matriz distingue código existente, testes sintéticos e homologação real. Ausência de falha em scanner não prova ausência de vulnerabilidade.

| Prioridade | Requisito | Estado | Evidência e critério restante |
|---|---|---|---|
| P0 | Projeto e publicação corretos | Concluído e comprovado | GitHub main baa7cc4; Vercel produção READY dpl_7oG3P7aSUCXJEBCnFvHeyetQashm; Supabase ACTIVE_HEALTHY |
| P0 | Cadastro candidato/empresa e login | Implementado, pendente de homologação | App.tsx usa Supabase Auth; falta jornada real com contas técnicas e entrega de e-mail |
| P0 | Confirmação de e-mail | Parcialmente implementado | Tratamento de expiração e reenvio em main; falta comprovar entrega e callback válido |
| P0 | Recuperação expirada | Parcialmente implementado | PR #89 separa recuperação de confirmação; 7 testes unitários de links passam; navegador/CI aprovados; aguarda revisão |
| P0 | Recuperação válida e troca de senha | Implementado, pendente de homologação | PASSWORD_RECOVERY e updateUser presentes; falta teste de sessão real |
| P0 | Senha mínima de oito caracteres | Parcialmente implementado | Interface comprovada; configuração Auth do servidor ainda não consultada |
| P0 | URLs oficiais de autenticação | Parcialmente implementado | Frontend usa domínio oficial; allowlist/site URL do servidor ainda não consultadas |
| P0 | Senhas vazadas | Bloqueado por dependência externa | Advisor confirma desativação; organização free; documentação exige Pro ou superior; nenhum plano contratado |
| P0 | Logout e expiração de sessão | Implementado, pendente de homologação | Persistência/renovação e listener presentes; falta execução real e teste de corrida de sessão |
| P0 | RLS habilitada | Concluído e comprovado | Consulta pg_class: 46 tabelas públicas com RLS |
| P0 | Isolamento de candidatos e empresas | Parcialmente implementado | recruiting_journey.sql passou no banco com identidades sintéticas e rollback; falta repetir fronteira HTTP/browser |
| P0 | Permissões de visualizador | Concluído e comprovado no banco | Teste permite leitura da candidatura e impede mudança de status; cobertura limitada aos caminhos exercitados |
| P0 | Privilégios administrativos | Implementado, pendente de homologação | rls_security.sql confirma provisionamento por app_metadata e proteção de role; falta jornada admin completa |
| P0 | Arquivos privados | SQL de RLS aprovado; HTTP pendente | Buckets candidate-resumes e skill-evidence privados (10 MiB); `storage_private_rls.sql` PASS: dono lê, outro candidato/anon não leem, usuário não altera documento de terceiro, evidência imutável não pode ser sobrescrita. Sem arquivos reais; falta tentativa de download via Storage API autenticada |
| P0 | Chaves no frontend | Concluído e comprovado no escopo do scanner | security:scan passou; não equivale a auditoria completa do histórico |
| P1 | Cadastro empresarial/CNPJ/cidade/limites | Implementado, pendente de homologação | Correções recentes na main e função company-team v8; falta exercitar endpoint de criação com conta técnica |
| P1 | Gestão de equipe | Parcialmente implementado | company_team_management.sql passou; transferência/remoção passaram em transação; convite real por e-mail pendente |
| P1 | Vaga até contratação | Parcialmente implementado; falha de regra de inscrição descoberta | `recruiting_journey.sql` PASS na jornada sintética. **Duas falhas da RLS vigente reproduzidas**: inserir candidatura em vaga fechada e criar candidatura diretamente como `contratado`. Migração `20261012221728_block_closed_job_applications.sql` ampliada para restringir novos registros de candidato à vaga aberta, status `novo` e motivos de rejeição nulos. Validação transacional PASS e revertida. **Não aplicada à produção**; aguarda revisão humana e publicação controlada |
| P1 | Currículo manual/PDF/Word | Implementado com validação de formato adicional, pendente de CI e homologação | Parser existente e testes Playwright com PDF/DOCX. Nova validação lê os primeiros bytes para recusar arquivos vazios, extensões indevidas e conteúdo disfarçado antes de PDF.js/Mammoth (`eecc144` + `08693fc`); CI `38317334512` e Security `38317334473` SUCCESS; ainda falta persistência real e os testes não substituem scanner de malware |
| P1 | Cancelar leitura sem salvar | Implementado, pendente de homologação | c8f485b: AbortController mais geração invalidada; teste Playwright de leitura atrasada e cancelamento aprovado em modo E2E, falta ambiente remoto/conta real |
| P1 | Skills editáveis sem inventar qualificações | Parcialmente implementado | c8f485b: remove inferência de cargo a partir da primeira linha, bloqueia menções negadas/aspiracionais e preserva frases positivas; testes automatizados aprovados, falta avaliação ampla com currículos reais consentidos |
| P1 | Filtros cargo/skill/cidade/empresa/salário/turno/modalidade | Corrigido e aprovado em CI sintética; homologação real pendente | `c51642c`: candidato não recebe vagas encerradas; cidade selecionada compara município inteiro e UF quando ambos têm UF, sem correspondência parcial. Testes de filtros combinados e resultado vazio passaram na CI `38315486240`. Validar dados reais e busca geográfica na produção após revisão |
| P1 | Duplicação de candidatura | Garantia de unicidade comprovada em SQL; fluxo HTTP pendente | Índice único PostgreSQL `(job_id,candidate_id)` presente; `application_uniqueness.sql` PASS: segunda inserção recusada com `unique_violation`, contagem mantida em 1 e fixtures revertidas. Falta UX de concorrência/reenvio HTTP |
| P1 | Mensagens/entrevistas/propostas/notificações | Concluído e comprovado no banco para cenário exercitado | Jornada transacional passou; e-mail/entrega externa e interface real ainda pendentes |
| P1 | Avaliações e competências comprovadas | Comprovado na camada SQL testada; pendente de homologação real | `evidence_skill_loop.sql` PASS: ownership, autovalidação negada, proveniência, progressão limitada, evento de auditoria, rematching, idempotência, privilégios e rollback. Falta fluxo real de navegador + documentos privados |
| P1 | Compilação e testes unitários | Concluído e comprovado no último código funcional inspecionado | CI build/e2e-smoke 38302827078 e Security 38302827143 passaram no c8f485b, inclusive extração de currículo; revalidar os commits documentais posteriores |
| P1 | Dependências | Parcialmente implementado | npm audit: 3 avisos moderados na mesma cadeia mammoth→argparse→sprintf-js, sem high/critical; avaliar atualização segura |
| P1 | Navegador e acessibilidade | Parcialmente implementado | CI e2e-smoke e fluxos públicos aprovados em c8f485b; inclui importação de currículo simulada e links expirados. Navegador de CI usa ambiente isolado; suíte desativa contraste e não comprova acessibilidade integral nem produção com backend real |
| P2 | Assistente conversacional de carreira | Não implementado na base inspecionada | Não encontrada integração generativa; definir provedor gratuito, consentimento e limites |
| P2 | Análise aprimorada de currículo | Parcialmente implementado | Extração determinística existente; não chamar de IA generativa |
| P2 | Recomendações explicáveis de vagas | Implementado, pendente de homologação | Matching com razões e lacunas existente; validar qualidade e explicação com dados autorizados |
| P2 | Simulador de entrevistas | Não implementado na base inspecionada | Não localizado fluxo de simulação para candidato |
| P2 | Plano personalizado de desenvolvimento | Comprovado em cenários SQL; pendente de homologação real | `evidence_skill_loop.sql` e `outcome_skill_feedback_loop.sql` PASS para vínculos de treinamento e recomendações após contratação, com rollback. Falta jornada real de usuário e qualidade dos recursos |
| P2 | Mapa visual de progressão | Parcialmente implementado | SkillGraph existente não comprova mapa pessoal de progressão |
| P2 | Pesquisa em linguagem natural | Não implementado na base inspecionada | Filtros existentes não equivalem a pesquisa semântica |
| P2 | Orientação de candidaturas | Parcialmente implementado | Informações de compatibilidade presentes; assistente individual ainda pendente |
| P2 | Alertas de oportunidades | Implementado, pendente de homologação | job_alerts e notificações funcionam no cenário SQL; entrega e relevância pendentes |
| P2 | Portfólio de competências | Implementado, pendente de homologação | Evidências e validação humana existentes; testar cadeia completa e acesso aos documentos |
| P2 | Padrão visual desktop/mobile/admin | Parcialmente implementado | Smoke existente cobre 390 px; adicionado `tests/e2e/mobile-360.spec.ts` para menus candidato/empresa (passaram em 360 px), e teste separado de recuperação na suíte de preview sintético (**CI aprovada em 8e5ca57**). Ainda falta inspeção visual real, contraste, outras larguras e dispositivos |
| P2 | Desempenho | Parcialmente implementado | Build alerta bundle principal >500 kB; falta medição em dispositivo/rede móvel |

## Evidências desta execução

- Banco: `supabase/tests/rls_security.sql`, `company_team_management.sql` e `recruiting_journey.sql` executados com sucesso.
- Jornada sintética usa transação e rollback. Consulta posterior retornou zero usuários com os cinco IDs de teste.
- Nenhuma migração ou função publicada. Nenhum dado real excluído. Nenhum e-mail enviado nesta execução.
- Produção continua em baa7cc4 (dpl_7oG3P7aSUCXJEBCnFvHeyetQashm, READY). Preview do código funcional c8f485b: dpl_CXJ6tdzzHkBmv1QQnV7jiTHcf9BQ, READY. PR #89 segue sem revisão humana registrada.
- Revisão de autenticação: https://github.com/airbnbdeluxo-hash/talentos-industrial/pull/89.

## Evidência adicional — continuação de 12/10/2026
- PR #89 aberto; diferença para main era 4 commits à frente/0 atrás antes de atualizar documentação. Alterações de autenticação e currículo ainda não promovidas.
- CI completa de c8f485b: build + e2e-smoke com sucesso (run 38302827078) e Security com sucesso (run 38302827143). Os novos testes de currículo usam fixtures e modo E2E; não são homologação de conta real.
- Supabase ACTIVE_HEALTHY, Edge Function company-team versão 8 ACTIVE com verificação JWT; advisor de segurança mantém aviso de proteção de senhas vazadas desativada. URLs Auth, política do servidor, SMTP e entrega de mensagens não foram verificadas pelo dashboard.
- Nenhuma migração/SQL mutável, promoção para produção ou ação sobre outros projetos foi executada nesta continuação. Testes SQL anteriormente aprovados não foram repetidos.
- AÇÃO BLOQUEANTE: revisão humana do PR #89, seguida de nova conferência do HEAD, checks e merge somente após aprovação; demais critérios de homologação real permanecem pendentes.

## Regressões SQL adicionais verificadas nesta continuação
- `supabase/tests/evidence_skill_loop.sql`: PASS (propriedade, autovalidação, proveniência, progressão, auditoria, idempotência, grants, recomendações).
- `supabase/tests/outcome_skill_feedback_loop.sql`: PASS (30/60/90 dias, sem validação automática, rematching, feedback, idempotência e autorização).
- Ambos executados com BEGIN/ROLLBACK em `kvxqhvngkjxqlvlzcsef`. Consulta posterior encontrou **0 usuários remanescentes** nos seis UUIDs sintéticos destes testes. Nenhuma migração foi aplicada.
- Estes resultados comprovam os cenários SQL executados e NÃO substituem teste real de e-mail, sessão, arquivos privados via HTTP, cadastro, candidaturas e persistência de currículo.

## Bloco de continuidade — segurança de armazenamento e unicidade
- `supabase/tests/storage_private_rls.sql` criado e executado: PASS. O teste usa apenas metadados fictícios de arquivos, nenhum byte enviado; verifica buckets privados, RLS, isolamento do proprietário/outro candidato/anon e imutabilidade de evidências. Políticas `skill_evidence_objects_immutable` (UPDATE) e `skill_evidence_objects_referenced_delete_guard` (DELETE) são RESTRICTIVE; a regra de exclusão foi verificada estruturalmente, não por chamada HTTP.
- `supabase/tests/application_uniqueness.sql` criado e executado: PASS. Índice único em `(job_id,candidate_id)` é controle transacional contra duplicação, teste de segunda inserção bloqueada. Não simula duas requisições HTTP simultâneas.
- Os dois scripts contêm `BEGIN`/`ROLLBACK`; consulta posterior confirmou zero metadados de Storage, zero candidaturas e zero contas sintéticas nos IDs usados.
- Novo Playwright em 360px: candidato e empresa em `tests/e2e/mobile-360.spec.ts` passaram na CI 38314421703; o caso de recuperação inicialmente falhou **por ambiente de teste sem Supabase configurado** (`authModal && supabaseConfigured`), não por falha comprovada em produção. Foi transferido para `tests/e2e-production/public.spec.ts`, que usa Supabase sintético (commit 8e5ca57). **CI 38314701915 e Security 38314701833 aprovaram o código corrigido 8e5ca57.**
- Vercel projeto correto: domínio `talentos-industrial.vercel.app` verificado, filtro de variáveis (sem decriptar valores) apresentou `VITE_SUPABASE_URL` e nenhuma chave pública de preview; `src/lib/supabaseTarget.ts` proíbe usar backend de produção em preview. Homologação real exige ambiente autorizado e isolado, não apontar preview para banco de produção.
- Vercel runtime_errors (24h) não apontou erros de funções; não é prova de ausência de erros de navegador nem confirmação de e-mail.
- Supabase advisor continua com aviso de proteção de senhas vazadas desativada. Não houve nova migração, publicação de função, criação de ambiente ou mudança de produção.

## Validação após a falha do teste móvel — correção comprovada
- CI `38314421703` falhou apenas no teste novo de recuperação expirada porque a suíte de desenvolvimento não configurava Supabase (`authModal && supabaseConfigured`); 28 testes passaram, incluindo os testes móveis de menus candidato e empresa em 360px. Build e Security passaram.
- Correção técnica de teste, sem alterar a aplicação: remover verificação de Auth da suíte sem Supabase (commit `9e06d9a`) e incluí-la na suíte de preview de produção com endpoint sintético, em `tests/e2e-production/public.spec.ts` (commit `8e5ca57`).
- CI `38314701915`: SUCCESS incluindo build, e2e-smoke e preview; Security `38314701833`: SUCCESS no commit funcional `8e5ca57`. Vercel preview do commit `8e5ca57`: `dpl_GMtsudWNGSBNwDnKA1JVNuZ6cM7Q`, READY.
- Criado `docs/AUTH_PRODUCTION_VALIDATION.md` com checklist de configuração Site URL/redirects/SMTP/política e testes reais, sem segredos e sem declarar homologação.
- Supabase Performance Advisor: 64 avisos INFO de índices não usados; **nenhum índice removido**, devido à necessidade de evidência de carga/consultas.

## Nova auditoria — integridade de vagas e fronteira do banco
- Ponto identificado: filtro do candidato mostrava vagas encerradas e comparava nomes de cidades por substring sem verificar UF. Corrigido em `src/App.tsx` e `src/lib/industrialCatalog.ts`; acrescentados `tests/jobCityFilter.test.mjs` e `tests/e2e/job-search.spec.ts`.
- CI `38315486240` SUCCESS e Security `38315486163` SUCCESS no commit `c51642c` (busca e filtros), em ambiente isolado. Cobertura: cidade/UF exata, cidades legadas sem UF, vagas fechadas ocultas para candidato, salário, modalidade, cargo, limpeza e resultado vazio.
- Auditado Supabase correto: 17 funções `SECURITY DEFINER` em `public`, nenhuma diretamente executável por `anon` ou `authenticated`; view `skill_market_summary` com `security_invoker=true`. Inspeção estática de privilégios, não demonstra segurança de todos os caminhos.
- Falha de regra do banco **reproduzida com transação reversível**: aplicação em vaga `fechada` aceita pelo RLS `applications_insert` atual (`closed_applications_accepted = 1`). Causa: WITH CHECK verificava identidade do candidato, mas não exigia vaga aberta.
- Correção SQL testada reversivelmente: ALTER POLICY limita nova candidatura do candidato a `jobs.status = 'aberta'`, preservando exceção administrativa e identidade. Teste de vaga aberta permitida e fechada bloqueada retornou PASS; ROLLBACK reverteu também a alteração de política.
- Migração preparada na branch: `supabase/migrations/20261012221728_block_closed_job_applications.sql`. Regressão pós-migração: `supabase/tests/application_closed_job_rls.sql` (só deve executar após aplicar a migração no ambiente-alvo). **A migração não foi aplicada à produção.**
- Consulta final de verificação: 0 contas sintéticas e 0 candidaturas sintéticas dos UUIDs exercitados; `production_guard_applied = false`. Não afirmar que o problema está resolvido em produção.
- Próxima ação condicionada à revisão humana: revisar diff e migração, executar pipeline controlado, conferir política e RLS pós-migração, rodar regressão SQL com rollback e homologar tentativa HTTP com conta técnica. Não aplicar a migração antes da aprovação necessária.

## Auditoria adicional de integridade — status forjado no INSERT
- O Supabase `kvxqhvngkjxqlvlzcsef` permitiu a um candidato autenticado criar diretamente `applications.status='contratado'` em vaga aberta. Reprodução sintética gerou `accepted_forged_hired_application=1` dentro de `BEGIN/ROLLBACK` (nenhum registro persistido).
- Causa: a política atual `applications_insert` verifica somente se `candidate_id=auth.uid()`; não restringe status inicial nem campos de decisão reservados à empresa. A falha de vaga fechada já havia sido reproduzida anteriormente.
- A **migração existente, ainda não aplicada**, `supabase/migrations/20261012221728_block_closed_job_applications.sql` foi ampliada para `status='novo'`, `rejection_reason_code IS NULL`, `rejection_reason_note IS NULL` e `jobs.status='aberta'`, mantendo a exceção `private.is_admin()`.
- A regressão `supabase/tests/application_closed_job_rls.sql` foi ampliada para criar quatro vagas sintéticas, testar uma candidatura inicial válida e rejeitar vaga fechada, auto-contratação e rejeição forjada. Delimitador `DO $$` corrigido antes da execução.
- Migração seguida da regressão foi **executada com sucesso na mesma transação `BEGIN/ROLLBACK`**, sem aplicar alterações permanentes: `PASS: open job accepted; closed job, forged hired status and forged rejection denied; all fixtures rolled back`.
- Consulta de auditoria após a prova: **zero** usuários e candidaturas sintéticas para todos os identificadores usados; a política real ainda é `(private.is_admin() OR candidate_id=auth.uid())`, sem os novos guardas.
- **P0 em produção:** não afirmar que está corrigido até revisão humana do PR #89, aplicação da migração e regressão pós-publicação com teste HTTP real. Nenhuma mudança de Auth/SMTP ou Vercel realizada neste bloco.


## Bloco independente — validação inicial de arquivos PDF/Word
- `src/lib/resumeParser.ts` (commit `eecc144`) agora confere extensão .pdf/.docx, rejeita arquivo vazio, mantém limite 10 MB e verifica o início do conteúdo (%PDF- no início até 1024 bytes, cabeçalho ZIP de .docx) antes de acionar os extratores. A checagem não comprova que o documento é seguro ou contém somente dados legítimos; PDF.js e Mammoth continuam responsáveis por extrair o conteúdo.
- `tests/resumeParser.test.mjs` (commit `08693fc`) cobre extensão disfarçada de MIME PDF, documentos vazios e conteúdo que não corresponde à extensão; fixtures reais de PDF/DOCX continuam na suíte E2E existente. CI `38317334512` SUCCESS e Security `38317334473` SUCCESS no commit de código/teste `08693fc`. Revalidar HEAD documental antes do merge.
- Nenhum arquivo real de candidato foi lido, persistido, enviado ao Supabase ou à Vercel nesta análise. Ainda faltam verificação HTTP/download de Storage, testes com usuários consentidos e persistência real.
