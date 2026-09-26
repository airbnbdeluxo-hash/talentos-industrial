# Deploy com free tiers

1. GitHub: fonte oficial do código.
2. Supabase: crie um projeto gratuito e execute `supabase/schema.sql`.
3. Configure as variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`.
4. Rode `npm run build`.
5. Publique o build no Cloudflare Pages.
6. Nunca coloque a service role key no frontend.

O uso dos free tiers deve ser acompanhado conforme a base de usuários crescer.
