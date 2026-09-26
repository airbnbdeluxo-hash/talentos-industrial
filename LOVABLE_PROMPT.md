# Prompt para Lovable

Continue o projeto TalentOS Industrial usando o repositório como fonte de verdade.

Objetivo: construir uma plataforma B2B de inteligência de talentos para indústria.

Não transforme em um portal genérico de empregos.

Entidades principais:
- profiles
- companies
- skills
- candidate_profiles
- candidate_skills
- jobs
- job_skills
- matches
- applications

Fluxo prioritário:
empresa cria vaga -> sistema estrutura skills -> encontra candidatos -> mostra score explicável -> mostra lacunas -> candidato entra no pipeline.

Regras:
1. Preservar o modelo visual existente.
2. Não introduzir dependências pagas sem necessidade.
3. Usar Supabase para dados reais.
4. Nunca expor service role key no frontend.
5. Usar RLS.
6. Matching deve continuar explicável.
7. Mobile-first nos formulários.
