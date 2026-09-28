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
