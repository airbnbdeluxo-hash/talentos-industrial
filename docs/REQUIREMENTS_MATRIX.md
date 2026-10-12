# Matriz de requisitos — 12/10/2026

Base inspecionada: baa7cc4; correção proposta: 39511e1. Esta matriz distingue código existente, testes sintéticos e homologação real. Ausência de falha em scanner não prova ausência de vulnerabilidade.

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
| P1 | Currículo manual/PDF/Word | Implementado, pendente de homologação | 4 testes do parser passam; falta arquivos reais variados e persistência ponta a ponta |
| P1 | Cancelar leitura sem salvar | Implementado, pendente de homologação | resumeImportGeneration invalida conclusão tardia; falta teste com leitura atrasada no navegador |
| P1 | Skills editáveis sem inventar qualificações | Parcialmente implementado | Testes de menções e limites de palavra passam; falta revisão de extração de experiência/formação |
| P1 | Filtros cargo/skill/cidade/empresa/salário/turno/modalidade | Implementado, pendente de homologação | UI e catálogos presentes; validar combinações e resultado vazio |
| P1 | Duplicação de candidatura | Implementado, pendente de homologação | Falta teste explícito de duas submissões concorrentes |
| P1 | Mensagens/entrevistas/propostas/notificações | Concluído e comprovado no banco para cenário exercitado | Jornada transacional passou; e-mail/entrega externa e interface real ainda pendentes |
| P1 | Avaliações e competências comprovadas | Implementado, pendente de homologação | Testes SQL de evidências existentes; ainda não executados neste bloco |
| P1 | Compilação e testes unitários | Concluído e comprovado | 25 testes locais passam; tsc/build passam; CI build/security passam em 39511e1 |
| P1 | Dependências | Parcialmente implementado | npm audit: 3 avisos moderados na mesma cadeia mammoth→argparse→sprintf-js, sem high/critical; avaliar atualização segura |
| P1 | Navegador e acessibilidade | Parcialmente implementado | CI e2e-smoke e public flows aprovados em 39511e1, incluindo dois novos casos de links expirados. Suíte desativa contraste: não afirmar acessibilidade integral |
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
- Produção continua em baa7cc4. Preview da correção: dpl_F3g8VaWP7ZwmmJ7wT3tj7JRsNBCc, READY, commit 39511e1.
- Revisão de autenticação: https://github.com/airbnbdeluxo-hash/talentos-industrial/pull/89.
