# TalentOS Industrial

MVP de inteligência e operação de talentos para a indústria.

## O que já funciona
- Dashboard operacional
- Criação de vagas
- Cadastro de talentos
- Cadastro de empresas
- Busca
- Matching explicável por skills, evidência, localização, experiência e faixa salarial
- Pipeline de contratação com mudança de etapa
- SkillGraph visual
- Persistência local no navegador
- Schema Supabase preparado

## Rodar
```bash
npm install
npm run dev
```

## Produção
A V1 foi desenhada para começar sem serviço pago. O modo local funciona imediatamente. Para multiusuário, execute `supabase/schema.sql`, configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` e substitua a camada local pelo repositório Supabase.

## Princípios
1. Não é um portal genérico de empregos.
2. O ativo central é a representação de competências e evidências.
3. O matching deve ser explicável e auditável.
4. Não colocar secrets no frontend.
