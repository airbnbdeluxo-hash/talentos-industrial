# Deploy TalentOS Industrial

## Supabase
Projeto provisionado: `talentos-industrial`.

URL:
`https://kvxqhvngkjxqlvlzcsef.supabase.co`

O banco já possui schema, índices, Auth trigger e RLS.

## Frontend
Configure no ambiente de deploy:

```
VITE_SUPABASE_URL=https://kvxqhvngkjxqlvlzcsef.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Nunca publique uma service-role key.

## GitHub
O workflow `.github/workflows/ci.yml` executa:

```
npm install --no-audit --no-fund
npm run build
```

## Lovable
Importe/conecte o repositório GitHub `airbnbdeluxo-hash/talentos-industrial`. Use as variáveis acima no ambiente do projeto.

## Segurança
RLS está habilitado nas tabelas principais. O próximo passo operacional é criar o primeiro usuário empresa, criar uma empresa e testar o fluxo vaga -> candidato -> candidatura.
