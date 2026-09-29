# TalentOS Industrial

**Capability Intelligence para a indústria.**

TalentOS transforma currículo, experiência, avaliações e evidências em uma representação estruturada da capacidade profissional.

## O produto
- **Skill Passport:** identidade profissional baseada em competências.
- **Evidence Chain:** cada skill pode apontar para certificado, experiência, avaliação ou desafio.
- **Readiness:** prontidão contextual para uma vaga específica.
- **Gap-to-Training:** identifica o que falta e transforma lacuna em próxima ação.
- **Market Graph:** observa oferta e demanda por competência.
- **Matching explicável:** mostra cobertura, evidências, turno, localização e faixa salarial.
- **Pipeline:** acompanha a jornada até contratação.

## Diferencial
Não somos apenas um banco de currículos nem um ATS genérico. O objetivo é construir uma camada de inteligência de capacidade para a indústria.

## Stack
React + Vite + TypeScript · Supabase · GitHub · Cloudflare Pages · Lovable.

## Segurança
Supabase Auth + RLS + isolamento multiempresa. Não coloque service-role keys no frontend.

## Desenvolvimento
```bash
npm install --no-audit --no-fund
npm run dev
npm run build
```

## V5 diferenciadores

O produto inclui Skill Passport, Evidence Chain, Readiness contextual, Gap-to-Training, Market Graph e Decision Timeline. Estes recursos são a base de diferenciação; desempenho superior à concorrência precisa ser demonstrado por métricas de clientes, não presumido.


## Motor de matching

O matching de vagas agora é persistido no Supabase: score contextual, razões explicáveis e gaps por candidato/vaga. O painel consulta esses resultados no backend quando está conectado ao projeto real.


## Operação e governança

O onboarding orienta a conta ao primeiro passo, o Skill Passport coleta preferências de turno e o profissional controla explicitamente a visibilidade do perfil. O dashboard mede o funil e o tempo entre criação da vaga e o primeiro candidato com readiness >=80.

## Desafios técnicos

O TalentOS mantém uma biblioteca de desafios por competência. A tentativa e as respostas são persistidas no backend; concluir um desafio não marca automaticamente a skill como verificada. A evidência permanece pendente até validação humana.

## Gap-to-Training operacional

Ao se candidatar a uma vaga, o TalentOS pode gerar um plano persistido por candidato/vaga. Cada gap registra skill, nível atual quando disponível, nível-alvo, prioridade, estimativa de horas e estado de desenvolvimento. O profissional pode iniciar e concluir cada ação; o plano é recalculável quando o conjunto de gaps muda.

A aba de Inteligência consolida os gaps visíveis para a conta, mostrando volume ativo, desenvolvimento em andamento, conclusões e horas estimadas por competência.

## Fila de validação humana

Empresas podem revisar evidências de candidatos que estejam em seu pipeline. Cada decisão registra status, responsável, horário e observação. Uma evidência aprovada atualiza a competência correspondente; uma rejeitada não pode ser usada como prova verificada.


## Analytics do funil

O dashboard consolida conversões descritivas entre etapas e o tempo médio observado entre mudanças de status registradas em `application_events`. As métricas são históricas e não são usadas como previsão de contratação.


## Industrial Capability Graph

O SkillGraph agora possui uma camada persistida no Supabase com nós de família, processo, máquina, controle, competência, cargo e contexto, além de relações ponderadas entre eles. A intenção é que a taxonomia evolua com evidências e resultados reais e se torne o mapa proprietário de capacidade industrial do TalentOS.

A versão inicial é deliberadamente curada: o banco contém o vocabulário e as relações-base; clientes não escrevem diretamente na taxonomia. Alterações estruturais entram por migração e podem ser governadas como ativo de produto.


## Outcome Loop

Após uma candidatura chegar a **contratado**, a empresa pode registrar checkpoints de 30, 60 e 90 dias ou uma saída. O registro inclui performance, ramp-up, situação de retenção e observação interna. Cada checkpoint fica vinculado à candidatura, vaga, empresa e profissional, criando a base para aprender com resultados reais de contratação sem misturar dados internos com o perfil público do candidato.


## Estratégia de capacidade

O dashboard separa, para a vaga selecionada, profissionais com readiness alto, profissionais próximos de prontidão e casos com gaps maiores. A leitura é uma heurística operacional baseada nos dados atuais do TalentOS; não é uma previsão de performance ou uma decisão automática de contratação.


## Outcome Skill Signals

Cada checkpoint pós-contratação pode registrar sinais estruturados por competência da vaga: se a skill foi utilizada, se necessita desenvolvimento, se não foi observada ou se não era aplicável. O gestor pode registrar uma avaliação de 1 a 5 e indicar necessidade de treinamento. Esses sinais ficam ligados à competência correspondente no Industrial Capability Graph, criando uma ponte entre contratação, utilização real da capacidade e desenvolvimento.

A aba de Inteligência consome uma agregação protegida no backend (`get_company_outcome_skill_intelligence`) para consolidar esses sinais por competência, mantendo o detalhe operacional separado da camada analítica.


## Provisionamento de papéis

O cadastro público não define privilégios de empresa ou administração. Novas contas entram como profissionais por padrão; papéis elevados são atribuídos por metadado administrativo confiável e permanecem protegidos pelo backend.


## Acesso, recuperação e consentimento

O acesso usa Supabase Auth com sessão persistente. O fluxo inclui login, criação de conta profissional, recuperação de senha por e-mail e atualização de senha. A recuperação redireciona para a origem configurada da aplicação; essa origem precisa estar cadastrada nas Redirect URLs do projeto Supabase. A experiência B2C possui onboarding do Skill Passport e uma tela dedicada para o profissional decidir se permite que empresas encontrem seu perfil. A visibilidade não transforma arquivos de evidência em conteúdo público: os documentos permanecem em Storage privado e sujeitos às políticas de acesso.

## Operação B2B

Contas empresariais entram por provisionamento confiável. No primeiro acesso, o onboarding orienta a empresa em três passos: cadastrar a empresa, estruturar a primeira vaga e gerar o matching. Ao criar a vaga, o recrutador informa cargo, atividades/contexto, cidade, faixa salarial, turno e competências. O profissional visualiza a vaga, usa seu Skill Passport como base da candidatura e, com o consentimento de visibilidade ativo, pode se candidatar diretamente. A candidatura pode gerar um plano de desenvolvimento para gaps identificados.


## Deploy do piloto

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fairbnbdeluxo-hash%2Ftalentos-industrial&project-name=talentos-industrial)

O fluxo de produção do piloto usa Vercel + Supabase.

<!-- Vercel production sync -->
