# Continuidade — TalentOS Industrial

Atualização: 2026-10-12 (continuação, PR #89 em testes e documentação; última correção funcional/testes `8e5ca57`). Objetivo: concluir e homologar o escopo aprovado, sem alterar outros projetos.

## Estado confirmado
- Repositório: airbnbdeluxo-hash/talentos-industrial. Base main: baa7cc4f1d3f3acf87526b72eaadc66c2c77288d.
- Vercel: talentos-industrial, prj_YEg1JW2yCyNl2dUUmNXslByfDw5B, equipe team_eozFtIK3qutzBey1SLzDmQgN.
- Produção READY: dpl_7oG3P7aSUCXJEBCnFvHeyetQashm, correspondente à base acima.
- Supabase kvxqhvngkjxqlvlzcsef: ACTIVE_HEALTHY; company-team ativa, versão 8, verify_jwt=true.
- Todas as 46 tabelas públicas consultadas têm RLS habilitada. Isso NÃO comprova isolamento comportamental.
- Advisor de segurança: proteção contra senhas vazadas desativada; nenhum outro aviso retornado.
- Interface exige oito caracteres, maiúscula, minúscula, número e símbolo. Política do servidor ainda não confirmada.

## Execução atual
- Branch: work/conclusao-20261012.
- Nenhuma migração, função ou publicação alterada nesta execução.
- PR #89 aberto: https://github.com/airbnbdeluxo-hash/talentos-industrial/pull/89. Alterações críticas dependem de revisão humana, conforme escopo aprovado.
- Dependências instaladas. 25 testes unitários e build local aprovados na etapa anterior, commit 39511e1. No HEAD atual c8f485b, CI build + e2e-smoke (38302827078) e Security (38302827143) concluíram com sucesso; o CI executou testes de extração e fluxos de navegador em modo isolado. Não equivale a homologação com contas/e-mails reais.
- Arquivos no PR #89 (HEAD c8f485b): src/App.tsx, src/lib/authLink.ts, src/lib/resumeParser.ts, tests/authLink.test.mjs, tests/e2e-production/public.spec.ts, tests/e2e/resume-import.spec.ts, tests/fixtures/resume-files.json, tests/resumeParser.test.mjs, docs/WORK_HANDOFF.md e docs/REQUIREMENTS_MATRIX.md.
- Commits da branch: 5581967 (checkpoint), 39511e1 (recuperação), 50e186b (documentação), c8f485b (currículo: extrair sem inventar competências, abortar leitura e testes de navegador). Commit local inicial 6812d47 é equivalente ao checkpoint, mas não foi enviado; git push não tinha credencial, usado conector GitHub.
- Preview atual READY: dpl_CXJ6tdzzHkBmv1QQnV7jiTHcf9BQ, commit c8f485bb57b74f25516fca6c664d78c0d3516aa5; produção permanece READY em dpl_7oG3P7aSUCXJEBCnFvHeyetQashm (baa7cc4).
- Testes SQL rls_security.sql, company_team_management.sql, recruiting_journey.sql, evidence_skill_loop.sql e outcome_skill_feedback_loop.sql passaram no projeto correto. Jornadas sintéticas revertidas por rollback; consultas posteriores indicaram zero usuários de teste remanescentes nos IDs examinados.
- Buckets candidate-resumes e skill-evidence privados, 10 MiB. 87 migrações remotas, última 20261011213109.
- npm audit: três avisos moderados na cadeia mammoth/argparse/sprintf-js; sem high/critical. Não aplicar downgrade automático.
- Organização free; proteção contra senhas vazadas exige Pro conforme documentação oficial. Não foi contratado plano.
- Ferramentas Supabase disponíveis não expõem configuração Auth/SMTP. Inspeção de política/URLs via dashboard depende de acesso autorizado ao navegador; não inferir configuração pelo frontend.
- Chromium local falhou no download; navegador foi validado na CI com sucesso. Não repetir instalação sem motivo.
- Não há indicador de créditos disponível nesta sessão.

## Bloco de continuação — verificação independente em 12/10/2026
- GitHub PR #89: aberto, mergeable, sem revisões humanas (nem threads); branch quatro commits à frente de main, zero atrás na consulta inicial.
- CI no HEAD c8f485b: build e e2e-smoke SUCCESS (38302827078); Security SUCCESS (38302827143); verificados os jobs e suas etapas. Scanner e auditoria de dependências com limiar high passaram; isso não elimina os três alertas moderados já registrados.
- Novos testes Playwright `tests/e2e/resume-import.spec.ts`: leitura de fixtures PDF e DOCX, edição sem salvar antes de confirmação e interrupção de importação lenta. São testes no modo VITE_E2E/localStorage, NÃO persistência real no Supabase de produção.
- Vercel no projeto e equipe declarados: prévia do HEAD READY, produção anterior READY, sem promoção/merge.
- Supabase correto: projeto ACTIVE_HEALTHY, única Edge Function company-team versão 8 ACTIVE verify_jwt=true; advisor de segurança mantém apenas WARN de proteção de senhas vazadas desativada. Nenhuma configuração de Auth URLs, SMTP, ou política de servidor foi comprovada nesta consulta.
- Nenhum SQL de escrita, migração, Edge Function, publicação ou usuário real alterado nesta continuação. Provas SQL da etapa anterior preservadas sem reexecução.

## Pendências prioritárias
1. Homologar confirmação, recuperação e sessões; conferir Auth URLs e política do servidor.
2. Executar testes de isolamento por perfil, equipe e arquivos privados em ambiente isolado.
3. Homologar cadastro empresarial e jornada até contratação sem dados fictícios permanentes na produção.
4. Homologar currículo manual/PDF/Word, cancelamento durante leitura, filtros e candidaturas.
5. Auditar recursos de IA e separar heurísticas existentes de integrações generativas ainda dependentes de provedor.
6. Revisar todas as telas desktop/mobile e acessibilidade.

## PRÓXIMA AÇÃO EXATA
Obter revisão humana do PR #89 exigida pelo escopo para alterações críticas de autenticação e também conferir as mudanças posteriores de currículo. Na consulta de 12/10, o PR continuava aberto e sem nenhuma revisão registrada. Após aprovação humana, conferir HEAD exato (c8f485b nesta consulta; se mudar, revisar diff e checks novamente), integrar e verificar deployment de produção com SHA correspondente. Em paralelo ao próximo bloco, conferir Auth URL/política/SMTP por dashboard autorizado e homologar e-mail real com conta técnica. As ferramentas conectadas não expuseram os ajustes Auth/SMTP; consulta read-only aos logs não demonstrou entrega de e-mail, portanto não registrar como homologado. Consultar docs/REQUIREMENTS_MATRIX.md para demais pendências; não repetir testes SQL já aprovados sem alteração relacionada.

## Retomada
Leia este documento na branch indicada e confira main/PRs antes de trabalhar. Use npm ci --no-audit --no-fund; node --experimental-strip-types --test tests/*.test.mjs scripts/security-check.test.mjs; npm run security:scan; npm run build. Não trate testes sintéticos como homologação de produção.


## Bloco seguinte — regressões SQL de evidências e pós-contratação
- Foram inspecionados e executados `supabase/tests/evidence_skill_loop.sql` e `supabase/tests/outcome_skill_feedback_loop.sql` exclusivamente no projeto Supabase `kvxqhvngkjxqlvlzcsef`.
- Ambos retornaram PASS. Cobrem autorização, impedimento de autovalidação, proveniência, evolução limitada, auditoria, idempotência, recomendações e retorno de competências após contratação.
- Ambos contêm BEGIN/ROLLBACK. Verificação posterior em `auth.users` para os seis UUIDs sintéticos `a100...001-003` e `b200...001-003`: **0 remanescentes**. Não usar isso para afirmar que nenhum outro dado sintético existe globalmente.
- Nenhuma migração, alteração persistente na base ou configuração de Auth/SMTP nesta etapa. Testes SQL são um indicador de segurança do banco, não substituem browser + HTTP/RLS com contas reais.
- Continuação prioritária: manter PR #89 aberto para revisão humana do diff completo; verificar checks do novo HEAD documental; após aprovação humana fazer merge e homologar em produção, incluindo e-mails e segurança entre perfis.

## Bloco seguinte — Storage privado, candidaturas únicas e teste móvel (12/10/2026)
- GitHub PR #89 ainda aberto e sem revisão humana. Estado conferido no HEAD `acffab2d`; CI 38312106776 e Security 38312106777 terminaram SUCCESS. Depois, foram acrescentados apenas testes e documentos na mesma branch, sem tocar na main.
- Supabase `kvxqhvngkjxqlvlzcsef` continua ACTIVE_HEALTHY; histórico reconsultado: 87 migrações, última `20261011213109` (`candidate_message_authorization`), sem novas migrações desta continuação.
- `supabase/tests/storage_private_rls.sql`: criado no commit `c4fdb54`, **PASS** em transação com rollback. Buckets `candidate-resumes` e `skill-evidence` privados e limitados a 10 MiB. Proprietário lê seus objetos, outro candidato e anônimo não leem, edição de documento alheio e sobrescrita de evidência imutável bloqueadas. Políticas de imutabilidade e exclusão referenciada confirmadas como RESTRICTIVE (a exclusão em si não foi simulada via HTTP).
- `supabase/tests/application_uniqueness.sql`: criado no commit `c193b2c`, **PASS**, demonstra índice único `(job_id,candidate_id)` e rejeição de segunda candidatura via `unique_violation`; não equivale a duas requisições HTTP concorrentes.
- Após ambos os testes: consulta de auditoria retornou **0 usuários fictícios**, **0 candidaturas fictícias** e **0 metadados fictícios de Storage** para os IDs de teste consultados. Nenhum arquivo binário foi carregado.
- `tests/e2e/mobile-360.spec.ts`: criado no commit `f7c3e44`, para verificar menus candidato/empresa e recuperação de senha expirada em 360px. Security 38314421741 SUCCESS; CI 38314421703 FALHOU exclusivamente no teste de recuperação expirada em suíte de desenvolvimento sem Supabase configurado (outros 28 testes passaram). Corrigido no commit `9e06d9a` (mantendo testes de menus 360px) e `8e5ca57` (teste de Auth movido para a suíte de preview sintético). CI `38314701915` e Security `38314701833` concluíram SUCCESS no código corrigido.
- Vercel projeto `prj_YEg1JW2yCyNl2dUUmNXslByfDw5B`: domínio oficial verificado; sem erros agregados de funções nas últimas 24h. A inspeção de chaves de ambiente **sem descriptografar** indicou apenas `VITE_SUPABASE_URL` em production/preview; código em `src/lib/supabaseTarget.ts` proíbe usar backend de produção numa prévia. Prévia não é homologação real de Auth/SMTP, nem deve ser conectada ao banco real sem isolamento/autorização.
- Advisor de segurança Supabase mantém aviso de proteção contra senhas vazadas desativada. Configuração Site URL/Redirect URLs/SMTP/política de senha do Auth continua não homologada; nenhuma credencial foi exposta ou alterada.
- Produção preservada no SHA `baa7cc4`. Não houve merge, alteração de ambiente, mudança de funções, exclusão de dados reais nem atuação em outros projetos.

## Bloco concluído — correção do teste E2E e homologação preparada
- O último código/testes aprovado nesta continuidade é `8e5ca57fa147ce9df5ed0a1fb23130ebeccf714f`: CI (build, e2e-smoke e preview público) `38314701915` SUCCESS; Security `38314701833` SUCCESS. A falha anterior de `38314421703` era uma incompatibilidade do teste com a suíte sem Supabase, não uma falha de autenticação comprovada em produção.
- Vercel preview do código `8e5ca57` READY (`dpl_GMtsudWNGSBNwDnKA1JVNuZ6cM7Q`), produção mantida em `baa7cc4`. Commits posteriores deste bloco alteram apenas documentação e seus checks devem ser conferidos.
- Criado `docs/AUTH_PRODUCTION_VALIDATION.md` (commit `2c90f44`), roteiro rigoroso de Site URL, Redirect URLs, SMTP, senha servidor, e-mails de confirmação/recuperação, perfis e Storage HTTP. Ainda NÃO executado com contas reais.
- Supabase Performance Advisor apresentou somente INFO sobre 64 índices sem uso; nenhum removido porque não existe medição de carga/consultas que justifique alteração.
- Mantida revisão humana obrigatória do PR #89. Nenhum merge, troca de senha real, envio de e-mail, publicação de função, mudança de ambiente Vercel ou migração. Outros projetos intocados.

## PRÓXIMA AÇÃO EXATA — atualizada
1. Conferir o HEAD atual do PR #89 e **obter revisão humana do diff**, especialmente as alterações de autenticação. **Não fazer merge sem aprovação.**
2. Após revisão, checar CI/Security do HEAD vigente, integrar e verificar SHA e deployment no domínio oficial.
3. Para homologação de produção, usar `docs/AUTH_PRODUCTION_VALIDATION.md` e confirmar Site URL/Redirect URLs, política do Auth de 8 caracteres, SMTP e e-mail real com contas técnicas autorizadas. Não alterar configurações às cegas.
4. Avançar nos testes reais de fronteira HTTP (Storage, perfis, candidaturas), currículo com persistência e UX/acessibilidade. Os testes SQL aprovados foram preservados; não reexecutar sem mudanças relacionadas.

## Bloco novo — busca de vagas, regras de inscrição e segurança SQL (12/10/2026)
- Estado no início: PR #89 aberto e sem nenhuma revisão humana, HEAD `0880a5d`, 19 commits à frente da main, sem divergência atrás. CI `38314972887` e Security `38314973279` SUCCESS; Vercel preview `dpl_FC7KkipAuke8ssNpv7QgUY8V7fQE` READY; produção `baa7cc4` em `dpl_7oG3P7aSUCXJEBCnFvHeyetQashm` READY.
- Correções de UI: `src/App.tsx` não exibe vagas fechadas para candidato; `src/lib/industrialCatalog.ts` adiciona `matchesBrazilianCityFilter` (nome municipal completo e UF quando presente) em vez de substring. `tests/jobCityFilter.test.mjs` e `tests/e2e/job-search.spec.ts` cobrem nomes ambíguos, dados legados sem UF, filtros combinados e vazios. CI `38315486240` e Security `38315486163` SUCCESS no commit funcional `c51642c`.
- Segurança do banco (inspeção read-only): 17 funções `SECURITY DEFINER` em `public`, nenhuma executável diretamente por `anon` ou `authenticated`; view `skill_market_summary` com `security_invoker=true`. Isso não substitui auditoria manual de todas as funções.
- **Falha de negócio reproduzida:** RLS `applications_insert` do Supabase `kvxqhvngkjxqlvlzcsef` permitiu INSERT direto em `applications` para vaga `fechada` (`closed_applications_accepted=1`), apesar do frontend. A transação de prova foi revertida.
- **Correção validada somente em transação:** `ALTER POLICY applications_insert` acrescentando teste `exists jobs where status='aberta'` para o próprio candidato, preservando `private.is_admin()`. Após alteração transitória, aplicação em vaga aberta aceita, fechada negada (PASS); `ROLLBACK` reverteu a política e fixtures.
- Migração em branch: `supabase/migrations/20261012221728_block_closed_job_applications.sql` (commit `bdf87fe`); regressão para ambiente já migrado: `supabase/tests/application_closed_job_rls.sql` (commit `99f5d4c`). **Nenhuma migração aplicada no projeto real.**
- Consultas posteriores: zero usuários e candidaturas sintéticas dos IDs usados; `production_guard_applied=false`. A vulnerabilidade permanece na produção até publicação autorizada. Não executar a regressão pós-migração no banco de produção antes da migração.
- Security no commit `99f5d4c` SUCCESS (run `38315887458`); CI de mesmo commit ainda estava em progresso na consulta. Commits de documentação posteriores exigem verificação do HEAD e checks antes de qualquer integração.
- Site URL, Redirect URLs, SMTP, política servidor de oito caracteres, e-mails e jornadas reais ainda não homologados. Não tocar Vercel/env nem serviços de outros projetos.

## PRÓXIMA AÇÃO EXATA — substitui instruções históricas acima
1. Reconsultar [PR #89](https://github.com/airbnbdeluxo-hash/talentos-industrial/pull/89): obter **revisão humana do diff completo**, especialmente Auth, currículo, busca de vagas e **migração RLS**. Não fazer merge nem aplicar a migração antes da revisão/coordenação de publicação.
2. Conferir novo HEAD, CI/Security e Preview READY. Após aprovação, alinhar execução da migração e publicação da main com plano de rollback; validar política `applications_insert` e rodar `supabase/tests/application_closed_job_rls.sql` (com rollback). Confirmar SHA final em produção e testar fluxo HTTP de vagas fechadas.
3. Seguir `docs/AUTH_PRODUCTION_VALIDATION.md` para SMTP, configuração de URL e política de senha do servidor; homologar e-mail e recuperação com contas técnicas próprias. Não inventar sucesso ou pedir credenciais no chat.
4. Homologar fronteiras HTTP Storage/candidaturas, importação PDF/DOCX com persistência, UX e acessibilidade. Não repetir regressões SQL já aprovadas salvo alteração relacionada. Não alterar outros projetos.
5. Manter estes documentos atualizados e gerar comando novo ao final de cada turno. Plataforma ainda não está 100% homologada.

## Bloco novo — bloquear auto-contratação e resultados forjados no banco (12/10/2026)
- Releitura completa de `WORK_HANDOFF.md`, `REQUIREMENTS_MATRIX.md`, `AUTH_PRODUCTION_VALIDATION.md`. Estado de entrada: PR #89 OPEN, sem nenhuma revisão humana, HEAD `52dd9e9af8d41971e23e265af1883071475669c1`; CI `38316005119` e Security `38316004959` SUCCESS. Prévia do HEAD `dpl_4KbuXmK8syouM5hjJjiMGx3JENXP` READY; produção continuou `baa7cc4` / `dpl_7oG3P7aSUCXJEBCnFvHeyetQashm` READY.
- **Falha adicional reproduzida no Supabase correto:** candidato autenticado inseriu aplicação para vaga aberta com `status='contratado'` diretamente via SQL; `accepted_forged_hired_application=1` dentro de `BEGIN/ROLLBACK`. O teste prévio já comprovou aplicação a vaga fechada. Estas falhas permanecem presentes na política real até publicação.
- **Correção na migração pendente, NÃO aplicada:** `supabase/migrations/20261012221728_block_closed_job_applications.sql` agora impõe para novo candidato: `job.status='aberta'`, `status='novo'`, `rejection_reason_code IS NULL`, `rejection_reason_note IS NULL`; mantém o ramo de autorização `private.is_admin()`.
- **Teste relacionado atualizado:** `supabase/tests/application_closed_job_rls.sql` valida no banco abertura legítima e recusa de vaga encerrada, auto-contratação e rejeição forjada. O teste foi executado junto ao texto integral da migração dentro de uma só transação; PASS; ROLLBACK. Nenhuma migração aplicada definitivamente.
- Consulta posterior confirmou zero usuários e zero candidaturas sintéticas com os UUIDs de prova, e que `applications_insert` real ainda possui somente a condição original de identidade (sem as novas condições).
- Commits técnicos: `d794b5b` (ampliar migração), `6d2a389` (teste), `1673d1d` (corrigir delimitador SQL), com Security `38317040405` SUCCESS; conferir a conclusão da CI `38317040429` e os checks do HEAD documental atual antes de integrar.
- Nenhum e-mail foi disparado, nenhum serviço contratado, nenhuma credencial exposta e nenhuma alteração feita em outros projetos. Revisão humana do PR #89 continua obrigatória antes do merge e da aplicação permanente da migração.

## PRÓXIMA AÇÃO EXATA — última versão
1. Conferir HEAD, CI/Security, Vercel Preview e revisões humanas do PR #89. A autorização humana para Auth, currículo e **migração de integridade RLS** não foi registrada nesta etapa. **Não fazer merge nem executar a migração permanente antes da revisão exigida.**
2. Após aprovação do PR e checks do SHA revisado, coordenar publicação do código e aplicação da migração pendente; consultar a política instalada e executar `supabase/tests/application_closed_job_rls.sql` com rollback. Homologar via HTTP que não se pode criar candidaturas com status contratado, motivo de rejeição ou vaga encerrada.
3. Independente do merge: conferir Auth URL/SMTP/política de senha real por painel do projeto correto, quando autorizado, e executar testes reais de e-mail e contas consentidas; não assumir que CI sintética ou configuração do frontend substituem isso.
4. Avançar com segurança dos arquivos via HTTP, currículos PDF/DOCX com persistência real, UX/contraste/acessibilidade e testes de regressão; preservar suítes já aprovadas.
5. Atualizar documentos e gerar comando de retomada com HEAD real ao terminar cada bloco. Não declarar plataforma 100% homologada.

## Bloco — guarda de formato de currículo e cobertura real pendente (12/10/2026)
- `src/lib/resumeParser.ts` recebeu checagem de extensão `.pdf`/`.docx`, arquivo vazio, limite 10 MB e assinatura inicial `%PDF-`/ZIP antes da leitura em PDF.js/Mammoth. Não equivale a scanner de malware, inspeção completa do ZIP ou homologação de armazenamento remoto.
- `tests/resumeParser.test.mjs` ganhou testes de arquivo vazio, executável renomeado e conteúdo incompatível com extensão; os PDFs/DOCX de teste anteriores continuam no E2E existente.
- Commits de código/teste: `eecc144a44739a21924bc511167f072a3303c33c` e `08693fc827dd796ac1c1426c400bac66061ade24`. Security `38317334473` SUCCESS e CI `38317334512` SUCCESS no código/teste `08693fc`; a execução de CI incluiu build e navegador. O HEAD documental posterior precisa ser verificado antes de merge.
- `docs/AUTH_PRODUCTION_VALIDATION.md` recebeu cenário HTTP explícito para impedir auto-contratação, rejeição forjada e inscrições em vagas fechadas após migração aprovada.
- A prova da política ampliada para bloquear status `contratado` e campos de rejeição já retornou PASS em transação revertida. Produção continua com a RLS original até revisão humana, merge e migração controlada.

## PRÓXIMA AÇÃO EXATA — atualização final deste bloco
1. Reconsultar revisão humana do PR #89 e checks do HEAD atual. SEM revisão, NÃO fazer merge nem aplicar `supabase/migrations/20261012221728_block_closed_job_applications.sql` em produção.
2. Se já houver revisão humana favorável, revalidar diff do HEAD exato, CI e segurança, coordenar migração, merge/deploy e teste RLS pós-migração. Confirmar SHA da produção e HTTP para vagas abertas/fechadas e status forjado.
3. CI `38317334512` e Security `38317334473` das novas verificações de arquivos já concluíram SUCCESS no SHA técnico `08693fc`. Conferir os checks do HEAD vigente, inclusive commits documentais posteriores, e corrigir qualquer regressão. Não confundir validação de assinatura com antivírus.
4. Prosseguir com configuração Auth/SMTP e entregabilidade (painel correto), prova real de senha mínima no servidor, contas e sessões, isolamentos HTTP, currículo com persistência e acessibilidade. Preservar regressões já aprovadas.
5. Regenerar comando de retomada no próximo turno com o HEAD real, reviews, deployments e pendências; não declarar 100%.

## COMANDO PRONTO PARA CONTINUAR EM OUTRO CHAT WORK

Continue o desenvolvimento e a homologação do TalentOS Industrial exatamente deste ponto. NOVO: `src/lib/resumeParser.ts` valida assinatura inicial de PDF/DOCX e arquivo vazio; os testes adicionados em `tests/resumeParser.test.mjs` passaram na CI `38317334512` e Security `38317334473` no commit `08693fc`. Consultar `docs/AUTH_PRODUCTION_VALIDATION.md` com cenário HTTP de candidatura forjada. PRIORIDADE: a migração `20261012221728_block_closed_job_applications.sql` foi AMPLIADA para bloquear auto-contratação (`status='contratado'`) e rejeição forjada, além de inscrições em vagas fechadas. O teste `application_closed_job_rls.sql` foi atualizado e PASSOU com alteração temporária de política na mesma transação e ROLLBACK. A migração ainda NÃO foi aplicada e exige revisão humana do PR #89. Repositório: airbnbdeluxo-hash/talentos-industrial. Produção: https://talentos-industrial.vercel.app. Supabase: kvxqhvngkjxqlvlzcsef. PRIMEIRO: leia integralmente docs/WORK_HANDOFF.md e docs/REQUIREMENTS_MATRIX.md na branch work/conclusao-20261012 (PR #89; se integrado, leia na main). Confira `tests/jobCityFilter.test.mjs` e `tests/e2e/job-search.spec.ts` (CI 38315486240 e Security 38315486163 SUCCESS no commit c51642c), a nova migração `supabase/migrations/20261012221728_block_closed_job_applications.sql` e o teste pós-migração `supabase/tests/application_closed_job_rls.sql` (NÃO aplicado ao projeto real). Preserve os testes antigos de Storage, unicidade, auth e currículo. Consulte `docs/AUTH_PRODUCTION_VALIDATION.md`. Confirme HEAD atual do PR, novas verificações, revisão humana, migrações e deploy. Não reproduza a falha de CI antiga 38314421703 sem considerar sua correção. Não reinicie o projeto nem repita trabalho comprovado. Siga PRÓXIMA AÇÃO EXATA, respeitando revisão humana de autenticação. Considere que evidence_skill_loop.sql e outcome_skill_feedback_loop.sql já retornaram PASS com rollback e zero usuários sintéticos nos seis IDs consultados; não repetir sem mudanças relacionadas. Execute autonomamente o restante autorizado, sem alterar outros projetos ou contratar serviços. Atualize este documento a cada bloco e gere novo comando antes de encerrar. A plataforma ainda não está integralmente homologada.
