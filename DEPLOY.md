# Implantação do TalentOS Industrial

## Produção
O projeto público do TalentOS está em `https://talentos-industrial.vercel.app`.
A implantação de produção, identificada pelo ambiente Vercel `VERCEL_ENV=production`, conserva a conexão pública e a chave **publishable** do Supabase TalentOS já usado pelo site. A chave `service_role`/secret **nunca** pertence ao frontend.

## Previews de pull requests — não acessar dados reais
Os previews criados pela Vercel não devem usar o banco de dados de produção. O frontend distingue o alvo pelo `VERCEL_ENV` no momento do build e pelo `VITE_VERCEL_ENV` quando fornecido. Se a configuração não existir, somente os domínios canônicos de produção conhecidos têm fallback.

- **Sem Supabase de testes:** não configure `VITE_SUPABASE_URL` nem `VITE_SUPABASE_PUBLISHABLE_KEY` para o ambiente Preview. A interface pública e os testes simulados continuam utilizáveis, mas funções remotas de cadastro/login ficam indisponíveis.
- **Com Supabase de testes isolado:** configure ambas as variáveis **apenas no Preview**, apontando para outro projeto Supabase que não contenha dados reais. Aponte o URL para o banco de testes, nunca para `kvxqhvngkjxqlvlzcsef.supabase.co`.
- Se uma variável Preview for acidentalmente configurada para o endpoint de produção, a aplicação **recusará** a conexão em vez de fazer requisições ao banco real.
- Credenciais da produção não podem ser copiadas para os ambientes Preview e Development. Em desenvolvimento local, qualquer conexão exige configuração explícita.

A publicação da `main` na Vercel mantém sua configuração anterior. Não modifique o projeto Supabase de outros produtos nem reutilize os tokens de outro aplicativo.

## Segurança e revisão
O GitHub Actions executa, em cada PR e push na `main`, o build, testes de navegação, scanner de credenciais, testes de isolamento do Supabase e auditoria de dependências. Revise o diff dos PRs de segurança **antes** do merge. Nenhum teste de desenvolvimento deve criar, atualizar ou excluir linhas no banco de produção.

Para validar um deploy: confira o commit `main`, status READY na Vercel, jobs CI/Security aprovados e, em teste autenticado real, as permissões separadas de candidato e empresa. Os testes simulados E2E não equivalem a um teste autenticado completo no banco real.

## Onboarding do piloto
1. Criar uma conta real de empresa no ambiente de produção.
2. Cadastrar a empresa, convidar a equipe e publicar vagas.
3. Criar uma conta de candidato distinta, importar o currículo, revisar competências e candidatar-se.
4. Verificar que candidatos não enxergam outros perfis e que recrutadores só acessam registros autorizados.
5. Validar e-mails de confirmação, recuperação de senha e contratação end-to-end com participantes autorizados.

## Histórico
Ver o arquivo `ROADMAP.md` para entregas implantadas e pendências.
