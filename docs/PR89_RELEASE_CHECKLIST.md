# Liberação controlada do PR #89 — TalentOS Industrial

**Estado:** aguardando revisão humana, sem merge e sem migração aplicada. Roteiro operacional; não constitui aprovação.
**Escopo imutável:** repositório `airbnbdeluxo-hash/talentos-industrial`, Vercel `prj_YEg1JW2yCyNl2dUUmNXslByfDw5B`, Supabase `kvxqhvngkjxqlvlzcsef`. Domínio oficial: `https://talentos-industrial.vercel.app`.
**Base comprovada no início deste roteiro:** `baa7cc4f1d3f3acf87526b72eaadc66c2c77288d` em produção. Confirmar novamente antes de qualquer ação.

## Regra objetiva de aceite e bloqueio

Este roteiro deve ser executado em conjunto com [`docs/ACCEPTANCE_CRITERIA.md`](ACCEPTANCE_CRITERIA.md). A decisão de liberar não depende de impressões: **pré-deploy exige G01/G02 e plano de rollout/reversão aprovado**, enquanto **a liberação comercial pós-deploy exige G01–G18 APROVADOS com evidência por SHA e assinatura humana**. Falha, evidência ausente ou estado BLOQUEADO em qualquer G01–G18 = **NÃO HOMOLOGAR A PRODUÇÃO**. CI verde e Vercel Preview READY **não** significam homologação da produção.

A declaração **“100% do escopo concluído”** exige adicionalmente **C01–C04** e 100% dos requisitos aprovados da matriz homologados. Nenhum item pode ser descartado sem decisão humana explícita. Consulte o quadro de status e o formato de evidências antes de iniciar a aprovação.

## Portão 1 — revisão humana (obrigatório; não automatizar aprovação)
- Abrir https://github.com/airbnbdeluxo-hash/talentos-industrial/pull/89 e analisar o **diff completo do HEAD exato**, não apenas a descrição do PR.
- Priorizar `src/lib/authLink.ts`, `src/App.tsx`, `src/lib/resumeParser.ts`, `src/lib/industrialCatalog.ts` e `supabase/migrations/20261012221728_block_closed_job_applications.sql`.
- Conferir a correção de recuperação expirada, URLs de retorno, limpeza de tokens somente em erro e retorno de foco, além do parser PDF/DOCX.
- Conferir autorização e compatibilidade de `applications_insert` com o fluxo real: somente `candidate_id=auth.uid()`, vaga aberta, status `novo`, dados de rejeição nulos; preservar `private.is_admin()`. Atenção a empresas autorizadas e à transição posterior de status por `UPDATE`.
- Registrar revisão humana no próprio PR. **Sem essa aprovação: não executar merge, migração, promoção ou deploy em produção.**

## Portão 2 — testes e prévia após a revisão
- Conferir que o HEAD aprovado é o mesmo HEAD do PR no momento da publicação. Se mudar, revisar o novo diff e checks novamente.
- Exigir **CI**, **Security** e **Vercel Preview READY** correspondentes ao mesmo SHA. Não inferir que checks de commit anterior garantem o HEAD atual.
- Revisar `tests/authLink.test.mjs`, `tests/resumeParser.test.mjs`, `tests/e2e-production/public.spec.ts`, `tests/e2e/job-search.spec.ts` e `supabase/tests/application_closed_job_rls.sql`.
- Não misturar a prévia Vercel com o banco Supabase de produção. Scripts SQL aprovados anteriormente com rollback permanecem como evidência histórica.

## Portão 3 — publicação controlada e integridade do banco
- Fazer conferência prévia (somente leitura) do projeto Supabase e da versão instalada da política `public.applications / applications_insert`. A produção comprovadamente ainda usa a regra antiga que permite status forjado e candidaturas a vaga fechada.
- Depois da aprovação humana, coordenar a aplicação da migração versionada `20261012221728_block_closed_job_applications.sql` com a integração do código. Usar o processo normal de migrations do projeto; não executar scripts destrutivos ou recriar projeto/banco.
- Fazer uma verificação pós-migração da expressão `WITH CHECK`: `status='novo'`, `rejection_reason_code IS NULL`, `rejection_reason_note IS NULL`, `jobs.status='aberta'`, autorização do candidato e exceção admin. Caso a migração falhe, **interromper a publicação e diagnosticar**, sem relaxar RLS automaticamente.
- Executar `supabase/tests/application_closed_job_rls.sql` **apenas após a migração**, com `BEGIN/ROLLBACK`, e provar que não restaram fixtures específicas.
- O teste deve validar **6/6 cenários**: candidatura inicial `novo` em vaga aberta aceita, e cinco tentativas negadas (vaga fechada, status `contratado`, status `triagem`, motivo de rejeição e nota de rejeição forjados). Complementar com os mesmos seis cenários via HTTP usando contas de homologação próprias; teste SQL com rollback não equivale a HTTP.
- Publicar a versão revisada do `main` somente com checks válidos. Conferir o SHA do deployment de produção associado a `talentos-industrial.vercel.app` e acessibilidade das rotas.
- Preparar plano de reversão do frontend. **Não restaurar a política vulnerável como rollback automático**: qualquer reversão de segurança exige nova análise humana.

## Portão 4 — homologação com contas reais e sem segredos
- Seguir `docs/AUTH_PRODUCTION_VALIDATION.md`: confirmar Site URL, allowlist, senha mínima de oito caracteres **no servidor**, SMTP, SPF/DKIM/DMARC e confirmação/reenvio/recuperação por e-mail com contas técnicas consentidas.
- Testar isolamento HTTP de `candidate-resumes` e `skill-evidence`, acesso próprio e negado ao terceiro, sem colocar tokens ou dados pessoais em logs/issues.
- Testar a importação PDF/DOCX com revisão/cancelamento e **persistência após confirmação**; verificar que o cancelamento não grava dados.
- Homologar candidato, empresa, recrutador e visualizador; candidatura, entrevista, proposta, recuperação, expiração da sessão e logout.
- Validar teclado, leitura assistiva, contraste real, larguras 360px/390px e desktop.
- Ao final registrar ambiente, timestamp, SHA, caso e PASS/FAIL sem dados sensíveis; limpar apenas recursos sintéticos de teste sob autorização.

## Bloqueios e escopo não resolvidos automaticamente
- A revisão humana está pendente. SMTP e ajustes de Auth no painel não são acessíveis/confirmados através dos conectores atuais.
- Advisor do Supabase apontou `auth_leaked_password_protection` desabilitado; analisar o risco e limitações do plano, sem comprar serviços automaticamente.
- A aprovação da CI, do scanner e da política SQL em rollback **não permite declarar a plataforma 100% homologada**.
- Preservar produção e não alterar nenhum outro repositório, Vercel project, Supabase project, conta ou fornecedor.
