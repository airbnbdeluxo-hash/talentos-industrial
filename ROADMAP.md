# Roadmap TalentOS

## Norte do produto
TalentOS não é um ATS genérico. É uma camada de **Capability Intelligence** para a indústria: descobrir capacidade, provar competência, medir prontidão, fechar gaps e observar oferta/demanda.

## Entregue
- [x] Dashboard operacional
- [x] Vagas
- [x] Talentos
- [x] Empresas
- [x] SkillGraph
- [x] Skill Passport
- [x] Evidence Chain
- [x] Readiness por vaga
- [x] Gap-to-Training
- [x] Market Graph inicial
- [x] Decision Timeline
- [x] Auth Supabase
- [x] CRUD remoto de empresas e vagas
- [x] CRUD remoto do Skill Passport
- [x] Aplicação a vaga
- [x] Pipeline remoto
- [x] RLS e isolamento multiempresa
- [x] Provisionamento confiável de papéis
- [x] GitHub Actions para build
- [x] Matching persistido no backend com score explicável e gaps
- [x] Upload privado de evidências via Supabase Storage
- [x] Onboarding inicial por tipo de conta
- [x] Preferências de turno persistidas no Skill Passport
- [x] Métrica inicial de time-to-qualified-candidate
- [x] Funil operacional no dashboard
- [x] Consentimento explícito de visibilidade do candidato
- [x] Validação humana de evidências com autoria e trilha de revisão
- [x] Proteção do papel da conta após criação
- [x] Plano de desenvolvimento persistido por candidato/vaga
- [x] Progresso de desenvolvimento: recomendado → em andamento → concluído
- [x] Inteligência de desenvolvimento por gaps, competências e horas estimadas
- [x] Outcome por competência agregado no backend e consumido pela aba de Inteligência

## Próxima entrega
- [ ] Seed operacional / onboarding da primeira empresa real
- [x] Upload real de evidências via Storage
- [x] Avaliações técnicas persistidas e biblioteca de desafios
- [x] Desafios com respostas persistidas e validação humana antes de evidência verificada
- [x] Gerar e persistir matches no backend por vaga
- [x] Dashboard de time-to-qualified-candidate
- [x] Gap-to-Training operacional com persistência de status, níveis e estimativa de carga
- [ ] Consentimento com tela dedicada
- [x] Analytics do funil
- [x] Testes automatizados de RLS

## Moat
- [x] Taxonomia industrial própria — v1 persistida no Supabase
- [x] Grafo skill -> evidência -> contexto -> readiness — base de capability graph criada
- [x] Estratégia Hire vs Build baseada em readiness e gaps
- [ ] Dados de oferta/demanda por região
- [x] Trilhas de treinamento operacionais baseadas em gaps reais
- [x] Base de histórico pós-contratação — Outcome Loop 30/60/90d
- [x] Loop pós-contratação 30/60/90d
- [x] Sinais pós-contratação por competência ligados ao Capability Graph
- [ ] Histórico de resultados por skill e função
- [ ] Benchmark de contratação
- [ ] Mobilidade interna e adjacências de carreira

## Expansão
- [ ] Serra Gaúcha piloto
- [ ] RS
- [ ] Sul do Brasil
- [ ] Multi-região
