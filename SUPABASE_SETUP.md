# Supabase setup

## 1. Criar projeto
Crie um projeto Supabase gratuito.

## 2. Aplicar banco
No SQL Editor, execute:
1. `supabase/schema.sql`
2. `supabase/migrations/002_security_multitenant.sql`
3. `supabase/migrations/003_production_hardening.sql`

## 3. Auth
Ative e-mail/senha no Supabase Auth.

O app já usa `@supabase/supabase-js` e mantém sessão no navegador. A inicialização segue a API oficial do Supabase.

## 4. Variáveis
Copie `.env.example` para `.env.local`:

```
VITE_SUPABASE_URL=...
VITE_SUPABASE_PUBLISHABLE_KEY=...
```

Nunca use a `service_role` key no navegador.

## 5. Evolução da V1
A aplicação já tem fallback local. A próxima implementação deve trocar a camada de leitura/escrita por queries Supabase, mantendo a UX atual.

## Segurança
O banco usa RLS e políticas separadas por operação. O próximo passo de produção é validar as políticas com testes de RLS antes de liberar dados reais.
