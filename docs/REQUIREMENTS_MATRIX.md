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
| P0 | Arquivos privados | Parcialmente implementado | candidate-resumes e skill-evidence privados, limite 10 MiB; falta testar download negado entre usuários |
| P0 | Chaves no frontend | Concluído e comprovado no escopo do scanner | security:scan passou; não equivale a auditoria completa do histórico |
| P1 | Cadastro empresarial/CNPJ/cidade/limites | Implementado, pendente de homologação | Correções recentes na main e função company-team v8; falta exercitar endpoint de criação com conta técnica |
| P1 | Gestão de equipe | Parcialmente implementado | company_team_management.sql passou; transferência/remoção passaram em transação; convite real por e-mail pendente |
| P1 | Vaga até contratação | Parcialmente implementado | recruiting_journey.sql PASS: vaga, candidatura, entrevista, oferta aceita e histórico; falta navegador com backend real |
| P1 | Currículo manual/PDF/Word | Implementado, pendente de homologação | CI de c8f485b aprovou parser e Playwright com fixtures PDF/DOCX reais de teste, revisão de campo e descarte sem confirmação em modo E2E; persistência ponta a ponta real e diversidade documental não homologadas |
| P1 | Cancelar leitura sem salvar | Implementado, pendente de homologação | c8f485b: AbortController mais geração invalidada; teste Playwright de leitura atrasada e cancelamento aprovado em modo E2E, falta ambiente remoto/conta real |
| P1 | Skills editáveis sem inventar qualificações | Parcialmente implementado | c8f485b: remove inferência de cargo a partir da primeira linha, bloqueia menções negadas/aspiracionais e preserva frases positivas; testes automatizados aprovados, falta avaliação ampla com currículos reais consentidos |
| P1 | Filtros cargo/skill/cidade/empresa/salário/turno/modalidade | Implementado, pendente de homologação | UI e catálogos presentes; validar combinações e resultado vazio |
| P1 | Duplicação de candidatura | Implementado, pendente de homologação | Falta teste explícito de duas submissões concorrentes |
| P1 | Mensagens/entrevistas/propostas/notificações | Concluído e comprovado no banco para cenário exercitado | Jornada transacional passou; e-mail/entrega externa e interface real ainda pendentes |
| P1 | Avaliações e competências comprovadas | Implementado, pendente de homologação | Testes SQL de evidências existentes; ainda não executados neste bloco |
| P1 | Compilação e testes unitários | Concluído e comprovado no último código funcional inspecionado | CI build/e2e-smoke 38302827078 e Security 38302827143 passaram no c8f485b, inclusive extração de currículo; revalidar os commits documentais posteriores |
| P1 | Dependências | Parcialmente implementado | npm audit: 3 avisos moderados na mesma cadeia mammoth→argparse→sprintf-js, sem high/critical; avaliar atualização segura |
| P1 | Navegador e acessibilidade | Parcialmente implementado | CI e2e-smoke e fluxos públicos aprovados em c8f485b; inclui importação de currículo simulada e links expirados. Navegador de CI usa ambiente isolado; suíte desativa contraste e não comprova acessibilidade integral nem produção com backend real |
| P2 | Assistente conversacional de carreira | Não implementado na base inspecionada | Não encontrada integração generativa; definir provedor gratuito, consentimento e limites |
| P2 | Análise aprimorada de currículo | Parcialmente implementado | Extração determinística existente; não chamar de IA generativa |
| P2 | Recomendações explicáveis de vagas | Implementado, pendente de homologação | Matching com razões e lacunas existente; validar qualidade e explicação com dados autorizados |
| P2 | Simulador de entrevistas | Não implementado na base inspecionada | Não localizado fluxo de simulação para candidato |
| P2 | Plano personalizado de desenvolvimento | Implementado, pendente de homologação | training_recommendations e RPCs existentes; faltam testes específicos neste bloco |
| P2 | Mapa visual de progressão | Parcialmente implementado | SkillGraph existente não comprova mapa pessoal de progressão |
| P2 | Pesquisa em linguagem natural | Não implementado na base inspecionada | Filtros existentes não equivalem a pesquisa semântica |
| P2 | Orientação de candidaturas | Parcialmente implementado | Informações de compatibilidade presentes; assistente individual ainda pendente |
| P2 | Alertas de oportunidades | Implementado, pendente de homologação | job_alerts e notificações funcionam no cenário SQL; entrega e relevância pendentes |
| P2 | Portfólio de competências | Implementado, pendente de homologação | Evidências e validação humana existentes; testar cadeia completa e acesso aos documentos |
| P2 | Padrão visual desktop/mobile/admin | Parcialmente implementado | workspace.css e central de carreira existentes; falta revisão visual de todas as páginas |
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
