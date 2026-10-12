# Homologação real da autenticação — TalentOS Industrial

**Estado:** roteiro preparado, **NÃO EXECUTADO com contas reais**. Nenhum item abaixo deve ser marcado como aprovado a partir de testes sintéticos.
**Escopo exclusivo:** Supabase `kvxqhvngkjxqlvlzcsef`, GitHub `airbnbdeluxo-hash/talentos-industrial` e `https://talentos-industrial.vercel.app`.

## Condições antes de começar
- Aprovação humana do PR #89 e deploy do commit exato na produção, se os testes incluírem as correções pendentes desse PR. Não fazer merge automaticamente.
- Usar apenas contas de teste próprias/consentidas, diferentes para candidato e empresa; não compartilhar senhas, tokens, links com parâmetros sensíveis nem credenciais SMTP em issues, logs ou capturas.
- Confirmar configurações diretamente no painel autorizado do projeto **indicado**. Ferramentas de SQL e inspeção do frontend não expõem essas configurações do Auth de forma confiável.
- Não apontar o preview Vercel para o banco de produção; o código em `src/lib/supabaseTarget.ts` evita essa mistura.

## Conferência de configuração do Supabase Auth
1. Em **Authentication → URL Configuration**, conferir `Site URL` como `https://talentos-industrial.vercel.app` e permitir somente URLs de retorno necessárias e confiáveis. Verificar os retornos reais produzidos por `authRedirectUrl('confirm')` e `authRedirectUrl('recovery')` no código; considerar hash/query completos e evitar curingas excessivos.
2. Em **Authentication → Providers → Email** (a localização exata pode mudar), verificar se confirmação de e-mail está ligada e se o método e-mail/senha está habilitado. Não desabilitar confirmação apenas para contornar problema de entrega.
3. Conferir política **servidor** de senha mínima de 8 caracteres, compatível com a UI (maiúscula, minúscula, número e símbolo). Não presumir que regras de complexidade da interface sejam impostas pelo Auth.
4. Em configuração **SMTP**, verificar host, porta, remetente e credenciais **sem copiá-las para o repositório ou chat**. Testar saída, reputação do domínio, registros SPF/DKIM/DMARC aplicáveis, erros de provedor e limites de taxa. Se o provedor ainda não existe, registrar impedimento; não contratar serviços.
5. Consultar Advisor de Segurança; `auth_leaked_password_protection` foi encontrado desabilitado no plano atual. Documentar o risco e avaliar recurso de plano somente mediante decisão humana; não contratar ou simular ativação.

## Matriz de aceitação com contas técnicas
| Cenário | Ação real | Critério de aprovação |
|---|---|---|
| Cadastro candidato | Criar conta técnica de candidato | Mensagem correta, e-mail entregue, link recebido e confirmação concluída |
| Cadastro empresa | Criar conta técnica separada | Confirmação entregue, retorno correto e configuração empresarial acessível apenas à empresa |
| Conta já existente | Tentar cadastro repetido sob política de privacidade | Resposta consistente, não criar identidade duplicada e não vazar informações indevidas |
| Reenvio de confirmação | Solicitar novo envio após link expirado | Nova mensagem entregue, novo link abre confirmação, não tela de recuperação |
| Recuperação válida | Pedir redefinição de senha | Mensagem entregue, link válido abre atualização de senha; senha antiga deixa de funcionar |
| Recuperação expirada | Usar link invalidado/expirado | Exibir **Enviar link de recuperação**, jamais **Reenviar confirmação** |
| URL de erro sem tokens | Abrir retorno sintético inválido com `error_code=otp_expired`, hash e parâmetros de autenticação fictícios | Remover tokens, `code`, `token_hash` e fragmento da barra de endereços sem interromper callbacks válidos; validar sem usar tokens reais nos logs/capturas |
| Senha e servidor | Testar uma senha de 7 caracteres e uma de 8 cumprindo política | A de 7 rejeitada pelo servidor; a de 8 aceita se cumprir todos os requisitos |
| Sessão e logout | Entrar, encerrar sessão, navegar e tentar ação protegida | Sessão removida, ações protegidas negadas e retorno ao login |
| Isolamento de papéis | Conta candidato e empresa | Candidato não lê outros candidatos; empresa não altera recursos de outra empresa |
| Arquivos privados | Duas contas técnicas distintas | Download de arquivo próprio permitido; download de arquivo alheio negado por API HTTP |
| Integridade de candidatura via HTTP | Conta candidata e duas vagas (aberta/encerrada) em ambiente autorizado | Rejeitar inscrição na vaga encerrada, status inicial diferente de `novo` e rejeição forjada; não permitir autocontratação; candidatura válida deve funcionar. Executar somente após a migração aprovada. |
| Currículo PDF/Word | Arquivo autorizado com campos editáveis | Extrai e exibe campos para revisão; só persiste após confirmação; cancelar não salva |

## Evidências a registrar sem expor dados
- Data e ambiente; URL pública **sem tokens**; ID do deploy e SHA da produção; nome do caso; resultado aprovado/reprovado; mensagem de erro sem PII; comprovante de recebimento **sem abrir link em ferramenta não confiável**.
- Registrar expiração e recuperação em navegadores e celulares reais; não tomar testes Playwright com configuração fictícia como homologação do backend.
- Limpar os recursos temporários conforme política de retenção e segurança; não apagar dados reais.

## Referências técnicas
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/auth/password-security
- https://supabase.com/docs/reference/javascript/auth-resetpasswordforemail

**Ação bloqueante atual:** PR #89 aguarda revisão humana; Site URL, allowlist, SMTP e política real do servidor ainda precisam ser conferidos no painel autorizado. Não afirmar homologação sem os testes reais acima.
